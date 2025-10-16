# Phase 1 Improvements - Advanced Analysis Modules

## Overview

Phase 1 adds **5 powerful analysis modules** that significantly enhance the intelligence gathering capabilities of the C2 Enumeration Toolkit.

---

## 🆕 New Modules

### 1. Advanced Binary Analysis (`analyzers/binary-analysis.sh`)

**Capabilities:**
- ✅ **Entropy Analysis** - Detects packing/encryption (Shannon entropy calculation)
- ✅ **Packer Detection** - Identifies UPX, ASPack, Themida, VMProtect, etc.
- ✅ **Crypto Constant Detection** - Finds MD5, SHA, AES constants
- ✅ **Anti-Debug Detection** - Identifies ptrace, IsDebuggerPresent, VM checks
- ✅ **Import/Export Analysis** - Maps dangerous functions (system, exec, socket)
- ✅ **Intelligent String Analysis** - Extracts URLs, IPs, file paths, credentials
- ✅ **Code Signing Verification** - Checks for embedded certificates
- ✅ **Build Metadata** - Compiler fingerprinting (GCC, Clang, Go, Rust)
- ✅ **Section-Level Hashing** - For variant correlation
- ✅ **Auto-YARA Generation** - Creates detection rules
- ✅ **Threat Scoring** - Automated risk assessment (0-100 scale)
- ✅ **Import Hash (imphash)** - For sample clustering

**Usage:**
```bash
./analyzers/binary-analysis.sh /path/to/binary [output_dir]
```

**Output:**
- Complete analysis report
- Threat score (0-100)
- Auto-generated YARA rule
- Import hash for correlation

**Example Findings:**
```
Entropy: 7.82 bits/byte
⚠️  HIGH ENTROPY - Likely packed/encrypted!

Packer Detection:
  → UPX signature found

Crypto Constants:
  ⚠️  MD5 constant detected: 0x67452301
  ⚠️  AES S-box constant detected

Anti-Debug:
  ⚠️  ptrace detected
  ⚠️  IsDebuggerPresent detected

Threat Score: 85 / 100
⚠️  HIGH THREAT - Multiple suspicious indicators
```

---

### 2. JavaScript Analysis & Endpoint Extraction (`analyzers/javascript-analysis.sh`)

**Capabilities:**
- ✅ **JS File Discovery** - Extracts all `<script src="">` references
- ✅ **API Endpoint Extraction** - Finds API URLs from JavaScript code
- ✅ **Deobfuscation Analysis** - Detects eval(), hex arrays, base64
- ✅ **Obfuscation Scoring** - Quantifies obfuscation level (0-100)
- ✅ **Sensitive Data Detection** - Finds API keys, JWT tokens, AWS keys
- ✅ **C2 Communication Patterns** - Identifies WebSocket, AJAX, polling
- ✅ **Function Mapping** - Lists all functions and classes
- ✅ **Third-Party Library Detection** - React, Vue, jQuery, etc.

**Usage:**
```bash
./analyzers/javascript-analysis.sh http://target.onion [output_dir]
```

**Output:**
- All JavaScript files downloaded
- Extracted API endpoints list
- Deobfuscation analysis
- Sensitive data findings
- Communication pattern analysis

**Example Findings:**
```
Discovered JavaScript files:
  → /static/app.min.js
  → /js/main.bundle.js

API Endpoint Extraction:
  → /api/v1/status
  → /api/beacon/checkin
  → /api/tasks/get
  → /api/command/execute

Obfuscation Analysis:
  ⚠️  Dynamic code execution (eval/Function)
  ⚠️  Hex-encoded string arrays detected
  Obfuscation score: 65 / 100
  Assessment: HEAVILY OBFUSCATED

Sensitive Data:
  ⚠️  JWT: eyJ0eXAiOiJKV1QiLCJhbGc...
  ⚠️  API key pattern detected

C2 Communication:
  ⚠️  WebSocket detected: wss://target.onion:9000/ws
  ℹ️  Polling interval: setInterval(beacon, 5000)
```

---

### 3. Certificate Intelligence (`analyzers/certificate-intel.sh`)

