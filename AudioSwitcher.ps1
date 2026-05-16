param(
    [string]$Hotkey = "Ctrl+Alt+A",
    [switch]$NoTray
)

$ErrorActionPreference = "Stop"

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

function Resolve-WindowsFormsReferences {
    $references = [System.Collections.Generic.List[string]]::new()
    $references.Add("System.Windows.Forms.dll")

    try {
        $primitives = [System.Reflection.Assembly]::Load("System.Windows.Forms.Primitives")
        if ($primitives.Location) {
            $references.Add($primitives.Location)
        }
    }
    catch {
    }

    $references.ToArray()
}

$nativeTypePath = Join-Path $PSScriptRoot "AudioSwitcher.Native.cs"
if (-not (Test-Path -LiteralPath $nativeTypePath)) {
    throw "AudioSwitcher.Native.cs wurde nicht gefunden: $nativeTypePath"
}

Add-Type -ReferencedAssemblies (Resolve-WindowsFormsReferences) -Path $nativeTypePath

function ConvertTo-HotkeyParts {
    param([string]$HotkeyText)

    $parts = $HotkeyText -split "\+" | ForEach-Object { $_.Trim() } | Where-Object { $_ }
    if ($parts.Count -lt 1) {
        throw "Hotkey ist leer. Beispiel: Ctrl+Alt+A"
    }

    $modifiers = [uint32]0
    $keyName = $null

    foreach ($part in $parts) {
        switch -Regex ($part) {
            "^(Ctrl|Control|Strg)$" { $modifiers = $modifiers -bor 0x0002; continue }
            "^(Alt)$" { $modifiers = $modifiers -bor 0x0001; continue }
            "^(Shift|Umschalt)$" { $modifiers = $modifiers -bor 0x0004; continue }
            "^(Win|Windows|Meta)$" { $modifiers = $modifiers -bor 0x0008; continue }
            default {
                if ($keyName) {
                    throw "Bitte genau eine normale Taste im Hotkey verwenden. Beispiel: Ctrl+Alt+A"
                }
                $keyName = $part
            }
        }
    }

    if (-not $keyName) {
        throw "Bitte eine normale Taste im Hotkey angeben. Beispiel: Ctrl+Alt+A"
    }

    try {
        $key = [System.Windows.Forms.Keys]::$keyName
    }
    catch {
        throw "Taste '$keyName' wurde nicht erkannt. Beispiele: A, F8, MediaNextTrack"
    }

    if ([int]$key -eq 0) {
        throw "Taste '$keyName' wurde nicht erkannt. Beispiele: A, F8, MediaNextTrack"
    }

    [pscustomobject]@{
        Modifiers = $modifiers
        Key = [uint32][int]$key
    }
}

$hotkeyParts = ConvertTo-HotkeyParts -HotkeyText $Hotkey
$window = [PortableAudioSwitcher.HotkeyWindow]::new(41011, $hotkeyParts.Modifiers, $hotkeyParts.Key)

$tray = $null
if (-not $NoTray) {
    $tray = [System.Windows.Forms.NotifyIcon]::new()
    $tray.Icon = [System.Drawing.SystemIcons]::Application
    $tray.Text = "Audio Switcher ($Hotkey)"
    $tray.Visible = $true

    $menu = [System.Windows.Forms.ContextMenuStrip]::new()
    $quitItem = [System.Windows.Forms.ToolStripMenuItem]::new("Beenden")
    $quitItem.add_Click({
        [System.Windows.Forms.Application]::Exit()
    })
    [void]$menu.Items.Add($quitItem)
    $tray.ContextMenuStrip = $menu
}

$window.add_Switched({
    param($sender, $eventArgs)
    Write-Host $eventArgs.Message
    if ($script:tray) {
        $script:tray.BalloonTipTitle = "Audio Switcher"
        $script:tray.BalloonTipText = $eventArgs.Message
        $script:tray.ShowBalloonTip(1200)
    }
})

try {
    Write-Host "Audio Switcher laeuft. Hotkey: $Hotkey"
    Write-Host "Zum Beenden das Tray-Menue verwenden oder dieses Fenster schliessen."
    [System.Windows.Forms.Application]::Run()
}
finally {
    if ($tray) {
        $tray.Visible = $false
        $tray.Dispose()
    }
    $window.Dispose()
}
