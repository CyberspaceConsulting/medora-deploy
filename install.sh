#!/bin/sh
# Medora installer. Usage: ./install.sh [install-directory]
set -eu

target="${1:-medora}"
skip_integrity_checks="${MEDORA_SKIP_INTEGRITY_CHECKS:-0}"
download_dir=""
docker_auth_dir=""
tty_state=""
tty_echo_disabled=0
cleanup() {
  if [ "$tty_echo_disabled" = 1 ]; then
    stty "$tty_state" </dev/tty 2>/dev/null || true
  fi
  if [ -n "$download_dir" ]; then
    rm -rf "$download_dir"
  fi
  if [ -n "$docker_auth_dir" ]; then
    rm -rf "$docker_auth_dir"
  fi
}
trap cleanup EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM
case "$skip_integrity_checks" in
  0) ;;
  1) echo "WARNING: Release signatures, checksums, and running image checks are disabled. The installation is not verified." >&2 ;;
  *) echo "MEDORA_SKIP_INTEGRITY_CHECKS must be 0 or 1" >&2; exit 1 ;;
esac
command -v docker >/dev/null 2>&1 || { echo "Docker is required" >&2; exit 1; }
# The release images are multi-arch (amd64 + arm64); Docker pulls the matching variant itself.
case "$(uname -m)" in
  x86_64|amd64|aarch64|arm64) ;;
  *) echo "Unsupported CPU architecture $(uname -m): Medora needs 64-bit x86 or ARM (e.g. Raspberry Pi 4/5 with a 64-bit OS)" >&2; exit 1 ;;
esac
docker compose version >/dev/null 2>&1 || { echo "Docker Compose v2 is required" >&2; exit 1; }
mkdir -p "$target"
target="$(cd "$target" && pwd)"
if [ -n "${MEDORA_EXTERNAL_KEY_FILE:-}" ] || { [ -f "$target/.env" ] && \
  grep -Eq '^[[:space:]]*(export[[:space:]]+)?MEDORA_EXTERNAL_KEY_FILE[[:space:]]*=' "$target/.env"; }; then
  echo "External-key installations must be updated with their existing Compose files, not the installer" >&2
  exit 1
fi
mkdir -p "$target/backups"
chmod 700 "$target/backups"

source_compose=""
if [ -f "$0" ]; then
  here="$(cd "$(dirname "$0")" && pwd)"
else
  here=""
fi

verify_release() {
  release_dir="$1"
  command -v sha256sum >/dev/null 2>&1 || { echo "sha256sum is required to verify the Medora release" >&2; exit 1; }
  command -v cosign >/dev/null 2>&1 || { echo "Cosign is required to verify the Medora release" >&2; exit 1; }
  cosign verify-blob \
    --bundle "$release_dir/SHA256SUMS.sigstore.json" \
    --certificate-identity-regexp '^https://github\.com/CyberspaceConsulting/MEDora/\.github/workflows/release-images\.yml@refs/tags/v[^/]+$' \
    --certificate-oidc-issuer https://token.actions.githubusercontent.com \
    "$release_dir/SHA256SUMS" >/dev/null || {
      echo "The release checksum signature is invalid" >&2
      exit 1
    }
  for asset in compose.yaml verify-integrity.sh; do
    expected_checksum="$(awk -v name="$asset" '$2 == name { print $1; count++ } END { if (count != 1) exit 1 }' "$release_dir/SHA256SUMS")" || {
      echo "The signed release checksum for $asset is missing or ambiguous" >&2
      exit 1
    }
    case "$expected_checksum" in
      *[!0-9a-fA-F]*|'') echo "The signed release contains an invalid $asset checksum" >&2; exit 1 ;;
    esac
    [ "${#expected_checksum}" -eq 64 ] || { echo "The signed release contains an invalid $asset checksum" >&2; exit 1; }
    if ! printf '%s  %s\n' "$expected_checksum" "$release_dir/$asset" | sha256sum --check --status -; then
      echo "The downloaded $asset failed checksum verification" >&2
      exit 1
    fi
  done
}