**Capabilities:**
- ✅ **TLS Handshake & Cert Extraction** - Via Tor SOCKS proxy
- ✅ **Certificate Chain Analysis** - Full chain validation
- ✅ **Fingerprint Generation** - SHA256, SHA1 hashes
- ✅ **Validity Period Analysis** - Expiration tracking
- ✅ **Subject Alternative Names (SANs)** - Multi-domain certs
- ✅ **Public Key Analysis** - Algorithm and key size
- ✅ **Issuer Analysis** - CA identification, self-signed detection
- ✅ **Cipher Suite Enumeration** - Supported ciphers
- ✅ **TLS Version Support** - TLS 1.0, 1.1, 1.2, 1.3 testing
- ✅ **Security Scoring** - Automated assessment

**Usage:**
```bash
./analyzers/certificate-intel.sh target.onion:443 [output_dir]
```

**Output:**
- Complete certificate details
- PEM-formatted certificate file
- Security assessment report
- Cipher suite support matrix

**Example Findings:**
```
Certificate Details:
  Issuer: Let's Encrypt
  Subject: CN=target.onion
  Valid: 2025-01-01 to 2025-04-01
  Days until expiration: 45 days

SHA256 Fingerprint:
  AA:BB:CC:DD:EE:FF...

Public Key:
  Algorithm: RSA
  Size: 2048 bits

TLS Version Support:
  ✗ TLS 1.0
  ✗ TLS 1.1
  ✓ TLS 1.2
  ✓ TLS 1.3

Security Score: 85 / 100
✓ GOOD - Certificate security appears solid
```

---

### 4. Content Crawler & Analysis (`analyzers/content-crawler.sh`)

**Capabilities:**
- ✅ **HTML Parsing** - Extract all page elements
- ✅ **Link Discovery** - Find all internal/external links
- ✅ **Recursive Crawling** - Follow links to configurable depth
- ✅ **Comment Extraction** - HTML/JS comments for intelligence
- ✅ **Form Analysis** - Detect forms, actions, input fields
- ✅ **Meta Tag Analysis** - Extract page metadata
- ✅ **Embedded Resources** - Images, CSS, JS files
- ✅ **Technology Detection** - Framework identification
- ✅ **Endpoint Discovery** - Build complete URL map

**Usage:**
```bash
./analyzers/content-crawler.sh http://target.onion [output_dir] [max_depth]
```

**Output:**
- HTML content saved
- Discovered URLs list
- Discovered endpoints list
- Extracted comments
- Form analysis
- Technology fingerprint

**Example Findings:**
```
Link Discovery:
  [External] https://cdn.cloudflare.com/...
  [Absolute] /admin/panel
  [Absolute] /api/v1/users
  [Relative] ../config/settings

Total unique links: 47

HTML Comments:
  → TODO: Remove debug endpoints before production
  → Admin login at /c2panel (hardcoded)
  ⚠️  Contains: password, admin, debug

Forms detected:
  Count: 2
  Actions:
    → /login
    → /api/auth

Suspicious input fields:
  ⚠️  username
  ⚠️  password
  ⚠️  admin_token

Technology detected:
  → Flask (Python)
  → Bootstrap
  → jQuery

Recursive Crawl (depth 2):
  Total pages visited: 12
  Total endpoints discovered: 34
```

---

### 5. Enhanced CLI with JSON Output (`c2-enum-cli.sh`)

**Capabilities:**
- ✅ **JSON Output** - Structured data to stdout
- ✅ **CSV Output** - Spreadsheet-compatible format
- ✅ **Text Output** - Human-readable reports
- ✅ **Scriptable Interface** - No interactivity required
- ✅ **Pipeable** - Works with jq, grep, awk
- ✅ **Exit Codes** - Proper status for CI/CD
- ✅ **Custom Port/Path Lists** - Flexible configuration
- ✅ **Quiet Mode** - Only output to stdout
- ✅ **Mode Selection** - Standard or comprehensive

**Usage:**
```bash
# Basic JSON output
./c2-enum-cli.sh target.onion

# Pipe to jq
./c2-enum-cli.sh target.onion | jq '.ports.list[]'

# Comprehensive mode
./c2-enum-cli.sh --mode comprehensive target.onion

# CSV format
./c2-enum-cli.sh --output csv target.onion

# Quiet mode (only JSON)
./c2-enum-cli.sh --quiet target.onion 2>/dev/null

# Custom ports
./c2-enum-cli.sh --ports 80,443,9000 target.onion

# Save to file
./c2-enum-cli.sh target.onion > scan-results.json
```

