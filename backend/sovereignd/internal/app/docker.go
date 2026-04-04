package app

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"io"
	"log"
	"strconv"
	"strings"
	"time"

	"github.com/docker/docker/api/types"
	"github.com/docker/docker/api/types/container"
	dockermount "github.com/docker/docker/api/types/mount"
	"github.com/docker/docker/client"
	"github.com/docker/docker/pkg/stdcopy"
	"github.com/docker/go-connections/nat"
)

var errManagedContainerRequired = errors.New("not a managed container")

func isManagedContainer(containerSummary types.Container) bool {
	if containerSummary.Labels == nil {
		return false
	}

	return strings.EqualFold(containerSummary.Labels[managedLabelKey], managedLabelValue)
}

func normalizeCreateInput(serviceName string, image string, containerPort int) (string, string, int) {
	if serviceName == "" {
		serviceName = defaultServiceName
	}
	if image == "" {
		image = defaultImage
	}
	if containerPort <= 0 {
		containerPort = defaultContainerPort
	}
	return serviceName, image, containerPort
}

func normalizeMounts(mounts []ServiceDefinitionMount) []ServiceDefinitionMount {
	if mounts == nil {
		return nil
	}

	normalized := make([]ServiceDefinitionMount, 0, len(mounts))
	for _, mount := range mounts {
		mountType := strings.ToLower(strings.TrimSpace(mount.Type))
		if mountType == "" {
			mountType = "bind"
		}

		source := strings.TrimSpace(mount.Source)
		target := strings.TrimSpace(mount.Target)
		if source == "" || target == "" {
			continue
		}

		normalized = append(normalized, ServiceDefinitionMount{
			Type:     mountType,
			Source:   source,
			Target:   target,
			ReadOnly: mount.ReadOnly,
			Managed:  mount.Managed,
		})
	}

	return normalized
}

func normalizeEnv(env []string) []string {
	if env == nil {
		return nil
	}

	normalized := make([]string, 0, len(env))
	for _, entry := range env {
		entry = strings.TrimSpace(entry)
		if entry == "" || !strings.Contains(entry, "=") {
			continue
		}
		normalized = append(normalized, entry)
	}

	return normalized
}

func dockerMounts(definitionMounts []ServiceDefinitionMount) []dockermount.Mount {
	if len(definitionMounts) == 0 {
		return nil
	}

	mounts := make([]dockermount.Mount, 0, len(definitionMounts))
	for _, definitionMount := range definitionMounts {
		mountType := dockermount.TypeBind
		switch definitionMount.Type {
		case "volume":
			mountType = dockermount.TypeVolume
		case "bind":
			mountType = dockermount.TypeBind
		default:
			mountType = dockermount.TypeBind
		}

		mounts = append(mounts, dockermount.Mount{
			Type:     mountType,
			Source:   definitionMount.Source,
			Target:   definitionMount.Target,
			ReadOnly: definitionMount.ReadOnly,
		})
	}

	return mounts
}

func pullImageBestEffort(ctx context.Context, dockerClient *client.Client, image string) {
	rc, err := dockerClient.ImagePull(ctx, image, types.ImagePullOptions{})
	if err != nil {
		return
	}
	defer rc.Close()
	_, _ = io.Copy(io.Discard, rc)
}

func serviceNameFromContainer(containerSummary types.Container) string {
	if len(containerSummary.Names) == 0 || len(containerSummary.Names[0]) == 0 {
		return ""
	}

	if containerSummary.Names[0][0] == '/' {
		return containerSummary.Names[0][1:]
	}

	return containerSummary.Names[0]
}

func publishedHostPort(containerSummary types.Container) int {
	for _, portBinding := range containerSummary.Ports {
		if portBinding.PublicPort != 0 {
			return int(portBinding.PublicPort)
		}
	}
	return 0
}

func hostPortFromInspect(inspected types.ContainerJSON) int {
	if inspected.Config != nil && inspected.Config.Labels != nil {
		if value := strings.TrimSpace(inspected.Config.Labels[hostPortLabelKey]); value != "" {
			if port, err := strconv.Atoi(value); err == nil && port > 0 {
				return port
			}
		}
	}

	if inspected.NetworkSettings == nil {
		return 0
	}

	for _, portBindings := range inspected.NetworkSettings.Ports {
		for _, binding := range portBindings {
			if binding.HostPort == "" {
				continue
			}
			port, err := strconv.Atoi(binding.HostPort)
			if err == nil {
				return port
			}
		}
	}

	return 0
}

