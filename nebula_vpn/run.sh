#!/usr/bin/env bash
set -e

CONFIG_PATH=/data/options.json
NEBULA_DIR=/data/nebula

mkdir -p "$NEBULA_DIR"

# ── Read options ──────────────────────────────────────────────────────────────
CA_CERT=$(jq -r '.ca_cert' "$CONFIG_PATH")
HOST_CERT=$(jq -r '.host_cert' "$CONFIG_PATH")
HOST_KEY=$(jq -r '.host_key' "$CONFIG_PATH")
NEBULA_CONFIG=$(jq -r '.nebula_config' "$CONFIG_PATH")
DEBUG=$(jq -r '.debug' "$CONFIG_PATH")

# ── Validate required fields ──────────────────────────────────────────────────
for FIELD in ca_cert host_cert host_key nebula_config; do
  VAL=$(jq -r ".$FIELD" "$CONFIG_PATH")
  if [ -z "$VAL" ] || [ "$VAL" = "null" ]; then
    echo "[ERROR] '$FIELD' is required but not set in the add-on options."
    exit 1
  fi
done

# ── Write certificate and key files ──────────────────────────────────────────
echo "$CA_CERT"    > "$NEBULA_DIR/ca.crt"
echo "$HOST_CERT"  > "$NEBULA_DIR/host.crt"
echo "$HOST_KEY"   > "$NEBULA_DIR/host.key"
chmod 600 "$NEBULA_DIR/host.key"

echo "[INFO] Certificates written to $NEBULA_DIR"

# ── Write user config and patch pki paths ────────────────────────────────────
echo "$NEBULA_CONFIG" > "$NEBULA_DIR/config.yml"

yq e -i '
  .pki.ca   = "/data/nebula/ca.crt" |
  .pki.cert = "/data/nebula/host.crt" |
  .pki.key  = "/data/nebula/host.key"
' "$NEBULA_DIR/config.yml"

echo "[INFO] Nebula config written to $NEBULA_DIR/config.yml"

if [ "$DEBUG" = "true" ]; then
  echo "[DEBUG] Nebula config (pki paths redacted):"
  yq e 'del(.pki)' "$NEBULA_DIR/config.yml"
fi

# ── Launch Nebula ─────────────────────────────────────────────────────────────
exec nebula -config "$NEBULA_DIR/config.yml"