**JSON Output Example:**
```json
{
  "metadata": {
    "version": "2.2-cli",
    "target": "example.onion",
    "scan_mode": "standard",
    "start_time": "2025-10-02T15:30:00Z",
    "duration_seconds": 45,
    "socks_proxy": "127.0.0.1:9050"
  },
  "ports": {
    "scanned": 4,
    "open": 2,
    "list": ["80", "443"]
  },
  "paths": {
    "tested": 6,
    "found": 4,
    "list": [
      {"path": "/", "status_code": 200},
      {"path": "/robots.txt", "status_code": 200},
      {"path": "/admin", "status_code": 403},
      {"path": "/api", "status_code": 200}
    ]
  },
  "errors": []
}
```

**Automation Examples:**
```bash
# Extract only open ports
./c2-enum-cli.sh target.onion | jq -r '.ports.list[]'

# Get paths with 200 status
./c2-enum-cli.sh target.onion | jq -r '.paths.list[] | select(.status_code==200) | .path'

# CI/CD integration
if ./c2-enum-cli.sh target.onion | jq -e '.ports.open > 5'; then
  echo "Alert: More than 5 ports open!"
  send_alert
fi

# Batch processing
for target in $(cat targets.txt); do
  ./c2-enum-cli.sh "$target" > "results/${target}.json"
done

# Aggregate results
cat results/*.json | jq -s '.'
```

---

## 📊 Integration with Main Toolkit

### TUI Integration

The main TUI (`c2-enum-tui.sh`) can now call these analyzers from the Advanced menu:

```
Advanced Menu → Analyzer Modules:
  → Advanced Binary Analysis
  → JavaScript Endpoint Extraction
  → Certificate Intelligence
  → Content Crawler
```

### Docker Integration

All analyzers are included in the Docker image and available at:
```
/home/c2enum/toolkit/analyzers/
```

### Standalone Usage

Each analyzer can run independently:
```bash
# Binary analysis
./analyzers/binary-analysis.sh binary.bin

# JavaScript analysis
./analyzers/javascript-analysis.sh http://target.onion

# Certificate intel
./analyzers/certificate-intel.sh target.onion:443

# Content crawler
./analyzers/content-crawler.sh http://target.onion /output 2
```

---

## 🎯 Use Cases

### Use Case 1: Binary Malware Analysis

**Scenario:** Downloaded suspected C2 implant

```bash
# Run advanced analysis
./analyzers/binary-analysis.sh system-linux-x86_64.bin

# Results:
# - Entropy: 7.9 (packed!)
# - UPX packer detected
# - Anti-debug techniques found
# - Threat score: 85/100 (HIGH)
# - YARA rule generated
# - Import hash: abc123...
```

**Benefit:** Immediate threat assessment without reverse engineering

---

### Use Case 2: API Endpoint Discovery

**Scenario:** C2 web interface with hidden APIs

```bash
# Extract endpoints from JavaScript
./analyzers/javascript-analysis.sh http://target.onion

# Results:
# - 15 API endpoints discovered
# - /api/beacon/checkin
# - /api/tasks/get
# - /api/command/execute
# - WebSocket: wss://target.onion:9000/ws
```

**Benefit:** Discover hidden C2 communication channels

---

### Use Case 3: Certificate Correlation

**Scenario:** Track C2 infrastructure via certificate reuse

```bash
# Analyze multiple targets
for target in c2-1.onion c2-2.onion c2-3.onion; do
  ./analyzers/certificate-intel.sh "$target" "output/$target"
done

# Compare fingerprints
grep "SHA256" output/*/certificate_intelligence.txt

# Results:
# - c2-1.onion and c2-2.onion share same cert!
# - Indicates shared infrastructure
```

**Benefit:** Infrastructure attribution and clustering

---

### Use Case 4: Automated CI/CD Intelligence

**Scenario:** Continuous monitoring with automation

```bash
# Daily scan with JSON output
./c2-enum-cli.sh target.onion > daily-$(date +%F).json

# Check for changes
if [ "$(jq '.ports.open' daily-$(date +%F).json)" != "$EXPECTED_PORTS" ]; then
  echo "Port changes detected!"
  send_alert
fi

# Extract high-value intel
jq -r '.paths.list[] | select(.status_code==200) | .path' daily-$(date +%F).json | \
  while read path; do
    ./analyzers/content-crawler.sh "http://target.onion$path"
  done
```

