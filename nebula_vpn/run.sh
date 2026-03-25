#!/usr/bin/env bash
set -e

CONFIG_PATH=/data/options.json
NEBULA_DIR=/data/nebula

mkdir -p "$NEBULA_DIR"

# ── Read options ──────────────────────────────────────────────────────────────
CA_CERT=$(jq -r '.ca_cert' "$CONFIG_PATH")
HOST_CERT=$(jq -r '.host_cert' "$CONFIG_PATH")
HOST_KEY=$(jq -r '.host_key' "$CONFIG_PATH")
CONFIG_FILE=$(jq -r '.config_path' "$CONFIG_PATH")
DEBUG=$(jq -r '.debug' "$CONFIG_PATH")

# ── Validate required fields ──────────────────────────────────────────────────
for FIELD in ca_cert host_cert host_key config_path; do
  VAL=$(jq -r ".$FIELD" "$CONFIG_PATH")
  if [ -z "$VAL" ] || [ "$VAL" = "null" ]; then
    echo "[ERROR] '$FIELD' is required but not set in the add-on options."
    exit 1
  fi
done

if [ ! -f "$CONFIG_FILE" ]; then
  echo "[ERROR] Nebula config file not found at: $CONFIG_FILE"
  echo "[ERROR] Create your config.yml at that path and restart the add-on."
  exit 1
fi

# ── Write certificate and key files ──────────────────────────────────────────
echo "$CA_CERT"   > "$NEBULA_DIR/ca.crt"
echo "$HOST_CERT" > "$NEBULA_DIR/host.crt"
echo "$HOST_KEY"  > "$NEBULA_DIR/host.key"
chmod 600 "$NEBULA_DIR/host.key"

echo "[INFO] Certificates written to $NEBULA_DIR"

# ── Copy user config and patch pki paths to managed locations ────────────────
cp "$CONFIG_FILE" "$NEBULA_DIR/config.yml"

yq e -i '
  .pki.ca   = "/data/nebula/ca.crt" |
  .pki.cert = "/data/nebula/host.crt" |
  .pki.key  = "/data/nebula/host.key"
' "$NEBULA_DIR/config.yml"

echo "[INFO] Nebula config loaded from $CONFIG_FILE"

if [ "$DEBUG" = "true" ]; then
  echo "[DEBUG] Nebula config (pki section redacted):"
  yq e 'del(.pki)' "$NEBULA_DIR/config.yml"
fi

# ── Launch Nebula ─────────────────────────────────────────────────────────────
exec nebula -config "$NEBULA_DIR/config.yml"
