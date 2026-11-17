# MEDora – Dokumentation & Deployment

[![Dokumentation](https://img.shields.io/badge/Dokumentation-online-39835d)](https://cyberspaceconsulting.github.io/medora-deploy/)
[![Release](https://img.shields.io/github/v/release/CyberspaceConsulting/medora-deploy?include_prereleases&label=Release)](https://github.com/CyberspaceConsulting/medora-deploy/releases)
[![Status](https://img.shields.io/badge/Status-Alpha-orange)](https://cyberspaceconsulting.github.io/medora-deploy/)

Dieses öffentliche Repository enthält die Dokumentation und den Installer für
[MEDora](https://cyberspaceconsulting.github.io/medora-deploy/), eine
selbst gehostete Anwendung für die Dienstplanung. Der Anwendungscode und die
Container-Images sind nicht öffentlich. Die Images werden nach erfolgreicher
Lizenzprüfung über einen Registry-Proxy bereitgestellt; ein GitHub-Konto ist
für die Installation nicht erforderlich.

> **Alpha:** MEDora ist noch nicht produktionsreif. Bis zu einer unabhängigen
> Sicherheits- und Datenschutzprüfung sollten keine echten sensiblen Daten
> verarbeitet werden.

## Schnellstart

Für die Installation benötigst du:

- Docker Engine mit Docker Compose v2 auf einem unterstützten 64-Bit-System
  (AMD64 oder ARM64)
- `curl`, `uuidgen`, `sha256sum` und
  [Cosign](https://docs.sigstore.dev/cosign/system_config/installation/)
- einen gültigen MEDora-Lizenzschlüssel, ein interaktives Terminal und
  ausgehenden HTTPS-Zugriff

Führe den Installer im gewünschten übergeordneten Verzeichnis aus:

```sh
curl --fail --location --silent --show-error https://raw.githubusercontent.com/CyberspaceConsulting/medora-deploy/main/install.sh | sh
```

Der Installer verwendet standardmäßig das Unterverzeichnis `medora`, fragt
den Lizenzschlüssel verdeckt ab und prüft Release-Signatur und Prüfsummen.
Erst nach Lizenzfreigabe werden die privaten Images heruntergeladen.
Anschließend erreichst du MEDora unter `http://localhost:8080` und kannst
die [Ersteinrichtung](https://cyberspaceconsulting.github.io/medora-deploy/getting-started/first-setup)
abschließen.

Details zu Voraussetzungen, Ports und Konfiguration stehen in der
[Installationsanleitung](https://cyberspaceconsulting.github.io/medora-deploy/getting-started/installation).

## Releases und Tags

Der Installer verwendet standardmäßig den Tag aus
[`current-release`](./current-release). Dieser verweist auf das aktuell
veröffentlichte Release und kann auch eine Alpha-Version sein.
Alle verfügbaren Versionen und ihre Hinweise findest du unter
[Releases](https://github.com/CyberspaceConsulting/medora-deploy/releases).

Um eine bestimmte Version auszuwählen, ersetze `RELEASE_TAG` durch einen
veröffentlichten Tag:

```sh
curl --fail --location --silent --show-error https://raw.githubusercontent.com/CyberspaceConsulting/medora-deploy/main/install.sh | MEDORA_RELEASE_TAG=RELEASE_TAG sh
```

Ältere Alpha-Releases können bekannte Installations- oder Datenbankprobleme
enthalten. Beachte die Release-Hinweise und verwende für Neuinstallationen
ein aktuelles Release.

## Betrieb und Updates

Vor Updates Datenbank, Verschlüsselungsschlüssel und Konfiguration sichern.
Führe den Installer danach im bisherigen übergeordneten Verzeichnis erneut
aus, damit die vorhandene Installation und ihre Installations-ID weiter
verwendet werden. Weitere Hinweise, auch zu bestehenden Installationen,
stehen in der [Update-Anleitung](https://cyberspaceconsulting.github.io/medora-deploy/getting-started/update).

- [Docker Compose und Speicher](https://cyberspaceconsulting.github.io/medora-deploy/getting-started/docker-compose)
- [Umgebungsvariablen und Secrets](https://cyberspaceconsulting.github.io/medora-deploy/getting-started/environment-variables)
- [Fehlerbehebung](https://cyberspaceconsulting.github.io/medora-deploy/troubleshooting)

Den Datenverschlüsselungsschlüssel getrennt von der Datenbank sichern: Ohne
den ursprünglichen Schlüssel lassen sich verschlüsselte Daten nicht
wiederherstellen.

## Veröffentlichung

Dokumentation und Installer werden aus dem privaten MEDora-Repository
synchronisiert. Der Release-Workflow veröffentlicht die signierten
Installationsartefakte und aktualisiert `current-release`; der Pages-Workflow
veröffentlicht `docs/` vom Branch `main`. Die Release-Artefakte enthalten
keinen Anwendungscode.

Vor der ersten Veröffentlichung muss ein Repository-Administrator in den
GitHub-Einstellungen **Pages → GitHub Actions** als Quelle aktivieren; das
Workflow-Token kann Pages nicht selbst aktivieren.
