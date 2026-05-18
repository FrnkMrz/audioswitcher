$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$scriptPath = Join-Path $repoRoot "AudioSwitcher.ps1"
$nativeTypePath = Join-Path $repoRoot "AudioSwitcher.Native.cs"
$configPath = Join-Path $repoRoot "config.json"
$readmePath = Join-Path $repoRoot "README.md"
$englishReadmePath = Join-Path $repoRoot "README.en.md"
$versionPath = Join-Path $repoRoot "VERSION.txt"
$iconPath = Join-Path $repoRoot "Assets/AudioSwitcher.ico"
$gitignorePath = Join-Path $repoRoot ".gitignore"
$launcherPath = Join-Path $repoRoot "Start-AudioSwitcher.bat"
$portableInstallPath = Join-Path $repoRoot "Install-Portable.ps1"
$portableUninstallPath = Join-Path $repoRoot "Uninstall-Portable.ps1"
$installAutostartPath = Join-Path $repoRoot "Install-Autostart.ps1"
$uninstallAutostartPath = Join-Path $repoRoot "Uninstall-Autostart.ps1"
$testWorkflowPath = Join-Path $repoRoot ".github/workflows/test.yml"
$releaseWorkflowPath = Join-Path $repoRoot ".github/workflows/release.yml"

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
Assert-True (Test-Path $configPath) "config.json was not found."
Assert-True (Test-Path $readmePath) "README.md was not found."
Assert-True (Test-Path $englishReadmePath) "README.en.md was not found."
Assert-True (Test-Path $versionPath) "VERSION.txt was not found."
Assert-True (Test-Path $iconPath) "Assets/AudioSwitcher.ico was not found."
Assert-True (Test-Path $gitignorePath) ".gitignore was not found."
Assert-True (Test-Path $launcherPath) "Start-AudioSwitcher.bat was not found."
Assert-True (Test-Path $portableInstallPath) "Install-Portable.ps1 was not found."
Assert-True (Test-Path $portableUninstallPath) "Uninstall-Portable.ps1 was not found."
Assert-True (Test-Path $installAutostartPath) "Install-Autostart.ps1 was not found."
Assert-True (Test-Path $uninstallAutostartPath) "Uninstall-Autostart.ps1 was not found."
Assert-True (Test-Path $testWorkflowPath) "Test workflow was not found."
Assert-True (Test-Path $releaseWorkflowPath) "Release workflow was not found."

$scriptContent = Get-Content -LiteralPath $scriptPath -Raw
$nativeTypeContent = Get-Content -LiteralPath $nativeTypePath -Raw
$configContent = Get-Content -LiteralPath $configPath -Raw
$readmeContent = Get-Content -LiteralPath $readmePath -Raw
$englishReadmeContent = Get-Content -LiteralPath $englishReadmePath -Raw
$versionContent = Get-Content -LiteralPath $versionPath -Raw
$gitignoreContent = Get-Content -LiteralPath $gitignorePath -Raw
$portableInstallContent = Get-Content -LiteralPath $portableInstallPath -Raw
$portableUninstallContent = Get-Content -LiteralPath $portableUninstallPath -Raw
$installAutostartContent = Get-Content -LiteralPath $installAutostartPath -Raw
$uninstallAutostartContent = Get-Content -LiteralPath $uninstallAutostartPath -Raw
$testWorkflowContent = Get-Content -LiteralPath $testWorkflowPath -Raw
$releaseWorkflowContent = Get-Content -LiteralPath $releaseWorkflowPath -Raw
$parseErrors = $null
[System.Management.Automation.Language.Parser]::ParseInput($scriptContent, [ref]$null, [ref]$parseErrors) | Out-Null

