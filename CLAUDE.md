# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

**For basic usage, setup, and commands, see README.md.**

## Architecture Overview

This is a Docker-based system that exposes a single USB scanner through three different protocols simultaneously. The system includes automated post-processing features for scanned documents (SMB network share copying and email delivery).

### Multi-Container USB Sharing Pattern

All three containers (saned, airsane, scanservjs) access the same physical USB scanner simultaneously:

- Each uses `privileged: true` for USB access permissions
- Each mounts `/dev/bus/usb` volume for direct hardware access
- Each uses `network_mode: host` (saned, airsane) or port mapping (scanservjs) for network access
- All three can detect and use the scanner concurrently without conflicts (SANE handles locking)
- All services include healthchecks (`scanimage -L`) with 40s start period

### Service Images

**saned (Custom Build)**
- Location: `saned/Dockerfile`
- Base: `debian:bookworm-slim`
- Custom Dockerfile that pre-installs SANE packages during build
- Uses runtime `envsubst` to inject .env variables into saned.conf
- Command: `saned -l -b 0.0.0.0 -d ${SANE_DEBUG_LEVEL}` (listen on all interfaces, with debug)

**airsane (Pre-built)**
- Image: `aguslr/airsane:latest` (different from original syncloudorg/airsane)
- Mounts local airsane.conf for configuration
- Provides eSCL/AirScan protocol with mDNS discovery

**scanservjs (Custom Build)**
- Location: `scanservjs/Dockerfile`
- Base: `sbs20/scanservjs:latest` (extends official image)
- Adds: `cifs-utils`, `python3`, `mailutils`, `inotify-tools`
- Custom entrypoint that runs both scanservjs AND file-watcher.sh in parallel
- File watcher monitors `/app/data/output` for new scans
- Triggers post-scan.sh for automated SMB copying and/or email delivery

### Post-Processing Architecture (scanservjs)

The scanservjs container has been extended with automated file handling:

```
┌─────────────────────────────────────────────────────────┐
│  scanservjs Container                                    │
│                                                           │
│  entrypoint-custom.sh (PID 1)                            │
│          │                                                │
│          ├──► Original scanservjs (PID 2)                │
│          │    └─ Web UI on port 8080                     │
│          │                                                │
│          └──► file-watcher.sh (PID 3)                    │
│               └─ inotifywait on /app/data/output         │
│                  │                                        │
│                  ▼                                        │
│              post-scan.sh (triggered on new files)       │
│                  │                                        │
│                  ├──► smb-handler.sh (if SMB_ENABLED)    │
│                  │    └─ Mounts SMB share & copies file  │
│                  │                                        │
│                  └──► email-handler.sh (if EMAIL_ENABLED)│
│                       └─ Sends file via SMTP             │
└─────────────────────────────────────────────────────────┘
```

**Key files:**
- `scanservjs/entrypoint.sh`: Custom entrypoint that starts both services
- `scanservjs/file-watcher.sh`: Uses inotifywait to monitor for new scans
- `scanservjs/post-scan.sh`: Orchestrates post-processing handlers
- `scanservjs/smb-handler.sh`: Mounts SMB/CIFS share and copies files
- `scanservjs/email-handler.sh`: Sends scanned files via SMTP email
- `scanservjs/config.local.js`: Sets UI defaults (Letter paper size, ADF Simplex source)

### Runtime Configuration Injection (saned)

The saned container uses a custom Dockerfile that:

1. Builds from `debian:bookworm-slim` base image
2. Pre-installs SANE packages during build (not at runtime) - **Note: libsane-extras is NOT installed**
3. Copies `saned.conf` and `dll.conf` into the image as templates
4. At container startup, runs `envsubst` to inject .env variables into saned.conf
5. Outputs configuration to logs for debugging
6. Starts daemon with `exec saned -l -b 0.0.0.0 -d ${SANE_DEBUG_LEVEL}`

**Why this pattern:**
- SANE packages are installed once during build (fast startup)
- Allows changing `ALLOWED_NETWORK` in .env without rebuilding - just restart container
- The `envsubst` step happens at startup, not build time
- Uses `exec` for proper signal handling (Docker stop signals reach saned directly)

**Key flags:**
- `-l`: Listen mode (daemon)
- `-b 0.0.0.0`: Bind to all network interfaces
- `-d ${SANE_DEBUG_LEVEL}`: Debug verbosity (1-128)

### Environment Variables (.env)

The `.env` file is extensively documented with inline comments. Key categories:

**Network Access Control:**
- `ALLOWED_NETWORK` (required): Primary CIDR range for SANE network access
- `SECONDARY_NETWORK` (optional): Additional network ranges

**Service Ports:**
- `SCANSERVJS_PORT`, `AIRSANE_PORT`, `SANED_PORT`

**Scanner Configuration:**
- `SCANNER_BRAND`: Brand name for USB detection in start.sh (default: epson)
- `SANE_DEBUG_LEVEL`: Debug verbosity 0-128

**ScanServJS Configuration:**
- `PUID`, `PGID`: File ownership for scanned files
- `TZ`: Timezone for timestamps

**SMB/CIFS Network Share (Optional):**
- `SMB_ENABLED`: Set to `true` to enable
- `SMB_SERVER`, `SMB_SHARE`, `SMB_USER`, `SMB_PASS`, `SMB_DOMAIN`

