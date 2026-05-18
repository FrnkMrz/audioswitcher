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

function Assert-Match {
    param(
        [string]$Content,
        [string]$Pattern,
        [string]$Message
    )

    Assert-True ([System.Text.RegularExpressions.Regex]::IsMatch($Content, $Pattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)) $Message
}

function Assert-Contains {
    param(
        [string]$Content,
        [string]$ExpectedText,
        [string]$Message
    )

    Assert-True ($Content.Contains($ExpectedText)) $Message
}

function Assert-ScriptParses {
    param(
        [string]$Content,
        [string]$Label
    )

    $localParseErrors = $null
    [System.Management.Automation.Language.Parser]::ParseInput($Content, [ref]$null, [ref]$localParseErrors) | Out-Null
    Assert-True ($localParseErrors.Count -eq 0) ("$Label parser found errors: " + ($localParseErrors | ForEach-Object { $_.Message } | Out-String))
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

function Invoke-PortableInstallationLifecycleTests {
    $tempRoot = Join-Path $env:TEMP ("AudioSwitcher-Smoke-" + [guid]::NewGuid().ToString("N"))

    try {
        & $portableInstallPath -DestinationPath $tempRoot

        Assert-True (Test-Path -LiteralPath (Join-Path $tempRoot "AudioSwitcher.ps1")) "Portable install did not copy AudioSwitcher.ps1."
        Assert-True (Test-Path -LiteralPath (Join-Path $tempRoot ".audioswitcher-install.json")) "Portable install did not write the install manifest."

        Set-Content -LiteralPath (Join-Path $tempRoot "config.json") -Value '{"OutputHotkey":"Ctrl+Alt+F8"}' -Encoding UTF8
        Set-Content -LiteralPath (Join-Path $tempRoot ".audioswitcher-install.json") -Value (@{ ManagedPaths = @("obsolete.txt") } | ConvertTo-Json) -Encoding UTF8
        Set-Content -LiteralPath (Join-Path $tempRoot "obsolete.txt") -Value "old file" -Encoding UTF8

        & $portableInstallPath -DestinationPath $tempRoot

        $preservedConfig = Get-Content -LiteralPath (Join-Path $tempRoot "config.json") -Raw | ConvertFrom-Json
        Assert-True ($preservedConfig.OutputHotkey -eq "Ctrl+Alt+F8") "Portable install should preserve an existing config.json by default."
        Assert-True (-not (Test-Path -LiteralPath (Join-Path $tempRoot "obsolete.txt"))) "Portable install should remove obsolete managed files from a previous manifest."

        & $portableInstallPath -DestinationPath $tempRoot -ReplaceConfig

        $replacedConfig = Get-Content -LiteralPath (Join-Path $tempRoot "config.json") -Raw | ConvertFrom-Json
        Assert-True ($replacedConfig.OutputHotkey -eq "Ctrl+Alt+A") "Portable install with -ReplaceConfig should restore the default config.json."

        & $portableUninstallPath -DestinationPath $tempRoot
        Assert-True (-not (Test-Path -LiteralPath $tempRoot)) "Portable uninstall should remove the installation directory."

        $driveRoot = [System.IO.Path]::GetPathRoot($tempRoot)
        Assert-Throws { & $portableInstallPath -DestinationPath $driveRoot } "Portable install should reject a drive root as DestinationPath."
        Assert-Throws { & $portableUninstallPath -DestinationPath $driveRoot } "Portable uninstall should reject a drive root as DestinationPath."
    }
    finally {
        if (Test-Path -LiteralPath $tempRoot) {
            Remove-Item -LiteralPath $tempRoot -Recurse -Force
        }
    }
}

Describe "AudioSwitcher repository smoke tests" {
    BeforeAll {
        $script:scriptContent = Get-Content -LiteralPath $scriptPath -Raw
        $script:nativeTypeContent = Get-Content -LiteralPath $nativeTypePath -Raw
        $script:configContent = Get-Content -LiteralPath $configPath -Raw
        $script:readmeContent = Get-Content -LiteralPath $readmePath -Raw
        $script:englishReadmeContent = Get-Content -LiteralPath $englishReadmePath -Raw
        $script:versionContent = Get-Content -LiteralPath $versionPath -Raw
        $script:gitignoreContent = Get-Content -LiteralPath $gitignorePath -Raw
        $script:portableInstallContent = Get-Content -LiteralPath $portableInstallPath -Raw
        $script:portableUninstallContent = Get-Content -LiteralPath $portableUninstallPath -Raw
        $script:installAutostartContent = Get-Content -LiteralPath $installAutostartPath -Raw
        $script:uninstallAutostartContent = Get-Content -LiteralPath $uninstallAutostartPath -Raw
        $script:testWorkflowContent = Get-Content -LiteralPath $testWorkflowPath -Raw
        $script:releaseWorkflowContent = Get-Content -LiteralPath $releaseWorkflowPath -Raw
    }

    It "has all expected project files" {
        $paths = @(
            $scriptPath,
            $nativeTypePath,
            $configPath,
            $readmePath,
            $englishReadmePath,
            $versionPath,
            $iconPath,
            $gitignorePath,
            $launcherPath,
            $portableInstallPath,
            $portableUninstallPath,
            $installAutostartPath,
            $uninstallAutostartPath,
            $testWorkflowPath,
            $releaseWorkflowPath
        )

        foreach ($path in $paths) {
            Assert-True (Test-Path -LiteralPath $path) ("Required file was not found: " + $path)
        }
    }

    It "contains required script features" {
        Assert-ScriptParses -Content $scriptContent -Label "AudioSwitcher.ps1"
        Assert-Match -Content $scriptContent -Pattern 'OutputHotkey = "Ctrl\+Alt\+A"' -Message "Default output hotkey is missing or changed."
        Assert-Match -Content $scriptContent -Pattern 'InputHotkey = "Ctrl\+Alt\+M"' -Message "Default input hotkey is missing or changed."
        Assert-Match -Content $scriptContent -Pattern 'Get-AudioSwitcherConfig' -Message "Config loader is missing."
        Assert-Match -Content $scriptContent -Pattern 'ExcludedOutputDeviceNamePatterns' -Message "Output exclusion patterns are not wired into the script."
        Assert-Match -Content $scriptContent -Pattern 'ExcludedInputDeviceNamePatterns' -Message "Input exclusion patterns are not wired into the script."
        Assert-Match -Content $scriptContent -Pattern 'ExcludedDeviceNamePatterns' -Message "Legacy excluded device patterns should remain supported."
        Assert-Match -Content $scriptContent -Pattern 'AudioSwitcher\.Native\.cs' -Message "Native C# type file is not loaded."
        Assert-Match -Content $scriptContent -Pattern 'Show-SwitchNotification' -Message "On-screen switch notification is missing."
        Assert-Match -Content $scriptContent -Pattern 'New-AudioSwitcherTrayIcon' -Message "Custom tray icon builder is missing."
        Assert-Match -Content $scriptContent -Pattern 'Get-AudioSwitcherIconPath' -Message "Tray icon path resolver is missing."
        Assert-Match -Content $scriptContent -Pattern 'DestroyIcon' -Message "Tray icon handle cleanup is missing."
        Assert-Match -Content $scriptContent -Pattern 'Assert-AudioSwitcherConfig' -Message "Config validation is missing."
        Assert-Match -Content $scriptContent -Pattern 'Write-AudioSwitcherDeviceList' -Message "Device listing command is missing."
        Assert-Match -Content $scriptContent -Pattern 'ListDevices' -Message "ListDevices parameter is missing."
        Assert-Match -Content $scriptContent -Pattern 'Ausgabe wechseln' -Message "Tray output switch action is missing."
        Assert-Match -Content $scriptContent -Pattern 'Mikrofon wechseln' -Message "Tray input switch action is missing."
        Assert-Match -Content $scriptContent -Pattern 'tray\.Icon = \$trayIcon' -Message "Tray should prefer the custom icon when it is available."
        Assert-Match -Content $scriptContent -Pattern '\$menuHotkeys = \[System\.Windows\.Forms\.ToolStripMenuItem\]::new\("\$OutputHotkey  \|  \$InputHotkey"\)' -Message "Tray menu should show the active hotkeys."
        Assert-Match -Content $scriptContent -Pattern 'Aktuelles Mikrofon' -Message "Input switch notification title is missing."
        Assert-Match -Content $scriptContent -Pattern 'FormBorderStyle\]::None' -Message "Notification should be borderless."
        Assert-Match -Content $scriptContent -Pattern '\.TopMost\s*=\s*\$true' -Message "Notification should be topmost."
        Assert-Match -Content $scriptContent -Pattern 'System\.Windows\.Forms\.Timer' -Message "Notification auto-dismiss timer is missing."
        Assert-Match -Content $scriptContent -Pattern '\.AutoEllipsis\s*=\s*\$true' -Message "Notification should handle long device names."
        Assert-Match -Content $scriptContent -Pattern 'notificationForm\.Dispose' -Message "Notification form cleanup is missing."
        Assert-Match -Content $scriptContent -Pattern 'NotificationPosition' -Message "Notification position setting is missing."
        Assert-Match -Content $scriptContent -Pattern 'SetHighDpiMode' -Message "DPI awareness setup is missing."
        Assert-Match -Content $scriptContent -Pattern 'PerMonitorV2' -Message "DPI awareness should prefer per-monitor scaling."
        Assert-Match -Content $scriptContent -Pattern 'MethodInvocationException' -Message "Blocked hotkey errors should be handled explicitly."
        Assert-Match -Content $scriptContent -Pattern 'InvalidOperationException' -Message "Direct blocked hotkey errors should be handled explicitly."
        Assert-Match -Content $scriptContent -Pattern 'Der \$Label-Hotkey \$HotkeyText ist bereits belegt' -Message "Blocked hotkey message should identify the affected hotkey."
        Assert-Match -Content $scriptContent -Pattern 'OutputHotkey und InputHotkey duerfen nicht identisch sein' -Message "Duplicate output/input hotkeys should be rejected."
        Assert-Match -Content $scriptContent -Pattern 'AudioDeviceKind\]::Output' -Message "Output hotkey window is missing."
        Assert-Match -Content $scriptContent -Pattern 'AudioDeviceKind\]::Input' -Message "Input hotkey window is missing."
        Assert-Match -Content $scriptContent -Pattern 'MOD_CONTROL' -Message "Hotkey modifier constants should be documented."
        Assert-Match -Content $scriptContent -Pattern 'PerMonitorV2\) is enabled' -Message "Fixed notification size should mention DPI scaling."
    }

    It "contains required native and packaging features" {
        Assert-Match -Content $nativeTypeContent -Pattern 'RegisterHotKey' -Message "Hotkey registration entry point is missing."
        Assert-Match -Content $nativeTypeContent -Pattern 'MOD_NOREPEAT' -Message "Hotkey repeat suppression is missing."
        Assert-Match -Content $nativeTypeContent -Pattern 'AudioDeviceKind' -Message "Hotkey window should know whether it controls output or input."
        Assert-Match -Content $nativeTypeContent -Pattern 'SwitchOutputToNext' -Message "Output switching entry point is missing."
        Assert-Match -Content $nativeTypeContent -Pattern 'SwitchInputToNext' -Message "Input switching entry point is missing."
        Assert-Match -Content $nativeTypeContent -Pattern 'ListOutputDevices' -Message "Output device listing entry point is missing."
        Assert-Match -Content $nativeTypeContent -Pattern 'ListInputDevices' -Message "Input device listing entry point is missing."
        Assert-Match -Content $nativeTypeContent -Pattern '0bd7a1be-7a1a-44db-8397-cc5392387b5e' -Message "IMMDeviceCollection IID is incorrect."
        Assert-Contains -Content $nativeTypeContent -ExpectedText 'EDataFlow.eRender' -Message "Output switching should enumerate render devices."
        Assert-Contains -Content $nativeTypeContent -ExpectedText 'EDataFlow.eCapture' -Message "Input switching should enumerate capture devices."
        Assert-Match -Content $nativeTypeContent -Pattern 'IsExcluded' -Message "Device exclusion filtering is missing."
        Assert-Match -Content $nativeTypeContent -Pattern 'Regex\.Escape' -Message "Device exclusion patterns should be wildcard-safe."
        Assert-Match -Content $nativeTypeContent -Pattern 'SetDefaultEndpoint' -Message "Audio endpoint switching entry point is missing."
        Assert-Match -Content $nativeTypeContent -Pattern 'DEVICE_STATE_ACTIVE' -Message "Active-device filtering is missing."
        Assert-Match -Content $nativeTypeContent -Pattern 'FinalReleaseComObject' -Message "COM object cleanup is missing."

        $config = $configContent | ConvertFrom-Json
        Assert-True ($config.OutputHotkey -eq "Ctrl+Alt+A") "config.json default output hotkey is incorrect."
        Assert-True ($config.InputHotkey -eq "Ctrl+Alt+M") "config.json default input hotkey is incorrect."
        Assert-True ($config.ShowTray -eq $true) "config.json should enable tray by default."
        Assert-True ($config.NotificationDurationMs -ge 500) "config.json notification duration is too low."
        Assert-True ($config.NotificationPosition -eq "BottomRight") "config.json notification position is incorrect."
        Assert-True (($config.PSObject.Properties.Name -contains "ExcludedOutputDeviceNamePatterns")) "config.json output excluded device list is missing."
        Assert-True (($config.PSObject.Properties.Name -contains "ExcludedInputDeviceNamePatterns")) "config.json input excluded device list is missing."
        Assert-Match -Content $versionContent -Pattern '^AudioSwitcher\s+\d+\.\d+\.\d+' -Message "VERSION.txt should contain a semantic AudioSwitcher version."

        Assert-Match -Content $installAutostartContent -Pattern 'WScript\.Shell' -Message "Autostart installer should create a Windows shortcut."
        Assert-Match -Content $installAutostartContent -Pattern 'Startup' -Message "Autostart installer should target the Startup folder."
        Assert-Match -Content $installAutostartContent -Pattern 'Start-AudioSwitcher\.bat' -Message "Autostart installer should launch the batch file."
        Assert-Match -Content $installAutostartContent -Pattern 'IconLocation' -Message "Autostart installer should assign the project icon to the shortcut."
        Assert-Match -Content $portableInstallContent -Pattern 'LOCALAPPDATA' -Message "Portable installer should default to LocalAppData."
        Assert-Match -Content $portableInstallContent -Pattern 'Install-Autostart\.ps1' -Message "Portable installer should be able to install autostart in the target directory."
        Assert-Match -Content $portableInstallContent -Pattern 'ReplaceConfig' -Message "Portable installer should support preserving an existing config."
        Assert-Match -Content $portableInstallContent -Pattern 'Assets' -Message "Portable installer should copy the Assets folder."
        Assert-Match -Content $portableInstallContent -Pattern 'ManagedPaths' -Message "Portable installer should track managed install paths."
        Assert-Match -Content $portableInstallContent -Pattern 'Read-InstallState' -Message "Portable installer should read an existing install state for updates."
        Assert-Match -Content $portableInstallContent -Pattern 'Write-InstallState' -Message "Portable installer should write an install state manifest."
        Assert-Match -Content $portableUninstallContent -Pattern 'LOCALAPPDATA' -Message "Portable uninstaller should default to LocalAppData."
        Assert-Match -Content $portableUninstallContent -Pattern 'CreateShortcut' -Message "Portable uninstaller should inspect the startup shortcut before deleting it."
        Assert-Match -Content $portableUninstallContent -Pattern 'TargetPath' -Message "Portable uninstaller should only remove autostart for the matching installation."
        Assert-Match -Content $portableUninstallContent -Pattern '\.audioswitcher-install\.json' -Message "Portable uninstaller should recognize the install manifest."
        Assert-Match -Content $uninstallAutostartContent -Pattern 'Remove-Item' -Message "Autostart uninstaller should remove the shortcut."

        Assert-Match -Content $readmeContent -Pattern 'Deutscher Quickguide' -Message "German quick guide is missing."
        Assert-Match -Content $readmeContent -Pattern 'README\.en\.md' -Message "German README should link the English documentation."
        Assert-Match -Content $readmeContent -Pattern 'Release-ZIP' -Message "German README should document release ZIPs."
        Assert-Match -Content $readmeContent -Pattern 'Ctrl\+Alt\+M' -Message "German README should document the input hotkey."
        Assert-Match -Content $readmeContent -Pattern 'Mikrofon' -Message "German README should document microphone switching."
        Assert-Match -Content $readmeContent -Pattern '-ListDevices' -Message "German README should document device listing."
        Assert-Match -Content $readmeContent -Pattern 'Ausgabe wechseln' -Message "German README should document tray switch actions."
        Assert-Match -Content $readmeContent -Pattern 'LocalAppData' -Message "German README should recommend a stable install location."
        Assert-Match -Content $readmeContent -Pattern 'AudioSwitcher\.ico' -Message "German README should document the fixed icon asset."
        Assert-Match -Content $readmeContent -Pattern 'Install-Portable\.ps1' -Message "German README should document the portable installer."
        Assert-Match -Content $readmeContent -Pattern 'Uninstall-Portable\.ps1' -Message "German README should document the portable uninstaller."
        Assert-Match -Content $readmeContent -Pattern 'aktualisiert' -Message "German README should document update behavior."
        Assert-Match -Content $readmeContent -Pattern 'VERSION\.txt' -Message "German README should document the version file."

        Assert-Match -Content $englishReadmeContent -Pattern 'Audio Switcher for Windows 11' -Message "English README title is missing."
        Assert-Match -Content $englishReadmeContent -Pattern 'Quick Start' -Message "English quick start is missing."
        Assert-Match -Content $englishReadmeContent -Pattern 'GitHub Actions test pipeline builds a portable' -Message "English README should document CI ZIP artifacts."
        Assert-Match -Content $englishReadmeContent -Pattern 'Ctrl\+Alt\+M' -Message "English README should document the input hotkey."
        Assert-Match -Content $englishReadmeContent -Pattern 'microphone' -Message "English README should document microphone switching."
        Assert-Match -Content $englishReadmeContent -Pattern '-ListDevices' -Message "English README should document device listing."
        Assert-Match -Content $englishReadmeContent -Pattern 'LocalAppData' -Message "English README should recommend a stable install location."
        Assert-Match -Content $englishReadmeContent -Pattern 'AudioSwitcher\.ico' -Message "English README should document the fixed icon asset."
        Assert-Match -Content $englishReadmeContent -Pattern 'Install-Portable\.ps1' -Message "English README should document the portable installer."
        Assert-Match -Content $englishReadmeContent -Pattern 'Uninstall-Portable\.ps1' -Message "English README should document the portable uninstaller."
        Assert-Match -Content $englishReadmeContent -Pattern 'keeps the installation updated cleanly' -Message "English README should document update behavior."
        Assert-Match -Content $englishReadmeContent -Pattern 'VERSION\.txt' -Message "English README should document the version file."
        Assert-Match -Content $englishReadmeContent -Pattern 'not stored directly in the repository' -Message "English README should explain that ZIP artifacts are not committed."
        Assert-Match -Content $englishReadmeContent -Pattern 'README\.md' -Message "English README should link the German documentation."

        Assert-Match -Content $gitignoreContent -Pattern 'AudioSwitcher\.zip' -Message ".gitignore should ignore the generated ZIP."
        Assert-Match -Content $gitignoreContent -Pattern '\*\.log' -Message ".gitignore should ignore local logs."
        Assert-Match -Content $gitignoreContent -Pattern '\.DS_Store' -Message ".gitignore should ignore macOS metadata."
        Assert-Match -Content $gitignoreContent -Pattern '\*\.icloud' -Message ".gitignore should ignore iCloud placeholder files."

        Assert-Match -Content $testWorkflowContent -Pattern 'VERSION\.txt' -Message "Test ZIP should include VERSION.txt."
        Assert-Match -Content $testWorkflowContent -Pattern 'Assets' -Message "Test ZIP should include the Assets folder."
        Assert-Match -Content $testWorkflowContent -Pattern 'Uninstall-Portable\.ps1' -Message "Test ZIP should include the portable uninstaller."

        Assert-Match -Content $releaseWorkflowContent -Pattern 'Compress-Archive' -Message "Release workflow should build a ZIP file."
        Assert-Match -Content $releaseWorkflowContent -Pattern 'Assets' -Message "Release ZIP should include the Assets folder."
        Assert-Match -Content $releaseWorkflowContent -Pattern 'Uninstall-Portable\.ps1' -Message "Release ZIP should include the portable uninstaller."
        Assert-Match -Content $releaseWorkflowContent -Pattern 'README\.en\.md' -Message "Release ZIP should include English documentation."
        Assert-Match -Content $releaseWorkflowContent -Pattern 'VERSION\.txt' -Message "Release ZIP should include VERSION.txt."
        Assert-Match -Content $releaseWorkflowContent -Pattern 'actions/upload-artifact@v4' -Message "Release workflow should upload the ZIP artifact."
        Assert-Match -Content $releaseWorkflowContent -Pattern 'softprops/action-gh-release@v2' -Message "Release workflow should publish tagged releases."
    }

    It "compiles the native interop and enumerates devices" {
        Add-Type -AssemblyName System.Windows.Forms
        Add-Type -AssemblyName System.Drawing
        Add-Type -ReferencedAssemblies (Resolve-WindowsFormsReferences) -Path $nativeTypePath

        [void][PortableAudioSwitcher.AudioSwitcher]
        [void][PortableAudioSwitcher.HotkeyWindow]

        $outputDevices = [PortableAudioSwitcher.AudioSwitcher]::ListOutputDevices()
        $inputDevices = [PortableAudioSwitcher.AudioSwitcher]::ListInputDevices()

        Assert-True ($null -ne $outputDevices) "Output device enumeration returned null."
        Assert-True ($null -ne $inputDevices) "Input device enumeration returned null."
    }

    It "parses hotkeys from ConvertTo-HotkeyParts" {
        $scriptParseErrors = $null
        $scriptAst = [System.Management.Automation.Language.Parser]::ParseInput($scriptContent, [ref]$null, [ref]$scriptParseErrors)
        Assert-True ($scriptParseErrors.Count -eq 0) "AST parse failed for AudioSwitcher.ps1."

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
"@)

        & $hotkeyTestScript

        Assert-Throws { & $hotkeyFunctionAst.Extent.Text; ConvertTo-HotkeyParts -HotkeyText "" } "Empty hotkey should fail."
        Assert-Throws { & $hotkeyFunctionAst.Extent.Text; ConvertTo-HotkeyParts -HotkeyText "Ctrl+Alt+A+B" } "Multiple normal keys should fail."
        Assert-Throws { & $hotkeyFunctionAst.Extent.Text; ConvertTo-HotkeyParts -HotkeyText "Ctrl+Alt+DefinitelyNotAKey" } "Unknown key should fail."
    }

    It "parses helper scripts and validates launcher" {
        $launcherContent = Get-Content -LiteralPath $launcherPath -Raw
        Assert-Match -Content $launcherContent -Pattern 'AudioSwitcher\.ps1' -Message "Launcher does not call AudioSwitcher.ps1."
        Assert-Match -Content $launcherContent -Pattern 'ExecutionPolicy Bypass' -Message "Launcher does not bypass local execution policy for portable start."

        Assert-ScriptParses -Content $portableInstallContent -Label "Install-Portable.ps1"
        Assert-ScriptParses -Content $portableUninstallContent -Label "Uninstall-Portable.ps1"
    }

    It "installs, updates and uninstalls portable builds" {
        Invoke-PortableInstallationLifecycleTests
    }
}