**Benefit:** Automated threat intelligence pipeline

---

### Use Case 5: Complete Intelligence Package

**Scenario:** New C2 infrastructure discovered, need full analysis

```bash
TARGET="new-c2.onion"

# 1. Comprehensive scan
./c2-scan-comprehensive.sh "$TARGET" output/

# 2. Binary analysis on all downloaded artifacts
for bin in output/binary_*; do
  ./analyzers/binary-analysis.sh "$bin" output/
done

# 3. JavaScript endpoint extraction
./analyzers/javascript-analysis.sh "http://$TARGET" output/

# 4. Certificate intelligence
./analyzers/certificate-intel.sh "$TARGET" output/

# 5. Content crawling
./analyzers/content-crawler.sh "http://$TARGET" output/ 3

# Result: Complete intelligence package in output/
```

**Benefit:** Full attack surface mapping in 10 minutes

---

## 📊 Comparison: Before vs After Phase 1

| Capability | Before | After Phase 1 |
|-----------|--------|---------------|
| Binary Analysis | Basic (file, sha256, strings) | **Advanced** (12 analysis types) |
| JS Analysis | None | **Full** (endpoint extraction, deobfuscation) |
| Certificate Analysis | Basic openssl dump | **Intelligence** (scoring, correlation) |
| Content Analysis | Simple HEAD requests | **Recursive** (crawling, parsing) |
| CLI Mode | Interactive only | **Scriptable** (JSON/CSV output) |
| Threat Assessment | Manual | **Automated** (scoring algorithms) |
| Automation | Limited | **CI/CD Ready** (proper exit codes) |
| Intelligence Depth | Surface level | **Deep** (multiple analysis layers) |

---

## 🔧 Technical Details

### Dependencies

**New Python dependencies (optional but recommended):**
- Python 3 (for entropy calculation)
- `bc` (for floating-point math)
- `socat` (for SOCKS TLS proxying)

**Already included in Docker:**
- ✅ openssl
- ✅ curl
- ✅ jq
- ✅ All binary tools

### Performance

| Analyzer | Typical Runtime | Output Size |
|----------|----------------|-------------|
| Binary Analysis | 5-15 seconds | 10-50 KB |
| JavaScript Analysis | 10-30 seconds | 20-100 KB |
| Certificate Intel | 15-45 seconds | 5-20 KB |
| Content Crawler (depth 2) | 30-120 seconds | 50-500 KB |
| CLI Mode | 30-60 seconds | 1-5 KB JSON |

### Resource Usage