if [ -n "$here" ] && [ -f "$here/compose.yaml" ]; then
  if [ "$skip_integrity_checks" = 0 ]; then
    verify_release "$here"
  fi
  if [ "$here" != "$target" ]; then
    cp "$here/compose.yaml" "$target/compose.yaml"
    cp "$here/verify-integrity.sh" "$target/verify-integrity.sh"
    cp "$here/SHA256SUMS" "$target/SHA256SUMS"
    cp "$here/SHA256SUMS.sigstore.json" "$target/SHA256SUMS.sigstore.json"
  fi
elif [ -n "$here" ] && [ -f "$here/../docker/docker-compose.yml" ]; then
  source_compose="$(cd "$here/../docker" && pwd)/docker-compose.yml"
  echo "Using the local source checkout and building its Docker images."
else
  command -v curl >/dev/null 2>&1 || { echo "curl is required to download the Medora release" >&2; exit 1; }
  download_dir="$(mktemp -d)"
  release_tag="${MEDORA_RELEASE_TAG:-current}"
  if [ "$release_tag" = current ]; then
    curl --fail --location --retry 3 --silent --show-error \
      -o "$download_dir/current-release" \
      "https://raw.githubusercontent.com/CyberspaceConsulting/medora-deploy/main/current-release"
    IFS= read -r release_tag < "$download_dir/current-release" || {
      echo "The current MEDora release tag could not be read" >&2
      exit 1
    }
  fi
  case "$release_tag" in
    *[!A-Za-z0-9._-]*|'') echo "MEDORA_RELEASE_TAG contains an invalid release tag" >&2; exit 1 ;;
  esac
  release_url="https://github.com/CyberspaceConsulting/medora-deploy/releases/download/$release_tag"
  curl --fail --location --retry 3 --silent --show-error \
    -o "$download_dir/compose.yaml" "$release_url/compose.yaml"
  curl --fail --location --retry 3 --silent --show-error \
    -o "$download_dir/SHA256SUMS" "$release_url/SHA256SUMS"
  curl --fail --location --retry 3 --silent --show-error \
    -o "$download_dir/SHA256SUMS.sigstore.json" "$release_url/SHA256SUMS.sigstore.json"
  curl --fail --location --retry 3 --silent --show-error \
    -o "$download_dir/verify-integrity.sh" "$release_url/verify-integrity.sh"
  if [ "$skip_integrity_checks" = 0 ]; then
    verify_release "$download_dir"
  fi
  cp "$download_dir/compose.yaml" "$target/compose.yaml"
  cp "$download_dir/verify-integrity.sh" "$target/verify-integrity.sh"
  cp "$download_dir/SHA256SUMS" "$target/SHA256SUMS"
  cp "$download_dir/SHA256SUMS.sigstore.json" "$target/SHA256SUMS.sigstore.json"
fi

if [ -z "${MEDORA_DATA_ENCRYPTION_KEY_FILE:-}" ] && [ -f "$target/.env" ] && \
  grep -Eq '^[[:space:]]*(export[[:space:]]+)?MEDORA_DATA_ENCRYPTION_KEY_FILE[[:space:]]*=' "$target/.env"; then
  echo "Set MEDORA_DATA_ENCRYPTION_KEY_FILE in the environment when rerunning the installer with an external key" >&2
  exit 1
fi
if [ -z "${MEDORA_SMTP_PASSWORD_SECRET_FILE:-}" ] && [ -f "$target/.env" ] && \
  grep -Eq '^[[:space:]]*(export[[:space:]]+)?MEDORA_SMTP_PASSWORD_SECRET_FILE[[:space:]]*=' "$target/.env"; then
  echo "Set MEDORA_SMTP_PASSWORD_SECRET_FILE in the environment when rerunning the installer with an external SMTP secret" >&2
  exit 1
