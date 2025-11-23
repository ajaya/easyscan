# ScanServJS Scanner Options

## Supported Options

ScanServJS supports the following scanner options through SANE backend configuration:

### 1. Paper Sizes ✅
Currently configured in `config.json`:
- Letter (215.9 x 279.4 mm)
- Legal (215.9 x 355.6 mm)
- A4 (210 x 297 mm)
- A5 (148 x 210 mm)
- A3 (297 x 420 mm)
- B4, B5, Executive, Folio, Quarto, Tabloid

**Note:** Paper sizes are defined in the config, but actual supported sizes depend on your scanner hardware.

### 2. Color Modes ✅
Currently configured in `config.json`:
- **Color** - Full color scanning
- **Grayscale** - Black and white with shades of gray
- **Lineart/Black & White** - Pure black and white (no grayscale)

### 3. Duplex (Double-sided) ⚠️
**Scanner-dependent feature:**
- Duplex scanning requires a scanner with automatic document feeder (ADF) that supports double-sided scanning
- If your scanner supports duplex, it will appear as an option in the web interface
- The `duplexModes` configuration in `config.json` defines available options, but actual availability depends on scanner capabilities

**To check if your scanner supports duplex:**
```bash
docker exec scanservjs scanimage -d <scanner-device> --help | grep -i duplex
```

### 4. Source (Platen vs ADF) ⚠️
**Scanner-dependent feature:**
- **Platen (Flatbed)**: For scanning single pages placed on the glass
- **ADF (Automatic Document Feeder)**: For scanning multiple pages automatically
- Not all scanners have ADF capability
- The `sources` configuration in `config.json` defines available options, but actual availability depends on scanner hardware

**To check available sources for your scanner:**
```bash
docker exec scanservjs scanimage -d <scanner-device> --help | grep -i source
```

## How ScanServJS Determines Available Options

ScanServJS automatically detects scanner capabilities by querying the SANE backend. The options available in the web interface depend on:

1. **Scanner Hardware**: What your physical scanner supports
2. **SANE Backend**: What the SANE driver reports as available
3. **Configuration**: What's defined in `config.json` (acts as a filter/whitelist)

## Configuration Notes

The `config.json` file defines:
- **paperSizes**: Available paper size presets (user can also enter custom dimensions)
- **scanModes**: Available color mode options
- **sources**: Available source options (if scanner supports them)
- **duplexModes**: Available duplex options (if scanner supports them)

**Important:** Even if you configure these options in `config.json`, they will only appear in the web interface if:
- Your scanner hardware supports them
- The SANE backend driver reports them as available

## Testing Your Scanner Capabilities

To see what options your scanner actually supports:

```bash
# List available scanners
docker exec scanservjs scanimage -L

# Check options for your scanner (replace with your scanner device)
docker exec scanservjs scanimage -d <scanner-device> --help

# Example for Epson ES-400:
docker exec scanservjs scanimage -d epson2:libusb:001:003 --help
```

Look for options like:
- `--source` - Available sources (Flatbed, ADF, etc.)
- `--mode` - Color modes (Color, Gray, Lineart)
- `--duplex` - Duplex capability
- `--page-width`, `--page-height` - Paper size options

## Epson ES-400 Specific Notes

The Epson ES-400 is a document scanner with:
- ✅ ADF (Automatic Document Feeder)
- ✅ Duplex scanning (double-sided)
- ✅ Color, Grayscale, and Lineart modes
- ✅ Multiple paper sizes

All configured options should be available for this scanner model.

