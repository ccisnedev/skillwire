# install.ps1 — Install the skillwire CLI from GitHub Releases (Windows)
#
#   irm https://skillwire.ccisne.dev/install.ps1 | iex
#
# This file is served from the site and exists nowhere else in the repository.
# A second copy under code/cli/ would be the copy that drifts, and the drifted
# one is always the one people actually run.

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repo       = 'ccisnedev/skillwire'
$asset      = 'skillwire-windows-x64.zip'
$installDir = "$env:LOCALAPPDATA\skillwire"
$binDir     = "$installDir\bin"
$tmpDir     = Join-Path $env:TEMP "skillwire_install_$(Get-Random)"

Write-Host "Installing the skillwire CLI..."

# 1. Find the latest release
$apiUrl  = "https://api.github.com/repos/$repo/releases/latest"
$release = Invoke-RestMethod -Uri $apiUrl -Headers @{ 'User-Agent' = 'skillwire-installer' }
$tag     = $release.tag_name
$dlUrl   = ($release.assets | Where-Object { $_.name -eq $asset }).browser_download_url

if (-not $dlUrl) {
    Write-Error "Asset '$asset' not found in release $tag"
    exit 1
}

Write-Host "Downloading $tag..."
New-Item -ItemType Directory -Force $tmpDir | Out-Null
$zipPath = Join-Path $tmpDir $asset
Invoke-WebRequest -Uri $dlUrl -OutFile $zipPath -UseBasicParsing

# 2. Extract.
#    The archive holds bin\ and assets\, and that shape is load-bearing: the CLI
#    resolves its skills as <dir of the exe>\..\assets, so moving either one
#    breaks `skill deploy` with no error until it is run.
Write-Host "Extracting to $installDir..."
New-Item -ItemType Directory -Force $installDir | Out-Null
Expand-Archive -Path $zipPath -DestinationPath $installDir -Force

# 3. The `sw` alias.
#    %~dp0 is the directory of this .cmd, so `sw` always runs the skillwire.exe
#    sitting next to it. Invoking a bare `skillwire` would resolve through PATH
#    and could silently run a different installation.
New-Item -ItemType Directory -Force $binDir | Out-Null
Set-Content -Path "$binDir\sw.cmd" -Value @('@echo off', '"%~dp0skillwire.exe" %*')

# 4. PATH
$userPath = [System.Environment]::GetEnvironmentVariable('PATH', 'User')
if ($userPath -notlike "*$binDir*") {
    [System.Environment]::SetEnvironmentVariable('PATH', "$userPath;$binDir", 'User')
    Write-Host "Added $binDir to the user PATH."
}

Remove-Item -Recurse -Force $tmpDir

Write-Host ""
Write-Host "skillwire $tag installed. Open a new terminal, then:"
Write-Host "  skillwire skill list --host claude --scope global --all"
