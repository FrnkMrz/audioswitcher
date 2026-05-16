param(
    [string]$Hotkey,
    [switch]$NoTray
)

$ErrorActionPreference = "Stop"

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

try {
    [System.Windows.Forms.Application]::SetHighDpiMode([System.Windows.Forms.HighDpiMode]::PerMonitorV2) | Out-Null
}
catch {
}

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

function Get-AudioSwitcherConfig {
    $defaults = [pscustomobject]@{
        Hotkey = "Ctrl+Alt+A"
        ShowTray = $true
        NotificationDurationMs = 1800
        NotificationPosition = "BottomRight"
        ExcludedDeviceNamePatterns = @()
    }

    $configPath = Join-Path $PSScriptRoot "config.json"
    if (-not (Test-Path -LiteralPath $configPath)) {
        return $defaults
    }

    try {
        $fileConfig = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
    }
    catch {
        throw "config.json konnte nicht gelesen werden: $($_.Exception.Message)"
    }

    foreach ($property in $defaults.PSObject.Properties.Name) {
        if ($null -ne $fileConfig.$property) {
            $defaults.$property = $fileConfig.$property
        }
    }

    $defaults
}

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

function Show-SwitchNotification {
    param([string]$Message)

    if ($script:notificationTimer) {
        $script:notificationTimer.Stop()
        $script:notificationTimer.Dispose()
        $script:notificationTimer = $null
    }

    if ($script:notificationForm) {
        $script:notificationForm.Close()
        $script:notificationForm.Dispose()
        $script:notificationForm = $null
    }

    $form = [System.Windows.Forms.Form]::new()
    $form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::None
    $form.StartPosition = [System.Windows.Forms.FormStartPosition]::Manual
    $form.ShowInTaskbar = $false
    $form.TopMost = $true
    $form.BackColor = [System.Drawing.Color]::FromArgb(32, 36, 42)
    $form.Opacity = 0.95
    $form.Width = 440
    $form.Height = 86

    $titleLabel = [System.Windows.Forms.Label]::new()
    $titleLabel.Text = "Aktuelle Audioausgabe"
    $titleLabel.ForeColor = [System.Drawing.Color]::FromArgb(180, 190, 205)
    $titleLabel.Font = [System.Drawing.Font]::new("Segoe UI", 9, [System.Drawing.FontStyle]::Regular)
    $titleLabel.Location = [System.Drawing.Point]::new(18, 12)
    $titleLabel.Size = [System.Drawing.Size]::new(404, 18)

    $messageLabel = [System.Windows.Forms.Label]::new()
    $messageLabel.Text = $Message -replace '^Audioausgabe:\s*', ''
    $messageLabel.ForeColor = [System.Drawing.Color]::White
    $messageLabel.Font = [System.Drawing.Font]::new("Segoe UI", 12, [System.Drawing.FontStyle]::Bold)
    $messageLabel.Location = [System.Drawing.Point]::new(18, 34)
    $messageLabel.Size = [System.Drawing.Size]::new(404, 34)
    $messageLabel.AutoEllipsis = $true
    $messageLabel.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft

    $form.Controls.Add($titleLabel)
    $form.Controls.Add($messageLabel)

    $workingArea = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea
    $marginX = 24
    $marginY = 32
    switch ($script:config.NotificationPosition) {
        "BottomLeft" {
            $form.Location = [System.Drawing.Point]::new($workingArea.Left + $marginX, $workingArea.Bottom - $form.Height - $marginY)
        }
        "TopLeft" {
            $form.Location = [System.Drawing.Point]::new($workingArea.Left + $marginX, $workingArea.Top + $marginY)
        }
        "TopRight" {
            $form.Location = [System.Drawing.Point]::new($workingArea.Right - $form.Width - $marginX, $workingArea.Top + $marginY)
        }
        default {
            $form.Location = [System.Drawing.Point]::new($workingArea.Right - $form.Width - $marginX, $workingArea.Bottom - $form.Height - $marginY)
        }
    }

    $timer = [System.Windows.Forms.Timer]::new()
    $timer.Interval = [Math]::Max(500, [int]$script:config.NotificationDurationMs)
    $timer.add_Tick({
        $script:notificationTimer.Stop()
        $script:notificationTimer.Dispose()
        $script:notificationTimer = $null

        if ($script:notificationForm) {
            $script:notificationForm.Close()
            $script:notificationForm.Dispose()
            $script:notificationForm = $null
        }
    })

    $script:notificationForm = $form
    $script:notificationTimer = $timer

    $form.Show()
    $timer.Start()
}

$script:config = Get-AudioSwitcherConfig
if ($Hotkey) {
    $script:config.Hotkey = $Hotkey
}
if ($NoTray) {
    $script:config.ShowTray = $false
}

[PortableAudioSwitcher.AudioSwitcherSettings]::ExcludedDeviceNamePatterns = @($script:config.ExcludedDeviceNamePatterns)

$Hotkey = $script:config.Hotkey
$hotkeyParts = ConvertTo-HotkeyParts -HotkeyText $Hotkey
try {
    $window = [PortableAudioSwitcher.HotkeyWindow]::new(41011, $hotkeyParts.Modifiers, $hotkeyParts.Key)
}
catch [System.Management.Automation.MethodInvocationException] {
    if ($_.Exception.InnerException -and $_.Exception.InnerException.Message -like "Hotkey konnte nicht registriert werden*") {
        throw "Der Hotkey $Hotkey ist bereits belegt. Bitte waehlen Sie eine andere Kombination."
    }

    throw
}
catch [System.InvalidOperationException] {
    if ($_.Exception.Message -like "Hotkey konnte nicht registriert werden*") {
        throw "Der Hotkey $Hotkey ist bereits belegt. Bitte waehlen Sie eine andere Kombination."
    }

    throw
}

$tray = $null
if ($script:config.ShowTray) {
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
    Show-SwitchNotification -Message $eventArgs.Message
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
    if ($notificationTimer) {
        $notificationTimer.Stop()
        $notificationTimer.Dispose()
    }
    if ($notificationForm) {
        $notificationForm.Close()
        $notificationForm.Dispose()
    }
    $window.Dispose()
}
