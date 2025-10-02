# C2 Enumeration TUI v2.0 - Quick Start Guide

## Prerequisites

### Required
- `curl` - For HTTP requests over Tor
- `date` - For timestamps
- Tor running with SOCKS proxy on 127.0.0.1:9050

### Recommended
- `dialog` or `fzf` - For interactive TUI menus
- `tcpdump`, `tshark`, or `dumpcap` - For PCAP capture
- `zstd` - For decompressing .zst artifacts
- `readelf`, `strings`, `nm`, `objdump` - For binary analysis
- `sha256sum` - For file hashing
- `jq` - For JSON export
- `git` - For differential snapshots
- `xxd` or `hexdump` - For hex dumps

---

## Quick Start

### 1. Start Tor
```bash
# System service
sudo systemctl start tor

# Or manually
tor &

# Verify it's running
ss -ltnp | grep 9050
```

### 2. Run the Script
```bash
# Default mode (auto-enumerates known targets)
./c2-enum-tui.sh

# Specify custom output directory
./c2-enum-tui.sh -o /path/to/output

# Custom targets
./c2-enum-tui.sh --targets target1.onion,target2.onion:9000

# Skip auto-enumeration (manual mode)
./c2-enum-tui.sh --no-auto-enum

# Disable PCAP
./c2-enum-tui.sh --no-pcap
```

---

## Main Menu Options

### Core Operations
- **1** - Re-enumerate all targets
- **2** - Enumerate a specific target
- **3** - Add a new target (runtime)
- **4** - File picker (inspect downloaded files)
- **5** - Decompress .zst archives to .bin files

### Analysis & Reporting
- **6** - Build YARA seed rules
- **7** - Build Suricata host detection rule
- **8** - View enumeration report
- **9** - View static analysis report
- **0** - View activity log

### Advanced Operations
- **P** - PCAP controls (Start/Stop/Statistics)
- **T** - Tor status check
- **A** - Advanced analysis menu
- **E** - Export JSON report
- **S** - Summary dashboard

### Exit
- **Q** - Quit (stops PCAP gracefully)

---

## Advanced Analysis Menu

### Deep Scanning
- **Select-Target-for-Deep-Scan** - Runs snapshots + assets + headers on one target
- **Run-All-Advanced-On-Target** - Full advanced analysis suite

### Individual Modules
- **Differential-Snapshots** - Git-tracked snapshots for change detection
- **Asset-Hash-Correlation** - Favicon and static asset fingerprinting
- **Header-Fingerprint-Matrix** - HTTP method testing + error fingerprints
- **Binary-Lineage-Analysis** - Deep ELF analysis of downloaded binaries
- **PCAP-Deep-Analysis** - Packet analysis and conversation stats
- **Certificate-Analysis** - TLS certificate extraction (if HTTPS)

---

## PCAP Menu

- **Start** - Begin packet capture
- **Stop** - Stop capture (shows stats)
- **Show-Status** - Current capture status
- **Show-Statistics** - Packet counts and preview
- **Show-PCAP-Path** - Display current file path
- **Summarize-PCAP** - Generate analysis report
- **List-All-PCAPs** - Show all captured files

---

## Output Structure

```
intel_<target>_<timestamp>/
├── c2-enum.log                       # Activity log
├── report.txt                        # Main enumeration report
├── static_analysis.txt               # Binary analysis
├── download.hashes.txt               # SHA256 hashes
├── yara_seed.yar                     # YARA rule template
├── suricata_c2_host.rule            # Suricata detection rule
├── c2-enum-report.json              # JSON export
├── <target>_root.head               # HTTP headers
├── <target>_root.sample             # Page samples
├── <target>_robots.txt.head         # Path-specific headers
├── <target>_robots.txt.sample       # Path-specific samples
├── <target>_system-linux-x86_64.zst # Binary artifacts
├── <target>_system-linux-x86_64.bin # Decompressed binaries
├── pcap/                            # Packet captures
│   └── c2-enum-<timestamp>.pcap
└── advanced/                        # Advanced analysis
    ├── snapshots/                   # Git-tracked snapshots
    │   └── <target>/
    ├── assets/                      # Asset fingerprints
    │   └── <target>/
    ├── header_matrix_<target>.txt   # Behavior analysis
    ├── binary_lineage.txt           # Binary forensics
    ├── pcap_summary.txt             # PCAP analysis
    └── cert_analysis_<target>.txt   # TLS certificates
```

---

## Common Workflows

### Workflow 1: Initial Reconnaissance
1. Start script: `./c2-enum-tui.sh`
2. Let auto-enumeration run
3. Press **S** for dashboard
4. Press **8** to view report
5. Press **9** to view static analysis
6. Press **E** to export JSON

### Workflow 2: Deep Analysis
1. Press **2** - Enumerate specific target
2. Press **5** - Decompress artifacts
3. Press **A** - Advanced menu
4. Select **Run-All-Advanced-On-Target**
5. Review advanced/ directory outputs

