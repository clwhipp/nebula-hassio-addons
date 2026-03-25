#!/usr/bin/env bash
set -e

CONFIG_PATH=/data/options.json
NEBULA_DIR=/data/nebula

mkdir -p "$NEBULA_DIR"

# ── Read options ──────────────────────────────────────────────────────────────
CA_CERT_PATH=$(jq -r '.ca_cert_path' "$CONFIG_PATH")
HOST_CERT_PATH=$(jq -r '.host_cert_path' "$CONFIG_PATH")
HOST_KEY_PATH=$(jq -r '.host_key_path' "$CONFIG_PATH")
CONFIG_FILE=$(jq -r '.config_path' "$CONFIG_PATH")
DEBUG=$(jq -r '.debug' "$CONFIG_PATH")

# ── Validate all files exist ──────────────────────────────────────────────────
for VAR in CA_CERT_PATH HOST_CERT_PATH HOST_KEY_PATH CONFIG_FILE; do
  FILE="${!VAR}"
  if [ -z "$FILE" ] || [ "$FILE" = "null" ]; then
    echo "[ERROR] Option for $VAR is not set in the add-on options."
    exit 1
  fi
  if [ ! -f "$FILE" ]; then
    echo "[ERROR] File not found: $FILE"
    exit 1
  fi
done

echo "[INFO] All certificate and config files found"

# ── Copy config and patch pki paths to the actual file locations ──────────────
cp "$CONFIG_FILE" "$NEBULA_DIR/config.yml"

yq e -i "
  .pki.ca   = \"$CA_CERT_PATH\" |
  .pki.cert = \"$HOST_CERT_PATH\" |
  .pki.key  = \"$HOST_KEY_PATH\"
" "$NEBULA_DIR/config.yml"

echo "[INFO] Nebula config loaded from $CONFIG_FILE"

if [ "$DEBUG" = "true" ]; then
  echo "[DEBUG] Nebula config (pki section redacted):"
  yq e 'del(.pki)' "$NEBULA_DIR/config.yml"
fi

# ── Launch Nebula ─────────────────────────────────────────────────────────────
exec nebula -config "$NEBULA_DIR/config.yml"
