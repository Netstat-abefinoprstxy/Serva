# Serva

Serva is a Windows desktop app for managing durable self-hosted services with Docker.

## Repo Layout

- `lib/` Flutter desktop app
- `backend/sovereignd/` local Go daemon used by the app
- `scripts/` helper scripts for local builds and packaging

## Backend

Build the Go daemon:

```powershell
.\scripts\build_backend.ps1
```

Build and copy it into the Windows runner output:

```powershell
.\scripts\build_backend.ps1 -Configuration Release -CopyToRunner
```

## Windows + MSIX

Build the Windows release bundle without packaging:

```powershell
.\scripts\build_windows.ps1
```

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