func containerPortFromInspect(inspected types.ContainerJSON) int {
	if inspected.Config != nil && inspected.Config.Labels != nil {
		if value := strings.TrimSpace(inspected.Config.Labels[containerPortLabelKey]); value != "" {
			if port, err := strconv.Atoi(value); err == nil && port > 0 {
				return port
			}
		}
	}

	return defaultContainerPort
}

func managedContainerName(inspected types.ContainerJSON) string {
	if inspected.Config != nil && inspected.Config.Labels != nil {
		if value := strings.TrimSpace(inspected.Config.Labels[serviceNameLabelKey]); value != "" {
			return value
		}
	}

	return strings.TrimPrefix(inspected.Name, "/")
}

func isManagedInspect(inspected types.ContainerJSON) bool {
	return inspected.Config != nil &&
		inspected.Config.Labels != nil &&
		strings.EqualFold(inspected.Config.Labels[managedLabelKey], managedLabelValue)
}

func bindScopeFromInspect(inspected types.ContainerJSON) string {
	if inspected.Config == nil || inspected.Config.Labels == nil {
		return ""
	}

	return strings.TrimSpace(inspected.Config.Labels[bindScopeLabelKey])
}

func urlsFromInspect(inspected types.ContainerJSON) (localURL string, lanURL string, lanEnabled bool) {
	hostPort := hostPortFromInspect(inspected)
	if hostPort == 0 {
		return "", "", false
	}

	proto := ""
	if inspected.Config != nil && inspected.Config.Labels != nil {
		proto = strings.TrimSpace(inspected.Config.Labels[serviceProtoLabelKey])
	}

	localURL, lanURL = buildURLs(proto, hostPort)
	bindScope := bindScopeFromInspect(inspected)
	lanEnabled = bindScope == bindScopeLAN
	if !lanEnabled {
		lanURL = ""
	}

	return localURL, lanURL, lanEnabled
}

func servicePortsFromInspect(inspected types.ContainerJSON) []ServicePort {
	if inspected.NetworkSettings == nil {
		return nil
	}

	ports := make([]ServicePort, 0)
	for containerRef, bindings := range inspected.NetworkSettings.Ports {
		privatePort := 0
		parts := strings.SplitN(string(containerRef), "/", 2)
		if len(parts) > 0 {
			if parsed, err := strconv.Atoi(parts[0]); err == nil {
				privatePort = parsed
			}
		}

		if len(bindings) == 0 {
			ports = append(ports, ServicePort{
				PrivatePort:  privatePort,
				Type:         protocolFromPortRef(containerRef),
				ContainerRef: string(containerRef),
			})
			continue
		}

		for _, binding := range bindings {
			publicPort := 0
			if binding.HostPort != "" {
				if parsed, err := strconv.Atoi(binding.HostPort); err == nil {
					publicPort = parsed
				}
			}

			ports = append(ports, ServicePort{
				IP:           binding.HostIP,
				PrivatePort:  privatePort,
				PublicPort:   publicPort,
				Type:         protocolFromPortRef(containerRef),
				ContainerRef: string(containerRef),
			})
		}
	}

	return ports
}

func protocolFromPortRef(portRef nat.Port) string {
	parts := strings.SplitN(string(portRef), "/", 2)
	if len(parts) == 2 {
		return parts[1]
	}
	return ""
}

func serviceMountsFromInspect(inspected types.ContainerJSON) []ServiceMount {
	if len(inspected.Mounts) == 0 {
		return nil
	}

	mounts := make([]ServiceMount, 0, len(inspected.Mounts))
	for _, mount := range inspected.Mounts {
		mounts = append(mounts, ServiceMount{
			Type:        string(mount.Type),
			Source:      mount.Source,
			Destination: mount.Destination,
			ReadOnly:    !mount.RW,
		})
	}

	return mounts
}

