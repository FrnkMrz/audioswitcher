# Audio Switcher - Vollstaendige Projektdokumentation

Diese Datei ist die zentrale Langdokumentation fuer Betrieb, Wartung und Weiterentwicklung des Audio Switcher.

## 1. Ziel und Scope

Audio Switcher ist ein portables Windows-11-Tool auf PowerShell-Basis, das per globalem Hotkey zwischen aktiven Audio-Ausgabegeraeten und aktiven Mikrofonen wechselt.

Das Tool ist fuer den taeglichen Einsatz ohne Adminrechte gedacht, insbesondere bei Setups mit mehreren:

- Lautsprechern
- Headsets
- Dockingstations
- Monitor-Audio-Ausgaben
- Mikrofonen

Nicht im Scope:

- Persistente Audio-Profile pro Anwendung
- GUI-Einstellungsdialog mit Formularen
- Installation als Windows-Service

## 2. Funktionsumfang

- globaler Ausgabe-Hotkey
- globaler Mikrofon-Hotkey
- Rotation nur ueber aktive Geraete
- getrennte Ausschlussmuster fuer Ausgabe und Eingabe
- Tray-Symbol mit Kontextmenue
- visuelle Benachrichtigung nach jedem Wechsel
- Ausgabe der aktiven Geraete per List-Modus
- portable Installation in stabilen Zielordner
- optionaler Windows-Autostart
- CI-Tests und Build eines portablen ZIP-Artefakts

## 3. Zielplattform und Voraussetzungen

### 3.1 Betriebssystem

- Windows 11 (primaer)
- Windows 10 wird voraussichtlich ebenfalls unterstuetzt, ist aber nicht die Hauptzielplattform

### 3.2 Laufzeitvoraussetzungen

- PowerShell 5.1 oder neuer
- PowerShell muss im STA-Modus (Single-Threaded Apartment) laufen. `Start-AudioSwitcher.bat` stellt das sicher. Wird das Skript direkt gestartet, prueft es den Apartment-Zustand und bricht mit einer klaren Fehlermeldung ab, wenn MTA erkannt wird.
- .NET/Windows Forms Laufzeitkomponenten (im Windows-Client standardmaessig vorhanden)

### 3.3 Rechte

- keine Administratorrechte erforderlich

## 4. Architekturueberblick

### 4.1 Technischer Ansatz

Audio Switcher kombiniert:

- PowerShell fuer Orchestrierung, Konfiguration und UI-Lebenszyklus
- eingebetteten C#-Interop-Code fuer Win32-Hotkeys und CoreAudio-Zugriff

### 4.2 Hauptbausteine

- [AudioSwitcher.ps1](AudioSwitcher.ps1): Hauptprozess, Config-Laden, Hotkey-Registrierung, Tray und Benachrichtigungen
- [AudioSwitcher.Native.cs](AudioSwitcher.Native.cs): Win32- und CoreAudio-Interop, eigentliche Umschaltlogik
- [config.json](config.json): Standardkonfiguration
- [Start-AudioSwitcher.bat](Start-AudioSwitcher.bat): Doppelklick-Start mit passender ExecutionPolicy

### 4.3 Datenfluss beim Umschalten

1. Hotkey-Ereignis wird von der Hotkey-Window-Klasse empfangen.
2. Je nach Geraeteart (Output/Input) wird die passende Switch-Funktion aufgerufen.
3. Die Native-Schicht ermittelt aktive Geraete, filtert Ausschluesse und waehlt das naechste Geraet.
4. Standardgeraet wird fuer relevante Rollen gesetzt.
5. Rueckmeldung wird im Terminal, als Overlay und optional als Tray-Balloon angezeigt.

## 5. Konfiguration

Die Konfiguration liegt in [config.json](config.json).

Beispiel:

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

### 5.1 Konfigurationsfelder

- OutputHotkey: Hotkey fuer Ausgabegeraet-Wechsel
- InputHotkey: Hotkey fuer Mikrofon-Wechsel
- ShowTray: Tray-Symbol ein/aus
- NotificationDurationMs: Sichtdauer des Overlays in Millisekunden (Minimum 500)
- NotificationPosition: BottomRight, BottomLeft, TopRight oder TopLeft
- ExcludedOutputDeviceNamePatterns: Wildcard-Muster fuer auszuschliessende Ausgabegeraete (`*` fuer beliebig viele Zeichen, `?` fuer genau ein Zeichen)
- ExcludedInputDeviceNamePatterns: Wildcard-Muster fuer auszuschliessende Eingabegeraete (`*` fuer beliebig viele Zeichen, `?` fuer genau ein Zeichen)

