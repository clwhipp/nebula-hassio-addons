# Nebula VPN Add-on for Home Assistant

Nebula VPN **v1.10.3** is packaged in this add-on.

> **Supported architectures: `amd64` only.**
> This add-on does not support ARM devices (Raspberry Pi, ODROID, etc.). If your Home Assistant instance runs on ARM hardware this add-on will not install or run.

---

## Overview

[Nebula](https://github.com/slackhq/nebula) is an open-source, overlay mesh VPN developed by Slack. Unlike traditional hub-and-spoke VPNs, Nebula creates direct peer-to-peer encrypted tunnels between nodes — even across different networks, ISPs, and NATs — using a certificate authority model for mutual authentication.

This add-on allows your Home Assistant instance to join a Nebula mesh network as a fully participating node. Once connected, other devices on your Nebula network can reach Home Assistant directly (e.g. on port 8123) without exposing it to the public internet, regardless of where those devices are located in the world.

**What this enables:**
- Secure remote access to all Home Assistant services from any Nebula-connected device
- Private, encrypted communication between Home Assistant and other nodes on your mesh
- Full network-level access to the host — not just the web UI, but any service running on it
- No port forwarding, dynamic DNS, or cloud relay required for peer-to-peer connections

---

## Prerequisites

Before configuring this add-on you need a working Nebula network with:

1. A **lighthouse node** — a publicly reachable server that helps peers find each other. This can be any always-on machine with a static public IP (VPS, cloud instance, etc.).
2. A **certificate authority (CA)** — created once using the `nebula-cert` tool. The CA signs all host certificates on your network.
3. **Certificates for your Home Assistant host** — a signed certificate and private key generated for this specific node.

If you have not yet set up a Nebula CA and lighthouse, refer to the [Nebula quick start guide](https://nebula.defined.net/docs/guides/quick-start/).

---

## Step 1 — Generate Certificates

On a trusted machine with `nebula-cert` installed, generate certificates for your Home Assistant host:

```bash
# Create a CA (only needed once for your whole network)
nebula-cert ca -name "My Nebula Network"

# Sign a certificate for Home Assistant
# Replace the IP with an unused address in your Nebula subnet
nebula-cert sign -name "homeassistant" -ip "192.168.100.10/24"
```

This produces three files:
| File | Description |
|---|---|
| `ca.crt` | Certificate Authority — shared across all nodes |
| `homeassistant.crt` | Host certificate for this HA instance |
| `homeassistant.key` | Private key for this HA instance — keep secret |

---

## Step 2 — Place Certificates on Home Assistant

Certificates and keys must be placed under the `/ssl/` directory on your Home Assistant instance. This directory is purpose-built for secrets and is not exposed to the network.

The recommended layout is:

```
/ssl/nebula/
├── ca.crt
├── host.crt
└── host.key
```

Copy the files to your Home Assistant instance via one of:
- **SSH & Terminal add-on**: `scp` or manual creation
- **Samba add-on**: copy files to the `ssl/nebula/` share
- **Configuration → Storage** in the HA UI (for supported installs)

The default paths expected by this add-on are:
- CA certificate: `/ssl/nebula/ca.crt`
- Host certificate: `/ssl/nebula/host.crt`
- Host key: `/ssl/nebula/host.key`

If you use different filenames, update the paths in the add-on configuration options accordingly.

---

## Step 3 — Create the Nebula Configuration File

Create a configuration file at `/config/nebula/config.yml`. You can use the HA **File Editor** add-on or SSH to create it.

A minimal working example:

```yaml
pki:
  # These paths are automatically overwritten by the add-on at startup.
  # The values below are placeholders — leave them as-is.
  ca: /placeholder
  cert: /placeholder
  key: /placeholder

# Map your lighthouse's Nebula IP to its real public address
static_host_map:
  "192.168.100.1": ["your.lighthouse.public.ip:4242"]

lighthouse:
  am_lighthouse: false
  interval: 60
  hosts:
    - "192.168.100.1"

listen:
  host: "[::]"   # Listen on both IPv4 and IPv6
  port: 4242

punchy:
  punch: true

tun:
  disabled: false
  dev: nebula1
  mtu: 1300

logging:
  level: info
  format: text

firewall:
  conntrack:
    tcp_timeout: 120s
    udp_timeout: 30s
    default_timeout: 10s

  outbound:
    - port: any
      proto: any
      host: any

  inbound:
    # Allow Nebula nodes to reach any service on this host.
    # Restrict to specific ports below if you prefer tighter control.
    - port: any
      proto: tcp
      host: any

    - port: any
      proto: udp
      host: any

    # Allow ICMP (ping) for diagnostics
    - port: any
      proto: icmp
      host: any
```

Replace `192.168.100.1` with your lighthouse's Nebula IP and `your.lighthouse.public.ip` with its real public IP address or hostname.

> **Note:** The `pki` paths in your `config.yml` do not need to be correct — the add-on patches them automatically at startup to point to the certificate files configured in the options.

### Commonly Used Ports

The firewall rules above allow all TCP and UDP traffic from Nebula peers. If you prefer to allow only specific services, here are the ports commonly used on a Home Assistant instance:

| Port | Protocol | Service |
|---|---|---|
| `8123` | TCP | Home Assistant web UI |
| `4357` | TCP | Home Assistant websocket API (used by companion apps) |
| `22` | TCP | SSH (SSH & Terminal add-on) |
| `8300` | TCP | Matter server (if installed) |
| `5353` | UDP | mDNS (local service discovery) |
| `1883` | TCP | MQTT broker (Mosquitto add-on) |
| `1884` | TCP | MQTT over WebSocket |
| `8883` | TCP | MQTT over TLS |
| `21063` | TCP | HomeKit bridge |
| `21064` | TCP | HomeKit accessory protocol |

To restrict access to specific ports instead of allowing everything, replace the `port: any` inbound rules with individual entries. Nebula supports filtering by hostname or by group — groups are assigned when signing certificates with `nebula-cert sign -groups "admin"`:

```yaml
  inbound:
    # Allow any Nebula node to reach the Home Assistant web UI by hostname
    - port: 8123
      proto: tcp
      host: my-laptop        # the Nebula hostname of the allowed node

    # Allow only nodes in the "admin" group to SSH into this host
    - port: 22
      proto: tcp
      group:
        - admin

    - port: any
      proto: icmp
      host: any
```

---

## Configuration Options

| Option | Default | Description |
|---|---|---|
| `ca_cert_path` | `/ssl/nebula/ca.crt` | Path to the Nebula CA certificate |
| `host_cert_path` | `/ssl/nebula/host.crt` | Path to this host's signed certificate |
| `host_key_path` | `/ssl/nebula/host.key` | Path to this host's private key |
| `config_path` | `/config/nebula/config.yml` | Path to the Nebula YAML configuration file |
| `debug` | `false` | Log the resolved config at startup (pki section is redacted) |

---

## How It Works

At startup the add-on:

1. Validates that all four files exist (CA cert, host cert, host key, config)
2. Copies your `config.yml` to an internal working directory
3. Patches the `pki` section of the copy to point to the configured certificate paths
4. Launches the Nebula daemon with the patched config

This means you can manage your Nebula config freely in `/config/nebula/config.yml` without worrying about keeping the `pki` paths in sync with the add-on options.

---

## Troubleshooting

**`File not found` on startup**
Verify the file exists at the exact path shown in the error. Check that the filename and extension match (e.g. `.crt` not `.pem`).

**`listener is IPv4, but writing to IPv6 remote`**
Change `listen.host` in your `config.yml` from `0.0.0.0` to `[::]` to enable dual-stack listening.

**Nebula connects to lighthouse but not to peers**
Enable `punchy.punch: true` in your config. Also verify that UDP port 4242 is open outbound from your network.

**Home Assistant services are unreachable from Nebula peers**
Check the `firewall.inbound` rules in your `config.yml`. The relevant port and protocol must be permitted for the source host or group. Refer to the port table above for common service ports.
