# Analyzer Modules

Specialized analysis tools for deep C2 intelligence gathering.

---

## 📦 Available Analyzers

### 1. `binary-analysis.sh` - Advanced Binary Analysis

**Purpose:** Deep analysis of binary artifacts with threat scoring

**Features:**
- Entropy analysis (packing detection)
- Packer identification
- Crypto constant detection
- Anti-debug technique detection
- Import/export analysis
- Intelligent string extraction
- Build metadata extraction
- Section-level hashing
- Auto-YARA generation
- Automated threat scoring (0-100)
- Import hash (imphash) generation

**Usage:**
```bash
./analyzers/binary-analysis.sh /path/to/binary [output_dir]
```

**Output:**
- `advanced_binary_analysis.txt` - Complete report
- Threat score with indicators
- Auto-generated YARA rule

---

### 2. `javascript-analysis.sh` - JavaScript Endpoint Extraction

**Purpose:** Extract API endpoints and analyze client-side code

**Features:**
- JS file discovery from HTML
- API endpoint extraction from code
- Obfuscation detection and scoring
- Sensitive data extraction (API keys, tokens)
- C2 communication pattern detection
- Function and class mapping
- Third-party library detection

**Usage:**
```bash
./analyzers/javascript-analysis.sh http://target.onion [output_dir]
```

**Output:**
- `js_analysis/javascript_analysis.txt` - Analysis report
- `js_analysis/extracted_endpoints.txt` - Discovered endpoints
- Downloaded JavaScript files

---

### 3. `certificate-intel.sh` - Certificate Intelligence

**Purpose:** Comprehensive TLS/SSL certificate analysis

**Features:**
- TLS handshake and cert extraction
- Certificate chain analysis
- Fingerprint generation (SHA256, SHA1)
- Validity period analysis
- Subject Alternative Names
- Public key analysis
- Issuer and CA analysis
- Cipher suite enumeration
- TLS version support testing
- Security scoring

**Usage:**
```bash
./analyzers/certificate-intel.sh target.onion:443 [output_dir]
```

**Output:**
- `cert_intel/certificate_intelligence.txt` - Analysis report
- `cert_intel/certificate.pem` - Extracted certificate
- Security score with issues

---

### 4. `content-crawler.sh` - Content Analysis & Recursive Enumeration

**Purpose:** Parse HTML and discover hidden endpoints

**Features:**
- HTML parsing and link extraction
- Recursive crawling (configurable depth)
- Comment extraction (HTML/JS)
- Form and input field analysis
- Meta tag analysis
- Embedded resource discovery
- Technology detection
- Complete URL mapping

**Usage:**
```bash
./analyzers/content-crawler.sh http://target.onion [output_dir] [max_depth]
```

**Output:**
- `content_analysis/content_analysis.txt` - Full report
- `content_analysis/discovered_urls.txt` - All URLs
- `content_analysis/discovered_endpoints.txt` - Internal endpoints
- `content_analysis/extracted_comments.txt` - Comments

---

## 🔧 Integration

### From Main TUI

```bash
./c2-enum-tui.sh
# Press 'A' for Advanced menu
# Select analyzer modules
```

### From Docker

```bash
docker run -v $(pwd)/output:/home/c2enum/output \
  c2-enum-toolkit:2.2 \
  /home/c2enum/toolkit/analyzers/binary-analysis.sh /path/to/binary
```

### Standalone

```bash
# All analyzers can run independently
./analyzers/binary-analysis.sh binary.bin
./analyzers/javascript-analysis.sh http://target.onion
./analyzers/certificate-intel.sh target.onion:443
./analyzers/content-crawler.sh http://target.onion output/ 2
```

---

## 📊 Typical Workflow

```bash
TARGET="new-c2.onion"
OUTPUT="intel_$(date +%F)"

# 1. Comprehensive scan
./c2-scan-comprehensive.sh "$TARGET" "$OUTPUT/"

# 2. Analyze downloaded binaries
for binary in "$OUTPUT"/binary_*; do
  [ -f "$binary" ] && ./analyzers/binary-analysis.sh "$binary" "$OUTPUT/"
done

# 3. Extract JavaScript endpoints
./analyzers/javascript-analysis.sh "http://$TARGET" "$OUTPUT/"

# 4. Certificate analysis
./analyzers/certificate-intel.sh "$TARGET:443" "$OUTPUT/"

# 5. Crawl content (depth 2)
./analyzers/content-crawler.sh "http://$TARGET" "$OUTPUT/" 2

# Complete intelligence package in $OUTPUT/
```

---

## 📈 Performance

| Analyzer | Typical Time | Output Size |
|----------|-------------|-------------|
| Binary Analysis | 5-15s | 10-50 KB |
| JavaScript Analysis | 10-30s | 20-100 KB |
| Certificate Intel | 15-45s | 5-20 KB |
| Content Crawler (depth 2) | 30-120s | 50-500 KB |

**Total for complete analysis:** 60-210 seconds (~1-3.5 minutes)

---

## 🎯 Best Practices

1. **Run analyzers after initial scan** - Let comprehensive scan collect artifacts first
2. **Use appropriate depth** - Content crawler depth 2-3 is usually sufficient
3. **Review threat scores** - Binary analysis threat score >60 requires attention
4. **Correlate findings** - Use import hashes to cluster related samples
5. **Automate workflows** - Combine analyzers in scripts for consistency

---

## 🔐 Security Notes

- All analyzers are read-only (no code execution)
- Safe to analyze potentially malicious content
- Docker isolation recommended for extra safety
- Downloaded files are chmod 0444 (read-only)
- No network connections except via Tor SOCKS

---

For complete documentation, see **PHASE1-IMPROVEMENTS.md**
