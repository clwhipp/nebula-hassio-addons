# Changelog

## 0.3.1

- Added full documentation visible in the Home Assistant add-on UI (Documentation tab)
- Added icon.png (128×128) for add-on store listing thumbnail
- Added changelog visible in the Home Assistant add-on UI (Changelog tab)

## 0.3.0

- Switched certificate and key inputs from pasted strings to file paths
- Certificates and keys are now read from `/ssl/nebula/` (HA's dedicated secrets directory)
- Removed unreliable PEM string-to-file conversion in favour of direct file references
- Added `ssl` volume map so the container can read from `/ssl/`
- Added `homeassistant_config` volume map so the container can read from `/config/`
- `config_path` option now points to the Nebula YAML config file (default: `/config/nebula/config.yml`)
- `pki` paths in the user config are patched automatically at startup

## 0.2.x

- Initial configuration file support
- Certificate and key material accepted as pasted strings in add-on options
- Added `yq` for config patching at runtime

## 0.1.0

- Initial release
- Nebula VPN v1.10.3
- amd64 architecture support
