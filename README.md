# Durango Hellcat App

Private Begleit-App für den **Dodge Durango SRT Hellcat 2025**, nur für das eigene iPhone.
Geschrieben in Swift und SwiftUI, ab iOS 17.

## Was die App kann (Version 0.1)

- **Live**: Drehzahl, Tempo, Ladedruck, Gaspedal, Kühlmittel-, Öl- und Ansauglufttemperatur, Batteriespannung, Warm-up-Hinweis
- **Fehlercodes** aus dem Motorsteuergerät lesen, mit Klartext für die häufigsten Codes
- **Performance**: 0–100, 0–200 und 100–200 km/h, mit Bestzeiten. Nutzt das OBD-Tempo, ohne Adapter GPS
- **Wartungsheft** mit Erinnerungen nach Kilometern oder Monaten
- **Tankbuch** mit Verbrauch und Kosten
- **Demo-Modus**, damit man alles ohne Adapter ausprobieren kann

Die App liest nur. Schreiben (z. B. Fehlercodes löschen) blockiert das Secure Gateway des Durango.

## Auf dem iPhone installieren

1. Xcode aus dem Mac App Store installieren (Version 16 oder neuer).
2. Dieses Repository klonen und `HellcatApp.xcodeproj` öffnen.
3. Links das Projekt **HellcatApp** wählen, dann *Signing & Capabilities* und bei **Team** deine Apple-ID auswählen.
   Falls Xcode meckert, dass die Bundle ID vergeben ist: `ch.patrickschaub.HellcatApp` leicht ändern.
4. iPhone per Kabel anschließen, oben als Ziel auswählen und auf ▶︎ klicken.
5. Beim ersten Mal auf dem iPhone: *Einstellungen › Allgemein › VPN & Geräteverwaltung* dem Entwickler vertrauen
   und unter *Datenschutz & Sicherheit* den **Entwicklermodus** einschalten.

Mit einer kostenlosen Apple-ID läuft die App 7 Tage, danach einfach erneut aus Xcode installieren.
Mit dem Apple Developer Program (99 $ pro Jahr) läuft sie ein Jahr.

## OBD-Adapter

Empfohlen: **OBDLink CX** (Bluetooth LE). iPhones können nur mit Bluetooth-LE-Adaptern frei kommunizieren.
Der OBDLink MX+ funktioniert auf dem iPhone nur mit Apps, die Apple dafür freigeschaltet hat.

1. Adapter in die OBD-Buchse unter dem Lenkrad stecken, Zündung an.
2. In der App auf **Adapter › Nach Adapter suchen** tippen und den Adapter auswählen.
3. Werte, die das Fahrzeug nicht liefert, erscheinen als „n. v.“ und werden nicht mehr abgefragt.

## Aufbau

| Ordner | Inhalt |
|---|---|
| `HellcatApp/OBD` | Bluetooth-Verbindung, ELM327-Befehle, Parser für Antworten und Fehlercodes |
| `HellcatApp/Performance` | Zeitmessung mit OBD- oder GPS-Tempo |
| `HellcatApp/Models` | SwiftData-Modelle für Wartung, Tanken und Messungen |
| `HellcatApp/Views` | Alle Bildschirme |

Neue Swift-Dateien im Ordner `HellcatApp` erkennt Xcode automatisch.
