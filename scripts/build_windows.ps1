param(
  [switch]$BuildBackend = $true
)

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot

Push-Location $repoRoot
try {
  flutter pub get
  flutter build windows --release

  if ($BuildBackend) {
    & (Join-Path $PSScriptRoot 'build_backend.ps1') -Configuration Release -CopyToRunner
  }
} finally {
  Pop-Location
}
