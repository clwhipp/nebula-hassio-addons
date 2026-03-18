#!/usr/bin/env bash
set -e

CONFIG_PATH=/data/options.json

NEBULA_CONFIG_PATH=$(jq -r '.nebula_config_path' "$CONFIG_PATH")
DEBUG=$(jq -r '.debug' "$CONFIG_PATH")

if [ -z "$NEBULA_CONFIG_PATH" ] || [ "$NEBULA_CONFIG_PATH" = "null" ]; then
  echo "[ERROR] 'nebula_config_path' is not set in add-on options."
  exit 1
fi

if [ ! -f "$NEBULA_CONFIG_PATH" ]; then
  echo "[ERROR] Nebula config file not found at: $NEBULA_CONFIG_PATH"
  echo "Create your config (and certs) under /config and restart the add-on."
  exit 1
fi

echo "[INFO] Starting Nebula with config: $NEBULA_CONFIG_PATH"

if [ "$DEBUG" = "true" ]; then
  echo "[DEBUG] Nebula config:"
  cat "$NEBULA_CONFIG_PATH"
fi

exec nebula -config "$NEBULA_CONFIG_PATH"