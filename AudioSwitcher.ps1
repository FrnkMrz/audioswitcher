param(
    [string]$Hotkey,
    [string]$OutputHotkey,
    [string]$InputHotkey,
    [switch]$ListDevices,
    [switch]$NoTray
)

$ErrorActionPreference = "Stop"

if ([System.Threading.Thread]::CurrentThread.GetApartmentState() -ne [System.Threading.ApartmentState]::STA) {
    throw "AudioSwitcher muss im STA-Modus (Single-Threaded Apartment) gestartet werden. Starten Sie PowerShell ohne -MTA, oder verwenden Sie: powershell.exe -STA -File AudioSwitcher.ps1"
}

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type @"
using System;
using System.Runtime.InteropServices;

public static class AudioSwitcherUser32
{
    [DllImport("user32.dll", SetLastError = true)]
    public static extern bool DestroyIcon(IntPtr hIcon);
}
"@

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

    # System.Management.Automation wird fuer WildcardPattern benoetigt.
    # Location kann je nach Host leer sein, daher Fallback auf den Assembly-Namen.
    $smaLocation = [System.Management.Automation.WildcardPattern].Assembly.Location
    if ($smaLocation) {
        $references.Add($smaLocation)
    }
    else {
        $references.Add("System.Management.Automation.dll")
    }

    $references | Select-Object -Unique | ForEach-Object { [string]$_ }
}

$nativeTypePath = Join-Path $PSScriptRoot "AudioSwitcher.Native.cs"
if (-not (Test-Path -LiteralPath $nativeTypePath)) {
    throw "AudioSwitcher.Native.cs wurde nicht gefunden: $nativeTypePath"
}

Add-Type -ReferencedAssemblies (Resolve-WindowsFormsReferences) -Path $nativeTypePath

