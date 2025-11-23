# SCAN Server - Multi-Protocol Scanner Sharing

This setup allows you to share an Epson ES-400 scanner (or other SANE-compatible scanner) across multiple computers using various protocols.

## Features

- **Web Interface** (ScanServJS) - Access from any browser
- **AirScan/eSCL** - Native support in macOS and Windows 10/11
- **SANE Network Protocol** - For Linux and SANE-compatible clients

## Quick Start

1. **Prerequisites**
   - Raspberry Pi with Docker and Docker Compose installed
   - Epson ES-400 connected via USB

2. **Configuration**
   - Edit `.env` file to match your network settings
   - See the `.env` file for detailed instructions on all configuration options

3. **Build and Start Services**

   **Option A: Use start.sh (Recommended)**
   ```bash
   ./start.sh
   ```
   The start script automatically builds the custom saned image if needed, validates configuration, and starts all services.

   **Option B: Manual Docker Compose**
   ```bash
   docker-compose build  # First time only - builds saned image
   docker-compose up -d   # Start all services in background
   ```

4. **Access Scanner**
   - Web Interface: `http://[PI_IP]:8080`
   - macOS Image Capture: Scanner appears automatically
   - Windows Scan: Scanner appears automatically

## Commands

- `./start.sh` - Start all services
  - `./start.sh --skip-check` or `./start.sh --force` - Skip USB scanner detection check (useful for automation)
  - `./start.sh --help` - Show usage information
- `./stop.sh` - Stop all services gracefully
- `./status.sh` - Check service status and scanner detection
- `docker-compose logs -f` - View logs from all services
- `docker-compose logs -f [service]` - View logs from a specific service (saned, airsane, or scanservjs)

## Directory Structure

```
SCAN/
├── .env                    # Environment variables (edit to configure)
├── .gitignore              # Git ignore rules
├── docker-compose.yml      # Service definitions with health checks
├── start.sh                # Start script (with --skip-check option)
├── stop.sh                 # Stop script (graceful shutdown)
├── status.sh               # Status check script
├── saned/                  # SANE daemon configs
│   ├── Dockerfile          # Custom saned image
│   ├── .dockerignore       # Docker build context exclusions
│   ├── saned.conf          # Network access control (template)
│   └── dll.conf            # SANE backend selection
├── scanservjs/             # Web interface configs
│   ├── config.json         # ScanServJS configuration
│   └── data/               # Scanned files (gitignored)
└── airsane/                # AirScan configs
    └── airsane.conf        # AirSane configuration
```

## Features & Improvements

- **Health Checks**: All services include Docker health checks for automatic monitoring
- **Error Handling**: Scripts include robust error handling and validation
- **Non-Interactive Mode**: Supports automated deployments with `--skip-check` flag
- **Configurable Scanner Brand**: Support for different scanner brands via `SCANNER_BRAND` variable
- **Pinned Versions**: Docker images use specific versions for stability
- **Graceful Shutdown**: Services stop gracefully, allowing active scans to complete

## Customization

All settings can be configured in the `.env` file. The file contains inline instructions for each option.

### Critical Configuration

**`ALLOWED_NETWORK`** (Required) - Set this to your local network range in CIDR notation (e.g., `192.168.0.0/16`, `192.168.1.0/24`). This controls which networks can access the scanner via SANE network protocol.

For all other settings, including ports, scanner brand, debug levels, and timezone, see the `.env` file for detailed instructions and default values.

## Troubleshooting

### Scanner Detection Issues

1. **Scanner not detected on USB**:
   ```bash
   lsusb | grep -i epson  # Check if scanner is connected
   ```
   - Verify USB connection
   - Try a different USB port
   - Check if scanner is powered on
   - Use `./start.sh --skip-check` to bypass USB check if scanner is detected in containers

2. **Scanner not detected in containers**:
   ```bash
   ./status.sh  # Check detection status in all containers
   docker exec saned scanimage -L  # Test SANE daemon
   docker exec airsane scanimage -L  # Test AirSane
   docker exec scanservjs scanimage -L  # Test ScanServJS
   ```

### Service Issues

3. **Services not starting**:
   ```bash
   docker-compose logs -f  # View all logs
   docker-compose logs -f saned  # View specific service logs
   ```
   - Check if required environment variables are set (see error message)
   - Verify `.env` file exists and is properly formatted
   - Check Docker daemon is running: `docker ps`

4. **Container health checks failing**:
   ```bash
   docker-compose ps  # Check health status
   ```
   - Containers may need more time to initialize (40s start period)
   - Check if scanner is properly connected
   - Review logs for specific errors

### Network Access Issues

5. **Cannot access from network**:
   - Verify firewall settings allow the configured ports
   - Check network ranges in `.env` match your network
   - Ensure services are using `network_mode: host` (saned, airsane) or port mapping (scanservjs)
   - Test locally first: `curl http://localhost:8080` (for scanservjs)

6. **Environment variable errors**:
   - Ensure `.env` file exists (it should be created automatically)
   - Verify all required variables are set: `ALLOWED_NETWORK`, `SCANSERVJS_PORT`, `AIRSANE_PORT`, `SANED_PORT`
   - Check for syntax errors (no spaces around `=` in `.env`)

### Debug Mode

Enable verbose debugging by setting in `.env`:
```bash
SANE_DEBUG_LEVEL=128
```
Then restart services: `./stop.sh && ./start.sh`

## Auto-start on Boot

To start services automatically on boot:

### Option 1: Using systemd (Recommended)

Create a systemd service file `/etc/systemd/system/scan-server.service`:

```ini
[Unit]
Description=SCAN Server Scanner Services
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/path/to/SCAN
ExecStart=/path/to/SCAN/start.sh --skip-check
ExecStop=/path/to/SCAN/stop.sh
User=your-username

[Install]
WantedBy=multi-user.target
```

Then enable and start:
```bash
sudo systemctl daemon-reload
sudo systemctl enable scan-server.service
sudo systemctl start scan-server.service
```

### Option 2: Using cron

```bash
sudo systemctl enable docker
crontab -e
# Add: @reboot cd /path/to/SCAN && ./start.sh --skip-check
```

**Note:** Use `--skip-check` flag for non-interactive startup (required for automation).
