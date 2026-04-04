package app

import (
	"context"
	"encoding/json"
	"errors"
	"log"
	"net/http"
	"strconv"
	"strings"
	"time"

	"github.com/docker/docker/api/types"
	"github.com/docker/docker/api/types/container"
)

func (app *App) routes() http.Handler {
	mux := http.NewServeMux()
	mux.HandleFunc("/health", app.handleHealth)
	mux.HandleFunc("/services", app.handleListServices)
	mux.HandleFunc("/service-definitions", app.handleListServiceDefinitions)
	mux.HandleFunc("/service-definitions/delete", app.handleDeleteServiceDefinition)
	mux.HandleFunc("/services/create-test", app.handleCreateTestService)
	mux.HandleFunc("/services/create", app.handleCreateService)
	mux.HandleFunc("/services/recreate", app.handleRecreateService)
	mux.HandleFunc("/services/expose-lan", app.handleExposeLAN)
	mux.HandleFunc("/services/start", app.handleStartService)
	mux.HandleFunc("/services/stop", app.handleStopService)
	mux.HandleFunc("/services/restart", app.handleRestartService)
	mux.HandleFunc("/services/remove", app.handleRemoveService)
	mux.HandleFunc("/services/logs", app.handleServiceLogs)
	mux.HandleFunc("/services/stats", app.handleServiceStats)
	mux.HandleFunc("/services/inspect", app.handleServiceInspect)
	return mux
}

func (app *App) handleHealth(w http.ResponseWriter, _ *http.Request) {
	if _, err := app.dockerClient(); err != nil {
		http.Error(w, "docker unavailable: "+err.Error(), http.StatusServiceUnavailable)
		return
	}
	writeJSON(w, http.StatusOK, map[string]bool{"ok": true})
}

func (app *App) handleListServices(w http.ResponseWriter, r *http.Request) {
	log.Printf("[services] request from=%s method=%s", r.RemoteAddr, r.Method)
	ctx, cancel := context.WithTimeout(r.Context(), 5*time.Second)
	defer cancel()

	services, err := app.listManagedServices(ctx)
	if err != nil {
		log.Printf("[services] docker list failed: %v", err)
		http.Error(w, "docker list failed: "+err.Error(), http.StatusInternalServerError)
		return
	}

	writeJSON(w, http.StatusOK, services)
}

func (app *App) handleListServiceDefinitions(w http.ResponseWriter, r *http.Request) {
	log.Printf("[service-definitions] request from=%s method=%s", r.RemoteAddr, r.Method)
	if r.Method != http.MethodGet {
		http.Error(w, "GET required", http.StatusMethodNotAllowed)
		return
	}

	definitions, err := app.listServiceDefinitions()
	if err != nil {
		http.Error(w, "definition list failed: "+err.Error(), http.StatusInternalServerError)
		return
	}

	writeJSON(w, http.StatusOK, definitions)
}

func (app *App) handleDeleteServiceDefinition(w http.ResponseWriter, r *http.Request) {
	log.Printf("[service-definitions/delete] request from=%s method=%s query=%s", r.RemoteAddr, r.Method, r.URL.RawQuery)
	if r.Method != http.MethodDelete {
		http.Error(w, "DELETE required", http.StatusMethodNotAllowed)
		return
	}

	id := strings.TrimSpace(r.URL.Query().Get("id"))
	if id == "" {
		http.Error(w, "missing id", http.StatusBadRequest)
		return
	}

	deleteDataValue := strings.TrimSpace(r.URL.Query().Get("deleteData"))
	deleteData := strings.EqualFold(deleteDataValue, "true") || deleteDataValue == "1" || strings.EqualFold(deleteDataValue, "yes")

	definition, found, err := app.getServiceDefinition(id)
	if err != nil {
		http.Error(w, "definition lookup failed: "+err.Error(), http.StatusInternalServerError)
		return
	}
	if !found {
		http.Error(w, "definition not found", http.StatusNotFound)
		return
	}
	if definition.CurrentContainerID != "" {
		http.Error(w, "definition is still deployed; remove the container first", http.StatusConflict)
		return
	}

	if deleteData {
		if err := app.deleteManagedDefinitionData(r.Context(), definition); err != nil {
			http.Error(w, "delete managed data failed: "+err.Error(), http.StatusInternalServerError)
			return
		}
	}

	if err := app.deleteServiceDefinition(id); err != nil {
		http.Error(w, "definition delete failed: "+err.Error(), http.StatusInternalServerError)
		return
	}

	writeJSON(w, http.StatusOK, map[string]any{
		"id":          id,
		"success":     true,
		"deletedData": deleteData,
	})
}

