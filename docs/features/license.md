# Lizenz

Für die Ersteinrichtung und den Betrieb ist ein gültiger Lizenzzugang erforderlich. Der API-Dienst prüft die Lizenz über den Lizenzdienst (`MEDORA_LICENSE_API_URL`, HTTPS) und validiert signierte Tokens mit einem öffentlichen RSA-Schlüssel (mind. 2048 Bit).

## Verhalten

| Zustand                        | Auswirkung                                                              |
| ------------------------------ | ----------------------------------------------------------------------- |
| aktiv                          | normaler Betrieb                                                        |
| nicht aktiv / gesperrt         | Zugriff wird abgelehnt (HTTP 403)                                       |
| Lizenzserver nicht erreichbar  | Prüfung nicht möglich (HTTP 503); ein bereits gespeicherter Token gilt weiter |
| Kulanzzeit abgelaufen          | Nur-Lesen-Modus: schreibende Aktionen werden mit HTTP 423 abgelehnt     |
| Benutzerlimit erreicht         | weitere Konten werden abgelehnt (HTTP 409)                              |

## Konfiguration

| Variable                              | Zweck                                          |
| ------------------------------------- | ---------------------------------------------- |
| `MEDORA_LICENSE_API_URL`         | Adresse des Lizenzdienstes                     |
| `MEDORA_LICENSE_PUBLIC_KEY_FILE` | Datei mit dem öffentlichen Schlüssel (optional) |
| `MEDORA_LICENSE_PUBLIC_KEY`      | öffentlicher Schlüssel als Text (optional)     |

Ohne eigene Angabe wird der mitgelieferte Schlüssel verwendet. Administratoren können den Status prüfen und ein Token einspielen.

Für bestehende Lizenzdienste akzeptiert MEDora die fest zugeordneten Paare
`medora-licensing`/`medora` und `clinicpulse-licensing`/`clinicpulse` für
Aussteller (`iss`) und Zielgruppe (`aud`). Gemischte oder andere Paare werden
abgelehnt. Beide Token-Arten müssen weiterhin mit dem konfigurierten Schlüssel
signiert sein; die Bindung des Lizenzstatus an Lizenz und Installation bleibt
erforderlich. Die Kompatibilität gilt erst für Releases, die diese Änderung
enthalten, nicht rückwirkend für `v-0.4.1.2-alpha`.

Der MEDora-Lizenzmanager stellt standardmäßig Tokens mit
`medora-licensing`/`medora` aus und akzeptiert weiterhin mit demselben Schlüssel
signierte ältere ClinicPulse-Lizenzen. Vor der Umstellung des Lizenzservers
müssen alle Clients eine Version verwenden, die MEDora-Statustokens versteht;
insbesondere `v-0.4.1.2-alpha` erfüllt diese Voraussetzung nicht.
Für Aktivierung und Statusabfrage sendet MEDora `medora_version` und das
Kompatibilitätsfeld `clinicpulse_version`; aktuelle Lizenzmanager akzeptieren
beide Feldnamen.

## Installation und private Images

Der öffentliche Installer fragt den Lizenzschlüssel verdeckt ab und ruft vor
dem ersten Image-Pull `/api/v1/instances/activate` auf. Die Lizenz muss aktiv
oder in der konfigurierten Kulanzzeit sein; außerdem muss noch ein
Installationsplatz frei sein. Erst danach meldet Docker sich mit der
Installations-ID und dem Lizenzschlüssel am Registry-Proxy an.

Die MEDora-Images liegen privat auf GHCR. Kunden erhalten weder GitHub-Zugang
noch GHCR-Zugangsdaten. `registry.cyberspaceconsulting.de` leitet Image-Pulls
über einen lizenzgeprüften Proxy weiter. Der Proxy akzeptiert ausschließlich
freigegebene Installationen, erteilt höchstens fünf Minuten gültige Tokens mit
`pull`-Rechten auf die MEDora-Images und prüft Lizenzstatus sowie
Installationssperren bei jeder Token-Anfrage erneut. Der Lizenzserver und der
Proxy benötigen ausgehenden HTTPS-Zugriff auf GitHub Container Registry.

Ein geänderter Installer kann diese Serverprüfung nicht umgehen: direkte
Pulls über den Proxy benötigen dieselben Lizenzdaten; direkte GHCR-Pulls
benötigen ein serverseitiges GitHub-Credential, das Kunden nicht erhalten.
Ein bereits autorisierter Betreiber kann heruntergeladene Images jedoch
kopieren oder auf einem eigenen Host verändern.

## Module

Enthält ein Lizenz-Token eine Featureliste, muss sie `core_scheduling` oder
`all` enthalten; andernfalls werden Ersteinrichtung und Tokenwechsel abgelehnt.
Bei älteren Tokens ohne Featureliste bleibt das bisherige Verhalten erhalten.
Weitere Featureeinträge sind aktuell nur Lizenzangaben und schränken einzelne
MEDora-Funktionen nicht ein. VIP und Warnungsunterdrückung werden unabhängig
von `vip_override` über den signierten Status gesteuert. Bei einer Modelländerung
muss der aktualisierte Lizenz-Token neu ausgestellt und eingespielt werden.

## Einrichtungsart aus der Lizenz

Die Einrichtungsart (Krankenhaus, Rettungsdienst, Leitstelle, Pflegeeinrichtung, Sonstige) und das Bundesland stammen normalerweise aus dem signierten Lizenztoken und lassen sich dann nicht überschreiben. Die Ersteinrichtung liest die Einrichtungsart aus dem Token und verlangt je nach Art weitere Angaben (Name der Hauptleitstelle bei der Leitstelle, Begriffe und Struktur bei „Sonstige“), siehe [Ersteinrichtung](../getting-started/first-setup.md). Das Eingabeformular wertet die Einrichtungsart nur zur Anzeige im Browser aus; der Server prüft das Token.