func inspectResponseFromContainer(inspected types.ContainerJSON) ServiceInspectResponse {
	state := ""
	status := ""
	image := ""
	env := []string(nil)
	labels := map[string]string(nil)
	if inspected.State != nil {
		state = inspected.State.Status
		status = inspected.State.Status
	}
	if inspected.Config != nil {
		image = inspected.Config.Image
		env = inspected.Config.Env
		labels = inspected.Config.Labels
	}

	restartPolicy := ""
	if inspected.HostConfig != nil {
		restartPolicy = string(inspected.HostConfig.RestartPolicy.Name)
	}

	localURL, lanURL, lanEnabled := urlsFromInspect(inspected)

	return ServiceInspectResponse{
		ID:            inspected.ID,
		Name:          managedContainerName(inspected),
		Image:         image,
		State:         state,
		Status:        status,
		Created:       inspected.Created,
		Path:          inspected.Path,
		Args:          inspected.Args,
		Env:           env,
		Labels:        labels,
		Ports:         servicePortsFromInspect(inspected),
		Mounts:        serviceMountsFromInspect(inspected),
		RestartPolicy: restartPolicy,
		LocalURL:      localURL,
		LANURL:        lanURL,
		LanEnabled:    lanEnabled,
	}
}

func (app *App) managedContainerInspect(ctx context.Context, id string) (types.ContainerJSON, error) {
	dockerClient, err := app.dockerClient()
	if err != nil {
		return types.ContainerJSON{}, err
	}

	inspected, err := dockerClient.ContainerInspect(ctx, id)
	if err != nil {
		return types.ContainerJSON{}, err
	}

	if !isManagedInspect(inspected) {
		return types.ContainerJSON{}, errManagedContainerRequired
	}

	return inspected, nil
}

func (app *App) listManagedServices(ctx context.Context) ([]Service, error) {
	dockerClient, err := app.dockerClient()
	if err != nil {
		return nil, err
	}

	containers, err := dockerClient.ContainerList(ctx, types.ContainerListOptions{All: true})
	if err != nil {
		return nil, err
	}

	services := make([]Service, 0, len(containers))
	for _, containerSummary := range containers {
		if !isManagedContainer(containerSummary) {
			continue
		}

		name := serviceNameFromContainer(containerSummary)
		port := 0
		proto := ""
		bindScope := ""

		if containerSummary.Labels != nil {
			if value := strings.TrimSpace(containerSummary.Labels[hostPortLabelKey]); value != "" {
				if parsedPort, err := strconv.Atoi(value); err == nil {
					port = parsedPort
				}
			}
			proto = strings.TrimSpace(containerSummary.Labels[serviceProtoLabelKey])
			bindScope = strings.TrimSpace(containerSummary.Labels[bindScopeLabelKey])
			if serviceLabel := strings.TrimSpace(containerSummary.Labels[serviceNameLabelKey]); serviceLabel != "" {
				name = serviceLabel
			}
		}

		if port == 0 {
			port = publishedHostPort(containerSummary)
		}

		localURL, lanURL := "", ""
		lanEnabled := bindScope == bindScopeLAN
		if port != 0 {
			localURL, lanURL = buildURLs(proto, port)
			if bindScope != bindScopeLAN {
				lanURL = ""
			}
		}

		services = append(services, Service{
			ID:         containerSummary.ID,
			Name:       name,
			Image:      containerSummary.Image,
			State:      containerSummary.State,
			Status:     containerSummary.Status,
			Port:       port,
			LocalURL:   localURL,
			LANURL:     lanURL,
			LanEnabled: lanEnabled,
		})
	}

	return services, nil
}