### Workflow 3: Monitoring Changes
1. Press **A** - Advanced menu
2. Select **Differential-Snapshots**
3. Wait (hours/days)
4. Run snapshots again
5. Check Git log: `cd advanced/snapshots/<target> && git log -p`

### Workflow 4: PCAP Analysis
1. Ensure PCAP started (or press **P** → **Start**)
2. Perform enumeration
3. Press **P** → **Summarize-PCAP**
4. View PCAP in Wireshark: `wireshark pcap/c2-enum-*.pcap`

---

## Troubleshooting

### Tor Not Working
```bash
# Check status
./c2-enum-tui.sh --no-auto-enum
# Then press T for Tor status

# If failed, check logs
journalctl -u tor -n 50

# Restart Tor
sudo systemctl restart tor
```

### PCAP Permission Denied
```bash
# Grant capabilities to tcpdump
sudo setcap cap_net_raw,cap_net_admin=eip /usr/sbin/tcpdump

# Or run with sudo (not recommended)
sudo ./c2-enum-tui.sh
```

### Target Unreachable
- Verify Tor is working: `curl --socks5-hostname 127.0.0.1:9050 https://check.torproject.org/api/ip`
- Check if .onion is correct
- Try with different SOCKS proxy: `--socks 127.0.0.1:9150` (Tor Browser)
- Increase timeouts (edit CURL_DOWNLOAD timeout in script)

### Missing Tools
```bash
# Debian/Ubuntu
sudo apt-get install curl tor tcpdump zstd binutils jq git dialog

# RHEL/CentOS
sudo yum install curl tor tcpdump zstd binutils jq git dialog

# Arch
sudo pacman -S curl tor tcpdump zstd binutils jq git dialog
```

---

## Command Line Options

```
Usage:
  ./c2-enum-tui.sh [OPTIONS]

Options:
  -o, --outdir DIR          Output directory (auto-generated if omitted)
  --socks HOST:PORT         SOCKS5 proxy (default: 127.0.0.1:9050)
  --targets LIST            Comma-separated .onion targets
  --add LIST                Add targets to known list
  --no-auto-enum            Skip automatic enumeration on startup
  --quiet                   Suppress verbose output
  --no-pcap                 Disable PCAP capture
  --pcap-if IFACE           Network interface (default: lo)
  --pcap-filter 'BPF'       BPF filter (default: tcp port 9050/9150/9000)
  --pcap-dir DIR            PCAP output directory
  -h, --help                Show help

Examples:
  # Auto mode with defaults
  ./c2-enum-tui.sh

  # Custom output
  ./c2-enum-tui.sh -o ~/intel/c2-recon

  # Specific targets, no PCAP
  ./c2-enum-tui.sh --targets evil.onion --no-pcap

  # Different Tor proxy
  ./c2-enum-tui.sh --socks 127.0.0.1:9150

  # Capture on eth0
  ./c2-enum-tui.sh --pcap-if eth0
```

---

## Tips & Best Practices

### Performance
- Use `--no-auto-enum` for manual control
- Limit targets to 5-10 for reasonable runtime
- PCAP on `lo` has minimal overhead
- Parallel jobs auto-limited to prevent overload

### Security
- Never execute downloaded binaries
- All downloads are read-only (0444)
- Review files before sharing
- PCAP may contain sensitive data (Tor metadata)

### Analysis
- Run static analysis before decompressing
- Compare hashes across multiple downloads
- Use Git snapshots for long-term monitoring
- Export JSON for integration with other tools

### Forensics
- Keep PCAP for full packet reconstruction
- Binary lineage tracks compilation artifacts
- Certificate analysis reveals infrastructure
- Header fingerprints identify server tech

---

## Integration Examples

### Export to MISP
```bash
./c2-enum-tui.sh -o /tmp/recon
# Press E for JSON export
python3 misp_import.py /tmp/recon/c2-enum-report.json
```

### Continuous Monitoring
```bash
#!/bin/bash
while true; do
  ./c2-enum-tui.sh --no-auto-enum --quiet -o ~/monitoring/$(date +%Y%m%d)
  sleep 3600
done
```

### Batch Analysis
```bash
for target in $(cat targets.txt); do
  ./c2-enum-tui.sh --targets "$target" -o "intel_$target" --no-pcap --quiet
done
```

---

## Getting Help

1. Press **0** in menu to view log
2. Check `c2-enum.log` for detailed errors
3. Run `bash -x c2-enum-tui.sh` for debug trace
4. Verify dependencies with **T** menu option

---

## Version Info

**Version**: 2.0-enhanced
**Script**: c2-enum-tui.sh
**Documentation**: ENHANCEMENTS.md, QUICKSTART.md
**License**: Use responsibly for defensive security only
