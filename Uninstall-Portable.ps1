param(
    [string]$DestinationPath = (Join-Path $env:LOCALAPPDATA "Programs\AudioSwitcher")
)

$ErrorActionPreference = "Stop"

$installStateFileName = ".audioswitcher-install.json"
$destinationRoot = [System.IO.Path]::GetFullPath($DestinationPath)

function Remove-AutostartForInstallation {
    param([string]$RootPath)

    $startupFolder = [Environment]::GetFolderPath("Startup")
    $shortcutPath = Join-Path $startupFolder "Audio Switcher.lnk"
    if (-not (Test-Path -LiteralPath $shortcutPath)) {
        return
    }

    $shell = New-Object -ComObject WScript.Shell
    $shortcut = $shell.CreateShortcut($shortcutPath)
    $expectedLauncherPath = Join-Path $RootPath "Start-AudioSwitcher.bat"
    if ([string]::Equals($shortcut.TargetPath, $expectedLauncherPath, [System.StringComparison]::OrdinalIgnoreCase)) {
        Remove-Item -LiteralPath $shortcutPath -Force
        Write-Host "Autostart entfernt: $shortcutPath"
    }
}

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

Assert-SafeInstallationPath -Path $destinationRoot

$statePath = Join-Path $destinationRoot $installStateFileName
$mainScriptPath = Join-Path $destinationRoot "AudioSwitcher.ps1"
$nativeTypePath = Join-Path $destinationRoot "AudioSwitcher.Native.cs"

if (-not (Test-Path -LiteralPath $destinationRoot)) {
    Write-Host "Portable Installation nicht gefunden: $destinationRoot"
    return
}

if (-not (Test-Path -LiteralPath $statePath) -and ((-not (Test-Path -LiteralPath $mainScriptPath)) -or (-not (Test-Path -LiteralPath $nativeTypePath)))) {
    throw "Der Zielordner sieht nicht wie eine Audio-Switcher-Installation aus: $destinationRoot"
}

Remove-AutostartForInstallation -RootPath $destinationRoot

Remove-Item -LiteralPath $destinationRoot -Recurse -Force
Write-Host "Audio Switcher entfernt aus: $destinationRoot"