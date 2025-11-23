# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

**For basic usage, setup, and commands, see README.md.**

## Architecture Overview

This is a Docker-based system that exposes a single USB scanner through three different protocols simultaneously. Understanding how three separate containers share one USB device is key to working with this codebase.

### Multi-Container USB Sharing Pattern

All three containers (saned, airsane, scanservjs) access the same physical USB scanner simultaneously:

- Each uses `privileged: true` for USB access permissions
- Each mounts `/dev/bus/usb` volume for direct hardware access
- Each uses `network_mode: host` to avoid port conflicts and enable direct network binding
- All three can detect and use the scanner concurrently without conflicts (SANE handles locking)

### Custom saned Image with Runtime Configuration Injection

The saned container uses a custom Dockerfile (`saned/Dockerfile`) that:

1. Builds from `debian:bookworm-slim` base image
2. Pre-installs SANE packages during build (not at runtime)
3. Copies `saned.conf` and `dll.conf` into the image
4. At container startup, runs `envsubst` to inject .env variables into saned.conf
5. Starts daemon with injected config

**Why this pattern:**
- SANE packages are installed once during build (fast startup)
- Allows changing `ALLOWED_NETWORK` in .env without rebuilding - just restart container
- The `envsubst` step happens at startup, not build time

**Key files:**
- `saned/Dockerfile` defines the custom image
- Dockerfile CMD shows the envsubst injection and daemon startup

### SANE Backend Selection (Performance)

`saned/dll.conf` controls which scanner drivers load. Currently only `epson2` is enabled.

**Important:** Every enabled backend is probed during `scanimage -L` calls. Enabling unnecessary backends (net, pixma, hp, etc.) significantly slows scanner detection. When supporting different scanner models, only enable the specific backend needed.

## Development Patterns

### Testing Scanner Detection

```bash
docker exec saned scanimage -L      # Test SANE daemon
docker exec airsane scanimage -L    # Test AirSane
docker exec scanservjs scanimage -L # Test web interface
```

Each container has its own SANE installation - test all three when debugging.

### Debugging SANE Issues

Set `SANE_DEBUG_LEVEL=128` in .env for verbose logging. This affects all three containers via docker-compose.yml environment variables (SANE_DEBUG_DLL, SANE_DEBUG_EPSON2).

### Adding Support for Different Scanners

1. Identify backend: Check SANE documentation for your scanner's driver (epson2, pixma, hp, etc.)
2. Enable in `saned/dll.conf`: Uncomment or add the backend name
3. Restart containers: New backend loads on next startup
4. **Don't enable extra backends** - only add what you need for performance

### Modifying Network Access

The saned service controls network access via `saned/saned.conf`. Change `ALLOWED_NETWORK` / `SECONDARY_NETWORK` in .env, then restart - the envsubst pattern automatically updates the config.
