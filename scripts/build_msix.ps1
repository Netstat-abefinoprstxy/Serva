param(
  [switch]$BuildBackend = $true
)

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$pubspecPath = Join-Path $repoRoot 'pubspec.yaml'

function Get-PubspecValue {
  param(
    [string]$Content,
    [string]$Key
  )

  $match = [regex]::Match($Content, "(?m)^\s*${Key}:\s*(.+)$")
  if (-not $match.Success) {
    throw "Could not find '$Key' in $pubspecPath"
  }

  return $match.Groups[1].Value.Trim()
}

$pubspecContent = Get-Content $pubspecPath -Raw
$flutterVersion = Get-PubspecValue -Content $pubspecContent -Key 'version'
$msixVersion = Get-PubspecValue -Content $pubspecContent -Key 'msix_version'
$flutterBuildName = ($flutterVersion -split '\+')[0]

if ($msixVersion -notmatch '^\d+\.\d+\.\d+\.0$') {
  throw "msix_version must use a Store-safe revision of .0. Current value: $msixVersion"
}

$expectedMsixVersion = "$flutterBuildName.0"
if ($msixVersion -ne $expectedMsixVersion) {
  throw "Version mismatch: version=$flutterVersion expects msix_version=$expectedMsixVersion but found $msixVersion"
}

Push-Location $repoRoot
try {
  Write-Host "Building Serva version $flutterVersion (MSIX $msixVersion)"
  flutter pub get
  flutter build windows --release

  if ($BuildBackend) {
    & (Join-Path $PSScriptRoot 'build_backend.ps1') -Configuration Release -CopyToRunner
  }

  dart run msix:create
} finally {
  Pop-Location
}
