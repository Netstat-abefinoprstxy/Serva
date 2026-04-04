package app

import (
	"context"
	"fmt"
	"log"
	"net/http"
	"sync"

	"github.com/docker/docker/client"
)

type App struct {
	docker      *client.Client
	dockerMu    sync.Mutex
	definitions *definitionStore
}

func Run() error {
	definitions, err := newDefinitionStore()
	if err != nil {
		return fmt.Errorf("definition store init failed: %w", err)
	}

	app := &App{
		definitions: definitions,
	}
	log.Printf("sovereignd listening on %s", defaultAddr)
	return http.ListenAndServe(defaultAddr, app.routes())
}

func (app *App) dockerClient() (*client.Client, error) {
	app.dockerMu.Lock()
	defer app.dockerMu.Unlock()

	if app.docker != nil {
		if _, err := app.docker.Ping(context.Background()); err == nil {
			return app.docker, nil
		}
		_ = app.docker.Close()
		app.docker = nil
	}

	dockerClient, err := client.NewClientWithOpts(client.FromEnv, client.WithAPIVersionNegotiation())
	if err != nil {
		return nil, fmt.Errorf("docker client init failed: %w", err)
	}

	if _, err := dockerClient.Ping(context.Background()); err != nil {
		_ = dockerClient.Close()
		return nil, fmt.Errorf("docker ping failed: %w", err)
	}

	app.docker = dockerClient
	return app.docker, nil
}
