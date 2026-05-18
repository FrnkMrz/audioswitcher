$ErrorActionPreference = "Stop"

Describe "AudioSwitcher repository smoke tests" {
    BeforeAll {
        $script:repoRoot               = Split-Path -Parent $PSScriptRoot
        $script:scriptPath             = Join-Path $script:repoRoot "AudioSwitcher.ps1"
        $script:nativeTypePath         = Join-Path $script:repoRoot "AudioSwitcher.Native.cs"
        $script:configPath             = Join-Path $script:repoRoot "config.json"
        $script:readmePath             = Join-Path $script:repoRoot "README.md"
        $script:englishReadmePath      = Join-Path $script:repoRoot "README.en.md"
        $script:versionPath            = Join-Path $script:repoRoot "VERSION.txt"
        $script:iconPath               = Join-Path $script:repoRoot "Assets/AudioSwitcher.ico"
        $script:gitignorePath          = Join-Path $script:repoRoot ".gitignore"
        $script:launcherPath           = Join-Path $script:repoRoot "Start-AudioSwitcher.bat"
        $script:portableInstallPath    = Join-Path $script:repoRoot "Install-Portable.ps1"
        $script:portableUninstallPath  = Join-Path $script:repoRoot "Uninstall-Portable.ps1"
        $script:installAutostartPath   = Join-Path $script:repoRoot "Install-Autostart.ps1"
        $script:uninstallAutostartPath = Join-Path $script:repoRoot "Uninstall-Autostart.ps1"
        $script:testWorkflowPath       = Join-Path $script:repoRoot ".github/workflows/test.yml"
        $script:releaseWorkflowPath    = Join-Path $script:repoRoot ".github/workflows/release.yml"

        $script:AssertTrue = {
            param(
                [bool]$Condition,
                [string]$Message
            )

            if (-not $Condition) {
                throw $Message
            }
        }

        $script:AssertThrows = {
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

        $script:AssertMatch = {
            param(
                [string]$Content,
                [string]$Pattern,
                [string]$Message
            )

            & $script:AssertTrue ([System.Text.RegularExpressions.Regex]::IsMatch($Content, $Pattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)) $Message
        }

        $script:AssertContains = {
            param(
                [string]$Content,
                [string]$ExpectedText,
                [string]$Message
            )

            & $script:AssertTrue ($Content.Contains($ExpectedText)) $Message
        }

        $script:AssertScriptParses = {
            param(
                [string]$Content,
                [string]$Label
            )

            $localParseErrors = $null
            [System.Management.Automation.Language.Parser]::ParseInput($Content, [ref]$null, [ref]$localParseErrors) | Out-Null
            & $script:AssertTrue ($localParseErrors.Count -eq 0) ("$Label parser found errors: " + ($localParseErrors | ForEach-Object { $_.Message } | Out-String))
        }

        $script:ResolveWindowsFormsReferences = {
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

            # System.Management.Automation wird fuer WildcardPattern in AudioSwitcher.Native.cs benoetigt.
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

        $script:InvokePortableInstallationLifecycleTests = {
            $tempRoot = Join-Path $env:TEMP ("AudioSwitcher-Smoke-" + [guid]::NewGuid().ToString("N"))

            try {
                & $script:portableInstallPath -DestinationPath $tempRoot

                & $script:AssertTrue (Test-Path -LiteralPath (Join-Path $tempRoot "AudioSwitcher.ps1")) "Portable install did not copy AudioSwitcher.ps1."
                & $script:AssertTrue (Test-Path -LiteralPath (Join-Path $tempRoot ".audioswitcher-install.json")) "Portable install did not write the install manifest."

                Set-Content -LiteralPath (Join-Path $tempRoot "config.json") -Value '{"OutputHotkey":"Ctrl+Alt+F8"}' -Encoding UTF8
                Set-Content -LiteralPath (Join-Path $tempRoot ".audioswitcher-install.json") -Value (@{ ManagedPaths = @("obsolete.txt") } | ConvertTo-Json) -Encoding UTF8
                Set-Content -LiteralPath (Join-Path $tempRoot "obsolete.txt") -Value "old file" -Encoding UTF8

                & $script:portableInstallPath -DestinationPath $tempRoot

                $preservedConfig = Get-Content -LiteralPath (Join-Path $tempRoot "config.json") -Raw | ConvertFrom-Json
                & $script:AssertTrue ($preservedConfig.OutputHotkey -eq "Ctrl+Alt+F8") "Portable install should preserve an existing config.json by default."
                & $script:AssertTrue (-not (Test-Path -LiteralPath (Join-Path $tempRoot "obsolete.txt"))) "Portable install should remove obsolete managed files from a previous manifest."

                & $script:portableInstallPath -DestinationPath $tempRoot -ReplaceConfig

                $replacedConfig = Get-Content -LiteralPath (Join-Path $tempRoot "config.json") -Raw | ConvertFrom-Json
                & $script:AssertTrue ($replacedConfig.OutputHotkey -eq "Ctrl+Alt+A") "Portable install with -ReplaceConfig should restore the default config.json."

                & $script:portableUninstallPath -DestinationPath $tempRoot
                & $script:AssertTrue (-not (Test-Path -LiteralPath $tempRoot)) "Portable uninstall should remove the installation directory."

                $driveRoot = [System.IO.Path]::GetPathRoot($tempRoot)
                & $script:AssertThrows { & $script:portableInstallPath -DestinationPath $driveRoot } "Portable install should reject a drive root as DestinationPath."
                & $script:AssertThrows { & $script:portableUninstallPath -DestinationPath $driveRoot } "Portable uninstall should reject a drive root as DestinationPath."
            }
            finally {
                if (Test-Path -LiteralPath $tempRoot) {
                    Remove-Item -LiteralPath $tempRoot -Recurse -Force
                }
            }
        }

        $readRequiredFileContent = {
            param(
                [string]$Path,
                [string]$Label
            )

            if (-not (Test-Path -LiteralPath $Path)) {
                throw ("Required file for {0} was not found: {1}" -f $Label, $Path)
            }

            try {
                Get-Content -LiteralPath $Path -Raw -ErrorAction Stop
            }
            catch {
                throw ("Failed to read {0} at '{1}': {2}" -f $Label, $Path, $_.Exception.Message)
            }
        }

        $script:scriptContent = & $readRequiredFileContent -Path $script:scriptPath -Label "AudioSwitcher.ps1"
        $script:nativeTypeContent = & $readRequiredFileContent -Path $script:nativeTypePath -Label "AudioSwitcher.Native.cs"
        $script:configContent = & $readRequiredFileContent -Path $script:configPath -Label "config.json"
        $script:readmeContent = & $readRequiredFileContent -Path $script:readmePath -Label "README.md"
        $script:englishReadmeContent = & $readRequiredFileContent -Path $script:englishReadmePath -Label "README.en.md"
        $script:versionContent = & $readRequiredFileContent -Path $script:versionPath -Label "VERSION.txt"
        $script:gitignoreContent = & $readRequiredFileContent -Path $script:gitignorePath -Label ".gitignore"
        $script:portableInstallContent = & $readRequiredFileContent -Path $script:portableInstallPath -Label "Install-Portable.ps1"
        $script:portableUninstallContent = & $readRequiredFileContent -Path $script:portableUninstallPath -Label "Uninstall-Portable.ps1"
        $script:installAutostartContent = & $readRequiredFileContent -Path $script:installAutostartPath -Label "Install-Autostart.ps1"
        $script:uninstallAutostartContent = & $readRequiredFileContent -Path $script:uninstallAutostartPath -Label "Uninstall-Autostart.ps1"
        $script:testWorkflowContent = & $readRequiredFileContent -Path $script:testWorkflowPath -Label ".github/workflows/test.yml"
        $script:releaseWorkflowContent = & $readRequiredFileContent -Path $script:releaseWorkflowPath -Label ".github/workflows/release.yml"
    }

    It "has all expected project files" {
        $paths = @(
            $script:scriptPath,
            $script:nativeTypePath,
            $script:configPath,
            $script:readmePath,
            $script:englishReadmePath,
            $script:versionPath,
            $script:iconPath,
            $script:gitignorePath,
            $script:launcherPath,
            $script:portableInstallPath,
            $script:portableUninstallPath,
            $script:installAutostartPath,
            $script:uninstallAutostartPath,
            $script:testWorkflowPath,
            $script:releaseWorkflowPath
        )

        foreach ($path in $paths) {
            & $script:AssertTrue (Test-Path -LiteralPath $path) ("Required file was not found: " + $path)
        }
    }

    It "contains required script features" {
        & $script:AssertScriptParses -Content $script:scriptContent -Label "AudioSwitcher.ps1"
        & $script:AssertMatch -Content $script:scriptContent -Pattern 'OutputHotkey = "Ctrl\+Alt\+A"' -Message "Default output hotkey is missing or changed."
        & $script:AssertMatch -Content $script:scriptContent -Pattern 'InputHotkey = "Ctrl\+Alt\+M"' -Message "Default input hotkey is missing or changed."
        & $script:AssertMatch -Content $script:scriptContent -Pattern 'Get-AudioSwitcherConfig' -Message "Config loader is missing."
        & $script:AssertMatch -Content $script:scriptContent -Pattern 'ExcludedOutputDeviceNamePatterns' -Message "Output exclusion patterns are not wired into the script."
        & $script:AssertMatch -Content $script:scriptContent -Pattern 'ExcludedInputDeviceNamePatterns' -Message "Input exclusion patterns are not wired into the script."
        & $script:AssertMatch -Content $script:scriptContent -Pattern 'ExcludedDeviceNamePatterns' -Message "Legacy excluded device patterns should remain supported."
        & $script:AssertMatch -Content $script:scriptContent -Pattern 'AudioSwitcher\.Native\.cs' -Message "Native C# type file is not loaded."
        & $script:AssertMatch -Content $script:scriptContent -Pattern 'Show-SwitchNotification' -Message "On-screen switch notification is missing."
        & $script:AssertMatch -Content $script:scriptContent -Pattern 'New-AudioSwitcherTrayIcon' -Message "Custom tray icon builder is missing."
        & $script:AssertMatch -Content $script:scriptContent -Pattern 'Get-AudioSwitcherIconPath' -Message "Tray icon path resolver is missing."
        & $script:AssertMatch -Content $script:scriptContent -Pattern 'DestroyIcon' -Message "Tray icon handle cleanup is missing."
        & $script:AssertMatch -Content $script:scriptContent -Pattern 'Assert-AudioSwitcherConfig' -Message "Config validation is missing."
        & $script:AssertMatch -Content $script:scriptContent -Pattern 'Write-AudioSwitcherDeviceList' -Message "Device listing command is missing."
        & $script:AssertMatch -Content $script:scriptContent -Pattern 'ListDevices' -Message "ListDevices parameter is missing."
        & $script:AssertMatch -Content $script:scriptContent -Pattern 'Ausgabe wechseln' -Message "Tray output switch action is missing."
        & $script:AssertMatch -Content $script:scriptContent -Pattern 'Mikrofon wechseln' -Message "Tray input switch action is missing."
        & $script:AssertMatch -Content $script:scriptContent -Pattern 'tray\.Icon = \$trayIcon' -Message "Tray should prefer the custom icon when it is available."
        & $script:AssertMatch -Content $script:scriptContent -Pattern '\$menuHotkeys = \[System\.Windows\.Forms\.ToolStripMenuItem\]::new\("\$OutputHotkey  \|  \$InputHotkey"\)' -Message "Tray menu should show the active hotkeys."
        & $script:AssertMatch -Content $script:scriptContent -Pattern 'Aktuelles Mikrofon' -Message "Input switch notification title is missing."
        & $script:AssertMatch -Content $script:scriptContent -Pattern 'FormBorderStyle\]::None' -Message "Notification should be borderless."
        & $script:AssertMatch -Content $script:scriptContent -Pattern '\.TopMost\s*=\s*\$true' -Message "Notification should be topmost."
        & $script:AssertMatch -Content $script:scriptContent -Pattern 'System\.Windows\.Forms\.Timer' -Message "Notification auto-dismiss timer is missing."
        & $script:AssertMatch -Content $script:scriptContent -Pattern '\.AutoEllipsis\s*=\s*\$true' -Message "Notification should handle long device names."
        & $script:AssertMatch -Content $script:scriptContent -Pattern 'notificationForm\.Dispose' -Message "Notification form cleanup is missing."
        & $script:AssertMatch -Content $script:scriptContent -Pattern 'NotificationPosition' -Message "Notification position setting is missing."
        & $script:AssertMatch -Content $script:scriptContent -Pattern 'SetHighDpiMode' -Message "DPI awareness setup is missing."
        & $script:AssertMatch -Content $script:scriptContent -Pattern 'PerMonitorV2' -Message "DPI awareness should prefer per-monitor scaling."
        & $script:AssertMatch -Content $script:scriptContent -Pattern 'MethodInvocationException' -Message "Blocked hotkey errors should be handled explicitly."
        & $script:AssertMatch -Content $script:scriptContent -Pattern 'InvalidOperationException' -Message "Direct blocked hotkey errors should be handled explicitly."
        & $script:AssertMatch -Content $script:scriptContent -Pattern 'Der \$Label-Hotkey \$HotkeyText ist bereits belegt' -Message "Blocked hotkey message should identify the affected hotkey."
        & $script:AssertMatch -Content $script:scriptContent -Pattern 'OutputHotkey und InputHotkey duerfen nicht identisch sein' -Message "Duplicate output/input hotkeys should be rejected."
        & $script:AssertMatch -Content $script:scriptContent -Pattern 'AudioDeviceKind\]::Output' -Message "Output hotkey window is missing."
        & $script:AssertMatch -Content $script:scriptContent -Pattern 'AudioDeviceKind\]::Input' -Message "Input hotkey window is missing."
        & $script:AssertMatch -Content $script:scriptContent -Pattern 'MOD_CONTROL' -Message "Hotkey modifier constants should be documented."
        & $script:AssertMatch -Content $script:scriptContent -Pattern 'PerMonitorV2\) is enabled' -Message "Fixed notification size should mention DPI scaling."
        & $script:AssertMatch -Content $script:scriptContent -Pattern '\[Math\]::Min\(\$formWidth,\s*600\)' -Message "Die Benachrichtigungsbreite wird nicht auf maximal 600 Pixel gedeckelt (erwartet: [Math]::Min(`$formWidth, 600))."
    }

    It "contains required native and packaging features" {
        & $script:AssertMatch -Content $script:nativeTypeContent -Pattern 'RegisterHotKey' -Message "Hotkey registration entry point is missing."
        & $script:AssertMatch -Content $script:nativeTypeContent -Pattern 'MOD_NOREPEAT' -Message "Hotkey repeat suppression is missing."
        & $script:AssertMatch -Content $script:nativeTypeContent -Pattern 'AudioDeviceKind' -Message "Hotkey window should know whether it controls output or input."
        & $script:AssertMatch -Content $script:nativeTypeContent -Pattern 'SwitchOutputToNext' -Message "Output switching entry point is missing."
        & $script:AssertMatch -Content $script:nativeTypeContent -Pattern 'SwitchInputToNext' -Message "Input switching entry point is missing."
        & $script:AssertMatch -Content $script:nativeTypeContent -Pattern 'ListOutputDevices' -Message "Output device listing entry point is missing."
        & $script:AssertMatch -Content $script:nativeTypeContent -Pattern 'ListInputDevices' -Message "Input device listing entry point is missing."
        & $script:AssertMatch -Content $script:nativeTypeContent -Pattern '0bd7a1be-7a1a-44db-8397-cc5392387b5e' -Message "IMMDeviceCollection IID is incorrect."
        & $script:AssertContains -Content $script:nativeTypeContent -ExpectedText 'EDataFlow.eRender' -Message "Output switching should enumerate render devices."
        & $script:AssertContains -Content $script:nativeTypeContent -ExpectedText 'EDataFlow.eCapture' -Message "Input switching should enumerate capture devices."
        & $script:AssertMatch -Content $script:nativeTypeContent -Pattern 'IsExcluded' -Message "Device exclusion filtering is missing."
        & $script:AssertMatch -Content $script:nativeTypeContent -Pattern 'WildcardPattern' -Message "Device exclusion patterns should be wildcard-safe."
        & $script:AssertMatch -Content $script:nativeTypeContent -Pattern 'SetDefaultEndpoint' -Message "Audio endpoint switching entry point is missing."
        & $script:AssertMatch -Content $script:nativeTypeContent -Pattern 'DEVICE_STATE_ACTIVE' -Message "Active-device filtering is missing."
        & $script:AssertMatch -Content $script:nativeTypeContent -Pattern 'FinalReleaseComObject' -Message "COM object cleanup is missing."

        $config = $script:configContent | ConvertFrom-Json
        & $script:AssertTrue ($config.OutputHotkey -eq "Ctrl+Alt+A") "config.json default output hotkey is incorrect."
        & $script:AssertTrue ($config.InputHotkey -eq "Ctrl+Alt+M") "config.json default input hotkey is incorrect."
        & $script:AssertTrue ($config.ShowTray -eq $true) "config.json should enable tray by default."
        & $script:AssertTrue ($config.NotificationDurationMs -ge 500) "config.json notification duration is too low."
        & $script:AssertTrue ($config.NotificationPosition -eq "BottomRight") "config.json notification position is incorrect."
        & $script:AssertTrue (($config.PSObject.Properties.Name -contains "ExcludedOutputDeviceNamePatterns")) "config.json output excluded device list is missing."
        & $script:AssertTrue (($config.PSObject.Properties.Name -contains "ExcludedInputDeviceNamePatterns")) "config.json input excluded device list is missing."
        & $script:AssertMatch -Content $script:versionContent -Pattern '^AudioSwitcher\s+\d+\.\d+\.\d+' -Message "VERSION.txt should contain a semantic AudioSwitcher version."

        & $script:AssertMatch -Content $script:installAutostartContent -Pattern 'WScript\.Shell' -Message "Autostart installer should create a Windows shortcut."
        & $script:AssertMatch -Content $script:installAutostartContent -Pattern 'Startup' -Message "Autostart installer should target the Startup folder."
        & $script:AssertMatch -Content $script:installAutostartContent -Pattern 'Start-AudioSwitcher\.bat' -Message "Autostart installer should launch the batch file."
        & $script:AssertMatch -Content $script:installAutostartContent -Pattern 'IconLocation' -Message "Autostart installer should assign the project icon to the shortcut."
        & $script:AssertMatch -Content $script:portableInstallContent -Pattern 'LOCALAPPDATA' -Message "Portable installer should default to LocalAppData."
        & $script:AssertMatch -Content $script:portableInstallContent -Pattern 'Install-Autostart\.ps1' -Message "Portable installer should be able to install autostart in the target directory."
        & $script:AssertMatch -Content $script:portableInstallContent -Pattern 'ReplaceConfig' -Message "Portable installer should support preserving an existing config."
        & $script:AssertMatch -Content $script:portableInstallContent -Pattern 'Assets' -Message "Portable installer should copy the Assets folder."
        & $script:AssertMatch -Content $script:portableInstallContent -Pattern 'ManagedPaths' -Message "Portable installer should track managed install paths."
        & $script:AssertMatch -Content $script:portableInstallContent -Pattern 'Read-InstallState' -Message "Portable installer should read an existing install state for updates."
        & $script:AssertMatch -Content $script:portableInstallContent -Pattern 'Write-InstallState' -Message "Portable installer should write an install state manifest."
        & $script:AssertMatch -Content $script:portableUninstallContent -Pattern 'LOCALAPPDATA' -Message "Portable uninstaller should default to LocalAppData."
        & $script:AssertMatch -Content $script:portableUninstallContent -Pattern 'CreateShortcut' -Message "Portable uninstaller should inspect the startup shortcut before deleting it."
        & $script:AssertMatch -Content $script:portableUninstallContent -Pattern 'TargetPath' -Message "Portable uninstaller should only remove autostart for the matching installation."
        & $script:AssertMatch -Content $script:portableUninstallContent -Pattern '\.audioswitcher-install\.json' -Message "Portable uninstaller should recognize the install manifest."
        & $script:AssertMatch -Content $script:uninstallAutostartContent -Pattern 'Remove-Item' -Message "Autostart uninstaller should remove the shortcut."

        & $script:AssertMatch -Content $script:readmeContent -Pattern 'Deutscher Quickguide' -Message "German quick guide is missing."
        & $script:AssertMatch -Content $script:readmeContent -Pattern 'README\.en\.md' -Message "German README should link the English documentation."
        & $script:AssertMatch -Content $script:readmeContent -Pattern 'Release-ZIP' -Message "German README should document release ZIPs."
        & $script:AssertMatch -Content $script:readmeContent -Pattern 'Ctrl\+Alt\+M' -Message "German README should document the input hotkey."
        & $script:AssertMatch -Content $script:readmeContent -Pattern 'Mikrofon' -Message "German README should document microphone switching."
        & $script:AssertMatch -Content $script:readmeContent -Pattern '-ListDevices' -Message "German README should document device listing."
        & $script:AssertMatch -Content $script:readmeContent -Pattern 'Ausgabe wechseln' -Message "German README should document tray switch actions."
        & $script:AssertMatch -Content $script:readmeContent -Pattern 'LocalAppData' -Message "German README should recommend a stable install location."
        & $script:AssertMatch -Content $script:readmeContent -Pattern 'AudioSwitcher\.ico' -Message "German README should document the fixed icon asset."
        & $script:AssertMatch -Content $script:readmeContent -Pattern 'Install-Portable\.ps1' -Message "German README should document the portable installer."
        & $script:AssertMatch -Content $script:readmeContent -Pattern 'Uninstall-Portable\.ps1' -Message "German README should document the portable uninstaller."
        & $script:AssertMatch -Content $script:readmeContent -Pattern 'aktualisiert' -Message "German README should document update behavior."
        & $script:AssertMatch -Content $script:readmeContent -Pattern 'VERSION\.txt' -Message "German README should document the version file."

        & $script:AssertMatch -Content $script:englishReadmeContent -Pattern 'Audio Switcher for Windows 11' -Message "English README title is missing."
        & $script:AssertMatch -Content $script:englishReadmeContent -Pattern 'Quick Start' -Message "English quick start is missing."
        & $script:AssertMatch -Content $script:englishReadmeContent -Pattern 'GitHub Actions test pipeline builds a portable' -Message "English README should document CI ZIP artifacts."
        & $script:AssertMatch -Content $script:englishReadmeContent -Pattern 'Ctrl\+Alt\+M' -Message "English README should document the input hotkey."
        & $script:AssertMatch -Content $script:englishReadmeContent -Pattern 'microphone' -Message "English README should document microphone switching."
        & $script:AssertMatch -Content $script:englishReadmeContent -Pattern '-ListDevices' -Message "English README should document device listing."
        & $script:AssertMatch -Content $script:englishReadmeContent -Pattern 'LocalAppData' -Message "English README should recommend a stable install location."
        & $script:AssertMatch -Content $script:englishReadmeContent -Pattern 'AudioSwitcher\.ico' -Message "English README should document the fixed icon asset."
        & $script:AssertMatch -Content $script:englishReadmeContent -Pattern 'Install-Portable\.ps1' -Message "English README should document the portable installer."
        & $script:AssertMatch -Content $script:englishReadmeContent -Pattern 'Uninstall-Portable\.ps1' -Message "English README should document the portable uninstaller."
        & $script:AssertMatch -Content $script:englishReadmeContent -Pattern 'keeps the installation updated cleanly' -Message "English README should document update behavior."
        & $script:AssertMatch -Content $script:englishReadmeContent -Pattern 'VERSION\.txt' -Message "English README should document the version file."
        & $script:AssertMatch -Content $script:englishReadmeContent -Pattern 'not stored directly in the repository' -Message "English README should explain that ZIP artifacts are not committed."
        & $script:AssertMatch -Content $script:englishReadmeContent -Pattern 'README\.md' -Message "English README should link the German documentation."

        & $script:AssertMatch -Content $script:gitignoreContent -Pattern 'AudioSwitcher\.zip' -Message ".gitignore should ignore the generated ZIP."
        & $script:AssertMatch -Content $script:gitignoreContent -Pattern '\*\.log' -Message ".gitignore should ignore local logs."
        & $script:AssertMatch -Content $script:gitignoreContent -Pattern '\.DS_Store' -Message ".gitignore should ignore macOS metadata."
        & $script:AssertMatch -Content $script:gitignoreContent -Pattern '\*\.icloud' -Message ".gitignore should ignore iCloud placeholder files."

        & $script:AssertMatch -Content $script:testWorkflowContent -Pattern 'VERSION\.txt' -Message "Test ZIP should include VERSION.txt."
        & $script:AssertMatch -Content $script:testWorkflowContent -Pattern 'Assets' -Message "Test ZIP should include the Assets folder."
        & $script:AssertMatch -Content $script:testWorkflowContent -Pattern 'Uninstall-Portable\.ps1' -Message "Test ZIP should include the portable uninstaller."

        & $script:AssertMatch -Content $script:releaseWorkflowContent -Pattern 'Compress-Archive' -Message "Release workflow should build a ZIP file."
        & $script:AssertMatch -Content $script:releaseWorkflowContent -Pattern 'Assets' -Message "Release ZIP should include the Assets folder."
        & $script:AssertMatch -Content $script:releaseWorkflowContent -Pattern 'Uninstall-Portable\.ps1' -Message "Release ZIP should include the portable uninstaller."
        & $script:AssertMatch -Content $script:releaseWorkflowContent -Pattern 'README\.en\.md' -Message "Release ZIP should include English documentation."
        & $script:AssertMatch -Content $script:releaseWorkflowContent -Pattern 'VERSION\.txt' -Message "Release ZIP should include VERSION.txt."
        & $script:AssertMatch -Content $script:releaseWorkflowContent -Pattern 'actions/upload-artifact@v4' -Message "Release workflow should upload the ZIP artifact."
        & $script:AssertMatch -Content $script:releaseWorkflowContent -Pattern 'softprops/action-gh-release@v2' -Message "Release workflow should publish tagged releases."
    }

    It "compiles the native interop and enumerates devices" {
        Add-Type -AssemblyName System.Windows.Forms
        Add-Type -AssemblyName System.Drawing
        Add-Type -ReferencedAssemblies (& $script:ResolveWindowsFormsReferences) -Path $script:nativeTypePath

        [void][PortableAudioSwitcher.AudioSwitcher]
        [void][PortableAudioSwitcher.HotkeyWindow]

        $outputDevices = [PortableAudioSwitcher.AudioSwitcher]::ListOutputDevices()
        $inputDevices = [PortableAudioSwitcher.AudioSwitcher]::ListInputDevices()

        & $script:AssertTrue ($null -ne $outputDevices) "Output device enumeration returned null."
        & $script:AssertTrue ($null -ne $inputDevices) "Input device enumeration returned null."
    }

    It "parses hotkeys from ConvertTo-HotkeyParts" {
        $scriptParseErrors = $null
        $scriptAst = [System.Management.Automation.Language.Parser]::ParseInput($script:scriptContent, [ref]$null, [ref]$scriptParseErrors)
        & $script:AssertTrue ($scriptParseErrors.Count -eq 0) "AST parse failed for AudioSwitcher.ps1."

        $hotkeyFunctionAst = $scriptAst.Find({
            param($node)
            $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
                $node.Name -eq "ConvertTo-HotkeyParts"
        }, $true)

        & $script:AssertTrue ($hotkeyFunctionAst -ne $null) "ConvertTo-HotkeyParts function was not found."

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

        & $script:AssertThrows { & $hotkeyFunctionAst.Extent.Text; ConvertTo-HotkeyParts -HotkeyText "" } "Empty hotkey should fail."
        & $script:AssertThrows { & $hotkeyFunctionAst.Extent.Text; ConvertTo-HotkeyParts -HotkeyText "Ctrl+Alt+A+B" } "Multiple normal keys should fail."
        & $script:AssertThrows { & $hotkeyFunctionAst.Extent.Text; ConvertTo-HotkeyParts -HotkeyText "Ctrl+Alt+DefinitelyNotAKey" } "Unknown key should fail."
    }

    It "parses helper scripts and validates launcher" {
        $launcherContent = Get-Content -LiteralPath $script:launcherPath -Raw
        & $script:AssertMatch -Content $launcherContent -Pattern 'AudioSwitcher\.ps1' -Message "Launcher does not call AudioSwitcher.ps1."
        & $script:AssertMatch -Content $launcherContent -Pattern 'ExecutionPolicy Bypass' -Message "Launcher does not bypass local execution policy for portable start."

        & $script:AssertScriptParses -Content $script:portableInstallContent -Label "Install-Portable.ps1"
        & $script:AssertScriptParses -Content $script:portableUninstallContent -Label "Uninstall-Portable.ps1"
    }

    It "installs, updates and uninstalls portable builds" {
        & $script:InvokePortableInstallationLifecycleTests
    }
}
