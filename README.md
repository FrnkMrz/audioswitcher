# Audio Switcher fuer Windows 11

[![Test](https://github.com/FrnkMrz/audioswitcher/actions/workflows/test.yml/badge.svg)](https://github.com/FrnkMrz/audioswitcher/actions/workflows/test.yml)

Ein kleines, portables PowerShell-Tool, das per globalem Hotkey sofort zum naechsten aktiven Windows-Ausgabegeraet wechselt. Praktisch fuer Setups mit Lautsprechern, Headset, Monitor-Audio, Dockingstation oder Bluetooth-Kopfhoerern.

English documentation: [README.en.md](README.en.md)

## Deutscher Quickguide

1. ZIP aus GitHub Actions herunterladen oder Repository klonen.
2. Ordner auf dem Windows-11-Laptop entpacken bzw. oeffnen.
3. `Start-AudioSwitcher.bat` doppelklicken.
4. Mit `Ctrl+Alt+A` zum naechsten aktiven Ausgabegeraet wechseln.
5. Nach jedem Tastendruck zeigt eine kleine Einblendung das neue aktuelle Ausgabegeraet.
6. Rechtsklick auf das Tray-Symbol und `Beenden`, wenn das Tool beendet werden soll.

Autostart einrichten:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Install-Autostart.ps1
```

Autostart entfernen:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Uninstall-Autostart.ps1
```

## Highlights

- kein Administratorrecht notwendig
- keine Installation, keine externen Tools
- globaler, frei waehlbarer Hotkey
- zyklischer Wechsel durch alle aktiven Ausgabegeraete
- setzt Standardgeraet fuer Konsole, Multimedia und Kommunikation
- zeigt nach jedem Wechsel kurz das aktuell aktive Ausgabegeraet an
- kann bestimmte Ausgabegeraete per Namensmuster auslassen
- laeuft im Hintergrund mit Tray-Symbol
- portabel als PowerShell-Skript plus optionaler Startdatei
- Release-ZIP wird durch GitHub Actions gebaut

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

## Konfiguration

Die Datei `config.json` steuert die Standardwerte:

```json
{
  "Hotkey": "Ctrl+Alt+A",
  "ShowTray": true,
  "NotificationDurationMs": 1800,
  "NotificationPosition": "BottomRight",
  "ExcludedDeviceNamePatterns": []
}
```

`NotificationPosition` akzeptiert `BottomRight`, `BottomLeft`, `TopRight` und `TopLeft`.

Geraete koennen mit Wildcards aus der Rotation genommen werden:

```json
"ExcludedDeviceNamePatterns": [
  "*Monitor*",
  "DELL*"
]
```

Kommandozeilenwerte wie `-Hotkey` und `-NoTray` ueberschreiben die Config fuer diesen Start.

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

Wenn ein Hotkey schon von Windows oder einem anderen Programm belegt ist, meldet das Skript beim Start:

```text
Der Hotkey Ctrl+Alt+A ist bereits belegt. Bitte waehlen Sie eine andere Kombination.
```

Waehle dann in `config.json` oder per `-Hotkey` eine andere Kombination.

## Autostart

Wenn der Audio Switcher automatisch mit Windows starten soll:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Install-Autostart.ps1
```

Autostart wieder entfernen:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Uninstall-Autostart.ps1
```

## Release-ZIP

Die normale GitHub-Actions-Pipeline baut nach dem Smoke-Test ein portables `AudioSwitcher.zip` und laedt es als Artifact hoch.

Die ZIP-Datei liegt nicht direkt im Repository. Du findest sie in GitHub unter `Actions` -> letzter erfolgreicher `Test`-Lauf -> `Artifacts` -> `AudioSwitcher`. Dort laedst du ein GitHub-Artifact herunter, in dem die portable `AudioSwitcher.zip` enthalten ist.

Fuer echte Releases gibt es zusaetzlich den Workflow `.github/workflows/release.yml`. Bei Tags wie `v1.0.0` wird ein GitHub Release mit ZIP-Anhang erzeugt.

```powershell
git tag v1.0.0
git push origin v1.0.0
```

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

Hinweis fuer Entwickler: Das Umschalten nutzt `IPolicyConfig`, eine undokumentierte Windows-COM-Schnittstelle. Sie funktioniert unter Windows 10 und 11 stabil, kann aber bei zukuenftigen Windows-Versionen ein Breaking-Point sein.

## Tests

Die GitHub-Actions-Pipeline laeuft auf `windows-latest` und fuehrt einen Smoke-Test aus:

- PowerShell-Syntax wird geparst
- `config.json`, Autostart-Skripte und Release-Workflow werden statisch geprueft
- deutsche und englische Dokumentation werden statisch geprueft
- Hotkey-Parsing wird mit gueltigen und ungueltigen Kombinationen getestet
- der native C#-Code wird kompiliert
- die Windows-API-Typen werden kompiliert
- wichtige Einstiegspunkte wie Hotkey-Registrierung, Anzeige und Audio-Umschaltung werden statisch geprueft
- danach wird ein portables ZIP-Artefakt gebaut

Der Test startet das Hintergrundprogramm nicht dauerhaft und aendert kein Audiogeraet auf dem Runner.

## Dateien

| Datei | Zweck |
| --- | --- |
| `AudioSwitcher.ps1` | Hauptskript mit Hotkey-Listener und Audio-Umschaltung |
| `AudioSwitcher.Native.cs` | Native Windows-Hotkey- und CoreAudio-Typen |
| `Start-AudioSwitcher.bat` | Doppelklick-Starter fuer Windows |
| `config.json` | Standard-Konfiguration fuer Hotkey, Anzeige und ausgeschlossene Geraete |
| `Install-Autostart.ps1` | Erstellt eine Windows-Autostart-Verknuepfung |
| `Uninstall-Autostart.ps1` | Entfernt die Windows-Autostart-Verknuepfung |
| `README.md` | Deutsche Dokumentation mit Quickguide |
| `README.en.md` | Englische Dokumentation |
| `Tests/Test-AudioSwitcher.ps1` | Smoke-Test fuer CI |
| `.github/workflows/test.yml` | Testet das Tool und baut ein portables ZIP |
| `.github/workflows/release.yml` | Baut und veroeffentlicht ein Release-ZIP |

## Hinweise

Nur aktive Ausgabegeraete werden beruecksichtigt. Deaktivierte, getrennte oder reine Aufnahmegeraete werden nicht in die Rotation aufgenommen.