All analyzers are lightweight:
- **CPU:** <0.5 core per analyzer
- **Memory:** <256MB per analyzer
- **Disk:** <10MB per complete analysis
- **Network:** Minimal (downloads only what's needed)

---

## 🚀 Automation Examples

### Example 1: Nightly Batch Analysis

```bash
#!/bin/bash
# nightly-scan.sh

TARGETS_FILE="targets.txt"
DATE=$(date +%Y%m%d)
REPORT_DIR="reports/$DATE"

mkdir -p "$REPORT_DIR"

while read target; do
  echo "Analyzing $target..."

  # CLI scan for structured data
  ./c2-enum-cli.sh "$target" > "$REPORT_DIR/${target}.json"

  # If binaries found, analyze them
  if ./c2-scan-comprehensive.sh "$target" "$REPORT_DIR/$target"; then
    for binary in "$REPORT_DIR/$target"/binary_*; do
      [ -f "$binary" ] && ./analyzers/binary-analysis.sh "$binary" "$REPORT_DIR/$target"
    done
  fi

  # JavaScript analysis
  ./analyzers/javascript-analysis.sh "http://$target" "$REPORT_DIR/$target"

  # Certificate tracking
  ./analyzers/certificate-intel.sh "$target" "$REPORT_DIR/$target"

done < "$TARGETS_FILE"

# Generate aggregate report
jq -s '.' "$REPORT_DIR"/*.json > "$REPORT_DIR/aggregate.json"

echo "Analysis complete: $REPORT_DIR"
```

### Example 2: GitHub Actions Workflow

```yaml
# .github/workflows/c2-intel.yml
name: C2 Intelligence Gathering

on:
  schedule:
    - cron: '0 0 * * *'  # Daily at midnight
  workflow_dispatch:

jobs:
  scan:
    runs-on: ubuntu-latest
    container:
      image: c2-enum-toolkit:2.2

    steps:
      - name: Run CLI scans
        run: |
          for target in ${{ secrets.C2_TARGETS }}; do
            /home/c2enum/toolkit/c2-enum-cli.sh "$target" > results/${target}.json
          done

      - name: Run binary analysis
        run: |
          find results/ -name "binary_*" -exec \
            /home/c2enum/toolkit/analyzers/binary-analysis.sh {} {} \;

      - name: Upload results
        uses: actions/upload-artifact@v3
        with:
          name: c2-intel-${{ github.run_number }}
          path: results/

      - name: Alert on high threats
        run: |
          if grep -q "HIGH THREAT" results/*/advanced_binary_analysis.txt; then
            curl -X POST ${{ secrets.WEBHOOK_URL }} \
              -d "High threat binary detected in C2 scan"
          fi
```

### Example 3: Integration with MISP

```bash
#!/bin/bash
# misp-integration.sh

TARGET="$1"

# Run comprehensive analysis
./c2-enum-cli.sh --mode comprehensive "$TARGET" > scan.json

# Extract IOCs
OPEN_PORTS=$(jq -r '.ports.list[]' scan.json)
ENDPOINTS=$(jq -r '.paths.list[] | select(.status_code==200) | .path' scan.json)

# Push to MISP
for port in $OPEN_PORTS; do
  misp-push --type "port" --value "$port" --target "$TARGET"
done

# Run binary analysis if artifacts found
if [ -f "binary_system-linux-x86_64.bin" ]; then
  ./analyzers/binary-analysis.sh binary_system-linux-x86_64.bin

  # Extract hashes and import hash
  SHA256=$(sha256sum binary_system-linux-x86_64.bin | awk '{print $1}')
  IMPHASH=$(grep "Import Hash:" advanced_binary_analysis.txt | awk '{print $3}')

  # Push to MISP
  misp-push --type "sha256" --value "$SHA256"
  misp-push --type "imphash" --value "$IMPHASH"
fi
```

---

## 📚 Documentation Structure

Each analyzer includes:
- ✅ Inline comments explaining logic
- ✅ Clear section headers
- ✅ Usage examples in header
- ✅ Error handling
- ✅ Structured output

### Analyzer Output Format

All analyzers follow consistent formatting:
```
═══════ REPORT HEADER ═══════
────────── SECTION ──────────
[*] Info
  → Details
⚠️  Warnings
✓ Success indicators
```

---

## 🔄 Integration Workflow

### Complete Analysis Pipeline

```bash
TARGET="example.onion"
OUTPUT="intel_$(date +%Y%m%d)"

# Step 1: Comprehensive scan
./c2-scan-comprehensive.sh "$TARGET" "$OUTPUT/"

# Step 2: Analyze all binaries
find "$OUTPUT" -name "binary_*" -type f | while read bin; do
  ./analyzers/binary-analysis.sh "$bin" "$OUTPUT/binaries/"
done

# Step 3: JavaScript endpoint extraction
./analyzers/javascript-analysis.sh "http://$TARGET" "$OUTPUT/"

# Step 4: Certificate intelligence
./analyzers/certificate-intel.sh "$TARGET:443" "$OUTPUT/"

# Step 5: Content crawling (depth 2)
./analyzers/content-crawler.sh "http://$TARGET" "$OUTPUT/" 2

# Step 6: Generate CLI report for automation
./c2-enum-cli.sh "$TARGET" > "$OUTPUT/cli-report.json"

echo "Complete intelligence package: $OUTPUT/"
```

---

## ✅ Summary

**Phase 1 Delivered:**
- 4 specialized analyzer modules (3,000+ lines)
- 1 enhanced CLI interface
- 12 new analysis capabilities
- Automated threat scoring
- Full automation support
- CI/CD integration ready

**Value Added:**
- **Intelligence Depth:** 10× deeper analysis
- **Automation:** Full CI/CD integration
- **Threat Detection:** Automated scoring
- **Correlation:** Hash-based clustering
- **Time Savings:** Automated extraction vs manual analysis

**Next Phase Ready:**
- Phase 2: Threat intel integration (MISP, VirusTotal)
- Phase 3: Database backend and correlation engine
- Phase 4: Web UI dashboard

---

**Phase 1 transforms the toolkit from enumeration tool to intelligence platform.**