func (app *App) createManagedService(
	ctx context.Context,
	serviceName string,
	image string,
	containerPort int,
	mounts []ServiceDefinitionMount,
	env []string,
) (id string, hostPort int, localURL string, lanURL string, err error) {
	serviceName, image, containerPort = normalizeCreateInput(serviceName, image, containerPort)
	mounts = normalizeMounts(mounts)
	env = normalizeEnv(env)

	hostPort, err = getFreeLocalPort()
	log.Printf("[create] name=%s image=%s containerPort=%d", serviceName, image, containerPort)
	if err != nil {
		return "", 0, "", "", err
	}

	proto := defaultServiceProtoHTTP
	dockerClient, err := app.dockerClient()
	if err != nil {
		return "", 0, "", "", err
	}
	pullImageBestEffort(ctx, dockerClient, image)

	portSpec := nat.Port(strconv.Itoa(containerPort) + "/tcp")
	labels := map[string]string{
		managedLabelKey:       managedLabelValue,
		serviceNameLabelKey:   serviceName,
		hostPortLabelKey:      strconv.Itoa(hostPort),
		containerPortLabelKey: strconv.Itoa(containerPort),
		serviceProtoLabelKey:  proto,
		bindScopeLabelKey:     bindScopeLocal,
	}

	resp, err := dockerClient.ContainerCreate(
		ctx,
		&container.Config{
			Image:        image,
			Labels:       labels,
			ExposedPorts: nat.PortSet{portSpec: struct{}{}},
			Env:          env,
		},
		&container.HostConfig{
			Mounts: dockerMounts(mounts),
			PortBindings: nat.PortMap{
				portSpec: []nat.PortBinding{{HostIP: "127.0.0.1", HostPort: strconv.Itoa(hostPort)}},
			},
		},
		nil,
		nil,
		serviceName,
	)
	log.Printf("[create] container created id=%s hostPort=%d", resp.ID, hostPort)
	if err != nil {
		return "", 0, "", "", err
	}

	if err := dockerClient.ContainerStart(ctx, resp.ID, types.ContainerStartOptions{}); err != nil {
		return "", 0, "", "", err
	}
	log.Printf("[create] container started id=%s", resp.ID)

	localURL, lanURL = buildURLs(proto, hostPort)
	return resp.ID, hostPort, localURL, lanURL, nil
}

func (app *App) createManagedServiceWithBinding(
	ctx context.Context,
	serviceName string,
	image string,
	containerPort int,
	hostPort int,
	hostIP string,
	bindScope string,
	mounts []ServiceDefinitionMount,
	env []string,
) (id string, outHostPort int, localURL string, lanURL string, err error) {
	serviceName, image, containerPort = normalizeCreateInput(serviceName, image, containerPort)
	mounts = normalizeMounts(mounts)
	env = normalizeEnv(env)

	if hostPort == 0 {
		hostPort, err = getFreeLocalPort()
		log.Printf("[create-bind] name=%s image=%s containerPort=%d hostPort=%d hostIP=%s scope=%s", serviceName, image, containerPort, hostPort, hostIP, bindScope)
		if err != nil {
			return "", 0, "", "", err
		}
	}

	if hostIP == "" {
		hostIP = "127.0.0.1"
	}
	if bindScope == "" {
		bindScope = bindScopeLocal
	}

	proto := defaultServiceProtoHTTP
	dockerClient, err := app.dockerClient()
	if err != nil {
		return "", 0, "", "", err
	}
	pullImageBestEffort(ctx, dockerClient, image)

	portSpec := nat.Port(strconv.Itoa(containerPort) + "/tcp")
	labels := map[string]string{
		managedLabelKey:       managedLabelValue,
		serviceNameLabelKey:   serviceName,
		hostPortLabelKey:      strconv.Itoa(hostPort),
		containerPortLabelKey: strconv.Itoa(containerPort),
		serviceProtoLabelKey:  proto,
		bindScopeLabelKey:     bindScope,
	}

	resp, err := dockerClient.ContainerCreate(
		ctx,
		&container.Config{
			Image:        image,
			Labels:       labels,
			ExposedPorts: nat.PortSet{portSpec: struct{}{}},
			Env:          env,
		},
		&container.HostConfig{
			Mounts: dockerMounts(mounts),
			PortBindings: nat.PortMap{
				portSpec: []nat.PortBinding{{HostIP: hostIP, HostPort: strconv.Itoa(hostPort)}},
			},
		},
		nil,
		nil,
		serviceName,
	)
	log.Printf("[create-bind] container created id=%s", resp.ID)
	if err != nil {
		return "", 0, "", "", err
	}

	if err := dockerClient.ContainerStart(ctx, resp.ID, types.ContainerStartOptions{}); err != nil {
		return "", 0, "", "", err
	}

	log.Printf("[create-bind] container started id=%s", resp.ID)
	localURL, lanURL = buildURLs(proto, hostPort)
	if bindScope != bindScopeLAN {
		lanURL = ""
	}

	return resp.ID, hostPort, localURL, lanURL, nil
}

