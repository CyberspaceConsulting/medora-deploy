# Installation

MEDora wird als Release mit Docker Compose gestartet. Weboberfläche, API und PostgreSQL laufen dabei in getrennten Containern.

## Voraussetzungen

- Docker Engine mit Docker Compose v2
- `curl`, `uuidgen`, `sha256sum` und [Cosign](https://docs.sigstore.dev/cosign/system_config/installation/)
- Ein gültiger Lizenzzugang und ausgehender HTTPS-Zugriff des Backends auf den Lizenzdienst

## Release installieren

Für die Standardinstallation genügt dieser Befehl. Der Installer fragt den Lizenzschlüssel verdeckt im Terminal ab, prüft die Installation beim MEDora-Lizenzserver und lädt private Images erst nach Freigabe:

```sh
curl --fail --location --silent --show-error https://raw.githubusercontent.com/CyberspaceConsulting/medora-deploy/main/install.sh | sh
```

Der Installer verwendet den im öffentlichen Repository markierten aktuellen
Release-Tag. Benötigt werden `curl`, `uuidgen`, `sha256sum`, Cosign, Docker
Engine mit Compose v2 und ein interaktives Terminal. Der Lizenzschlüssel wird
nicht in die Shell-Historie geschrieben. Für ein bestimmtes Alpha-Release kann
der Tag explizit angegeben werden:

```sh
curl --fail --location --silent --show-error https://raw.githubusercontent.com/CyberspaceConsulting/medora-deploy/main/install.sh | MEDORA_RELEASE_TAG=RELEASE_TAG sh
```

Die öffentlichen Installationsdateien liegen im [medora-deploy-Repository](https://github.com/CyberspaceConsulting/medora-deploy). Jedes Release enthält eine von MEDora GitHub Actions signierte Prüfsummenliste. Die Compose-Datei pinnt Backend und Web per Image-Digest. Die Images selbst bleiben privat auf GHCR und werden nur über den lizenzgeprüften Registry-Proxy ausgeliefert; Kunden benötigen keinen GitHub-Account.

Für Updates sicherst du zuerst Datenbank, Schlüssel und Konfiguration und führst denselben Installer erneut im bestehenden Installationsverzeichnis aus. Er verwendet die dort gespeicherte Installations-ID weiter und fragt den Lizenzschlüssel erneut ab.

Ändere signierte Release-Dateien nicht nachträglich. Ältere Alpha-Releases mit
bekannten Installations- oder Datenbankproblemen sind nicht für Neuinstallationen
geeignet; nutze ein aktuelles Release.

Öffne anschließend `http://localhost:8080` und lege bei der [Ersteinrichtung](first-setup.md) Lizenz und Administrator an.

::: warning Schlüssel sichern
Sichere den Datenverschlüsselungsschlüssel getrennt von der Datenbank. Ohne den ursprünglichen Schlüssel sind verschlüsselte Daten nicht wiederherstellbar. Beachte die [Hinweise zu Secrets](environment-variables.md#secrets).
:::

### Installation ohne Integritätsprüfung

Die Prüfung ist standardmäßig aktiviert und wird empfohlen. Nur bei bewusster
Risikoübernahme kannst du sie für ein Release überspringen, dessen Installer
`MEDORA_SKIP_INTEGRITY_CHECKS` unterstützt:

::: danger Keine Prüfung der Herkunft oder Integrität
Hier werden **ungeprüfter Code und ungeprüfte Images ausgeführt**. Eine
manipulierte Datei oder ein manipuliertes Image kann den Host und seine Daten
gefährden. Die Option deaktiviert Signatur-, Prüfsummen- und Containerprüfung,
nicht nur die Prüfung der laufenden Container.
:::

Ersetze `RELEASE_TAG` durch ein entsprechendes Release. Das bereits
veröffentlichte Release `v-0.4.1.1-alpha` unterstützt die Option nicht.

```sh
(
  set -eu
  target="$(pwd)/medora"
  tmpdir=$(mktemp -d)
  trap 'rm -rf "$tmpdir"' EXIT
  url=https://github.com/CyberspaceConsulting/medora-deploy/releases/download/RELEASE_TAG
  for asset in install.sh compose.yaml SHA256SUMS SHA256SUMS.sigstore.json verify-integrity.sh; do
    curl -fsSL -o "$tmpdir/$asset" "$url/$asset"
  done
  MEDORA_SKIP_INTEGRITY_CHECKS=1 sh "$tmpdir/install.sh" "$target"
)
```

Die Dateien mit Prüfsummen und Signatur werden auch bei übersprungener Prüfung
heruntergeladen, aber nicht verifiziert. Die Option gilt nur für den jeweiligen
Installer-Aufruf. Für eine spätere Prüfung siehe
[Manuelle Integritätsprüfung](#manuelle-integritätsprüfung).

## Volumes und Verzeichnisse

| Speicher | Zweck |
| --- | --- |
| Docker-Volume `medora_data` | PostgreSQL-Datenbank |
| Docker-Volume `medora_keys` | Automatisch verwalteter Schlüssel und optionales SMTP-Passwort |
| `medora/backups` | Verschlüsselte Anwendungssicherungen |

Die Volume-Verwaltung gilt für den aktuellen Quellcode und künftige Releases mit dieser Funktion. Das ältere Release `v-0.3.4.1-alpha` verwendet weiterhin Dateien unter `medora/secrets`. Beide Volumes bleiben beim Neustart und Update erhalten und dürfen nicht gelöscht werden, solange Daten benötigt werden.

## Anderer Port

Setze vor der Installation `MEDORA_PORT`, zum Beispiel `export MEDORA_PORT=9090`. Damit spätere Compose-Aufrufe denselben Port verwenden, trage `MEDORA_PORT=9090` in `medora/.env` ein. Die Anwendung ist dann unter `http://localhost:9090` erreichbar.

## Updates

Release-Images sind versionsgebunden. Ein `docker compose pull` allein wechselt nicht auf eine neue Version. Sichere Daten und Schlüssel und folge der [Update-Anleitung](update.md).

## Manuelle Integritätsprüfung

Der Installer prüft die signierte Release-Prüfsummenliste automatisch. Für die unabhängige Notfallprüfung nicht dem installierten Prüfer vertrauen, sondern Prüfer und Signaturdateien frisch aus demselben GitHub-Release laden. Das folgende Beispiel im Installationsverzeichnis ausführen und `RELEASE_TAG` durch den installierten Release-Tag ersetzen. Für `v-0.4.1.1-alpha` schlägt der veröffentlichte Prüfer wegen der oben beschriebenen falschen Signiereridentität fehl.

```sh
(
  set -eu
  tmpdir=$(mktemp -d)
  trap 'rm -rf "$tmpdir"' EXIT
  url=https://github.com/CyberspaceConsulting/medora-deploy/releases/download/RELEASE_TAG
  for asset in compose.yaml SHA256SUMS SHA256SUMS.sigstore.json verify-integrity.sh; do
    curl -fsSL -o "$tmpdir/$asset" "$url/$asset"
  done
  (
    cd "$tmpdir"
    cosign verify-blob \
      --bundle SHA256SUMS.sigstore.json \
      --certificate-identity-regexp '^https://github\.com/CyberspaceConsulting/MEDora/\.github/workflows/release-images\.yml@refs/tags/v[^/]+$' \
      --certificate-oidc-issuer https://token.actions.githubusercontent.com \
      SHA256SUMS
    awk '$2 == "compose.yaml" || $2 == "verify-integrity.sh" { print; count++ } END { if (count != 2) exit 1 }' SHA256SUMS > assets.sha256
    sha256sum --check assets.sha256
  )
  sh "$tmpdir/verify-integrity.sh" --release-dir "$tmpdir" --project-dir "$PWD"
)
```

Die manuelle Prüfung läuft außerhalb der Anwendung. Cosign prüft
die Signatur gegen die festgelegte GitHub-Actions-Identität; der frisch geladene
Prüfer vergleicht danach die laufenden Backend- und Web-Container mit den
signierten Image-Digests. Benötigt werden Cosign, Docker Compose, `curl` und
`sha256sum`. Die Prüfung bestätigt die Container-Images zum Prüfzeitpunkt,
nicht die Integrität der Datenbank, des Hosts oder sämtlicher Laufzeitänderungen.

## Integritätsprüfung in der Admin-Oberfläche

Bei einem Release, das `integrity-agent.py` und `compose.integrity.yaml`
enthält, können Administratoren nach Einrichtung des Host-Dienstes unter
**Einstellungen → Sicherheit → Release-Integrität** manuell prüfen. Bis zur
ersten Prüfung steht der Status auf „Noch nicht geprüft“. Ein Fehler oder ein
nicht erreichbarer Dienst wird nicht als sicher angezeigt. Das Ergebnis gilt
nur zum Prüfzeitpunkt und wird nach einer neuen Anmeldung nicht übernommen.

Der Dienst lädt das konfigurierte Release erneut, prüft dessen Signatur und
Dateien sowie die installierte Compose-Datei und vergleicht die laufenden
Backend- und Web-Images mit den signierten Digests. Er prüft weder den Host,
die Datenbank, andere Images, zusätzliche Compose-Overlays noch nachträgliche
Änderungen in laufenden Containern. Ein kompromittierter Host kann das
Ergebnis manipulieren. Für eine unabhängige Prüfung die oben beschriebene
Host-Prüfung verwenden.

::: warning Host-Rechte
Der optionale Host-Dienst benötigt Docker-Zugriff und wird im folgenden Beispiel
als Root ausgeführt. Docker-Zugriff entspricht weitreichenden Host-Rechten.
Der Backend-Container erhält **nicht** den Docker-Socket, sondern nur Zugriff
auf den eigenen Prüfsocket. Ein kompromittiertes Backend kann Prüfungen
auslösen; den Dienst, seine Konfiguration und das Host-Verzeichnis deshalb
gegen Änderungen durch Unbefugte schützen. Die Anleitung setzt Linux mit
systemd, Docker ohne User-Namespace-Remapping, Python 3, Cosign und
ausgehenden HTTPS-Zugriff auf GitHub und Sigstore voraus.
:::

1. Im Release-Installationsverzeichnis die zusätzlichen Dateien aus **dem
   installierten Release** laden und vor der Ausführung prüfen. Ersetze
   `RELEASE_TAG` durch dessen Tag; alte Releases wie `v-0.4.1.1-alpha`
   enthalten diese Dateien nicht:

   ```sh
   (
     set -eu
     tag=RELEASE_TAG
     tmpdir=$(mktemp -d)
     trap 'rm -rf "$tmpdir"' EXIT
     url="https://github.com/CyberspaceConsulting/medora-deploy/releases/download/$tag"
     for asset in integrity-agent.py compose.integrity.yaml SHA256SUMS SHA256SUMS.sigstore.json; do
       curl -fsSL -o "$tmpdir/$asset" "$url/$asset"
     done
     (
       cd "$tmpdir"
       cosign verify-blob --bundle SHA256SUMS.sigstore.json \
         --certificate-identity "https://github.com/CyberspaceConsulting/MEDora/.github/workflows/release-images.yml@refs/tags/$tag" \
         --certificate-oidc-issuer https://token.actions.githubusercontent.com SHA256SUMS
       awk '$2 == "integrity-agent.py" { agent++; print } $2 == "compose.integrity.yaml" { overlay++; print } END { if (agent != 1 || overlay != 1) exit 1 }' SHA256SUMS > assets.sha256
       sha256sum --check assets.sha256
     )
     sudo install -d -m 755 /usr/local/lib/medora-integrity
     sudo install -m 644 "$tmpdir/integrity-agent.py" /usr/local/lib/medora-integrity/integrity-agent.py
     cp "$tmpdir/compose.integrity.yaml" ./compose.integrity.yaml
   )
   ```

2. Mit `sudo systemctl edit --force --full medora-integrity.service` einen
   Dienst mit folgendem Inhalt anlegen. `RELEASE_TAG` und
   `/ABSOLUTER/PFAD/ZU/medora` durch den installierten Tag und den absoluten
   Pfad zum Installationsverzeichnis ersetzen:

   ```ini
   [Unit]
   Description=MEDora release integrity checker
   After=docker.service network-online.target
   Wants=network-online.target

   [Service]
   Type=simple
   RuntimeDirectory=medora-integrity
   RuntimeDirectoryMode=0755
   ExecStart=/usr/bin/python3 /usr/local/lib/medora-integrity/integrity-agent.py --tag RELEASE_TAG --project-dir /ABSOLUTER/PFAD/ZU/medora
   Restart=on-failure
   NoNewPrivileges=true

   [Install]
   WantedBy=multi-user.target
   ```

   Anschließend `sudo systemctl daemon-reload` und
   `sudo systemctl enable --now medora-integrity.service` ausführen. Mit
   `sudo systemctl status medora-integrity.service` den Dienst prüfen;
   Fehlerdetails stehen in `sudo journalctl -u medora-integrity.service`.

3. Das Overlay im Installationsverzeichnis aktivieren:

   ```sh
   docker compose -f compose.yaml -f compose.integrity.yaml up -d --no-deps backend
   ```

   Nutzt die Installation weitere Compose-Dateien, müssen diese ebenfalls mit
   ihren bisherigen `-f`-Optionen angegeben werden. Das Overlay muss auch bei
   späteren Compose-Aufrufen beibehalten werden. Der Socket bleibt auf dem
   Host auf Root beschränkt; bei Rootless Docker oder User-Namespace-Remapping
   benötigt die Einrichtung ein angepasstes Berechtigungskonzept.

Nach einem Release-Update den Host-Dienst auf den neuen Tag umstellen, die
zugehörigen signierten Agent- und Overlay-Dateien erneut prüfen und installieren
und den Dienst neu starten. Andernfalls schlägt die Prüfung fehl, wenn die
laufenden Images nicht dem konfigurierten Release entsprechen.

## Aus dem Quellcode

Der MEDora-Anwendungscode ist privat. Kunden verwenden zur Installation die
öffentlichen signierten Release-Artefakte aus [medora-deploy](https://github.com/CyberspaceConsulting/medora-deploy).

## Nächste Schritte

- [Docker Compose](docker-compose.md): Dienste, Netzwerke und Speicher
- [Umgebungsvariablen und Secrets](environment-variables.md): Konfiguration und Schlüsselverwaltung
- [Fehlerbehebung](../troubleshooting.md): Status und Logs prüfen
