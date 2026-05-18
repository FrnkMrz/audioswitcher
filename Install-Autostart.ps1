$ErrorActionPreference = "Stop"

$repoRoot = $PSScriptRoot
$launcherPath = Join-Path $repoRoot "Start-AudioSwitcher.bat"
if (-not (Test-Path -LiteralPath $launcherPath)) {
    throw "Start-AudioSwitcher.bat wurde nicht gefunden: $launcherPath"
}

$iconPath = Join-Path $repoRoot "Assets\AudioSwitcher.ico"

$startupFolder = [Environment]::GetFolderPath("Startup")
$shortcutPath = Join-Path $startupFolder "Audio Switcher.lnk"

$shell = New-Object -ComObject WScript.Shell
$shortcut = $shell.CreateShortcut($shortcutPath)
$shortcut.TargetPath = $launcherPath
$shortcut.WorkingDirectory = $repoRoot
$shortcut.WindowStyle = 7
$shortcut.Description = "Audio Switcher beim Windows-Start ausfuehren"
if (Test-Path -LiteralPath $iconPath) {
    $shortcut.IconLocation = $iconPath
}
$shortcut.Save()

Write-Host "Autostart installiert: $shortcutPath"
