$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$scriptPath = Join-Path $repoRoot "AudioSwitcher.ps1"
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
Assert-True (Test-Path $launcherPath) "Start-AudioSwitcher.bat was not found."

$scriptContent = Get-Content -LiteralPath $scriptPath -Raw
$parseErrors = $null
[System.Management.Automation.Language.Parser]::ParseInput($scriptContent, [ref]$null, [ref]$parseErrors) | Out-Null

Assert-True ($parseErrors.Count -eq 0) ("PowerShell parser found errors: " + ($parseErrors | ForEach-Object { $_.Message } | Out-String))
Assert-True ($scriptContent -match '\[string\]\$Hotkey = "Ctrl\+Alt\+A"') "Default hotkey is missing or changed."
Assert-True ($scriptContent -match 'RegisterHotKey') "Hotkey registration entry point is missing."
Assert-True ($scriptContent -match 'SetDefaultEndpoint') "Audio endpoint switching entry point is missing."
Assert-True ($scriptContent -match 'DEVICE_STATE_ACTIVE') "Active-device filtering is missing."

$typeDefinitionMatch = [regex]::Match(
    $scriptContent,
    '(?s)Add-Type\s+-ReferencedAssemblies\s+@\("System\.Windows\.Forms\.dll"\)\s+-TypeDefinition\s+@"\r?\n(?<code>.*?)\r?\n"@'
)

Assert-True $typeDefinitionMatch.Success "Could not extract embedded C# type definition."

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

Add-Type -ReferencedAssemblies (Resolve-WindowsFormsReferences) -TypeDefinition $typeDefinitionMatch.Groups["code"].Value

Assert-True (("PortableAudioSwitcher.AudioSwitcher" -as [type]) -ne $null) "AudioSwitcher type was not compiled."
Assert-True (("PortableAudioSwitcher.HotkeyWindow" -as [type]) -ne $null) "HotkeyWindow type was not compiled."

$launcherContent = Get-Content -LiteralPath $launcherPath -Raw
Assert-True ($launcherContent -match 'AudioSwitcher\.ps1') "Launcher does not call AudioSwitcher.ps1."
Assert-True ($launcherContent -match 'ExecutionPolicy Bypass') "Launcher does not bypass local execution policy for portable start."

Write-Host "Audio Switcher smoke tests passed."