### 5.2 Validierung beim Start

Beim Programmstart werden unter anderem geprueft:

- Hotkeys nicht leer
- OutputHotkey und InputHotkey nicht identisch
- Hotkey-Format parsebar
- NotificationPosition in erlaubter Wertebasis
- NotificationDurationMs >= 500

### 5.3 Rueckwaertskompatibilitaet

Aeltere Konfigurationen bleiben nutzbar:

- Hotkey wird als Legacy-Wert fuer OutputHotkey uebernommen
- ExcludedDeviceNamePatterns wird als Legacy-Wert fuer ExcludedOutputDeviceNamePatterns uebernommen

## 6. Kommandozeilenreferenz

### 6.1 Hauptskript

Datei: [AudioSwitcher.ps1](AudioSwitcher.ps1)

Parameter:

- -Hotkey (Legacy-Alias fuer Ausgabe-Hotkey)
- -OutputHotkey
- -InputHotkey
- -ListDevices
- -NoTray

Beispiele:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\AudioSwitcher.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\AudioSwitcher.ps1 -OutputHotkey "Ctrl+Alt+F8" -InputHotkey "Ctrl+Alt+F9"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\AudioSwitcher.ps1 -ListDevices
```

### 6.2 Portable Installation

Datei: [Install-Portable.ps1](Install-Portable.ps1)

Parameter:

- -DestinationPath (Standard: %LocalAppData%\Programs\AudioSwitcher)
- -InstallAutostart
- -ReplaceConfig

Verhalten:

- legt Zielordner an
- kopiert verwaltete Projektdateien
- ersetzt alte verwaltete Dateien
- entfernt nicht mehr verwaltete Altdateien anhand Install-State
- behaelt vorhandene config.json standardmaessig bei
- schreibt Install-State-Datei .audioswitcher-install.json

### 6.3 Portable Deinstallation

Datei: [Uninstall-Portable.ps1](Uninstall-Portable.ps1)

Parameter:

- -DestinationPath (Standard: %LocalAppData%\Programs\AudioSwitcher)

Verhalten:

- Sicherheitspruefung auf gueltigen Zielpfad
- optionales Entfernen eines passend verknuepften Autostart-Shortcuts
- rekursives Entfernen des Installationsordners

### 6.4 Autostart

Dateien:

- [Install-Autostart.ps1](Install-Autostart.ps1)
- [Uninstall-Autostart.ps1](Uninstall-Autostart.ps1)

Verhalten:

- erstellt/entfernt Audio Switcher.lnk in shell:startup
- Shortcut startet `powershell.exe` direkt mit `-STA`, `-WindowStyle Hidden` und [AudioSwitcher.ps1](AudioSwitcher.ps1)
- Shortcut nutzt optional [Assets/AudioSwitcher.ico](Assets/AudioSwitcher.ico)

## 7. Betriebskonzepte

### 7.1 Empfohlener Dauerbetrieb

1. Projekt nach %LocalAppData%\Programs\AudioSwitcher installieren.
2. Optional Autostart aktivieren.
3. Konfiguration nur ueber config.json pflegen.
4. Updates erneut ueber Install-Portable.ps1 einspielen.

### 7.2 Upgrade-Strategie

Empfehlung fuer Updates:

1. Neue Version in separates Verzeichnis laden.
2. Install-Portable.ps1 aus neuer Version starten.
3. Bestehende config.json wird beibehalten (ohne -ReplaceConfig).
4. Funktionstest mit Hotkeys und Tray-Menue.

### 7.3 Rollback

Ein dedizierter Rollback-Mechanismus ist nicht eingebaut.
Empfehlte Praxis:

1. Vor Update den bestehenden Installationsordner sichern.
2. Bei Problemen auf die gesicherte Version zurueckkopieren.
3. Optional den neuen Stand via Uninstall-Portable.ps1 entfernen.

## 8. Qualitaetssicherung und Tests

### 8.1 Lokale Tests

- [Tests/Test-AudioSwitcher.ps1](Tests/Test-AudioSwitcher.ps1) startet die Pester-Suite.
- [Tests/AudioSwitcher.Tests.ps1](Tests/AudioSwitcher.Tests.ps1) enthaelt Smoke- und Lifecycle-Tests.

Ausfuehrung:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Tests\Test-AudioSwitcher.ps1
```

### 8.2 CI

