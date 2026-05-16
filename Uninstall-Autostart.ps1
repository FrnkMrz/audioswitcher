$ErrorActionPreference = "Stop"

$startupFolder = [Environment]::GetFolderPath("Startup")
$shortcutPath = Join-Path $startupFolder "Audio Switcher.lnk"

if (Test-Path -LiteralPath $shortcutPath) {
    Remove-Item -LiteralPath $shortcutPath -Force
    Write-Host "Autostart entfernt: $shortcutPath"
}
else {
    Write-Host "Autostart war nicht installiert."
}
