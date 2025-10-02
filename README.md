# C2 Enumeration Toolkit v2.0

Safe, defensive security toolkit for analyzing .onion C2 infrastructure over Tor.

## 📦 Contents

```
c2-enum-toolkit/
├── c2-enum-tui.sh      Main TUI script (1,340 lines, fully enhanced)
├── ENHANCEMENTS.md     Detailed technical documentation
├── QUICKSTART.md       User guide and quick reference
└── README.md           This file
```

## 🎯 Purpose

This toolkit provides safe, read-only enumeration and analysis of Command & Control (C2) infrastructure accessible via Tor hidden services (.onion addresses). It is designed for **defensive security research only**.

## ⚡ Quick Start

### Prerequisites
```bash
# Ensure Tor is running
sudo systemctl start tor

# Or start manually
tor &

# Verify Tor SOCKS proxy
ss -ltnp | grep 9050
```

### Run the Tool
```bash
# Make executable
chmod +x c2-enum-tui.sh

# Run with defaults (auto-enumerates preseeded targets)
./c2-enum-tui.sh

# Run in manual mode
./c2-enum-tui.sh --no-auto-enum
```

## 🔍 Preseeded C2 Targets

The script comes with two known C2 targets for analysis:

1. `wtxqf54djhp5pskv2lfyduub5ievxbyvlzjgjopk6hxge5umombr63ad.onion`
2. `2hdv5kven4m422wx4dmqabotumkeisrstzkzaotvuhwx3aebdig573qd.onion:9000`

You can add more targets via:
- Command line: `--targets your.onion,another.onion:port`
- Interactive menu: Option **3) Add a new target**

## 🛠️ Features

### Core Capabilities
- ✅ TUI-driven interface (dialog/fzf/select)
- ✅ Tor connectivity verification
- ✅ PCAP packet capture (tcpdump/tshark/dumpcap)
- ✅ Parallel enumeration with retry logic
- ✅ Static binary analysis (ELF, strings, symbols)
- ✅ YARA and Suricata rule generation
- ✅ JSON export for integration
- ✅ Summary dashboard

### Advanced Analysis
- 🔬 Differential snapshots (Git-tracked)
- 🔬 Asset fingerprinting (favicons, static files)
- 🔬 HTTP header behavioral analysis
- 🔬 Binary lineage and forensics
- 🔬 TLS certificate extraction
- 🔬 PCAP deep analysis

### Security Features
- 🔒 Read-only downloads (chmod 0444)
- 🔒 No remote code execution
- 🔒 Safe heredocs and parameter handling
- 🔒 set -euo pipefail for error handling
- 🔒 Defensive umask (027)

## 📚 Documentation

1. **README.md** (this file) - Overview and quick start
2. **QUICKSTART.md** - Comprehensive user guide with workflows
3. **ENHANCEMENTS.md** - Technical details of all improvements

## 🚀 Example Workflows

### Quick Reconnaissance
```bash
./c2-enum-tui.sh
# Wait for auto-enumeration
# Press 'S' for dashboard
# Press '8' to view report
# Press 'E' to export JSON
```

### Deep Analysis
```bash
./c2-enum-tui.sh --no-auto-enum
# Press '2' - Enumerate specific target
# Press 'A' - Advanced menu
# Select "Run-All-Advanced-On-Target"
# Review advanced/ directory outputs
```

### Custom Target
```bash
./c2-enum-tui.sh --targets your-target.onion --no-pcap
```

## 📂 Output Structure

```
intel_<target>_<timestamp>/
├── c2-enum.log                  # Activity log
├── report.txt                   # Main report
├── static_analysis.txt          # Binary analysis
├── c2-enum-report.json         # JSON export
├── yara_seed.yar               # YARA rules
├── suricata_c2_host.rule       # Suricata rules
├── download.hashes.txt         # SHA256 hashes
├── <files>.head                # HTTP headers
├── <files>.sample              # Content samples
├── <files>.zst                 # Binary artifacts
├── <files>.bin                 # Decompressed binaries
├── pcap/                       # Packet captures
└── advanced/                   # Advanced analysis
    ├── snapshots/              # Git-tracked changes
    ├── assets/                 # Asset fingerprints
    └── *.txt                   # Analysis reports
```

## ⚠️ Important Notes

### Legal & Ethical Use
- **FOR DEFENSIVE SECURITY RESEARCH ONLY**
- Do not use for unauthorized access or malicious purposes
- Respect all applicable laws and regulations
- Only analyze infrastructure you have authorization to research

### Safety
- All downloads are read-only and never executed
- Script performs only HTTP requests and static analysis
- No exploitation or active attacks are performed
- PCAP capture is local traffic to Tor SOCKS proxy only

### Privacy
- All traffic is routed through Tor for anonymity
- PCAP files contain Tor metadata - handle accordingly
- Consider operational security when storing outputs

## 🔧 Dependencies

### Required
- `bash` (4.0+)
- `curl` - HTTP requests
- `date` - Timestamps
- Tor (running with SOCKS on 127.0.0.1:9050)

### Recommended
- `dialog` or `fzf` - Interactive menus
- `tcpdump`, `tshark`, or `dumpcap` - PCAP
- `zstd` - Decompression
- `readelf`, `strings`, `nm`, `objdump` - Binary analysis
- `sha256sum` - Hashing
- `jq` - JSON export
- `git` - Differential snapshots
- `xxd` or `hexdump` - Hex dumps

### Install on Debian/Ubuntu
```bash
sudo apt-get install curl tor tcpdump zstd binutils jq git dialog
```

### Install on RHEL/CentOS
```bash
sudo yum install curl tor tcpdump zstd binutils jq git dialog
```

## 🐛 Troubleshooting

### Tor Not Working
```bash
# Check Tor status
systemctl status tor

# View logs
journalctl -u tor -n 50

# Test connectivity
curl --socks5-hostname 127.0.0.1:9050 https://check.torproject.org/api/ip
```

### PCAP Permission Issues
```bash
# Grant capabilities (recommended)
sudo setcap cap_net_raw,cap_net_admin=eip /usr/sbin/tcpdump

# Or disable PCAP
./c2-enum-tui.sh --no-pcap
```

### Target Unreachable
- Verify .onion address is correct
- Check Tor is working (use 'T' menu option)
- Try different SOCKS proxy: `--socks 127.0.0.1:9150`
- Some .onion services may be offline

## 📊 Statistics

- **Script Size**: 1,340 lines (2.74x original)
- **Functions**: 45+
- **Menu Options**: 16
- **Tool Integrations**: 17
- **Analysis Depth**: 3x enhanced

## 🔄 Version History

### v2.0-enhanced (Current)
- Comprehensive enhancements across all modules
- Added JSON export, dashboard, certificate analysis
- Enhanced Tor connectivity verification
- Parallel processing with job control
- Retry logic and error handling
- Production-ready PCAP capture
- Detailed documentation

### v1.0 (Original)
- Basic TUI enumeration
- Simple PCAP capture
- Basic static analysis

## 📞 Support

For issues, questions, or improvements:
1. Review QUICKSTART.md for common solutions
2. Check ENHANCEMENTS.md for technical details
3. Examine c2-enum.log in output directory
4. Run with `bash -x` for debug trace

## 📜 License

Use responsibly for defensive security research only.

---

**🛡️ Remember: This is a defensive security tool. Use ethically and legally.**
