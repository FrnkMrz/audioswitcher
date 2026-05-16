$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$scriptPath = Join-Path $repoRoot "AudioSwitcher.ps1"
$nativeTypePath = Join-Path $repoRoot "AudioSwitcher.Native.cs"
$launcherPath = Join-Path $repoRoot "Start-AudioSwitcher.bat"

function Assert-True {
    param(
        [bool]$Condition,
        [string]$Message
    )

    if (-not $Condition) {
        throw $Message
    }
}

function Assert-Throws {
    param(
        [scriptblock]$ScriptBlock,
        [string]$Message
    )

    $threw = $false
    try {
        & $ScriptBlock
    }
    catch {
        $threw = $true
    }

    if (-not $threw) {
        throw $Message
    }
}

Assert-True (Test-Path $scriptPath) "AudioSwitcher.ps1 was not found."
Assert-True (Test-Path $nativeTypePath) "AudioSwitcher.Native.cs was not found."
Assert-True (Test-Path $launcherPath) "Start-AudioSwitcher.bat was not found."

$scriptContent = Get-Content -LiteralPath $scriptPath -Raw
$nativeTypeContent = Get-Content -LiteralPath $nativeTypePath -Raw
$parseErrors = $null
[System.Management.Automation.Language.Parser]::ParseInput($scriptContent, [ref]$null, [ref]$parseErrors) | Out-Null

Assert-True ($parseErrors.Count -eq 0) ("PowerShell parser found errors: " + ($parseErrors | ForEach-Object { $_.Message } | Out-String))
Assert-True ($scriptContent -match '\[string\]\$Hotkey = "Ctrl\+Alt\+A"') "Default hotkey is missing or changed."
Assert-True ($scriptContent -match 'AudioSwitcher\.Native\.cs') "Native C# type file is not loaded."
Assert-True ($scriptContent -match 'Show-SwitchNotification') "On-screen switch notification is missing."
Assert-True ($scriptContent -match 'FormBorderStyle\]::None') "Notification should be borderless."
Assert-True ($scriptContent -match '\.TopMost\s*=\s*\$true') "Notification should be topmost."
Assert-True ($scriptContent -match 'System\.Windows\.Forms\.Timer') "Notification auto-dismiss timer is missing."
Assert-True ($scriptContent -match '\.AutoEllipsis\s*=\s*\$true') "Notification should handle long device names."
Assert-True ($scriptContent -match 'notificationForm\.Dispose') "Notification form cleanup is missing."
Assert-True ($nativeTypeContent -match 'RegisterHotKey') "Hotkey registration entry point is missing."
Assert-True ($nativeTypeContent -match 'MOD_NOREPEAT') "Hotkey repeat suppression is missing."
Assert-True ($nativeTypeContent -match 'SetDefaultEndpoint') "Audio endpoint switching entry point is missing."
Assert-True ($nativeTypeContent -match 'DEVICE_STATE_ACTIVE') "Active-device filtering is missing."
Assert-True ($nativeTypeContent -match 'FinalReleaseComObject') "COM object cleanup is missing."
Assert-True ($nativeTypeContent -match 'SetDefaultEndpoint\(next\.Id, ERole\.eConsole\)') "Console role is not updated."
Assert-True ($nativeTypeContent -match 'SetDefaultEndpoint\(next\.Id, ERole\.eMultimedia\)') "Multimedia role is not updated."
Assert-True ($nativeTypeContent -match 'SetDefaultEndpoint\(next\.Id, ERole\.eCommunications\)') "Communications role is not updated."
Assert-True ($nativeTypeContent -match 'catch \(InvalidComObjectException\)') "COM cleanup should tolerate already-released RCWs."

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

Add-Type -ReferencedAssemblies (Resolve-WindowsFormsReferences) -Path $nativeTypePath

Assert-True (("PortableAudioSwitcher.AudioSwitcher" -as [type]) -ne $null) "AudioSwitcher type was not compiled."
Assert-True (("PortableAudioSwitcher.HotkeyWindow" -as [type]) -ne $null) "HotkeyWindow type was not compiled."

$scriptAst = [System.Management.Automation.Language.Parser]::ParseInput($scriptContent, [ref]$null, [ref]$parseErrors)
$hotkeyFunctionAst = $scriptAst.Find({
    param($node)
    $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
        $node.Name -eq "ConvertTo-HotkeyParts"
}, $true)

Assert-True ($hotkeyFunctionAst -ne $null) "ConvertTo-HotkeyParts function was not found."

$hotkeyTestScript = [scriptblock]::Create(@"
$($hotkeyFunctionAst.Extent.Text)

`$ctrlAltA = ConvertTo-HotkeyParts -HotkeyText "Ctrl+Alt+A"
if (`$ctrlAltA.Modifiers -ne 3 -or `$ctrlAltA.Key -ne [uint32][int][System.Windows.Forms.Keys]::A) {
    throw "Ctrl+Alt+A parsed incorrectly."
}

`$strgAltF8 = ConvertTo-HotkeyParts -HotkeyText "Strg+Alt+F8"
if (`$strgAltF8.Modifiers -ne 3 -or `$strgAltF8.Key -ne [uint32][int][System.Windows.Forms.Keys]::F8) {
    throw "Strg+Alt+F8 parsed incorrectly."
}

`$winShiftS = ConvertTo-HotkeyParts -HotkeyText "Win+Shift+S"
if (`$winShiftS.Modifiers -ne 12 -or `$winShiftS.Key -ne [uint32][int][System.Windows.Forms.Keys]::S) {
    throw "Win+Shift+S parsed incorrectly."
}

Assert-Throws { ConvertTo-HotkeyParts -HotkeyText "" } "Empty hotkey should fail."
Assert-Throws { ConvertTo-HotkeyParts -HotkeyText "Ctrl+Alt+A+B" } "Multiple normal keys should fail."
Assert-Throws { ConvertTo-HotkeyParts -HotkeyText "Ctrl+Alt+DefinitelyNotAKey" } "Unknown key should fail."
"@)

& $hotkeyTestScript

$launcherContent = Get-Content -LiteralPath $launcherPath -Raw
Assert-True ($launcherContent -match 'AudioSwitcher\.ps1') "Launcher does not call AudioSwitcher.ps1."
Assert-True ($launcherContent -match 'ExecutionPolicy Bypass') "Launcher does not bypass local execution policy for portable start."

Write-Host "Audio Switcher smoke tests passed."
