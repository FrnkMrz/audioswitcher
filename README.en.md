# Audio Switcher for Windows 11

[![Test](https://github.com/FrnkMrz/audioswitcher/actions/workflows/test.yml/badge.svg)](https://github.com/FrnkMrz/audioswitcher/actions/workflows/test.yml)

A small portable PowerShell tool that switches to the next active Windows audio output device through a global hotkey. It is useful for setups with speakers, headsets, monitor audio, docking stations, or Bluetooth headphones.

German documentation: [README.md](README.md)

## Quick Start

Download the GitHub Actions artifact or clone the repository on Windows 11:

```powershell
git clone https://github.com/FrnkMrz/audioswitcher.git
cd audioswitcher
.\Start-AudioSwitcher.bat
```

Default hotkey:

```text
Ctrl+Alt+A
```

Every key press selects the next active output device and shows the newly selected device in a small on-screen notification.

## Features

- no administrator rights required
- no installation and no external tools
- configurable global hotkey
- cycles through all active audio output devices
- sets the default device for console, multimedia, and communication roles
- shows the current output device after each switch
- can skip devices by name pattern
- runs in the background with a tray icon
- optional Windows startup helper scripts
- CI builds a portable release ZIP

## Run Directly With PowerShell

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\AudioSwitcher.ps1
```

Use a custom hotkey:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\AudioSwitcher.ps1 -Hotkey "Ctrl+Alt+F8"
```

Run without tray icon:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\AudioSwitcher.ps1 -NoTray
```

## Configuration

Default settings are stored in `config.json`:

```json
{
  "Hotkey": "Ctrl+Alt+A",
  "ShowTray": true,
  "NotificationDurationMs": 1800,
  "NotificationPosition": "BottomRight",
  "ExcludedDeviceNamePatterns": []
}
```

`NotificationPosition` supports `BottomRight`, `BottomLeft`, `TopRight`, and `TopLeft`.

Devices can be excluded from the rotation with wildcard patterns:

```json
"ExcludedDeviceNamePatterns": [
  "*Monitor*",
  "DELL*"
]
```

Command-line options such as `-Hotkey` and `-NoTray` override the config for the current launch only.

## Hotkeys

Modifiers are combined with `+`.

| Modifier | Alternatives |
| --- | --- |
| `Ctrl` | `Control`, `Strg` |
| `Alt` | - |
| `Shift` | `Umschalt` |
| `Win` | `Windows`, `Meta` |

Examples:

```text
Ctrl+Alt+A
Ctrl+Alt+F8
Win+Shift+S
```

If the hotkey is already used by Windows or another app, the tool shows a clear startup error:

```text
Der Hotkey Ctrl+Alt+A ist bereits belegt. Bitte waehlen Sie eine andere Kombination.
```

Choose another hotkey in `config.json` or pass one through `-Hotkey`.

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

Tagged releases are handled by `.github/workflows/release.yml`. A tag like `v1.0.0` creates a GitHub Release with the ZIP attached.

```powershell
git tag v1.0.0
git push origin v1.0.0
```

## How It Works

The tool uses Windows CoreAudio and Win32 APIs:

1. enumerate active render devices
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
- verifies key entry points for hotkey registration, notification display, and audio switching
- builds a portable ZIP artifact

The test does not keep the background program running and does not change the runner's audio device.

## Files

| File | Purpose |
| --- | --- |
| `AudioSwitcher.ps1` | Main script with hotkey listener and notification UI |
| `AudioSwitcher.Native.cs` | Native Windows hotkey and CoreAudio interop code |
| `Start-AudioSwitcher.bat` | Double-click launcher for Windows |
| `config.json` | Default configuration |
| `Install-Autostart.ps1` | Creates a Windows startup shortcut |
| `Uninstall-Autostart.ps1` | Removes the startup shortcut |
| `README.md` | German documentation with quick guide |
| `README.en.md` | English documentation |
| `Tests/Test-AudioSwitcher.ps1` | CI smoke test |
| `.github/workflows/test.yml` | Tests the tool and builds a portable ZIP |
| `.github/workflows/release.yml` | Builds and publishes release ZIPs |

## Notes

Only active output devices are included. Disabled, disconnected, or input-only devices are ignored.