Assert-True ($parseErrors.Count -eq 0) ("PowerShell parser found errors: " + ($parseErrors | ForEach-Object { $_.Message } | Out-String))
Assert-True ($scriptContent -match 'OutputHotkey = "Ctrl\+Alt\+A"') "Default output hotkey is missing or changed."
Assert-True ($scriptContent -match 'InputHotkey = "Ctrl\+Alt\+M"') "Default input hotkey is missing or changed."
Assert-True ($scriptContent -match 'Get-AudioSwitcherConfig') "Config loader is missing."
Assert-True ($scriptContent -match 'ExcludedOutputDeviceNamePatterns') "Output exclusion patterns are not wired into the script."
Assert-True ($scriptContent -match 'ExcludedInputDeviceNamePatterns') "Input exclusion patterns are not wired into the script."
Assert-True ($scriptContent -match 'ExcludedDeviceNamePatterns') "Legacy excluded device patterns should remain supported."
Assert-True ($scriptContent -match 'AudioSwitcher\.Native\.cs') "Native C# type file is not loaded."
Assert-True ($scriptContent -match 'Show-SwitchNotification') "On-screen switch notification is missing."
Assert-True ($scriptContent -match 'New-AudioSwitcherTrayIcon') "Custom tray icon builder is missing."
Assert-True ($scriptContent -match 'Get-AudioSwitcherIconPath') "Tray icon path resolver is missing."
Assert-True ($scriptContent -match 'DestroyIcon') "Tray icon handle cleanup is missing."
Assert-True ($scriptContent -match 'Assert-AudioSwitcherConfig') "Config validation is missing."
Assert-True ($scriptContent -match 'Write-AudioSwitcherDeviceList') "Device listing command is missing."
Assert-True ($scriptContent -match 'ListDevices') "ListDevices parameter is missing."
Assert-True ($scriptContent -match 'Ausgabe wechseln') "Tray output switch action is missing."
Assert-True ($scriptContent -match 'Mikrofon wechseln') "Tray input switch action is missing."
Assert-True ($scriptContent -match 'tray\.Icon = \$trayIcon') "Tray should prefer the custom icon when it is available."
Assert-True ($scriptContent -match '\$menuHotkeys = \[System\.Windows\.Forms\.ToolStripMenuItem\]::new\("\$OutputHotkey  \|  \$InputHotkey"\)') "Tray menu should show the active hotkeys."
Assert-True ($scriptContent -match 'Aktuelles Mikrofon') "Input switch notification title is missing."
Assert-True ($scriptContent -match 'FormBorderStyle\]::None') "Notification should be borderless."
Assert-True ($scriptContent -match '\.TopMost\s*=\s*\$true') "Notification should be topmost."
Assert-True ($scriptContent -match 'System\.Windows\.Forms\.Timer') "Notification auto-dismiss timer is missing."
Assert-True ($scriptContent -match '\.AutoEllipsis\s*=\s*\$true') "Notification should handle long device names."
Assert-True ($scriptContent -match 'notificationForm\.Dispose') "Notification form cleanup is missing."
Assert-True ($scriptContent -match 'NotificationPosition') "Notification position setting is missing."
Assert-True ($scriptContent -match 'SetHighDpiMode') "DPI awareness setup is missing."
Assert-True ($scriptContent -match 'PerMonitorV2') "DPI awareness should prefer per-monitor scaling."
Assert-True ($scriptContent -match 'MethodInvocationException') "Blocked hotkey errors should be handled explicitly."
Assert-True ($scriptContent -match 'InvalidOperationException') "Direct blocked hotkey errors should be handled explicitly."
Assert-True ($scriptContent -match 'Der \$Label-Hotkey \$HotkeyText ist bereits belegt') "Blocked hotkey message should identify the affected hotkey."
Assert-True ($scriptContent -match 'OutputHotkey und InputHotkey duerfen nicht identisch sein') "Duplicate output/input hotkeys should be rejected."
Assert-True ($scriptContent -match 'AudioDeviceKind\]::Output') "Output hotkey window is missing."
Assert-True ($scriptContent -match 'AudioDeviceKind\]::Input') "Input hotkey window is missing."
Assert-True ($scriptContent -match 'MOD_CONTROL') "Hotkey modifier constants should be documented."
Assert-True ($scriptContent -match 'PerMonitorV2\) is enabled') "Fixed notification size should mention DPI scaling."
Assert-True ($nativeTypeContent -match 'RegisterHotKey') "Hotkey registration entry point is missing."
Assert-True ($nativeTypeContent -match 'MOD_NOREPEAT') "Hotkey repeat suppression is missing."
Assert-True ($nativeTypeContent -match 'AudioDeviceKind') "Hotkey window should know whether it controls output or input."
Assert-True ($nativeTypeContent -match 'SwitchOutputToNext') "Output switching entry point is missing."
Assert-True ($nativeTypeContent -match 'SwitchInputToNext') "Input switching entry point is missing."
Assert-True ($nativeTypeContent -match 'ListOutputDevices') "Output device listing entry point is missing."
Assert-True ($nativeTypeContent -match 'ListInputDevices') "Input device listing entry point is missing."
Assert-True ($nativeTypeContent -match '0bd7a1be-7a1a-44db-8397-cc5392387b5e') "IMMDeviceCollection IID is incorrect."
Assert-True ($nativeTypeContent -match 'EDataFlow\.eRender') "Output switching should enumerate render devices."
Assert-True ($nativeTypeContent -match 'EDataFlow\.eCapture') "Input switching should enumerate capture devices."
Assert-True ($nativeTypeContent -match 'IsExcluded') "Device exclusion filtering is missing."
Assert-True ($nativeTypeContent -match 'Regex\.Escape') "Device exclusion patterns should be wildcard-safe."
Assert-True ($nativeTypeContent -match 'SetDefaultEndpoint') "Audio endpoint switching entry point is missing."
Assert-True ($nativeTypeContent -match 'DEVICE_STATE_ACTIVE') "Active-device filtering is missing."
Assert-True ($nativeTypeContent -match 'FinalReleaseComObject') "COM object cleanup is missing."
Assert-True ($nativeTypeContent -match 'SetDefaultEndpoint\(next\.Id, ERole\.eConsole\)') "Console role is not updated."
Assert-True ($nativeTypeContent -match 'SetDefaultEndpoint\(next\.Id, ERole\.eMultimedia\)') "Multimedia role is not updated."
Assert-True ($nativeTypeContent -match 'SetDefaultEndpoint\(next\.Id, ERole\.eCommunications\)') "Communications role is not updated."
Assert-True ($nativeTypeContent -match 'catch \(InvalidComObjectException\)') "COM cleanup should tolerate already-released RCWs."
Assert-True ($nativeTypeContent -match 'undocumented Windows COM interface') "Undocumented IPolicyConfig risk should be documented."
Assert-True ($nativeTypeContent -match 'CoreAudio objects are native COM references') "Explicit COM release should be explained."
Assert-True ($nativeTypeContent -match 'MMDeviceEnumerator is the documented CoreAudio COM object') "CoreAudio enumerator should be explained."
Assert-True ($nativeTypeContent -match 'method order matters for COM interop') "IPolicyConfig method order risk should be documented."