**Email Delivery (Optional):**
- `EMAIL_ENABLED`: Set to `true` to enable
- `SMTP_SERVER`, `SMTP_PORT`, `SMTP_USER`, `SMTP_PASS`
- `EMAIL_FROM`, `EMAIL_TO`, `EMAIL_SUBJECT`

**Important:** docker-compose.yml uses `${VAR:-default}` syntax for all env vars, providing safe defaults.

### SANE Backend Selection (Performance)

`saned/dll.conf` controls which scanner drivers load. Currently only `epson2` is enabled.

**Important:** Every enabled backend is probed during `scanimage -L` calls. Enabling unnecessary backends (net, pixma, hp, etc.) significantly slows scanner detection. When supporting different scanner models, only enable the specific backend needed.

### Git Ignore Pattern

**Critical:** The `.gitignore` file has `.env` commented out (line 2):
```
# .env
```

This means `.env` **IS CURRENTLY TRACKED BY GIT**. This was likely intentional to provide a working example, but be careful not to commit secrets. Consider:
- Uncommenting `# .env` in .gitignore if secrets are added
- Using `.env.example` for documentation (already exists)

## Development Patterns

### Testing Scanner Detection

```bash
docker exec saned scanimage -L      # Test SANE daemon
docker exec airsane scanimage -L    # Test AirSane
docker exec scanservjs scanimage -L # Test web interface
```

Each container has its own SANE installation - test all three when debugging. Healthchecks run this same command every 30s.

### Debugging SANE Issues

Set `SANE_DEBUG_LEVEL=128` in .env for verbose logging. This affects all three containers via docker-compose.yml environment variables (SANE_DEBUG_DLL, SANE_DEBUG_EPSON2).

The saned container also outputs its configuration to logs on startup for debugging network access issues.

### Testing Post-Processing Features

**SMB Share:**
1. Set `SMB_ENABLED=true` in .env
2. Configure SMB_* variables
3. Restart: `./stop.sh && ./start.sh`
4. Scan a document via web UI
5. Check logs: `docker-compose logs -f scanservjs`
6. File should appear on network share

**Email Delivery:**
1. Set `EMAIL_ENABLED=true` in .env
2. Configure SMTP_* and EMAIL_* variables
3. Restart containers
4. Scan a document via web UI
5. Check email inbox

**Manual Testing:**
```bash
# Trigger post-processing manually
docker exec scanservjs /app/post-scan.sh /app/data/output/test.pdf
```

### Modifying ScanServJS UI Defaults

Edit `scanservjs/config.local.js` to change:
- Default paper size (currently: Letter)
- Default source (currently: adf-simplex)
- Default scan mode (Color, Gray, Lineart)
- Default resolution

Changes require container rebuild: `docker-compose build scanservjs && docker-compose up -d scanservjs`

### Adding Support for Different Scanners

1. Identify backend: Check SANE documentation for your scanner's driver (epson2, pixma, hp, etc.)
2. Enable in `saned/dll.conf`: Uncomment or add the backend name
3. Update `SCANNER_BRAND` in .env to match scanner brand for USB detection
4. Restart containers: `./stop.sh && ./start.sh`
5. **Don't enable extra backends** - only add what you need for performance

### Modifying Network Access

The saned service controls network access via `saned/saned.conf`. Change `ALLOWED_NETWORK` / `SECONDARY_NETWORK` in .env, then restart - the envsubst pattern automatically updates the config.

**Note:** Only saned uses network access control. AirSane and ScanServJS have their own security models (mDNS discovery is broadcast, web UI is open to network).

### Start Script Features

`start.sh` includes:
- `--skip-check` or `--force`: Skip USB scanner detection (for automation/systemd)
- `--help` or `-h`: Show usage information
- Validates required environment variables before starting
- Safe environment variable loading (handles spaces and special characters)
- Automatically builds custom images if needed
- Error handling with proper exit codes
- Non-interactive mode detection

### Healthcheck Monitoring

All three services have healthchecks (interval: 30s, timeout: 10s, retries: 3, start_period: 40s).

Check health status:
```bash
docker-compose ps  # Shows health: starting/healthy/unhealthy
```

Healthchecks use `scanimage -L` to verify scanner detection. If a container becomes unhealthy, check:
1. USB connection is stable
2. Scanner is powered on
3. Container logs for SANE errors: `docker-compose logs saned`

## Common Pitfalls

1. **.env not ignored:** Remember that `.env` is currently tracked by git. Uncomment line 2 in .gitignore if you add secrets.

2. **SMB credentials in logs:** SMB_PASS appears in environment variables. Avoid `docker inspect` output in public bug reports.

3. **Backend performance:** Adding backends to `dll.conf` slows down scanner detection. Only enable what you need.

4. **Healthcheck failures during startup:** Containers have 40s start period. Don't worry about "unhealthy" status immediately after starting.

5. **File watcher not triggering:** The file-watcher.sh uses inotifywait on `/app/data/output`. If post-processing doesn't trigger, check container logs for inotify errors.

6. **Config changes not applied:** Most .env changes only need restart (`./stop.sh && ./start.sh`), but config.local.js changes require rebuild of scanservjs container.
