# Audio Switcher for Windows 11

[![Test](https://github.com/FrnkMrz/audioswitcher/actions/workflows/test.yml/badge.svg)](https://github.com/FrnkMrz/audioswitcher/actions/workflows/test.yml)

A small portable PowerShell tool that switches to the next active Windows audio output device or microphone through global hotkeys. It is useful for setups with speakers, headsets, monitor audio, docking stations, Bluetooth headphones, or multiple microphones.

German documentation: [README.md](README.md)

Comprehensive project documentation (German): [DOKUMENTATION.md](DOKUMENTATION.md)

## Quick Start

Download the GitHub Actions artifact or clone the repository on Windows 11:

```powershell
git clone https://github.com/FrnkMrz/audioswitcher.git
cd audioswitcher
.\Start-AudioSwitcher.bat
```

Default hotkeys:

```text
Ctrl+Alt+A = switch audio output
Ctrl+Alt+M = switch microphone
```

Every key press selects the next active device and shows the newly selected device in a small on-screen notification.
The tray menu also provides direct actions for switching output, switching microphone, and quitting the tool.

Recommended folder for permanent use:

- `%LocalAppData%\Programs\AudioSwitcher`
- alternatively `%UserProfile%\Tools\AudioSwitcher`

Important: copy the folder to its final location first, then run `Install-Autostart.ps1`. The startup shortcut always points to that exact folder.

Install automatically into the recommended target folder:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Install-Portable.ps1
```

Install and enable startup in one step:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Install-Portable.ps1 -InstallAutostart
```

An existing `config.json` in the target folder is preserved by default. Use `-ReplaceConfig` if you explicitly want to overwrite it.

Running the same command against an existing target folder keeps the installation updated cleanly. Managed files are replaced, no longer needed managed files are removed, and the existing `config.json` is preserved by default.

Remove the portable installation again:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Uninstall-Portable.ps1
```

## Features

- no administrator rights required
- no installation and no external tools
- configurable global hotkeys
- cycles through all active audio output devices
- cycles through all active microphone and recording devices
- sets the default device for console, multimedia, and communication roles
- shows the current output or input device after each switch
- can skip output and input devices by name pattern
- runs in the background with a tray icon and direct switch actions
- uses a fixed Audio Switcher icon for both tray and startup shortcut
- shows a cleaner tray menu with the active hotkeys visible
- can list active output and input devices with `-ListDevices`
- optional Windows startup helper scripts
- CI builds a portable release ZIP

## Run Directly With PowerShell

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\AudioSwitcher.ps1
```

Use custom hotkeys:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\AudioSwitcher.ps1 -OutputHotkey "Ctrl+Alt+F8" -InputHotkey "Ctrl+Alt+F9"
```

Run without tray icon:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\AudioSwitcher.ps1 -NoTray
```

List active output and input devices:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\AudioSwitcher.ps1 -ListDevices
```

## Configuration

Default settings are stored in `config.json`:

```json
{
  "OutputHotkey": "Ctrl+Alt+A",
  "InputHotkey": "Ctrl+Alt+M",
  "ShowTray": true,
  "NotificationDurationMs": 1800,
  "NotificationPosition": "BottomRight",
  "ExcludedOutputDeviceNamePatterns": [],
  "ExcludedInputDeviceNamePatterns": []
}
```

`NotificationPosition` supports `BottomRight`, `BottomLeft`, `TopRight`, and `TopLeft`.

Output and input devices can be excluded from their rotations with wildcard patterns:

```json
"ExcludedOutputDeviceNamePatterns": [
  "*Monitor*",
  "DELL*"
],
"ExcludedInputDeviceNamePatterns": [
  "*Webcam*"
]
```

Command-line options such as `-OutputHotkey`, `-InputHotkey`, and `-NoTray` override the config for the current launch only. Old configs with `Hotkey` still work; that value is treated as the output hotkey.

At startup the tool validates the config: hotkeys must not be empty or identical, `NotificationPosition` must be supported, and `NotificationDurationMs` must be at least `500`.

## Hotkeys

Modifiers are combined with `+`.

| Modifier | Alternatives |
| --- | --- |
| `Ctrl` | `Control`, `Strg` |
| `Alt` | - |
| `Shift` | `Umschalt` |
| `Win` | `Windows`, `Meta` |

Defaults and examples:

```text
Ctrl+Alt+A = output
Ctrl+Alt+M = microphone
Ctrl+Alt+F8 = custom output hotkey
Ctrl+Alt+F9 = custom microphone hotkey
```

If the hotkey is already used by Windows or another app, the tool shows a clear startup error:

```text
Der Audioausgabe-Hotkey Ctrl+Alt+A ist bereits belegt. Bitte waehlen Sie eine andere Kombination.
```

Choose another hotkey in `config.json` or pass one through `-OutputHotkey` or `-InputHotkey`.

## Startup

Install the Windows startup shortcut:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Install-Autostart.ps1
```

Remove it again:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Uninstall-Autostart.ps1
```

## Release ZIP

The normal GitHub Actions test pipeline builds a portable `AudioSwitcher.zip` after the smoke test and uploads it as an artifact.

The ZIP file is not stored directly in the repository. Open GitHub, go to `Actions`, select the latest successful `Test` run, and download the `AudioSwitcher` artifact. That artifact contains the portable `AudioSwitcher.zip`.

Visible downloads under `Releases` are handled by `.github/workflows/release.yml`.

- Every push to `main` updates a `latest` pre-release with the current ZIP.
- You can still create versioned releases with tags like `v1.0.0`.

```powershell
git tag v1.0.0
git push origin v1.0.0
```

## Troubleshooting

### Hotkey Already Used

If startup says that a hotkey is already used, Windows or another app has reserved that key combination. Choose different values for `OutputHotkey` or `InputHotkey` in `config.json`, for example `Ctrl+Alt+F8` and `Ctrl+Alt+F9`.

### PowerShell Blocks Startup

Prefer launching `Start-AudioSwitcher.bat`, because it already starts PowerShell with `ExecutionPolicy Bypass`. If Windows blocks downloaded files, open PowerShell in the extracted folder and run:

```powershell
Get-ChildItem -File | Unblock-File
```

### Microphone Does Not Appear

Only active recording devices are included. Check Windows `Settings` -> `System` -> `Sound` -> `Input` and make sure the microphone is enabled and connected. Use `-ListDevices` to see which microphones the tool currently detects, and check `ExcludedInputDeviceNamePatterns` in `config.json` if needed.

### Find The ZIP In GitHub Actions

The ZIP is not stored directly in the repository. Open GitHub `Actions`, select the latest successful `Test` run, and download the `AudioSwitcher` entry under `Artifacts`. That download contains the portable `AudioSwitcher.zip`.

Alternatively, check `Releases` for the visible `latest` entry with the attached ZIP.

### Check Startup

Startup uses a shortcut in the Windows Startup folder. `Install-Autostart.ps1` creates it, and `Uninstall-Autostart.ps1` removes it. To inspect it manually, press `Win+R`, enter `shell:startup`, and check whether `Audio Switcher.lnk` exists.

For a clean portable setup, keep the whole folder in a stable location such as `%LocalAppData%\Programs\AudioSwitcher`. Avoid `Downloads`, temporary extraction folders, or frequently moving cloud-sync work directories if startup should keep working.

## How It Works

The tool uses Windows CoreAudio and Win32 APIs:

1. enumerate active render or capture devices
2. read the current default device
3. choose the next device in the filtered list
4. set it as default for all relevant Windows audio roles
5. wrap back to the first device at the end of the list

Windows does not provide an official PowerShell cmdlet for changing the default audio output device. This tool therefore calls Windows COM/CoreAudio APIs directly from PowerShell and C#.

Developer note: switching uses `IPolicyConfig`, an undocumented Windows COM interface. It is stable on Windows 10 and 11 today, but it is the most likely breaking point if a future Windows version changes the internal audio policy API.

## Tests

The GitHub Actions pipeline runs on `windows-latest` and performs a smoke test:

- parses the PowerShell script
- statically checks `config.json`, startup scripts, release workflow, and documentation
- tests valid and invalid hotkey parsing
- compiles the native C# code
- verifies key entry points for hotkey registration, notification display, output switching, and microphone switching
- builds a portable ZIP artifact
- includes `VERSION.txt` in the ZIP

The test does not keep the background program running and does not change the runner's audio device.

You can run the same test runner locally:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Tests\Test-AudioSwitcher.ps1
```

That runner executes the Pester suite from `Tests/AudioSwitcher.Tests.ps1`.

## Files

| File | Purpose |
| --- | --- |
| `AudioSwitcher.ps1` | Main script with hotkey listener and notification UI |
| `AudioSwitcher.Native.cs` | Native Windows hotkey and CoreAudio interop code |
| `Start-AudioSwitcher.bat` | Double-click launcher for Windows |
| `Install-Portable.ps1` | Copies the tool into a stable target folder for daily use |
| `Uninstall-Portable.ps1` | Removes the portable installation and clears startup when present |
| `config.json` | Default configuration |
| `Install-Autostart.ps1` | Creates a Windows startup shortcut |
| `Uninstall-Autostart.ps1` | Removes the startup shortcut |
| `Assets/AudioSwitcher.ico` | Fixed icon used for tray and startup shortcut |
| `README.md` | German documentation with quick guide |
| `README.en.md` | English documentation |
| `VERSION.txt` | Version note for the portable ZIP |
| `Tests/Test-AudioSwitcher.ps1` | CI-compatible test runner (invokes Pester) |
| `Tests/AudioSwitcher.Tests.ps1` | Pester suite with smoke and lifecycle checks |
| `.github/workflows/test.yml` | Tests the tool and builds a portable ZIP |
| `.github/workflows/release.yml` | Builds and publishes release ZIPs |

## Notes

Only active output and input devices are included. Disabled, disconnected, or mismatched devices are ignored.