$config = $configContent | ConvertFrom-Json
Assert-True ($config.OutputHotkey -eq "Ctrl+Alt+A") "config.json default output hotkey is incorrect."
Assert-True ($config.InputHotkey -eq "Ctrl+Alt+M") "config.json default input hotkey is incorrect."
Assert-True ($config.ShowTray -eq $true) "config.json should enable tray by default."
Assert-True ($config.NotificationDurationMs -ge 500) "config.json notification duration is too low."
Assert-True ($config.NotificationPosition -eq "BottomRight") "config.json notification position is incorrect."
Assert-True (($config.PSObject.Properties.Name -contains "ExcludedOutputDeviceNamePatterns")) "config.json output excluded device list is missing."
Assert-True (($config.PSObject.Properties.Name -contains "ExcludedInputDeviceNamePatterns")) "config.json input excluded device list is missing."
Assert-True ($versionContent -match '^AudioSwitcher\s+\d+\.\d+\.\d+') "VERSION.txt should contain a semantic AudioSwitcher version."

Assert-True ($installAutostartContent -match 'WScript\.Shell') "Autostart installer should create a Windows shortcut."
Assert-True ($installAutostartContent -match 'Startup') "Autostart installer should target the Startup folder."
Assert-True ($installAutostartContent -match 'Start-AudioSwitcher\.bat') "Autostart installer should launch the batch file."
Assert-True ($installAutostartContent -match 'IconLocation') "Autostart installer should assign the project icon to the shortcut."
Assert-True ($portableInstallContent -match 'LOCALAPPDATA') "Portable installer should default to LocalAppData."
Assert-True ($portableInstallContent -match 'Install-Autostart\.ps1') "Portable installer should be able to install autostart in the target directory."
Assert-True ($portableInstallContent -match 'ReplaceConfig') "Portable installer should support preserving an existing config."
Assert-True ($portableInstallContent -match 'Assets') "Portable installer should copy the Assets folder."
Assert-True ($portableInstallContent -match 'ManagedPaths') "Portable installer should track managed install paths."
Assert-True ($portableInstallContent -match 'Read-InstallState') "Portable installer should read an existing install state for updates."
Assert-True ($portableInstallContent -match 'Write-InstallState') "Portable installer should write an install state manifest."
Assert-True ($portableUninstallContent -match 'LOCALAPPDATA') "Portable uninstaller should default to LocalAppData."
Assert-True ($portableUninstallContent -match 'CreateShortcut') "Portable uninstaller should inspect the startup shortcut before deleting it."
Assert-True ($portableUninstallContent -match 'TargetPath') "Portable uninstaller should only remove autostart for the matching installation."
Assert-True ($portableUninstallContent -match '\.audioswitcher-install\.json') "Portable uninstaller should recognize the install manifest."
Assert-True ($uninstallAutostartContent -match 'Remove-Item') "Autostart uninstaller should remove the shortcut."
Assert-True ($readmeContent -match 'Deutscher Quickguide') "German quick guide is missing."
Assert-True ($readmeContent -match 'README\.en\.md') "German README should link the English documentation."
Assert-True ($readmeContent -match 'Release-ZIP') "German README should document release ZIPs."
Assert-True ($readmeContent -match 'Ctrl\+Alt\+M') "German README should document the input hotkey."
Assert-True ($readmeContent -match 'Mikrofon') "German README should document microphone switching."
Assert-True ($readmeContent -match '-ListDevices') "German README should document device listing."
Assert-True ($readmeContent -match 'Ausgabe wechseln') "German README should document tray switch actions."
Assert-True ($readmeContent -match 'LocalAppData') "German README should recommend a stable install location."
Assert-True ($readmeContent -match 'AudioSwitcher\.ico') "German README should document the fixed icon asset."
Assert-True ($readmeContent -match 'Install-Portable\.ps1') "German README should document the portable installer."
Assert-True ($readmeContent -match 'Uninstall-Portable\.ps1') "German README should document the portable uninstaller."
Assert-True ($readmeContent -match 'aktualisiert') "German README should document update behavior."
Assert-True ($readmeContent -match 'VERSION\.txt') "German README should document the version file."
Assert-True ($readmeContent -match 'Actions[\s\S]+Artifacts[\s\S]+AudioSwitcher') "German README should explain where to find the Actions ZIP artifact."
Assert-True ($englishReadmeContent -match 'Audio Switcher for Windows 11') "English README title is missing."
Assert-True ($englishReadmeContent -match 'Quick Start') "English quick start is missing."
Assert-True ($englishReadmeContent -match 'GitHub Actions test pipeline builds a portable') "English README should document CI ZIP artifacts."
Assert-True ($englishReadmeContent -match 'Ctrl\+Alt\+M') "English README should document the input hotkey."
Assert-True ($englishReadmeContent -match 'microphone') "English README should document microphone switching."
Assert-True ($englishReadmeContent -match '-ListDevices') "English README should document device listing."
Assert-True ($englishReadmeContent -match 'LocalAppData') "English README should recommend a stable install location."
Assert-True ($englishReadmeContent -match 'AudioSwitcher\.ico') "English README should document the fixed icon asset."
Assert-True ($englishReadmeContent -match 'Install-Portable\.ps1') "English README should document the portable installer."
Assert-True ($englishReadmeContent -match 'Uninstall-Portable\.ps1') "English README should document the portable uninstaller."
Assert-True ($englishReadmeContent -match 'updated') "English README should document update behavior."
Assert-True ($englishReadmeContent -match 'VERSION\.txt') "English README should document the version file."
Assert-True ($englishReadmeContent -match 'not stored directly in the repository') "English README should explain that ZIP artifacts are not committed."
Assert-True ($englishReadmeContent -match 'README\.md') "English README should link the German documentation."
Assert-True ($gitignoreContent -match 'AudioSwitcher\.zip') ".gitignore should ignore the generated ZIP."
Assert-True ($gitignoreContent -match '\*\.log') ".gitignore should ignore local logs."
Assert-True ($gitignoreContent -match '\.DS_Store') ".gitignore should ignore macOS metadata."
Assert-True ($gitignoreContent -match '\*\.icloud') ".gitignore should ignore iCloud placeholder files."
Assert-True ($testWorkflowContent -match 'VERSION\.txt') "Test ZIP should include VERSION.txt."
Assert-True ($testWorkflowContent -match 'Assets') "Test ZIP should include the Assets folder."
Assert-True ($testWorkflowContent -match 'Uninstall-Portable\.ps1') "Test ZIP should include the portable uninstaller."
Assert-True ($releaseWorkflowContent -match 'Compress-Archive') "Release workflow should build a ZIP file."
Assert-True ($releaseWorkflowContent -match 'Assets') "Release ZIP should include the Assets folder."
Assert-True ($releaseWorkflowContent -match 'Uninstall-Portable\.ps1') "Release ZIP should include the portable uninstaller."
Assert-True ($releaseWorkflowContent -match 'README\.en\.md') "Release ZIP should include English documentation."
Assert-True ($releaseWorkflowContent -match 'VERSION\.txt') "Release ZIP should include VERSION.txt."
Assert-True ($releaseWorkflowContent -match 'actions/upload-artifact@v4') "Release workflow should upload the ZIP artifact."
Assert-True ($releaseWorkflowContent -match 'softprops/action-gh-release@v2') "Release workflow should publish tagged releases."

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