func (app *App) serviceLogs(ctx context.Context, id string, tail string, stdout bool, stderr bool) (ServiceLogsResponse, error) {
	inspected, err := app.managedContainerInspect(ctx, id)
	if err != nil {
		return ServiceLogsResponse{}, err
	}

	includeStdout, includeStderr := resolveLogStreams(stdout, stderr)
	tail = defaultString(tail, defaultLogsTail)

	dockerClient, err := app.dockerClient()
	if err != nil {
		return ServiceLogsResponse{}, err
	}

	reader, err := dockerClient.ContainerLogs(ctx, id, container.LogsOptions{
		ShowStdout: includeStdout,
		ShowStderr: includeStderr,
		Tail:       tail,
	})
	if err != nil {
		return ServiceLogsResponse{}, err
	}
	defer reader.Close()

	var stdoutBuffer bytes.Buffer
	var stderrBuffer bytes.Buffer
	_, err = stdcopy.StdCopy(&stdoutBuffer, &stderrBuffer, reader)
	if err != nil {
		return ServiceLogsResponse{}, err
	}

	logs := stdoutBuffer.String()
	if includeStdout && includeStderr {
		logs += stderrBuffer.String()
	} else if includeStderr {
		logs = stderrBuffer.String()
	}

	return ServiceLogsResponse{
		ID:     inspected.ID,
		Name:   managedContainerName(inspected),
		Logs:   logs,
		Tail:   tail,
		Stdout: includeStdout,
		Stderr: includeStderr,
	}, nil
}

func (app *App) serviceStats(ctx context.Context, id string) (ServiceStatsResponse, error) {
	inspected, err := app.managedContainerInspect(ctx, id)
	if err != nil {
		return ServiceStatsResponse{}, err
	}

	dockerClient, err := app.dockerClient()
	if err != nil {
		return ServiceStatsResponse{}, err
	}

	response, err := dockerClient.ContainerStats(ctx, id, false)
	if err != nil {
		return ServiceStatsResponse{}, err
	}
	defer response.Body.Close()

	var payload map[string]any
	if err := json.NewDecoder(response.Body).Decode(&payload); err != nil {
		return ServiceStatsResponse{}, err
	}

	readAt := response.OSType
	_ = readAt

	return ServiceStatsResponse{
		ID:     inspected.ID,
		Name:   managedContainerName(inspected),
		ReadAt: statsReadTime(payload),
		Raw:    payload,
	}, nil
}

func statsReadTime(payload map[string]any) time.Time {
	if value, ok := payload["read"].(string); ok && value != "" {
		if parsed, err := time.Parse(time.RFC3339Nano, value); err == nil {
			return parsed
		}
	}
	return time.Time{}
}

func (app *App) serviceInspect(ctx context.Context, id string) (ServiceInspectResponse, error) {
	inspected, err := app.managedContainerInspect(ctx, id)
	if err != nil {
		return ServiceInspectResponse{}, err
	}

	return inspectResponseFromContainer(inspected), nil
}

func (app *App) restartManagedContainer(ctx context.Context, id string) error {
	if _, err := app.managedContainerInspect(ctx, id); err != nil {
		return err
	}

	dockerClient, err := app.dockerClient()
	if err != nil {
		return err
	}

	return dockerClient.ContainerRestart(ctx, id, container.StopOptions{})
}

func (app *App) removeManagedContainer(ctx context.Context, id string) error {
	if _, err := app.managedContainerInspect(ctx, id); err != nil {
		return err
	}

	dockerClient, err := app.dockerClient()
	if err != nil {
		return err
	}

	return dockerClient.ContainerRemove(ctx, id, types.ContainerRemoveOptions{Force: true})
}

func resolveLogStreams(stdout bool, stderr bool) (bool, bool) {
	if !stdout && !stderr {
		return true, true
	}
	return stdout, stderr
}

func defaultString(value string, fallback string) string {
	if strings.TrimSpace(value) == "" {
		return fallback
	}
	return value
}