func (app *App) handleCreateTestService(w http.ResponseWriter, r *http.Request) {
	log.Printf("[create-test] request from=%s method=%s", r.RemoteAddr, r.Method)
	if r.Method != http.MethodPost {
		http.Error(w, "POST required", http.StatusMethodNotAllowed)
		return
	}

	ctx, cancel := context.WithTimeout(r.Context(), 60*time.Second)
	defer cancel()

	id, port, localURL, lanURL, err := app.createManagedService(
		ctx,
		defaultTestServiceName,
		defaultImage,
		defaultContainerPort,
		nil,
		nil,
	)
	if err != nil {
		log.Printf("[create-test] create failed: %v", err)
		http.Error(w, "create failed: "+err.Error(), http.StatusConflict)
		return
	}
	if err := app.persistServiceDefinition(defaultTestServiceName, defaultImage, defaultContainerPort, id, port, false, nil, nil); err != nil {
		log.Printf("[create-test] persist definition failed: %v", err)
		http.Error(w, "persist definition failed: "+err.Error(), http.StatusInternalServerError)
		return
	}

	log.Printf("[create-test] success id=%s port=%d local=%s", id, port, localURL)
	writeJSON(w, http.StatusCreated, map[string]any{
		"id":       id,
		"name":     defaultTestServiceName,
		"port":     port,
		"localUrl": localURL,
		"lanUrl":   lanURL,
	})
}

func (app *App) handleCreateService(w http.ResponseWriter, r *http.Request) {
	log.Printf("[create] request from=%s method=%s", r.RemoteAddr, r.Method)
	if r.Method != http.MethodPost {
		http.Error(w, "POST required", http.StatusMethodNotAllowed)
		return
	}

	var req CreateServiceRequest
	contentType := strings.ToLower(strings.TrimSpace(r.Header.Get("Content-Type")))
	if strings.Contains(contentType, "application/json") {
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			log.Printf("[create] invalid json: %v", err)
			http.Error(w, "invalid json: "+err.Error(), http.StatusBadRequest)
			return
		}
	} else {
		req.Name = strings.TrimSpace(r.URL.Query().Get("name"))
		req.Image = strings.TrimSpace(r.URL.Query().Get("image"))
		if value := strings.TrimSpace(r.URL.Query().Get("containerPort")); value != "" {
			if parsedPort, err := strconv.Atoi(value); err == nil && parsedPort > 0 {
				req.ContainerPort = parsedPort
			}
		}
	}

	serviceName, image, containerPort := normalizeCreateInput(
		strings.TrimSpace(req.Name),
		strings.TrimSpace(req.Image),
		req.ContainerPort,
	)
	mounts := normalizeMounts(req.Mounts)
	env := normalizeEnv(req.Env)

	log.Printf("[create] name=%s image=%s containerPort=%d", serviceName, image, containerPort)

	ctx, cancel := context.WithTimeout(r.Context(), 60*time.Second)
	defer cancel()

	id, port, localURL, lanURL, err := app.createManagedService(ctx, serviceName, image, containerPort, mounts, env)
	if err != nil {
		log.Printf("[create] create failed: %v", err)
		http.Error(w, "create failed: "+err.Error(), http.StatusConflict)
		return
	}
	if err := app.persistServiceDefinition(serviceName, image, containerPort, id, port, false, mounts, env); err != nil {
		log.Printf("[create] persist definition failed: %v", err)
		http.Error(w, "persist definition failed: "+err.Error(), http.StatusInternalServerError)
		return
	}

	log.Printf("[create] success id=%s port=%d local=%s", id, port, localURL)
	writeJSON(w, http.StatusCreated, map[string]any{
		"id":       id,
		"name":     serviceName,
		"port":     port,
		"localUrl": localURL,
		"lanUrl":   lanURL,
	})
}