try {
    [void][PortableAudioSwitcher.AudioSwitcher]
}
catch {
    throw "AudioSwitcher type was not compiled."
}

try {
    [void][PortableAudioSwitcher.HotkeyWindow]
}
catch {
    throw "HotkeyWindow type was not compiled."
}

$outputDevices = [PortableAudioSwitcher.AudioSwitcher]::ListOutputDevices()
$inputDevices = [PortableAudioSwitcher.AudioSwitcher]::ListInputDevices()
Assert-True ($null -ne $outputDevices) "Output device enumeration returned null."
Assert-True ($null -ne $inputDevices) "Input device enumeration returned null."

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

$portableInstallContentForParser = Get-Content -LiteralPath $portableInstallPath -Raw
[System.Management.Automation.Language.Parser]::ParseInput($portableInstallContentForParser, [ref]$null, [ref]$parseErrors) | Out-Null
Assert-True ($parseErrors.Count -eq 0) ("Install-Portable.ps1 parser found errors: " + ($parseErrors | ForEach-Object { $_.Message } | Out-String))

$portableUninstallContentForParser = Get-Content -LiteralPath $portableUninstallPath -Raw
[System.Management.Automation.Language.Parser]::ParseInput($portableUninstallContentForParser, [ref]$null, [ref]$parseErrors) | Out-Null
Assert-True ($parseErrors.Count -eq 0) ("Uninstall-Portable.ps1 parser found errors: " + ($parseErrors | ForEach-Object { $_.Message } | Out-String))

Write-Host "Audio Switcher smoke tests passed."
