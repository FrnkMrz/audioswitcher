param(
    [string]$DestinationPath = (Join-Path $env:LOCALAPPDATA "Programs\AudioSwitcher"),
    [switch]$InstallAutostart,
    [switch]$ReplaceConfig
)

$ErrorActionPreference = "Stop"

$sourceRoot = $PSScriptRoot
$destinationRoot = [System.IO.Path]::GetFullPath($DestinationPath)
$installStateFileName = ".audioswitcher-install.json"

function Assert-SafeInstallationPath {
    param([string]$Path)

    if ([string]::IsNullOrWhiteSpace($Path)) {
        throw "DestinationPath darf nicht leer sein."
    }

    $resolvedPath = [System.IO.Path]::GetFullPath($Path)
    $pathRoot = [System.IO.Path]::GetPathRoot($resolvedPath)
    if ([string]::Equals($resolvedPath.TrimEnd('\\'), $pathRoot.TrimEnd('\\'), [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "DestinationPath darf kein Laufwerksstamm sein: $resolvedPath"
    }
}

function Get-InstallStatePath {
    param([string]$RootPath)

    Join-Path $RootPath $installStateFileName
}

function Get-ManagedRelativePaths {
    @(
        "Assets",
        "AudioSwitcher.ps1",
        "AudioSwitcher.Native.cs",
        "Start-AudioSwitcher.bat",
        "Install-Portable.ps1",
        "Uninstall-Portable.ps1",
        "Install-Autostart.ps1",
        "Uninstall-Autostart.ps1",
        "README.md",
        "README.en.md",
        "VERSION.txt",
        "LICENSE",
        "config.json",
        $installStateFileName
    )
}

function Remove-ManagedItem {
    param(
        [string]$RootPath,
        [string]$RelativePath
    )

    $targetPath = Join-Path $RootPath $RelativePath
    if (Test-Path -LiteralPath $targetPath) {
        Remove-Item -LiteralPath $targetPath -Recurse -Force
    }
}

function Read-InstallState {
    param([string]$RootPath)

    $statePath = Get-InstallStatePath -RootPath $RootPath
    if (-not (Test-Path -LiteralPath $statePath)) {
        return $null
    }

    Get-Content -LiteralPath $statePath -Raw | ConvertFrom-Json
}

function Write-InstallState {
    param(
        [string]$RootPath,
        [string[]]$ManagedPaths
    )

    $state = [pscustomobject]@{
        ManagedPaths = $ManagedPaths
        InstalledAtUtc = [DateTime]::UtcNow.ToString("o")
    }

    $state | ConvertTo-Json -Depth 3 | Set-Content -LiteralPath (Get-InstallStatePath -RootPath $RootPath) -Encoding UTF8
}

Assert-SafeInstallationPath -Path $destinationRoot

$managedRelativePaths = Get-ManagedRelativePaths
$itemsToCopy = @(
    "Assets",
    "AudioSwitcher.ps1",
    "AudioSwitcher.Native.cs",
    "Start-AudioSwitcher.bat",
    "Install-Portable.ps1",
    "Uninstall-Portable.ps1",
    "Install-Autostart.ps1",
    "Uninstall-Autostart.ps1",
    "README.md",
    "README.en.md",
    "VERSION.txt",
    "LICENSE"
)

New-Item -ItemType Directory -Path $destinationRoot -Force | Out-Null

$existingInstallState = Read-InstallState -RootPath $destinationRoot
$previousManagedPaths = @()
if ($existingInstallState -and $existingInstallState.ManagedPaths) {
    $previousManagedPaths = @($existingInstallState.ManagedPaths)
}

foreach ($relativePath in $previousManagedPaths) {
    if ($managedRelativePaths -notcontains $relativePath) {
        Remove-ManagedItem -RootPath $destinationRoot -RelativePath $relativePath
    }
}

foreach ($item in $itemsToCopy) {
    $sourcePath = Join-Path $sourceRoot $item
    if (-not (Test-Path -LiteralPath $sourcePath)) {
        throw "Installationsdatei wurde nicht gefunden: $sourcePath"
    }

    Remove-ManagedItem -RootPath $destinationRoot -RelativePath $item
    Copy-Item -LiteralPath $sourcePath -Destination $destinationRoot -Recurse -Force
}

$sourceConfigPath = Join-Path $sourceRoot "config.json"
$destinationConfigPath = Join-Path $destinationRoot "config.json"
if (-not (Test-Path -LiteralPath $sourceConfigPath)) {
    throw "config.json wurde nicht gefunden: $sourceConfigPath"
}

$configWasPreserved = $false
if ((Test-Path -LiteralPath $destinationConfigPath) -and -not $ReplaceConfig) {
    $configWasPreserved = $true
}
else {
    Copy-Item -LiteralPath $sourceConfigPath -Destination $destinationConfigPath -Force
}

Write-InstallState -RootPath $destinationRoot -ManagedPaths $managedRelativePaths

if ($InstallAutostart) {
    & (Join-Path $destinationRoot "Install-Autostart.ps1")
}

if ($previousManagedPaths.Count -gt 0) {
    Write-Host "Audio Switcher aktualisiert in: $destinationRoot"
}
else {
    Write-Host "Audio Switcher installiert nach: $destinationRoot"
}
if ($configWasPreserved) {
    Write-Host "Vorhandene config.json wurde beibehalten. Mit -ReplaceConfig kann sie ersetzt werden."
}
else {
    Write-Host "config.json wurde in den Zielordner kopiert."
}

Write-Host "Starten: $(Join-Path $destinationRoot 'Start-AudioSwitcher.bat')"
if (-not $InstallAutostart) {
    Write-Host "Autostart optional einrichten mit: powershell.exe -NoProfile -ExecutionPolicy Bypass -File $(Join-Path $destinationRoot 'Install-Autostart.ps1')"
}