func (app *App) handleExposeLAN(w http.ResponseWriter, r *http.Request) {
	log.Printf("[expose-lan] request from=%s method=%s query=%s", r.RemoteAddr, r.Method, r.URL.RawQuery)
	if r.Method != http.MethodPost {
		http.Error(w, "POST required", http.StatusMethodNotAllowed)
		return
	}

	id := strings.TrimSpace(r.URL.Query().Get("id"))
	if id == "" {
		http.Error(w, "missing id", http.StatusBadRequest)
		return
	}

	enabledValue := strings.TrimSpace(r.URL.Query().Get("enabled"))
	enabled := strings.EqualFold(enabledValue, "true") || enabledValue == "1" || strings.EqualFold(enabledValue, "yes")
	log.Printf("[expose-lan] parsed id=%s enabled=%v", id, enabled)

	ctx, cancel := context.WithTimeout(r.Context(), 60*time.Second)
	defer cancel()

	inspected, err := app.managedContainerInspect(ctx, id)
	if err != nil {
		writeManagedContainerError(w, "inspect failed", err)
		return
	}
	log.Printf("[expose-lan] inspected name=%s image=%s", inspected.Name, inspected.Config.Image)

	serviceName := managedContainerName(inspected)
	image := inspected.Config.Image
	containerPort := containerPortFromInspect(inspected)
	hostPort := hostPortFromInspect(inspected)
	definition, _, err := app.getServiceDefinition(serviceName)
	if err != nil {
		http.Error(w, "definition lookup failed: "+err.Error(), http.StatusInternalServerError)
		return
	}

	log.Printf("[expose-lan] stopping + removing container id=%s", id)
	dockerClient, err := app.dockerClient()
	if err != nil {
		http.Error(w, "docker unavailable: "+err.Error(), http.StatusServiceUnavailable)
		return
	}
	_ = dockerClient.ContainerStop(ctx, id, container.StopOptions{})
	if err := dockerClient.ContainerRemove(ctx, id, types.ContainerRemoveOptions{Force: true}); err != nil {
		http.Error(w, "remove failed: "+err.Error(), http.StatusInternalServerError)
		return
	}

	hostIP := "127.0.0.1"
	bindScope := bindScopeLocal
	if enabled {
		hostIP = "0.0.0.0"
		bindScope = bindScopeLAN
	}
	log.Printf("[expose-lan] binding hostIP=%s scope=%s", hostIP, bindScope)

	newID, newPort, localURL, lanURL, err := app.createManagedServiceWithBinding(
		ctx,
		serviceName,
		image,
		containerPort,
		hostPort,
		hostIP,
		bindScope,
		definition.Mounts,
		definition.Env,
	)
	if err != nil {
		http.Error(w, "recreate failed: "+err.Error(), http.StatusInternalServerError)
		return
	}
	if err := app.persistServiceDefinition(serviceName, image, containerPort, newID, newPort, enabled, nil, nil); err != nil {
		log.Printf("[expose-lan] persist definition failed: %v", err)
		http.Error(w, "persist definition failed: "+err.Error(), http.StatusInternalServerError)
		return
	}
	log.Printf("[expose-lan] success newID=%s local=%s lan=%s", newID, localURL, lanURL)

	writeJSON(w, http.StatusOK, map[string]any{
		"id":       newID,
		"name":     serviceName,
		"port":     newPort,
		"localUrl": localURL,
		"lanUrl":   lanURL,
		"enabled":  enabled,
	})
}

