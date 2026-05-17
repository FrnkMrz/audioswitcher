# Audio Switcher fuer Windows 11

[![Test](https://github.com/FrnkMrz/audioswitcher/actions/workflows/test.yml/badge.svg)](https://github.com/FrnkMrz/audioswitcher/actions/workflows/test.yml)

Ein kleines, portables PowerShell-Tool, das per globalem Hotkey sofort zum naechsten aktiven Windows-Ausgabegeraet oder Mikrofon wechselt. Praktisch fuer Setups mit Lautsprechern, Headset, Monitor-Audio, Dockingstation, Bluetooth-Kopfhoerern oder mehreren Mikrofonen.

English documentation: [README.en.md](README.en.md)

## Deutscher Quickguide

1. ZIP aus GitHub Actions herunterladen oder Repository klonen.
2. Ordner auf dem Windows-11-Laptop entpacken bzw. oeffnen.
3. `Start-AudioSwitcher.bat` doppelklicken.
4. Mit `Ctrl+Alt+A` zum naechsten aktiven Ausgabegeraet wechseln.
5. Mit `Ctrl+Alt+M` zum naechsten aktiven Mikrofon wechseln.
6. Nach jedem Tastendruck zeigt eine kleine Einblendung das neue aktuelle Geraet.
7. Rechtsklick auf das Tray-Symbol fuer `Ausgabe wechseln`, `Mikrofon wechseln` oder `Beenden`.

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
- eigener Hotkey fuer aktive Mikrofone und Aufnahmegeraete
- setzt Standardgeraet fuer Konsole, Multimedia und Kommunikation
- zeigt nach jedem Wechsel kurz das aktuell aktive Ausgabe- oder Eingabegeraet an
- kann bestimmte Ausgabe- und Eingabegeraete per Namensmuster auslassen
- laeuft im Hintergrund mit Tray-Symbol und direkten Wechselaktionen
- kann aktive Ausgabe- und Eingabegeraete mit `-ListDevices` anzeigen
- portabel als PowerShell-Skript plus optionaler Startdatei
- Release-ZIP wird durch GitHub Actions gebaut

## Schnellstart

Repository herunterladen oder klonen und auf Windows 11 starten:

```powershell
git clone https://github.com/FrnkMrz/audioswitcher.git
cd audioswitcher
.\Start-AudioSwitcher.bat
```

Standard-Hotkeys:

```text
Ctrl+Alt+A = Audioausgabe wechseln
Ctrl+Alt+M = Mikrofon wechseln
```

Nach jedem Tastendruck wird das naechste aktive Geraet als Standard gesetzt und kurz unten rechts eingeblendet.

## Direkt per PowerShell starten

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\AudioSwitcher.ps1
```

Mit eigenen Hotkeys:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\AudioSwitcher.ps1 -OutputHotkey "Ctrl+Alt+F8" -InputHotkey "Ctrl+Alt+F9"
```

Ohne Tray-Symbol:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\AudioSwitcher.ps1 -NoTray
```

Aktive Ausgabe- und Eingabegeraete anzeigen:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\AudioSwitcher.ps1 -ListDevices
```

## Konfiguration

Die Datei `config.json` steuert die Standardwerte:

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

`NotificationPosition` akzeptiert `BottomRight`, `BottomLeft`, `TopRight` und `TopLeft`.

Geraete koennen getrennt fuer Ausgabe und Eingabe mit Wildcards aus der Rotation genommen werden:

```json
"ExcludedOutputDeviceNamePatterns": [
  "*Monitor*",
  "DELL*"
],
"ExcludedInputDeviceNamePatterns": [
  "*Webcam*"
]
```

Kommandozeilenwerte wie `-OutputHotkey`, `-InputHotkey` und `-NoTray` ueberschreiben die Config fuer diesen Start. Alte Configs mit `Hotkey` funktionieren weiter; dieser Wert wird als Ausgabe-Hotkey gelesen.

Beim Start prueft das Tool die Config: Hotkeys duerfen nicht leer oder identisch sein, `NotificationPosition` muss gueltig sein und `NotificationDurationMs` muss mindestens `500` betragen.

## Hotkeys

Modifier werden mit `+` kombiniert.

| Modifier | Alternativen |
| --- | --- |
| `Ctrl` | `Control`, `Strg` |
| `Alt` | - |
| `Shift` | `Umschalt` |
| `Win` | `Windows`, `Meta` |

Standard und Beispiele:

```text
Ctrl+Alt+A = Ausgabe
Ctrl+Alt+M = Mikrofon
Ctrl+Alt+F8 = eigener Ausgabe-Hotkey
Ctrl+Alt+F9 = eigener Mikrofon-Hotkey
```

Wenn ein Hotkey schon von Windows oder einem anderen Programm belegt ist, meldet das Skript beim Start:

```text
Der Audioausgabe-Hotkey Ctrl+Alt+A ist bereits belegt. Bitte waehlen Sie eine andere Kombination.
```

Waehle dann in `config.json` oder per `-OutputHotkey` bzw. `-InputHotkey` eine andere Kombination.

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

## Troubleshooting

### Hotkey belegt

Wenn beim Start die Meldung erscheint, dass ein Hotkey bereits belegt ist, nutzt Windows oder ein anderes Programm diese Tastenkombination schon. Waehle in `config.json` andere Werte fuer `OutputHotkey` oder `InputHotkey`, zum Beispiel `Ctrl+Alt+F8` und `Ctrl+Alt+F9`.

### PowerShell blockiert Start

Starte am einfachsten `Start-AudioSwitcher.bat`, weil die Datei PowerShell bereits mit `ExecutionPolicy Bypass` aufruft. Wenn Windows heruntergeladene Dateien blockiert, oeffne PowerShell im entpackten Ordner und fuehre aus:

```powershell
Get-ChildItem -File | Unblock-File
```

### Mikrofon erscheint nicht

Es werden nur aktive Aufnahmegeraete beruecksichtigt. Pruefe in Windows unter `Einstellungen` -> `System` -> `Sound` -> `Eingabe`, ob das Mikrofon aktiviert und verbunden ist. Mit `-ListDevices` kannst du sehen, welche Mikrofone das Tool aktuell findet; pruefe bei Bedarf auch `ExcludedInputDeviceNamePatterns` in `config.json`.

### ZIP in GitHub Actions finden

Die ZIP liegt nicht direkt im Repository. Oeffne in GitHub `Actions`, waehle den letzten erfolgreichen `Test`-Lauf und lade unten bei `Artifacts` den Eintrag `AudioSwitcher` herunter. Darin liegt die portable `AudioSwitcher.zip`.

### Autostart pruefen

Der Autostart nutzt eine Verknuepfung im Windows-Startup-Ordner. Mit `Install-Autostart.ps1` wird sie angelegt, mit `Uninstall-Autostart.ps1` entfernt. Zum Kontrollieren kannst du `shell:startup` in `Win+R` eingeben und pruefen, ob dort `Audio Switcher.lnk` liegt.

## Beenden

Rechtsklick auf das Tray-Symbol und `Beenden` waehlen. Alternativ kann das PowerShell-Fenster geschlossen werden.

Im Tray-Menue kannst du auch ohne Tastenkombination direkt `Ausgabe wechseln` oder `Mikrofon wechseln` ausloesen.

## Wie es funktioniert

Das Skript verwendet lokale Windows-CoreAudio-Schnittstellen:

1. aktive Wiedergabe- oder Aufnahmegeraete abrufen
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
- wichtige Einstiegspunkte wie Hotkey-Registrierung, Anzeige, Ausgabe-Umschaltung und Mikrofon-Umschaltung werden statisch geprueft
- danach wird ein portables ZIP-Artefakt gebaut
- das ZIP enthaelt `VERSION.txt`

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
| `VERSION.txt` | Versionshinweis fuer das portable ZIP |
| `Tests/Test-AudioSwitcher.ps1` | Smoke-Test fuer CI |
| `.github/workflows/test.yml` | Testet das Tool und baut ein portables ZIP |
| `.github/workflows/release.yml` | Baut und veroeffentlicht ein Release-ZIP |

## Hinweise

Nur aktive Ausgabe- und Eingabegeraete werden beruecksichtigt. Deaktivierte, getrennte oder jeweils unpassende Geraete werden nicht in die Rotation aufgenommen.
