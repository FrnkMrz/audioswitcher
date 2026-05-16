# Audio Switcher fuer Windows 11

Portables PowerShell-Tool, das per Hotkey zum naechsten aktiven Windows-Ausgabegeraet wechselt.

## Eigenschaften

- funktioniert ohne Administratorrechte
- keine Installation notwendig
- frei waehlbarer globaler Hotkey
- schaltet aktive Ausgabegeraete zyklisch durch
- setzt das neue Geraet fuer Konsole, Multimedia und Kommunikation
- laeuft im Hintergrund mit Tray-Symbol

## Start

Per Doppelklick:

```text
Start-AudioSwitcher.bat
```

In PowerShell im Projektordner ausfuehren:

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\AudioSwitcher.ps1
```

Standard-Hotkey:

```text
Ctrl+Alt+A
```

Mit eigenem Hotkey starten:

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\AudioSwitcher.ps1 -Hotkey "Ctrl+Alt+F8"
```

Ohne Tray-Symbol starten:

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\AudioSwitcher.ps1 -NoTray
```

## Hotkey-Format

Modifier werden mit `+` kombiniert. Unterstuetzt werden:

- `Ctrl` oder `Strg`
- `Alt`
- `Shift` oder `Umschalt`
- `Win`

Beispiele:

```text
Ctrl+Alt+A
Ctrl+Alt+F8
Win+Shift+S
```

## Beenden

Rechtsklick auf das Tray-Symbol und `Beenden` auswaehlen. Alternativ das PowerShell-Fenster schliessen.

## Hinweise

Windows bietet fuer das Setzen des Standard-Audiogeraets keine offiziell dokumentierte PowerShell-Schnittstelle. Das Skript nutzt deshalb die lokale Windows-CoreAudio-Schnittstelle, die auch unter normalen Benutzerrechten funktioniert. Es braucht weder Administratorrechte noch externe Programme.

Nur aktive Ausgabegeraete werden beruecksichtigt. Deaktivierte, getrennte oder nur als Aufnahmegeraet vorhandene Geraete werden nicht in die Rotation aufgenommen.