func (app *App) handleRecreateService(w http.ResponseWriter, r *http.Request) {
	log.Printf("[recreate] request from=%s method=%s query=%s", r.RemoteAddr, r.Method, r.URL.RawQuery)
	if r.Method != http.MethodPost {
		http.Error(w, "POST required", http.StatusMethodNotAllowed)
		return
	}

	id := strings.TrimSpace(r.URL.Query().Get("id"))
	if id == "" {
		http.Error(w, "missing id", http.StatusBadRequest)
		return
	}

	definition, found, err := app.getServiceDefinition(id)
	if err != nil {
		http.Error(w, "definition lookup failed: "+err.Error(), http.StatusInternalServerError)
		return
	}
	if !found {
		http.Error(w, "definition not found", http.StatusNotFound)
		return
	}

	ctx, cancel := context.WithTimeout(r.Context(), 60*time.Second)
	defer cancel()

	hostIP := "127.0.0.1"
	bindScope := bindScopeLocal
	if definition.LanEnabled {
		hostIP = "0.0.0.0"
		bindScope = bindScopeLAN
	}

	newID, newPort, localURL, lanURL, err := app.createManagedServiceWithBinding(
		ctx,
		definition.Name,
		definition.Image,
		definition.ContainerPort,
		definition.LastKnownHostPort,
		hostIP,
		bindScope,
		definition.Mounts,
		definition.Env,
	)
	if err != nil {
		http.Error(w, "recreate failed: "+err.Error(), http.StatusConflict)
		return
	}

	if err := app.persistServiceDefinition(
		definition.Name,
		definition.Image,
		definition.ContainerPort,
		newID,
		newPort,
		definition.LanEnabled,
		definition.Mounts,
		definition.Env,
	); err != nil {
		http.Error(w, "persist definition failed: "+err.Error(), http.StatusInternalServerError)
		return
	}

	writeJSON(w, http.StatusOK, map[string]any{
		"id":       newID,
		"name":     definition.Name,
		"port":     newPort,
		"localUrl": localURL,
		"lanUrl":   lanURL,
	})
}

func (app *App) handleStartService(w http.ResponseWriter, r *http.Request) {
	log.Printf("[start] request from=%s method=%s query=%s", r.RemoteAddr, r.Method, r.URL.RawQuery)
	if r.Method != http.MethodPost {
		http.Error(w, "POST required", http.StatusMethodNotAllowed)
		return
	}

	id := r.URL.Query().Get("id")
	if id == "" {
		log.Printf("[start] missing id")
		http.Error(w, "missing id", http.StatusBadRequest)
		return
	}

	ctx, cancel := context.WithTimeout(r.Context(), 10*time.Second)
	defer cancel()

	inspected, err := app.managedContainerInspect(ctx, id)
	if err != nil {
		log.Printf("[start] inspect failed: %v", err)
		writeManagedContainerError(w, "inspect failed", err)
		return
	}
	log.Printf("[start] inspected name=%s image=%s", inspected.Name, inspected.Config.Image)

	dockerClient, err := app.dockerClient()
	if err != nil {
		http.Error(w, "docker unavailable: "+err.Error(), http.StatusServiceUnavailable)
		return
	}
	if err := dockerClient.ContainerStart(ctx, id, types.ContainerStartOptions{}); err != nil {
		log.Printf("[start] start failed: %v", err)
		http.Error(w, "start failed: "+err.Error(), http.StatusInternalServerError)
		return
	}
	if err := app.syncServiceDefinitionFromInspect(inspectResponseFromContainer(inspected)); err != nil {
		log.Printf("[start] definition sync failed id=%s err=%v", id, err)
		http.Error(w, "definition sync failed: "+err.Error(), http.StatusInternalServerError)
		return
	}

	log.Printf("[start] success id=%s", id)
	w.WriteHeader(http.StatusNoContent)
}

