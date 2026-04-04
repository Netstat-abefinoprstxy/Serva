param(
  [ValidateSet('Debug', 'Release')]
  [string]$Configuration = 'Release',
  [switch]$CopyToRunner
)

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$backendDir = Join-Path $repoRoot 'backend\sovereignd'
$goCache = Join-Path $repoRoot '.gocache'
$outputExe = Join-Path $backendDir 'sovereignd.exe'

Write-Host "Building backend from $backendDir"
New-Item -ItemType Directory -Path $goCache -Force | Out-Null

Push-Location $backendDir
try {
  $env:GOCACHE = $goCache
  go build -o $outputExe .
} finally {
  Pop-Location
}

Write-Host "Built $outputExe"

if ($CopyToRunner) {
  $runnerDir = Join-Path $repoRoot "build\windows\x64\runner\$Configuration"
  if (!(Test-Path $runnerDir)) {
    throw "Runner output folder does not exist yet: $runnerDir"
  }

  Copy-Item -LiteralPath $outputExe -Destination (Join-Path $runnerDir 'sovereignd.exe') -Force
  Write-Host "Copied backend to $runnerDir"
}
