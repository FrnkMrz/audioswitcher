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
Assert-True ($nativeTypeContent -match 'RegisterHotKey') "Hotkey registration entry point is missing."
Assert-True ($nativeTypeContent -match 'MOD_NOREPEAT') "Hotkey repeat suppression is missing."
Assert-True ($nativeTypeContent -match 'SetDefaultEndpoint') "Audio endpoint switching entry point is missing."
Assert-True ($nativeTypeContent -match 'DEVICE_STATE_ACTIVE') "Active-device filtering is missing."
Assert-True ($nativeTypeContent -match 'FinalReleaseComObject') "COM object cleanup is missing."

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

$launcherContent = Get-Content -LiteralPath $launcherPath -Raw
Assert-True ($launcherContent -match 'AudioSwitcher\.ps1') "Launcher does not call AudioSwitcher.ps1."
Assert-True ($launcherContent -match 'ExecutionPolicy Bypass') "Launcher does not bypass local execution policy for portable start."

Write-Host "Audio Switcher smoke tests passed."