func (app *App) handleStopService(w http.ResponseWriter, r *http.Request) {
	log.Printf("[stop] request from=%s method=%s query=%s", r.RemoteAddr, r.Method, r.URL.RawQuery)
	if r.Method != http.MethodPost {
		http.Error(w, "POST required", http.StatusMethodNotAllowed)
		return
	}

	id := r.URL.Query().Get("id")
	if id == "" {
		log.Printf("[stop] missing id")
		http.Error(w, "missing id", http.StatusBadRequest)
		return
	}

	ctx, cancel := context.WithTimeout(r.Context(), 10*time.Second)
	defer cancel()

	inspected, err := app.managedContainerInspect(ctx, id)
	if err != nil {
		log.Printf("[stop] inspect failed: %v", err)
		writeManagedContainerError(w, "inspect failed", err)
		return
	}
	log.Printf("[stop] inspected name=%s image=%s", inspected.Name, inspected.Config.Image)

	dockerClient, err := app.dockerClient()
	if err != nil {
		http.Error(w, "docker unavailable: "+err.Error(), http.StatusServiceUnavailable)
		return
	}
	if err := dockerClient.ContainerStop(ctx, id, container.StopOptions{}); err != nil {
		log.Printf("[stop] stop failed: %v", err)
		http.Error(w, "stop failed: "+err.Error(), http.StatusInternalServerError)
		return
	}
	if err := app.syncServiceDefinitionFromInspect(inspectResponseFromContainer(inspected)); err != nil {
		log.Printf("[stop] definition sync failed id=%s err=%v", id, err)
		http.Error(w, "definition sync failed: "+err.Error(), http.StatusInternalServerError)
		return
	}

	log.Printf("[stop] success id=%s", id)
	w.WriteHeader(http.StatusNoContent)
}

func (app *App) handleRestartService(w http.ResponseWriter, r *http.Request) {
	log.Printf("[restart] request from=%s method=%s query=%s", r.RemoteAddr, r.Method, r.URL.RawQuery)
	if r.Method != http.MethodPost {
		http.Error(w, "POST required", http.StatusMethodNotAllowed)
		return
	}

	id := strings.TrimSpace(r.URL.Query().Get("id"))
	if id == "" {
		http.Error(w, "missing id", http.StatusBadRequest)
		return
	}

	ctx, cancel := context.WithTimeout(r.Context(), 20*time.Second)
	defer cancel()

	if err := app.restartManagedContainer(ctx, id); err != nil {
		log.Printf("[restart] failed id=%s err=%v", id, err)
		writeManagedContainerError(w, "restart failed", err)
		return
	}
	inspected, err := app.managedContainerInspect(ctx, id)
	if err == nil {
		if syncErr := app.syncServiceDefinitionFromInspect(inspectResponseFromContainer(inspected)); syncErr != nil {
			log.Printf("[restart] definition sync failed id=%s err=%v", id, syncErr)
			http.Error(w, "definition sync failed: "+syncErr.Error(), http.StatusInternalServerError)
			return
		}
	}

	log.Printf("[restart] success id=%s", id)
	writeJSON(w, http.StatusOK, ServiceActionResponse{ID: id, Success: true})
}

func (app *App) handleRemoveService(w http.ResponseWriter, r *http.Request) {
	log.Printf("[remove] request from=%s method=%s query=%s", r.RemoteAddr, r.Method, r.URL.RawQuery)
	if r.Method != http.MethodDelete {
		http.Error(w, "DELETE required", http.StatusMethodNotAllowed)
		return
	}

	id := strings.TrimSpace(r.URL.Query().Get("id"))
	if id == "" {
		http.Error(w, "missing id", http.StatusBadRequest)
		return
	}

	ctx, cancel := context.WithTimeout(r.Context(), 20*time.Second)
	defer cancel()

	inspected, err := app.managedContainerInspect(ctx, id)
	if err != nil {
		log.Printf("[remove] inspect failed id=%s err=%v", id, err)
		writeManagedContainerError(w, "inspect failed", err)
		return
	}

	if err := app.removeManagedContainer(ctx, id); err != nil {
		log.Printf("[remove] failed id=%s err=%v", id, err)
		writeManagedContainerError(w, "remove failed", err)
		return
	}
	if err := app.markServiceDefinitionContainerRemoved(managedContainerName(inspected)); err != nil {
		log.Printf("[remove] definition sync failed id=%s err=%v", id, err)
		http.Error(w, "definition sync failed: "+err.Error(), http.StatusInternalServerError)
		return
	}

	log.Printf("[remove] success id=%s", id)
	writeJSON(w, http.StatusOK, ServiceActionResponse{ID: id, Success: true})
}

