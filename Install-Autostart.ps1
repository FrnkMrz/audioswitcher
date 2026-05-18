$ErrorActionPreference = "Stop"

$repoRoot = $PSScriptRoot
$scriptPath = Join-Path $repoRoot "AudioSwitcher.ps1"
if (-not (Test-Path -LiteralPath $scriptPath)) {
    throw "AudioSwitcher.ps1 wurde nicht gefunden: $scriptPath"
}

$iconPath = Join-Path $repoRoot "Assets\AudioSwitcher.ico"

$startupFolder = [Environment]::GetFolderPath("Startup")
$shortcutPath = Join-Path $startupFolder "Audio Switcher.lnk"

$shell = New-Object -ComObject WScript.Shell
$shortcut = $shell.CreateShortcut($shortcutPath)
$shortcut.TargetPath = "powershell.exe"
$shortcut.Arguments = "-STA -WindowStyle Hidden -NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`""
$shortcut.WorkingDirectory = $repoRoot
$shortcut.WindowStyle = 7
$shortcut.Description = "Audio Switcher beim Windows-Start ausfuehren"
if (Test-Path -LiteralPath $iconPath) {
    $shortcut.IconLocation = $iconPath
}
$shortcut.Save()

Write-Host "Autostart installiert: $shortcutPath"
