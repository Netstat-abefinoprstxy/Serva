package app

import "time"

const (
	defaultAddr             = "127.0.0.1:8080"
	defaultImage            = "nginx:alpine"
	defaultContainerPort    = 80
	defaultServiceName      = "sovereignd-service"
	defaultTestServiceName  = "sovereignd-test"
	defaultServiceProtoHTTP = "http"
	defaultLogsTail         = "200"

	managedLabelKey   = "sovereignd.managed"
	managedLabelValue = "true"

	serviceNameLabelKey   = "sovereignd.service"
	hostPortLabelKey      = "sovereignd.host_port"
	containerPortLabelKey = "sovereignd.container_port"
	serviceProtoLabelKey  = "sovereignd.proto"
	bindScopeLabelKey     = "sovereignd.bind"

	bindScopeLocal = "local"
	bindScopeLAN   = "lan"
)

type Service struct {
	ID         string `json:"id"`
	Name       string `json:"name"`
	Image      string `json:"image"`
	State      string `json:"state"`
	Status     string `json:"status"`
	Port       int    `json:"port"`
	LocalURL   string `json:"localUrl"`
	LANURL     string `json:"lanUrl"`
	LanEnabled bool   `json:"lanEnabled"`
}

type CreateServiceRequest struct {
	Name          string                   `json:"name"`
	Image         string                   `json:"image"`
	ContainerPort int                      `json:"containerPort"`
	Mounts        []ServiceDefinitionMount `json:"mounts"`
	Env           []string                 `json:"env"`
}

type ServiceActionResponse struct {
	ID      string `json:"id"`
	Success bool   `json:"success"`
}

type ServiceLogsResponse struct {
	ID     string `json:"id"`
	Name   string `json:"name"`
	Logs   string `json:"logs"`
	Tail   string `json:"tail"`
	Stdout bool   `json:"stdout"`
	Stderr bool   `json:"stderr"`
}

type ServiceStatsResponse struct {
	ID     string         `json:"id"`
	Name   string         `json:"name"`
	ReadAt time.Time      `json:"readAt"`
	Raw    map[string]any `json:"raw"`
}

type ServiceInspectResponse struct {
	ID            string            `json:"id"`
	Name          string            `json:"name"`
	Image         string            `json:"image"`
	State         string            `json:"state"`
	Status        string            `json:"status"`
	Created       string            `json:"created"`
	Path          string            `json:"path"`
	Args          []string          `json:"args"`
	Env           []string          `json:"env"`
	Labels        map[string]string `json:"labels"`
	Ports         []ServicePort     `json:"ports"`
	Mounts        []ServiceMount    `json:"mounts"`
	RestartPolicy string            `json:"restartPolicy"`
	LocalURL      string            `json:"localUrl"`
	LANURL        string            `json:"lanUrl"`
	LanEnabled    bool              `json:"lanEnabled"`
}

type ServicePort struct {
	IP           string `json:"ip"`
	PrivatePort  int    `json:"privatePort"`
	PublicPort   int    `json:"publicPort"`
	Type         string `json:"type"`
	ContainerRef string `json:"containerRef"`
}

type ServiceMount struct {
	Type        string `json:"type"`
	Source      string `json:"source"`
	Destination string `json:"destination"`
	ReadOnly    bool   `json:"readOnly"`
}

type ServiceDefinition struct {
	ID                 string                   `json:"id"`
	Name               string                   `json:"name"`
	Image              string                   `json:"image"`
	ContainerPort      int                      `json:"containerPort"`
	ServiceProto       string                   `json:"serviceProto"`
	LanEnabled         bool                     `json:"lanEnabled"`
	CurrentContainerID string                   `json:"currentContainerId"`
	LastKnownHostPort  int                      `json:"lastKnownHostPort"`
	CreatedAt          time.Time                `json:"createdAt"`
	UpdatedAt          time.Time                `json:"updatedAt"`
	Mounts             []ServiceDefinitionMount `json:"mounts"`
	Env                []string                 `json:"env"`
}

type ServiceDefinitionMount struct {
	Type     string `json:"type"`
	Source   string `json:"source"`
	Target   string `json:"target"`
	ReadOnly bool   `json:"readOnly"`
	Managed  bool   `json:"managed"`
}
