package app

import (
	"context"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"slices"
	"sync"
	"time"
)

const definitionStoreVersion = 1

type definitionStore struct {
	path string
	mu   sync.Mutex
}

type persistedDefinitions struct {
	Version     int                 `json:"version"`
	Definitions []ServiceDefinition `json:"definitions"`
}

func newDefinitionStore() (*definitionStore, error) {
	configDir, err := os.UserConfigDir()
	if err != nil {
		return nil, fmt.Errorf("resolve user config dir: %w", err)
	}

	baseDir := filepath.Join(configDir, "sovereignd")
	if err := os.MkdirAll(baseDir, 0o755); err != nil {
		return nil, fmt.Errorf("create config dir: %w", err)
	}

	store := &definitionStore{
		path: filepath.Join(baseDir, "service-definitions.json"),
	}

	if err := store.ensureFile(); err != nil {
		return nil, err
	}

	return store, nil
}

func (store *definitionStore) ensureFile() error {
	if _, err := os.Stat(store.path); err == nil {
		return nil
	} else if !os.IsNotExist(err) {
		return fmt.Errorf("stat definition store: %w", err)
	}

	return store.writeAllLocked(persistedDefinitions{
		Version:     definitionStoreVersion,
		Definitions: []ServiceDefinition{},
	})
}

func (store *definitionStore) upsert(definition ServiceDefinition) error {
	store.mu.Lock()
	defer store.mu.Unlock()

	data, err := store.readAllLocked()
	if err != nil {
		return err
	}

	index := slices.IndexFunc(data.Definitions, func(existing ServiceDefinition) bool {
		return existing.ID == definition.ID
	})
	if index >= 0 {
		data.Definitions[index] = definition
	} else {
		data.Definitions = append(data.Definitions, definition)
	}

	return store.writeAllLocked(data)
}

func (store *definitionStore) deleteByID(id string) error {
	store.mu.Lock()
	defer store.mu.Unlock()

	data, err := store.readAllLocked()
	if err != nil {
		return err
	}

	data.Definitions = slices.DeleteFunc(data.Definitions, func(definition ServiceDefinition) bool {
		return definition.ID == id
	})

	return store.writeAllLocked(data)
}

func (store *definitionStore) getByID(id string) (ServiceDefinition, bool, error) {
	store.mu.Lock()
	defer store.mu.Unlock()

	data, err := store.readAllLocked()
	if err != nil {
		return ServiceDefinition{}, false, err
	}

	for _, definition := range data.Definitions {
		if definition.ID == id {
			return definition, true, nil
		}
	}

	return ServiceDefinition{}, false, nil
}

func (store *definitionStore) list() ([]ServiceDefinition, error) {
	store.mu.Lock()
	defer store.mu.Unlock()

	data, err := store.readAllLocked()
	if err != nil {
		return nil, err
	}

	definitions := make([]ServiceDefinition, len(data.Definitions))
	copy(definitions, data.Definitions)
	return definitions, nil
}

func (store *definitionStore) readAllLocked() (persistedDefinitions, error) {
	raw, err := os.ReadFile(store.path)
	if err != nil {
		return persistedDefinitions{}, fmt.Errorf("read definition store: %w", err)
	}

	if len(raw) == 0 {
		return persistedDefinitions{
			Version:     definitionStoreVersion,
			Definitions: []ServiceDefinition{},
		}, nil
	}

	var data persistedDefinitions
	if err := json.Unmarshal(raw, &data); err != nil {
		return persistedDefinitions{}, fmt.Errorf("decode definition store: %w", err)
	}

	if data.Definitions == nil {
		data.Definitions = []ServiceDefinition{}
	}
	if data.Version == 0 {
		data.Version = definitionStoreVersion
	}

	return data, nil
}

func (store *definitionStore) writeAllLocked(data persistedDefinitions) error {
	if data.Definitions == nil {
		data.Definitions = []ServiceDefinition{}
	}
	if data.Version == 0 {
		data.Version = definitionStoreVersion
	}

	payload, err := json.MarshalIndent(data, "", "  ")
	if err != nil {
		return fmt.Errorf("encode definition store: %w", err)
	}

	if err := os.WriteFile(store.path, append(payload, '\n'), 0o644); err != nil {
		return fmt.Errorf("write definition store: %w", err)
	}

	return nil
}