- [.github/workflows/test.yml](.github/workflows/test.yml): Testpipeline inklusive ZIP-Build
- [.github/workflows/release.yml](.github/workflows/release.yml): Releasepipeline fuer sichtbare ZIP-Assets unter Releases (auch ohne Tag via latest-Pre-Release)

Hinweis: Die CI testet Struktur, Parsing und Build-Aspekte. Ein echter End-to-End-Audiowechsel in einer interaktiven Desktop-Session ist im Hosted-Runner nur eingeschraenkt abbildbar.

## 9. Sicherheit, Datenschutz und Risiken

### 9.1 Sicherheitsprofil

- keine Netzwerkkommunikation fuer Kernfunktion erforderlich
- keine Persistenz sensibler Nutzdaten
- keine Hintergrunddienste mit erweiterten Rechten

### 9.2 Datenschutz

Das Tool verarbeitet nur lokal verfuegbare Geraetenamen und lokale Benutzereingaben (Hotkeys). Es sendet keine Telemetrie.

### 9.3 Bekannte technische Risiken

- Nutzung der undokumentierten COM-Schnittstelle IPolicyConfig
- COM-Fehler beim Setzen des Standardgeraets werden separat als `COMException` gefangen und liefern HRESULT sowie Geraetenamen in der Fehlermeldung
- moegliche Inkompatibilitaet bei zukuenftigen Windows-Aenderungen
- Hotkey-Konflikte mit Drittsoftware

### 9.4 Harter Sicherheitsrahmen fuer Skripte

- Zielpfade werden auf gefaehrliche Werte (z. B. Laufwerksroot) geprueft.
- Portable-Deinstallation validiert den Zielordner, bevor geloescht wird.

## 10. Troubleshooting-Matrix

- MTA-Fehler beim Start: PowerShell laeuft im MTA-Modus. Start ueber `Start-AudioSwitcher.bat` verwenden (startet mit `-STA`)
- Hotkey registriert nicht: andere Kombination waehlen, Konflikt mit OS/App
- Kein Mikrofon in Rotation: Geraet aktivieren, in Windows pruefen, Exclude-Patterns pruefen
- Keine Benachrichtigung sichtbar: NotificationPosition pruefen, ggf. ShowTray/NoTray Verhalten testen
- Start aus Explorer blockiert: ueber Start-AudioSwitcher.bat oder Unblock-File starten
- Autostart wirkt nicht: Shortcut in shell:startup pruefen und Zielpfad validieren

## 11. Wartung und Weiterentwicklung

### 11.1 Wartungs-Checkliste pro Release

1. VERSION.txt aktualisieren.
2. README und diese Doku auf Konsistenz pruefen.
3. Tests lokal ausfuehren.
4. CI-Ergebnis auf windows-latest pruefen.
5. Release-Workflow ueber main (latest) oder optional per Versionstag veroeffentlichen.

### 11.2 Code-Ownership-Empfehlung

- Core-Logik: AudioSwitcher.ps1 + AudioSwitcher.Native.cs
- Packaging: Install-/Uninstall-Skripte
- CI/CD: Workflows unter .github/workflows
- Dokumentation: README.md, README.en.md, DOKUMENTATION.md

### 11.3 Definition of Done fuer Features

Ein Feature gilt als abgeschlossen, wenn:

- Anforderungen dokumentiert sind
- Tests angepasst oder begruendet unveraendert sind
- CI gruen ist
- Doku aktualisiert ist
- keine Regression im Hotkey- oder Tray-Verhalten erkennbar ist

## 12. Repository-Referenz

Wichtige Dateien im Ueberblick:

- [README.md](README.md): deutsche Kurz- und Betriebsdoku
- [README.en.md](README.en.md): englische Kurz- und Betriebsdoku
- [DOKUMENTATION.md](DOKUMENTATION.md): ausfuehrliche Projektdokumentation
- [LICENSE](LICENSE): Lizenztext
- [VERSION.txt](VERSION.txt): Versionshinweis fuer Artefakte

## 13. Supportprozess (empfohlen)

Fuer Issues und Fehlerberichte sollten mindestens enthalten sein:

- Windows-Version
- Ausgabe von -ListDevices
- relevante config.json (ohne private Daten)
- exakte Fehlermeldung
- Schritte zur Reproduktion

Empfohlene Reihenfolge bei Analyse:

1. Konfigurationsvalidierung
2. Hotkey-Konfliktanalyse
3. Geraeteliste und Exclude-Patterns
4. Startmodus (direkt, BAT, Autostart)
5. Regression gegen letzte funktionierende Version