func (app *App) handleServiceLogs(w http.ResponseWriter, r *http.Request) {
	log.Printf("[logs] request from=%s method=%s query=%s", r.RemoteAddr, r.Method, r.URL.RawQuery)
	if r.Method != http.MethodGet {
		http.Error(w, "GET required", http.StatusMethodNotAllowed)
		return
	}

	id := strings.TrimSpace(r.URL.Query().Get("id"))
	if id == "" {
		http.Error(w, "missing id", http.StatusBadRequest)
		return
	}

	stdout, stdoutSet := parseBoolQuery(r, "stdout")
	stderr, stderrSet := parseBoolQuery(r, "stderr")
	if !stdoutSet && !stderrSet {
		stdout = true
		stderr = true
	}

	ctx, cancel := context.WithTimeout(r.Context(), 20*time.Second)
	defer cancel()

	response, err := app.serviceLogs(ctx, id, strings.TrimSpace(r.URL.Query().Get("tail")), stdout, stderr)
	if err != nil {
		log.Printf("[logs] failed id=%s err=%v", id, err)
		writeManagedContainerError(w, "logs failed", err)
		return
	}

	writeJSON(w, http.StatusOK, response)
}

func (app *App) handleServiceStats(w http.ResponseWriter, r *http.Request) {
	log.Printf("[stats] request from=%s method=%s query=%s", r.RemoteAddr, r.Method, r.URL.RawQuery)
	if r.Method != http.MethodGet {
		http.Error(w, "GET required", http.StatusMethodNotAllowed)
		return
	}

	id := strings.TrimSpace(r.URL.Query().Get("id"))
	if id == "" {
		http.Error(w, "missing id", http.StatusBadRequest)
		return
	}

	ctx, cancel := context.WithTimeout(r.Context(), 20*time.Second)
	defer cancel()

	response, err := app.serviceStats(ctx, id)
	if err != nil {
		log.Printf("[stats] failed id=%s err=%v", id, err)
		writeManagedContainerError(w, "stats failed", err)
		return
	}

	writeJSON(w, http.StatusOK, response)
}

func (app *App) handleServiceInspect(w http.ResponseWriter, r *http.Request) {
	log.Printf("[inspect] request from=%s method=%s query=%s", r.RemoteAddr, r.Method, r.URL.RawQuery)
	if r.Method != http.MethodGet {
		http.Error(w, "GET required", http.StatusMethodNotAllowed)
		return
	}

	id := strings.TrimSpace(r.URL.Query().Get("id"))
	if id == "" {
		http.Error(w, "missing id", http.StatusBadRequest)
		return
	}

	ctx, cancel := context.WithTimeout(r.Context(), 20*time.Second)
	defer cancel()

	response, err := app.serviceInspect(ctx, id)
	if err != nil {
		log.Printf("[inspect] failed id=%s err=%v", id, err)
		writeManagedContainerError(w, "inspect failed", err)
		return
	}

	writeJSON(w, http.StatusOK, response)
}

func writeManagedContainerError(w http.ResponseWriter, prefix string, err error) {
	if errors.Is(err, errManagedContainerRequired) {
		http.Error(w, errManagedContainerRequired.Error(), http.StatusForbidden)
		return
	}

	http.Error(w, prefix+": "+err.Error(), http.StatusInternalServerError)
}

func parseBoolQuery(r *http.Request, key string) (bool, bool) {
	value := strings.TrimSpace(r.URL.Query().Get(key))
	if value == "" {
		return false, false
	}

	switch strings.ToLower(value) {
	case "1", "true", "yes", "on":
		return true, true
	case "0", "false", "no", "off":
		return false, true
	default:
		return false, false
	}
}
