# Audio Switcher fuer Windows 11

[![Test](https://github.com/FrnkMrz/audioswitcher/actions/workflows/test.yml/badge.svg)](https://github.com/FrnkMrz/audioswitcher/actions/workflows/test.yml)

Ein kleines, portables PowerShell-Tool, das per globalem Hotkey sofort zum naechsten aktiven Windows-Ausgabegeraet wechselt. Praktisch fuer Setups mit Lautsprechern, Headset, Monitor-Audio, Dockingstation oder Bluetooth-Kopfhoerern.

## Highlights

- kein Administratorrecht notwendig
- keine Installation, keine externen Tools
- globaler, frei waehlbarer Hotkey
- zyklischer Wechsel durch alle aktiven Ausgabegeraete
- setzt Standardgeraet fuer Konsole, Multimedia und Kommunikation
- zeigt nach jedem Wechsel kurz das aktuell aktive Ausgabegeraet an
- laeuft im Hintergrund mit Tray-Symbol
- portabel als PowerShell-Skript plus optionaler Startdatei

## Schnellstart

Repository herunterladen oder klonen und auf Windows 11 starten:

```powershell
git clone https://github.com/FrnkMrz/audioswitcher.git
cd audioswitcher
.\Start-AudioSwitcher.bat
```

Standard-Hotkey:

```text
Ctrl+Alt+A
```

Nach jedem Tastendruck wird das naechste aktive Ausgabegeraet als Standard gesetzt und kurz unten rechts eingeblendet.

## Direkt per PowerShell starten

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\AudioSwitcher.ps1
```

Mit eigenem Hotkey:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\AudioSwitcher.ps1 -Hotkey "Ctrl+Alt+F8"
```

Ohne Tray-Symbol:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\AudioSwitcher.ps1 -NoTray
```

## Hotkeys

Modifier werden mit `+` kombiniert.

| Modifier | Alternativen |
| --- | --- |
| `Ctrl` | `Control`, `Strg` |
| `Alt` | - |
| `Shift` | `Umschalt` |
| `Win` | `Windows`, `Meta` |

Beispiele:

```text
Ctrl+Alt+A
Ctrl+Alt+F8
Win+Shift+S
```

Wenn ein Hotkey schon von Windows oder einem anderen Programm belegt ist, meldet das Skript beim Start einen Fehler. Waehle dann einfach eine andere Kombination.

## Autostart

Wenn der Audio Switcher automatisch mit Windows starten soll:

1. `Win+R` druecken.
2. `shell:startup` eingeben.
3. Eine Verknuepfung zu `Start-AudioSwitcher.bat` in diesen Ordner legen.

## Beenden

Rechtsklick auf das Tray-Symbol und `Beenden` waehlen. Alternativ kann das PowerShell-Fenster geschlossen werden.

## Wie es funktioniert

Das Skript verwendet lokale Windows-CoreAudio-Schnittstellen:

1. aktive Wiedergabegeraete abrufen
2. aktuelles Standardgeraet erkennen
3. naechstes Geraet in der Liste bestimmen
4. neues Standardgeraet fuer alle relevanten Audio-Rollen setzen
5. am Listenende wieder beim ersten Geraet anfangen

Windows stellt fuer das Setzen des Standard-Audiogeraets keine offizielle PowerShell-Cmdlet-Schnittstelle bereit. Deshalb nutzt das Skript die vorhandene Windows-COM/CoreAudio-API direkt aus PowerShell heraus. Das funktioniert unter normalen Benutzerrechten.

## Tests

Die GitHub-Actions-Pipeline laeuft auf `windows-latest` und fuehrt einen Smoke-Test aus:

- PowerShell-Syntax wird geparst
- der native C#-Code wird kompiliert
- die Windows-API-Typen werden kompiliert
- wichtige Einstiegspunkte wie Hotkey-Registrierung und Audio-Umschaltung werden statisch geprueft

Der Test startet das Hintergrundprogramm nicht dauerhaft und aendert kein Audiogeraet auf dem Runner.

## Dateien

| Datei | Zweck |
| --- | --- |
| `AudioSwitcher.ps1` | Hauptskript mit Hotkey-Listener und Audio-Umschaltung |
| `AudioSwitcher.Native.cs` | Native Windows-Hotkey- und CoreAudio-Typen |
| `Start-AudioSwitcher.bat` | Doppelklick-Starter fuer Windows |
| `Tests/Test-AudioSwitcher.ps1` | Smoke-Test fuer CI |
| `.github/workflows/test.yml` | GitHub-Actions-Pipeline |

## Hinweise

Nur aktive Ausgabegeraete werden beruecksichtigt. Deaktivierte, getrennte oder reine Aufnahmegeraete werden nicht in die Rotation aufgenommen.
