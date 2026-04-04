# Serva

Serva is an open source Windows desktop app for durable local self-hosting with Docker.

It gives Windows users a friendlier way to launch, inspect, recreate, and manage Docker-powered services without losing track of the data those services depend on.

## Project Mission

Containers are disposable, but your services and your data are not.

Serva exists to make self-hosting on Windows feel approachable without hiding the important parts. It focuses on:

- simple local service management
- persistent data that survives container recreation
- helpful guidance when Docker Desktop or virtualization are not ready
- transparent, open source tooling for people who want control over their stack

The goal is not to replace Docker. The goal is to make Docker easier to live with on Windows.

Serva is also rooted in a broader idea: people should be able to own the software and services they rely on. Instead of defaulting to bigger hosted platforms for everything, Serva tries to make home labs and personal infrastructure more accessible, more understandable, and more practical for everyday users.

## Get Serva

If you want to run Serva, you currently have two main options.

### Microsoft Store

Install Serva from the Microsoft Store:

- [Microsoft Store web listing](https://apps.microsoft.com/store/detail/9N958R6C3QFM?cid=DevShareMCLPCS)
- [Open in Microsoft Store](ms-windows-store://pdp/?productid=9N958R6C3QFM)

### GitHub Releases

You can also download a release from GitHub and run Serva directly.

- [GitHub Releases](https://github.com/KaelanWillauer/Serva/releases)
- [Latest Release](https://github.com/KaelanWillauer/Serva/releases/latest)

For the manual release flow, start:

- `serva.exe`
- `sovereignd.exe`

The desktop app uses the local `sovereignd` service as its backend control plane.

## Serva Application

Serva is organized around a few core screens that cover the main self-hosting workflow.

### Dashboard

The Dashboard is the live control center for the machine and the services Serva manages.
<img width="2205" height="1050" alt="Dashboard" src="https://github.com/user-attachments/assets/9b133198-d7f2-4390-b6e8-275014aa1c59" />

It focuses on:

- Serva resource usage over time
- active service status
- quick links to service web UIs
- mission readiness and local environment health
- Docker and virtualization guidance when the host is not ready

<!-- Add dashboard screenshot here -->
<!-- Example: ![Dashboard](docs/images/dashboard.png) -->

### Services

The Services screen separates running services, inactive saved services, and persistent data.
<img width="2206" height="1045" alt="Services" src="https://github.com/user-attachments/assets/ebbdd18f-b37c-409f-8bd1-528b741ee0f6" />

It is designed to make the service lifecycle easier to understand:

- active services can be opened, restarted, paused, stopped, or inspected
- inactive services can be recreated later from saved definitions
- persistent data can be opened, wiped, deleted, or managed separately from the container itself

This is where Serva becomes more than a container launcher. It treats data as a first-class part of self-hosting.

<!-- Add services screenshot here -->
<!-- Example: ![Services](docs/images/services.png) -->

### Launch

The Launch screen is the one-click app gallery.
<img width="2206" height="1045" alt="Services" src="https://github.com/user-attachments/assets/62497853-e90b-4db1-b5cb-9ff4732506ad" />

It includes:

- verified templates for apps that are known to work well
- experimental templates for everything else
- quick launch setup for naming and reusing data
- template details and settings
- custom template creation and editing
- custom config files for more advanced setups

This screen is meant to help new users get started quickly while still leaving room for power users to build their own templates.

<!-- Add launch screenshot here -->
<!-- Example: ![Launch](docs/images/launch.png) -->

### Legacy Mode

Serva also includes a Legacy mode for the older service management flow.

It is hidden by default and can be enabled from the Services screen. This keeps the modern experience clean while still preserving deeper compatibility and older workflows when needed.

## What Serva Can Do

- Create and manage Docker-based services from a desktop app
- Start, stop, restart, inspect, and remove containers
- View logs and runtime metrics
- Save service definitions so services can be recreated later
- Keep persistent bind mounts and managed data organized
- Open service data folders directly from the app
- Create reusable launch templates
- Store custom config files with templates
- Help users recover from Docker Desktop and virtualization setup problems

## Repo Layout

- `lib/` Flutter desktop app
- `backend/sovereignd/` local Go daemon used by the app
- `scripts/` helper scripts for local builds and packaging

## Local Development

Serva is a monorepo with a Flutter desktop app and a local Go backend.

### Prerequisites

- Flutter
- Go
- Docker Desktop
- Windows desktop build tooling for Flutter

### Backend

Build the Go daemon:

```powershell
.\scripts\build_backend.ps1
```

Build and copy it into the Windows runner output:

```powershell
.\scripts\build_backend.ps1 -Configuration Release -CopyToRunner
```

### Windows Release Build

Build the Windows release bundle without packaging:

```powershell
.\scripts\build_windows.ps1
```

### Windows MSIX Packaging

Before Store uploads, keep the versions in `pubspec.yaml` aligned:

- `version: 1.0.3+3`
- `msix_version: 1.0.3.0`

The MSIX revision number must stay at `.0` for Store submissions.

Build the Windows app and package the MSIX:

```powershell
.\scripts\build_msix.ps1
```

That script will:

- verify that `version` and `msix_version` are aligned
- run `flutter pub get`
- build the Windows app in release mode
- build `backend/sovereignd/sovereignd.exe`
- copy it beside `serva.exe`
- run `dart run msix:create`

## Build Scripts

### `build_backend.ps1`

Builds the Go backend at `backend/sovereignd/sovereignd.exe`.

With `-CopyToRunner`, it also copies the backend executable into the built Windows runner output beside the Flutter app.

### `build_windows.ps1`

Builds the Flutter Windows release app and, by default, also builds and copies the backend so the local release bundle is complete.

### `build_msix.ps1`

Runs the full Store packaging flow.

It validates version alignment, builds the Windows app, builds and copies the backend, and creates the MSIX package.

## Contributing

Contributions are welcome.

Good areas to contribute include:

- improving template coverage and compatibility
- polishing the Windows UX for self-hosting workflows
- improving diagnostics and setup recovery
- expanding persistent data management
- strengthening packaging and release automation

If you contribute:

- keep the Windows-first self-hosting experience in mind
- prefer small, understandable flows over hidden complexity
- avoid regressing persistent data behavior

## Open Source Direction

Serva is being built in the open because local infrastructure tools benefit from transparency.

That matters for a project like this because users should be able to understand:

- how services are created
- how data is stored
- how templates are defined
- how the local control plane behaves

Open source also makes it easier for the community to improve templates, validate workflows, and shape where the project goes next.

Just as importantly, it supports the idea that people can run and own more of their own software again. Serva is meant to lower the barrier to personal infrastructure, bring home lab ideas to more people, and make self-hosting feel like something normal users can actually adopt instead of something reserved only for specialists.

## Roadmap Ideas

- richer template sharing and discovery
- stronger community template workflows
- more guided service configuration
- better remote access and networking flows
- improved release automation and distribution

## License

See [LICENSE](LICENSE).