fi
if [ -n "${MEDORA_DATA_ENCRYPTION_KEY_FILE:-}" ]; then
  case "$MEDORA_DATA_ENCRYPTION_KEY_FILE" in
    /*) ;;
    *) echo "MEDORA_DATA_ENCRYPTION_KEY_FILE must be an absolute path" >&2; exit 1 ;;
  esac
  [ -f "$MEDORA_DATA_ENCRYPTION_KEY_FILE" ] && [ -r "$MEDORA_DATA_ENCRYPTION_KEY_FILE" ] || {
    echo "The configured encryption key file must already exist and be readable" >&2; exit 1
  }
  legacy_key="$MEDORA_DATA_ENCRYPTION_KEY_FILE"
elif [ -f "$target/secrets/data_encryption_key" ]; then
  legacy_key="$target/secrets/data_encryption_key"
  chmod 700 "$target/secrets"
  chmod 600 "$legacy_key"
else
  legacy_key=""
fi
legacy_smtp="${MEDORA_SMTP_PASSWORD_SECRET_FILE:-$target/secrets/smtp_password}"
case "$legacy_smtp" in
  /*) ;;
  *) legacy_smtp="$target/$legacy_smtp" ;;
esac
if [ -n "${MEDORA_SMTP_PASSWORD_SECRET_FILE:-}" ] && [ ! -f "$legacy_smtp" ]; then
  echo "The configured SMTP password file must already exist" >&2
  exit 1
fi

cd "$target"
compose() {
  if [ -n "$source_compose" ]; then
    docker compose --file "$source_compose" "$@"
  else
    docker compose "$@"
  fi
}

import_secret() {
  compose run --rm --no-deps --volume "$1:/run/medora-import:ro" --entrypoint /bin/sh backend -c '
    set -eu
    umask 077
    destination="/var/lib/medora-secrets/$1"
    mkdir -p /var/lib/medora-secrets
    chmod 700 /var/lib/medora-secrets
    if [ -e "$destination" ]; then
      cmp -s /run/medora-import "$destination" || {
        echo "Existing managed secret differs from the original; refusing to overwrite it" >&2
        exit 1
      }
    else
      temporary="$(mktemp /var/lib/medora-secrets/.import.XXXXXXXX)"
      trap '\''rm -f "$temporary"'\'' EXIT
      cp /run/medora-import "$temporary"
      if ! ln "$temporary" "$destination"; then
        cmp -s /run/medora-import "$destination" || exit 1
      fi
    fi
  ' -- "$2"
}

if [ -n "$source_compose" ]; then
  export MEDORA_BACKUP_HOST_DIR="$target/backups"
  (
    if [ -n "${COMPOSE_ENV_FILES:-}" ]; then
      resolved_env_files=""
      saved_ifs="$IFS"
      IFS=,
      set -f
      for env_file in $COMPOSE_ENV_FILES; do
        case "$env_file" in
          /*) ;;
          *) env_file="$target/$env_file" ;;
        esac
        resolved_env_files="${resolved_env_files:+$resolved_env_files,}$env_file"
      done
      IFS="$saved_ifs"
      export COMPOSE_ENV_FILES="$resolved_env_files"
    fi
    cd "$here/.."
    if [ -n "${COMPOSE_ENV_FILES:-}" ]; then
      docker compose --file "$source_compose" build
    elif [ -f "$target/.env" ] && [ "${COMPOSE_DISABLE_ENV_FILE:-0}" != 1 ] && \
      [ "${COMPOSE_DISABLE_ENV_FILE:-false}" != true ]; then
      docker compose --env-file "$target/.env" --file "$source_compose" build
    else
      docker compose --env-file /dev/null --file "$source_compose" build
    fi
  )
else
  command -v uuidgen >/dev/null 2>&1 || { echo "uuidgen is required to identify this installation" >&2; exit 1; }
  if [ -f "$target/.installation_id" ]; then
    IFS= read -r installation_id < "$target/.installation_id"
  else
    installation_id="$(uuidgen | tr '[:upper:]' '[:lower:]')"
    printf '%s\n' "$installation_id" > "$target/.installation_id"
    chmod 600 "$target/.installation_id"
  fi
  case "$installation_id" in
    ????????-????-????-????-????????????) ;;
    *) echo "The saved MEDora installation ID is invalid" >&2; exit 1 ;;
  esac
  case "$installation_id" in
    *[!0-9a-fA-F-]*) echo "The saved MEDora installation ID is invalid" >&2; exit 1 ;;
  esac
  release_version="$(awk '$1 == "x-medora-version:" { if (++count > 1) exit 1; version = $2 } END { if (count != 1) exit 1; print version }' "$target/compose.yaml")" || {
    echo "The release Compose file has no unique MEDora version" >&2; exit 1
  }
  case "$release_version" in
    v-[0-9]*|v[0-9]*) ;;
    *) echo "The release Compose file contains an invalid MEDora version" >&2; exit 1 ;;
  esac
  case "$release_version" in
    *[!A-Za-z0-9.-]*) echo "The release Compose file contains an invalid MEDora version" >&2; exit 1 ;;
  esac
  release_channel="main"
  case "$release_version" in
    *-alpha*|*-test*) release_channel="test" ;;
  esac
  if ! ( : </dev/tty ) 2>/dev/null; then
    echo "Run the installer from a terminal to enter the MEDora license key securely" >&2
    exit 1
  fi
  printf 'MEDora-Lizenzschlüssel: ' >/dev/tty
  tty_state="$(stty -g </dev/tty)" || { echo "Could not read terminal settings" >&2; exit 1; }
  stty -echo </dev/tty || { echo "Could not disable terminal echo" >&2; exit 1; }
  tty_echo_disabled=1
  if ! IFS= read -r license_token </dev/tty; then
    echo >&2
    echo "Could not read the MEDora license key" >&2
    exit 1
  fi
  stty "$tty_state" </dev/tty
  tty_echo_disabled=0
  printf '\n' >&2
  case "$license_token" in
    *[!A-Za-z0-9._-]*|'') echo "The MEDora license key has an invalid format" >&2; exit 1 ;;
  esac
  activation_payload="$(printf '{"license_token":"%s","installation_id":"%s","medora_version":"%s","release_channel":"%s"}' \
    "$license_token" "$installation_id" "$release_version" "$release_channel")"
  license_api_url="${MEDORA_LICENSE_API_URL:-https://lic.api.cyberspaceconsulting.de/api/v1}"
  case "$license_api_url" in
    https://*) ;;
    *) echo "MEDORA_LICENSE_API_URL must use HTTPS" >&2; exit 1 ;;
  esac
  if ! printf '%s' "$activation_payload" | curl --fail --silent --show-error \
    --header 'Content-Type: application/json' --data-binary @- \
    --output /dev/null "$license_api_url/instances/activate"; then
    echo "MEDora did not authorize this license and installation; no images were downloaded" >&2
    exit 1
  fi
  unset activation_payload
  docker_auth_dir="$(mktemp -d)"
  chmod 700 "$docker_auth_dir"
  registry_host="registry.cyberspaceconsulting.de"
  if ! printf '%s' "$license_token" | DOCKER_CONFIG="$docker_auth_dir" \
    docker login --username "$installation_id" --password-stdin "$registry_host"; then
    echo "Could not authorize Docker with the MEDora license server" >&2
    exit 1
  fi
  unset license_token
  export DOCKER_CONFIG="$docker_auth_dir"
  if [ "$skip_integrity_checks" = 0 ]; then
    sh ./verify-integrity.sh --release-only
  fi
  compose pull
fi
if [ -n "$legacy_key" ]; then
  import_secret "$legacy_key" data_encryption_key
  echo "Imported the existing encryption key without deleting the original."
fi
if [ -s "$legacy_smtp" ]; then
  import_secret "$legacy_smtp" smtp_password
  echo "Imported the existing SMTP password without deleting the original."
fi
if [ -n "$source_compose" ]; then
  compose up --no-build -d
else
  compose up -d
  if [ "$skip_integrity_checks" = 0 ]; then
    sh ./verify-integrity.sh --check-running
  fi
fi
echo "Back up the medora_keys volume separately from the database; without its key encrypted data is unrecoverable."
echo "Medora is starting on http://localhost:${MEDORA_PORT:-8080}"