func newServiceDefinition(
	serviceName string,
	image string,
	containerPort int,
	containerID string,
	hostPort int,
	lanEnabled bool,
	mounts []ServiceDefinitionMount,
	env []string,
) ServiceDefinition {
	now := time.Now().UTC()
	if mounts == nil {
		mounts = []ServiceDefinitionMount{}
	}
	if env == nil {
		env = []string{}
	}

	return ServiceDefinition{
		ID:                 serviceName,
		Name:               serviceName,
		Image:              image,
		ContainerPort:      containerPort,
		ServiceProto:       defaultServiceProtoHTTP,
		LanEnabled:         lanEnabled,
		CurrentContainerID: containerID,
		LastKnownHostPort:  hostPort,
		CreatedAt:          now,
		UpdatedAt:          now,
		Mounts:             mounts,
		Env:                env,
	}
}

func (app *App) persistServiceDefinition(
	serviceName string,
	image string,
	containerPort int,
	containerID string,
	hostPort int,
	lanEnabled bool,
	mounts []ServiceDefinitionMount,
	env []string,
) error {
	existing, found, err := app.definitions.getByID(serviceName)
	if err != nil {
		return err
	}

	definition := newServiceDefinition(serviceName, image, containerPort, containerID, hostPort, lanEnabled, mounts, env)
	if found {
		definition.CreatedAt = existing.CreatedAt
		if mounts == nil {
			definition.Mounts = existing.Mounts
		}
		if env == nil {
			definition.Env = existing.Env
		}
	}

	return app.definitions.upsert(definition)
}

func (app *App) deleteServiceDefinition(serviceName string) error {
	return app.definitions.deleteByID(serviceName)
}

func (app *App) getServiceDefinition(id string) (ServiceDefinition, bool, error) {
	return app.definitions.getByID(id)
}

func (app *App) listServiceDefinitions() ([]ServiceDefinition, error) {
	return app.definitions.list()
}

func (app *App) markServiceDefinitionContainerRemoved(serviceName string) error {
	definition, found, err := app.definitions.getByID(serviceName)
	if err != nil || !found {
		return err
	}

	definition.CurrentContainerID = ""
	definition.LastKnownHostPort = 0
	definition.UpdatedAt = time.Now().UTC()
	return app.definitions.upsert(definition)
}

func (app *App) syncServiceDefinitionFromInspect(inspected ServiceInspectResponse) error {
	definition, found, err := app.definitions.getByID(inspected.Name)
	if err != nil {
		return err
	}
	if !found {
		return nil
	}

	definition.CurrentContainerID = inspected.ID
	if inspected.LocalURL != "" || inspected.LANURL != "" {
		definition.LanEnabled = inspected.LanEnabled
	}
	definition.UpdatedAt = time.Now().UTC()
	return app.definitions.upsert(definition)
}

func (app *App) deleteManagedDefinitionData(ctx context.Context, definition ServiceDefinition) error {
	bindRoots := map[string]struct{}{}

	for _, mount := range definition.Mounts {
		if !mount.Managed {
			continue
		}

		switch mount.Type {
		case "bind":
			if mount.Source == "" {
				continue
			}
			bindRoots[filepath.Dir(mount.Source)] = struct{}{}
			if err := os.RemoveAll(mount.Source); err != nil {
				return fmt.Errorf("remove bind mount %q: %w", mount.Source, err)
			}
		case "volume":
			if mount.Source == "" {
				continue
			}
			dockerClient, err := app.dockerClient()
			if err != nil {
				return err
			}
			if err := dockerClient.VolumeRemove(ctx, mount.Source, true); err != nil {
				return fmt.Errorf("remove volume %q: %w", mount.Source, err)
			}
		}
	}

	for root := range bindRoots {
		if root == "" {
			continue
		}
		if err := os.RemoveAll(root); err != nil && !os.IsNotExist(err) {
			return fmt.Errorf("remove bind root %q: %w", root, err)
		}
	}

	return nil
}
