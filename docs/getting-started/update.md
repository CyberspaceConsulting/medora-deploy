# MEDora aktualisieren

Plane eine kurze Unterbrechung ein und lies vor dem Update die Hinweise zum
neuen Release auf [medora-deploy GitHub Releases](https://github.com/CyberspaceConsulting/medora-deploy/releases).
Der Update-Hinweis in der Anwendung vergleicht Images über den lizenzgeprüften
Registry-Proxy. Sichere zuerst Datenbank, Verschlüsselungsschlüssel und
Konfiguration; prüfe auch, ob das Backup wiederherstellbar ist. Führe kein
`docker compose down -v` aus, da dadurch Compose-Volumes gelöscht werden.

## Installation aus einem Release aktualisieren

Führe den öffentlichen Installer erneut aus und gib dein vorhandenes
Installationsverzeichnis an. Er übernimmt die dort gespeicherte
Installations-ID, fragt den Lizenzschlüssel am Terminal ab und autorisiert den
Image-Pull beim Lizenzserver. Direkte `docker compose pull`-Aufrufe sind für
Release-Installationen nicht vorgesehen, weil deren kurzlebige Registry-
Anmeldedaten nur der Installer verwaltet.

Für das neueste stabile Release:

```sh
curl --fail --location --silent --show-error https://raw.githubusercontent.com/CyberspaceConsulting/medora-deploy/main/install.sh | sh -s -- /pfad/zur/medora-installation
```

Für ein Alpha- oder gezieltes Release ersetze `RELEASE_TAG` durch dessen Tag:

```sh
curl --fail --location --silent --show-error https://raw.githubusercontent.com/CyberspaceConsulting/medora-deploy/main/install.sh | MEDORA_RELEASE_TAG=RELEASE_TAG sh -s -- /pfad/zur/medora-installation
```

Der Installer verifiziert die signierten Release-Prüfsummen, prüft die
Lizenzfreigabe vor dem Pull und startet danach die festgelegten Images. Verwende
das Verzeichnis der bestehenden Installation, damit Volumes, Schlüssel und
Einstellungen erhalten bleiben.

Wenn die optionale Integritätsprüfung in der Admin-Oberfläche verwendet wird,
müssen nach dem Update Agent, Overlay und konfigurierter Release-Tag auf das
neue Release aktualisiert werden. Beachte die
[Einrichtung und Sicherheitsgrenzen](installation.md#integritätsprüfung-in-der-admin-oberfläche).

## Datenbankänderungen

Neue Tabellen und Spalten legt das Backend beim Start automatisch an; bestehende
Daten bleiben erhalten. Dazu gehören zuletzt die Zuordnung von Personen zu
weiteren Abteilungen (`employee_department_access`), Fahrzeuge (`vehicles`,
`shift_types.vehicle_id`) und die Begriffs- und Strukturfelder der
Betriebskonfiguration. Eine Rückkehr zur älteren Version nach dem Start der
neuen ist nur mit der zuvor erstellten Sicherung möglich. Bestehende Dienste
werden nicht verändert; neue Zuweisungen verlangen jedoch die passende
Qualifikation, siehe [Dienstplanung](../features/shift-planning.md).

## Installation aus dem Quellcode aktualisieren

Beim ersten Umstieg auf das verwaltete Schlüssel-Volume nicht direkt `docker compose up` verwenden: Führe im Repository `sh deploy/install.sh "$PWD"` aus, wenn die bisherigen Dateien in `./secrets` liegen. Bei einem anderen Installationsziel denselben Zielpfad wie bisher angeben. Der Installer importiert vorhandene Schlüssel vor dem Start.

Im bestehenden Repository-Hauptverzeichnis:

```sh
git status
git pull --ff-only
docker compose -f docker/docker-compose.yml up --build -d
docker compose -f docker/docker-compose.yml ps
docker compose -f docker/docker-compose.yml logs --tail=100 backend
```

`git pull --ff-only` aktualisiert den ausgecheckten Branch nur, wenn dies ohne
Merge möglich ist. Kläre lokale Änderungen oder einen fehlgeschlagenen Pull,
bevor du fortfährst. Wenn du ein bestimmtes Release oder einen anderen Branch
verwenden möchtest, prüfe zuerst dessen Release-Hinweise und wechsle bewusst
darauf. Verwende bei eigenen Compose-Dateien oder Einstellungen dieselben
Optionen und Umgebungsvariablen wie bei der ursprünglichen Installation.

Wurde aus dem Checkout mit `deploy/install.sh` installiert, liegen Secrets und
Backups standardmäßig im Zielverzeichnis `medora`. Führe nach dem
Aktualisieren des Checkouts stattdessen erneut `sh deploy/install.sh
./medora` aus, damit diese Pfade beim Neubau verwendet werden.

Prüfe anschließend den Status und die Erreichbarkeit der Anwendung. Bei
Problemen helfen die [Fehlerbehebung](../troubleshooting.md) und die zuvor
geprüfte Sicherung. Ein Downgrade ist nach Datenbankänderungen nicht
grundsätzlich sicher; beachte die Hinweise des jeweiligen Releases.