function Get-AudioSwitcherConfig {
    $defaults = [pscustomobject]@{
        OutputHotkey = "Ctrl+Alt+A"
        InputHotkey = "Ctrl+Alt+M"
        ShowTray = $true
        NotificationDurationMs = 1800
        NotificationPosition = "BottomRight"
        ExcludedOutputDeviceNamePatterns = @()
        ExcludedInputDeviceNamePatterns = @()
        # Legacy setting kept so older config.json files still work.
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

    if ($null -eq $fileConfig.OutputHotkey -and $null -ne $fileConfig.Hotkey) {
        $defaults.OutputHotkey = $fileConfig.Hotkey
    }

    if (($null -eq $fileConfig.ExcludedOutputDeviceNamePatterns) -and ($null -ne $fileConfig.ExcludedDeviceNamePatterns)) {
        $defaults.ExcludedOutputDeviceNamePatterns = $fileConfig.ExcludedDeviceNamePatterns
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
            # 0x0002 is the Win32 MOD_CONTROL flag used by RegisterHotKey.
            "^(Ctrl|Control|Strg)$" { $modifiers = $modifiers -bor 0x0002; continue }
            # 0x0001 is MOD_ALT.
            "^(Alt)$" { $modifiers = $modifiers -bor 0x0001; continue }
            # 0x0004 is MOD_SHIFT.
            "^(Shift|Umschalt)$" { $modifiers = $modifiers -bor 0x0004; continue }
            # 0x0008 is MOD_WIN, the Windows logo key.
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

function Assert-AudioSwitcherConfig {
    $validPositions = @("BottomRight", "BottomLeft", "TopRight", "TopLeft")
    if ($validPositions -notcontains $script:config.NotificationPosition) {
        throw "NotificationPosition '$($script:config.NotificationPosition)' ist ungueltig. Erlaubt sind: $($validPositions -join ', ')."
    }

    if ([int]$script:config.NotificationDurationMs -lt 500) {
        throw "NotificationDurationMs muss mindestens 500 sein."
    }

    if ([string]::IsNullOrWhiteSpace($script:config.OutputHotkey)) {
        throw "OutputHotkey darf nicht leer sein."
    }

    if ([string]::IsNullOrWhiteSpace($script:config.InputHotkey)) {
        throw "InputHotkey darf nicht leer sein."
    }

    if ([string]::Equals($script:config.OutputHotkey.Trim(), $script:config.InputHotkey.Trim(), [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "OutputHotkey und InputHotkey duerfen nicht identisch sein. Bitte waehlen Sie zwei unterschiedliche Kombinationen."
    }

    [void](ConvertTo-HotkeyParts -HotkeyText $script:config.OutputHotkey)
    [void](ConvertTo-HotkeyParts -HotkeyText $script:config.InputHotkey)
}

function Write-AudioSwitcherDeviceList {
    $outputs = @([PortableAudioSwitcher.AudioSwitcher]::ListOutputDevices())
    $inputs = @([PortableAudioSwitcher.AudioSwitcher]::ListInputDevices())

    Write-Host "Ausgaben:"
    if ($outputs.Count -eq 0) {
        Write-Host "- keine aktiven Ausgabegeraete gefunden"
    }
    else {
        foreach ($device in $outputs) {
            Write-Host "- $device"
        }
    }

    Write-Host ""
    Write-Host "Mikrofone:"
    if ($inputs.Count -eq 0) {
        Write-Host "- keine aktiven Mikrofone gefunden"
    }
    else {
        foreach ($device in $inputs) {
            Write-Host "- $device"
        }
    }
}

function Get-AudioSwitcherIconPath {
    $iconPath = Join-Path $PSScriptRoot "Assets\AudioSwitcher.ico"
    if (Test-Path -LiteralPath $iconPath) {
        return $iconPath
    }

    $null
}

function New-AudioSwitcherTrayIcon {
    $iconPath = Get-AudioSwitcherIconPath
    if ($iconPath) {
        return [System.Drawing.Icon]::new($iconPath)
    }

    $bitmap = $null
    $graphics = $null
    $backgroundBrush = $null
    $speakerBrush = $null
    $outerRingPen = $null
    $waveInnerPen = $null
    $waveOuterPen = $null
    $tempIcon = $null
    $iconHandle = [IntPtr]::Zero

    try {
        $bitmap = [System.Drawing.Bitmap]::new(32, 32, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
        $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
        $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
        $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
        $graphics.Clear([System.Drawing.Color]::Transparent)

        $backgroundBrush = [System.Drawing.Drawing2D.LinearGradientBrush]::new(
            [System.Drawing.Rectangle]::new(2, 2, 28, 28),
            [System.Drawing.Color]::FromArgb(255, 20, 111, 140),
            [System.Drawing.Color]::FromArgb(255, 36, 185, 173),
            45.0)
        $graphics.FillEllipse($backgroundBrush, 2, 2, 28, 28)

        $outerRingPen = [System.Drawing.Pen]::new([System.Drawing.Color]::FromArgb(220, 236, 246, 248), 1.4)
        $graphics.DrawEllipse($outerRingPen, 2, 2, 27, 27)

        $speakerBrush = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(248, 250, 252))
        $graphics.FillRectangle($speakerBrush, 8, 12, 4, 8)
        $graphics.FillPolygon($speakerBrush, @(
                [System.Drawing.Point]::new(11, 12),
                [System.Drawing.Point]::new(18, 8),
                [System.Drawing.Point]::new(18, 24),
                [System.Drawing.Point]::new(11, 20)
            ))

        $waveInnerPen = [System.Drawing.Pen]::new([System.Drawing.Color]::FromArgb(255, 255, 205, 96), 2.2)
        $waveInnerPen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
        $waveInnerPen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
        $graphics.DrawArc($waveInnerPen, 14, 11, 6, 10, -45, 90)

        $waveOuterPen = [System.Drawing.Pen]::new([System.Drawing.Color]::FromArgb(255, 255, 171, 66), 2.2)
        $waveOuterPen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
        $waveOuterPen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
        $graphics.DrawArc($waveOuterPen, 14, 8, 10, 16, -50, 100)

        $iconHandle = $bitmap.GetHicon()
        $tempIcon = [System.Drawing.Icon]::FromHandle($iconHandle)
        return $tempIcon.Clone()
    }
    finally {
        if ($tempIcon) {
            $tempIcon.Dispose()
        }
        if ($iconHandle -ne [IntPtr]::Zero) {
            [AudioSwitcherUser32]::DestroyIcon($iconHandle) | Out-Null
        }
        if ($waveOuterPen) {
            $waveOuterPen.Dispose()
        }
        if ($waveInnerPen) {
            $waveInnerPen.Dispose()
        }
        if ($outerRingPen) {
            $outerRingPen.Dispose()
        }
        if ($speakerBrush) {
            $speakerBrush.Dispose()
        }
        if ($backgroundBrush) {
            $backgroundBrush.Dispose()
        }
        if ($graphics) {
            $graphics.Dispose()
        }
        if ($bitmap) {
            $bitmap.Dispose()
        }
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

    $title = "Aktuelle Audioausgabe"
    $displayMessage = $Message
    if ($Message -match '^Mikrofon:\s*(.+)$') {
        $title = "Aktuelles Mikrofon"
        $displayMessage = $Matches[1]
    }
    elseif ($Message -match '^Audioausgabe:\s*(.+)$') {
        $displayMessage = $Matches[1]
    }

    $titleLabel = [System.Windows.Forms.Label]::new()
    $titleLabel.Text = $title
    $titleLabel.ForeColor = [System.Drawing.Color]::FromArgb(180, 190, 205)
    $titleLabel.Font = [System.Drawing.Font]::new("Segoe UI", 9, [System.Drawing.FontStyle]::Regular)
    $titleLabel.AutoSize = $true

    $messageLabel = [System.Windows.Forms.Label]::new()
    $messageLabel.Text = $displayMessage
    $messageLabel.ForeColor = [System.Drawing.Color]::White
    $messageLabel.Font = [System.Drawing.Font]::new("Segoe UI", 12, [System.Drawing.FontStyle]::Bold)
    $messageLabel.AutoSize = $true
    # AutoEllipsis greift wenn das Label schmaler als der Text ist (z. B. bei sehr langen Geraetebezeichnungen).
    $messageLabel.AutoEllipsis = $true

    # Die Formgröße wird dynamisch berechnet. SetHighDpiMode(PerMonitorV2) is enabled
    # vor dem Erstellen von Forms, damit die Pixel auf skalierten Displays korrekt bleiben.
    # Berechne Formgröße dynamisch auf Basis der tatsächlichen Textlänge.
    $sideMargin = 18
    $topMargin = 12
    $labelGap = 4
    $bottomMargin = 12
    $titleSize = [System.Windows.Forms.TextRenderer]::MeasureText($title, $titleLabel.Font)
    $messageSize = [System.Windows.Forms.TextRenderer]::MeasureText($displayMessage, $messageLabel.Font)
    $formWidth = [Math]::Max($titleSize.Width, $messageSize.Width) + $sideMargin * 2 + 4
    $formWidth = [Math]::Max($formWidth, 280)
    $messageLabelTop = $topMargin + $titleSize.Height + $labelGap
    $formHeight = $messageLabelTop + $messageSize.Height + $bottomMargin

    $titleLabel.Location = [System.Drawing.Point]::new($sideMargin, $topMargin)
    $messageLabel.Location = [System.Drawing.Point]::new($sideMargin, $messageLabelTop)
    $form.ClientSize = [System.Drawing.Size]::new($formWidth, $formHeight)

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

function Publish-SwitchMessage {
    param([string]$Message)

    Write-Host $Message
    Show-SwitchNotification -Message $Message
    if ($script:tray) {
        $script:tray.BalloonTipTitle = "Audio Switcher"
        $script:tray.BalloonTipText = $Message
        $script:tray.ShowBalloonTip(1200)
    }
}

function Invoke-AudioSwitcherSwitch {
    param([PortableAudioSwitcher.AudioDeviceKind]$DeviceKind)

    try {
        if ($DeviceKind -eq [PortableAudioSwitcher.AudioDeviceKind]::Input) {
            Publish-SwitchMessage -Message ([PortableAudioSwitcher.AudioSwitcher]::SwitchInputToNext([PortableAudioSwitcher.AudioSwitcherSettings]::ExcludedInputDeviceNamePatterns))
        }
        else {
            Publish-SwitchMessage -Message ([PortableAudioSwitcher.AudioSwitcher]::SwitchOutputToNext([PortableAudioSwitcher.AudioSwitcherSettings]::ExcludedOutputDeviceNamePatterns))
        }
    }
    catch {
        $prefix = if ($DeviceKind -eq [PortableAudioSwitcher.AudioDeviceKind]::Input) { "Mikrofon-Wechsel fehlgeschlagen: " } else { "Audioausgabe-Wechsel fehlgeschlagen: " }
        Publish-SwitchMessage -Message ($prefix + $_.Exception.Message)
    }
}

function New-AudioSwitcherHotkeyWindow {
    param(
        [string]$Label,
        [string]$HotkeyText,
        [int]$Id,
        [PortableAudioSwitcher.AudioDeviceKind]$DeviceKind
    )

    $hotkeyParts = ConvertTo-HotkeyParts -HotkeyText $HotkeyText
    try {
        [PortableAudioSwitcher.HotkeyWindow]::new($Id, $hotkeyParts.Modifiers, $hotkeyParts.Key, $DeviceKind)
    }
    catch [System.Management.Automation.MethodInvocationException] {
        if ($_.Exception.InnerException -and $_.Exception.InnerException.Message -like "Hotkey konnte nicht registriert werden*") {
            throw "Der $Label-Hotkey $HotkeyText ist bereits belegt. Bitte waehlen Sie eine andere Kombination."
        }

        throw
    }
    catch [System.InvalidOperationException] {
        if ($_.Exception.Message -like "Hotkey konnte nicht registriert werden*") {
            throw "Der $Label-Hotkey $HotkeyText ist bereits belegt. Bitte waehlen Sie eine andere Kombination."
        }

        throw
    }
}

$script:config = Get-AudioSwitcherConfig
if ($Hotkey -and -not $OutputHotkey) {
    $OutputHotkey = $Hotkey
}
if ($OutputHotkey) {
    $script:config.OutputHotkey = $OutputHotkey
}
if ($InputHotkey) {
    $script:config.InputHotkey = $InputHotkey
}
if ($NoTray) {
    $script:config.ShowTray = $false
}

Assert-AudioSwitcherConfig

$OutputHotkey = $script:config.OutputHotkey
$InputHotkey = $script:config.InputHotkey

$excludedOutputPatterns = @($script:config.ExcludedOutputDeviceNamePatterns)
if ($excludedOutputPatterns.Count -eq 0 -and $script:config.ExcludedDeviceNamePatterns) {
    $excludedOutputPatterns = @($script:config.ExcludedDeviceNamePatterns)
}

[PortableAudioSwitcher.AudioSwitcherSettings]::ExcludedOutputDeviceNamePatterns = $excludedOutputPatterns
[PortableAudioSwitcher.AudioSwitcherSettings]::ExcludedInputDeviceNamePatterns = @($script:config.ExcludedInputDeviceNamePatterns)

if ($ListDevices) {
    Write-AudioSwitcherDeviceList
    return
}

$outputWindow = $null
$inputWindow = $null
try {
    $outputWindow = New-AudioSwitcherHotkeyWindow -Label "Audioausgabe" -HotkeyText $OutputHotkey -Id 41011 -DeviceKind ([PortableAudioSwitcher.AudioDeviceKind]::Output)
    $inputWindow = New-AudioSwitcherHotkeyWindow -Label "Mikrofon" -HotkeyText $InputHotkey -Id 41012 -DeviceKind ([PortableAudioSwitcher.AudioDeviceKind]::Input)
}
catch {
    if ($outputWindow) {
        $outputWindow.Dispose()
    }
    if ($inputWindow) {
        $inputWindow.Dispose()
    }

    throw
}

$tray = $null
$trayIcon = $null
$script:tray = $null
if ($script:config.ShowTray) {
    $tray = [System.Windows.Forms.NotifyIcon]::new()
    try {
        $trayIcon = New-AudioSwitcherTrayIcon
    }
    catch {
        $trayIcon = $null
    }

    if ($trayIcon) {
        $tray.Icon = $trayIcon
    }
    else {
        $tray.Icon = [System.Drawing.SystemIcons]::Application
    }
    $tray.Text = "Audio Switcher ($OutputHotkey / $InputHotkey)"
    $tray.Visible = $true
    $script:tray = $tray

    $menu = [System.Windows.Forms.ContextMenuStrip]::new()
    $menu.ShowImageMargin = $false
    $menu.BackColor = [System.Drawing.Color]::FromArgb(18, 27, 38)
    $menu.ForeColor = [System.Drawing.Color]::FromArgb(238, 244, 247)

    $menuTitle = [System.Windows.Forms.ToolStripMenuItem]::new("Audio Switcher")
    $menuTitle.Enabled = $false
    $menuTitle.Font = [System.Drawing.Font]::new("Segoe UI Semibold", 9.5, [System.Drawing.FontStyle]::Bold)
    $menuTitle.ForeColor = [System.Drawing.Color]::FromArgb(238, 244, 247)
    $menuTitle.BackColor = [System.Drawing.Color]::FromArgb(18, 27, 38)
    $menuTitle.Padding = [System.Windows.Forms.Padding]::new(14, 8, 14, 2)
    [void]$menu.Items.Add($menuTitle)

    $menuHotkeys = [System.Windows.Forms.ToolStripMenuItem]::new("$OutputHotkey  |  $InputHotkey")
    $menuHotkeys.Enabled = $false
    $menuHotkeys.Font = [System.Drawing.Font]::new("Segoe UI", 8.5, [System.Drawing.FontStyle]::Regular)
    $menuHotkeys.ForeColor = [System.Drawing.Color]::FromArgb(162, 186, 198)
    $menuHotkeys.BackColor = [System.Drawing.Color]::FromArgb(18, 27, 38)
    $menuHotkeys.Padding = [System.Windows.Forms.Padding]::new(14, 0, 14, 8)
    [void]$menu.Items.Add($menuHotkeys)
    [void]$menu.Items.Add([System.Windows.Forms.ToolStripSeparator]::new())

    $switchOutputItem = [System.Windows.Forms.ToolStripMenuItem]::new("Ausgabe wechseln    $OutputHotkey")
    $switchOutputItem.BackColor = [System.Drawing.Color]::FromArgb(18, 27, 38)
    $switchOutputItem.ForeColor = [System.Drawing.Color]::FromArgb(238, 244, 247)
    $switchOutputItem.Padding = [System.Windows.Forms.Padding]::new(14, 6, 14, 6)
    $switchOutputItem.add_Click({
        Invoke-AudioSwitcherSwitch -DeviceKind ([PortableAudioSwitcher.AudioDeviceKind]::Output)
    })
    [void]$menu.Items.Add($switchOutputItem)

    $switchInputItem = [System.Windows.Forms.ToolStripMenuItem]::new("Mikrofon wechseln    $InputHotkey")
    $switchInputItem.BackColor = [System.Drawing.Color]::FromArgb(18, 27, 38)
    $switchInputItem.ForeColor = [System.Drawing.Color]::FromArgb(238, 244, 247)
    $switchInputItem.Padding = [System.Windows.Forms.Padding]::new(14, 6, 14, 6)
    $switchInputItem.add_Click({
        Invoke-AudioSwitcherSwitch -DeviceKind ([PortableAudioSwitcher.AudioDeviceKind]::Input)
    })
    [void]$menu.Items.Add($switchInputItem)
    [void]$menu.Items.Add([System.Windows.Forms.ToolStripSeparator]::new())

    $quitItem = [System.Windows.Forms.ToolStripMenuItem]::new("Beenden")
    $quitItem.BackColor = [System.Drawing.Color]::FromArgb(18, 27, 38)
    $quitItem.ForeColor = [System.Drawing.Color]::FromArgb(255, 186, 178)
    $quitItem.Padding = [System.Windows.Forms.Padding]::new(14, 6, 14, 6)
    $quitItem.add_Click({
        [System.Windows.Forms.Application]::Exit()
    })
    [void]$menu.Items.Add($quitItem)
    $tray.ContextMenuStrip = $menu
}

$switchHandler = {
    param($source, $switchEvent)
    Publish-SwitchMessage -Message $switchEvent.Message
}

$outputWindow.add_Switched($switchHandler)
$inputWindow.add_Switched($switchHandler)

try {
    Write-Host "Audio Switcher laeuft. Ausgabe-Hotkey: $OutputHotkey | Mikrofon-Hotkey: $InputHotkey"
    Write-Host "Zum Beenden das Tray-Menue verwenden oder dieses Fenster schliessen."
    [System.Windows.Forms.Application]::Run()
}
finally {
    if ($tray) {
        $tray.Visible = $false
        $tray.Dispose()
        $script:tray = $null
    }
    if ($trayIcon) {
        $trayIcon.Dispose()
    }
    if ($notificationTimer) {
        $notificationTimer.Stop()
        $notificationTimer.Dispose()
    }
    if ($notificationForm) {
        $notificationForm.Close()
        $notificationForm.Dispose()
    }
    if ($outputWindow) {
        $outputWindow.Dispose()
    }
    if ($inputWindow) {
        $inputWindow.Dispose()
    }
}
