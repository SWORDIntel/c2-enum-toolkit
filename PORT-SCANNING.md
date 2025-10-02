# Port Scanning & Reachability Features

## Overview

Enhanced c2-enum-tui.sh now includes comprehensive port scanning and multi-protocol reachability checking to handle non-live or hard-to-reach .onion services.

---

## 🔍 New Features

### 1. Multi-Protocol Reachability Testing

When checking if a target is reachable, the script now:

- ✅ Tests both **HTTP** and **HTTPS**
- ✅ Tries multiple common ports: `80, 443, 8080, 8443, 9000, 9001`
- ✅ Saves working protocol/port combination for later use
- ✅ Provides detailed feedback on each attempt

**Example Output:**
```
[*] Testing wtxqf54djhp5pskv2lfyduub5ievxbyvlzjgjopk6hxge5umombr63ad.onion...
  → Trying http://wtxqf54djhp5pskv2lfyduub5ievxbyvlzjgjopk6hxge5umombr63ad.onion:80...
  → Trying http://wtxqf54djhp5pskv2lfyduub5ievxbyvlzjgjopk6hxge5umombr63ad.onion:443...
  → Trying https://wtxqf54djhp5pskv2lfyduub5ievxbyvlzjgjopk6hxge5umombr63ad.onion:443...
[✓] Target is reachable on https://wtxqf54djhp5pskv2lfyduub5ievxbyvlzjgjopk6hxge5umombr63ad.onion:443
```

### 2. Comprehensive Port Scanner

Full port scanning functionality for .onion addresses:

**Scanned Ports:**
- `80` - HTTP
- `443` - HTTPS
- `8080` - HTTP-Alt
- `8443` - HTTPS-Alt
- `9000` - Custom
- `9001` - Tor Directory
- `22` - SSH
- `21` - FTP
- `3306` - MySQL
- `5432` - PostgreSQL
- `6379` - Redis
- `27017` - MongoDB

**Features:**
- Timeout-based connection testing (8 seconds per port)
- Detailed results saved to file
- Summary statistics (open vs closed/filtered)
- Visual feedback during scan

**Example Output:**
```
[*] Scanning common ports on wtxqf54djhp5pskv2lfyduub5ievxbyvlzjgjopk6hxge5umombr63ad.onion...
  [*] 80    (HTTP)... [CLOSED/FILTERED]
  [*] 443   (HTTPS)... [OPEN]
  [*] 8080  (HTTP-Alt)... [CLOSED/FILTERED]
  [*] 8443  (HTTPS-Alt)... [CLOSED/FILTERED]
  [*] 9000  (Custom)... [OPEN]
  [*] 9001  (Tor-Dir)... [CLOSED/FILTERED]
  [*] 22    (SSH)... [CLOSED/FILTERED]
  [*] 21    (FTP)... [CLOSED/FILTERED]
  [*] 3306  (MySQL)... [CLOSED/FILTERED]
  [*] 5432  (PostgreSQL)... [CLOSED/FILTERED]
  [*] 6379  (Redis)... [CLOSED/FILTERED]
  [*] 27017 (MongoDB)... [CLOSED/FILTERED]

[✓] Port scan complete: 2 open, 10 closed/filtered
    Results: intel_<target>_<timestamp>/port_scan_<target>.txt
```

---

## 📍 How to Access

### Main Menu

**Option R) Quick reachability check**
- Tests all configured targets
- Tries multiple protocols and ports
- Shows which ones are reachable
- Fast pre-enumeration check

**Usage:**
1. Run script: `./c2-enum-tui.sh`
2. Press **R**
3. View results for all targets

### Advanced Menu

**Option: Port-Scanner**
- Full port scan on selected target
- Tests 12 common ports
- Saves detailed results to file

**Usage:**
1. Run script: `./c2-enum-tui.sh`
2. Press **A** (Advanced menu)
3. Select **Port-Scanner**
4. Choose target
5. Wait for scan to complete

### Automatic Integration

Port scanning is also integrated into:
- **Select-Target-for-Deep-Scan** - Includes port scan
- **Run-All-Advanced-On-Target** - Includes port scan

---

## 🔧 Technical Details

### Function: `test_onion_reachable()`

**Location:** Lines 229-288

**Features:**
- Parses target into host and port components
- Tests multiple protocol/port combinations
- Stores successful configuration in `.reachable_*` file
- Returns 0 on success, 1 on failure

**Protocols Tested:**
- HTTP (port 80 default)
- HTTPS (port 443 default)

**Ports Tested (if port 80):**
- 80, 443, 8080, 8443, 9000, 9001

**Timeout Settings:**
- Overall: 30 seconds
- Connect: 15 seconds

### Function: `scan_onion_ports()`

**Location:** Lines 290-358

**Features:**
- Scans 12 common ports
- 8-second timeout per port
- Generates detailed report file
- Returns summary statistics

**Output File:**
```
port_scan_<sanitized-hostname>.txt
```

**Report Contents:**
- Timestamp
- Per-port results (OPEN/CLOSED/FILTERED)
- Summary statistics

---

## 📊 Use Cases

### 1. Pre-Enumeration Check

Before full enumeration, check if targets are alive:

```bash
./c2-enum-tui.sh --no-auto-enum
# Press R to check reachability
# Press 1 to enumerate only live targets
```

### 2. Finding Alternative Ports

If known port is down, discover alternatives:

```bash
# In Advanced menu:
# Select Port-Scanner
# Review results for open ports
# Manually add target with discovered port
```

### 3. Infrastructure Mapping

Discover exposed services:

```bash
# Port scan shows:
# - Web services (80, 443, 8080, 8443)
# - Admin interfaces (9000, 9001)
# - Database exposure (3306, 5432, 6379, 27017)
# - Remote access (22, 21)
```

### 4. Non-Live Target Handling

Script now gracefully handles:
- Targets that are temporarily down
- Targets on non-standard ports
- Targets requiring HTTPS instead of HTTP
- Targets with specific port requirements

---

## 🎯 Example Scenarios

### Scenario 1: Target on Non-Standard Port

**Problem:** Target `example.onion` is on port 9000, not 80

**Before:** Enumeration would fail with timeout

**After:**
1. Reachability check tries ports: 80, 443, 8080, 8443, **9000**, 9001
2. Discovers service on port 9000
3. Saves: `http://example.onion:9000`
4. Enumeration uses correct port

### Scenario 2: HTTPS-Only Service

**Problem:** Target only accepts HTTPS connections

**Before:** HTTP attempts would fail

**After:**
1. Tries HTTP first
2. Falls back to HTTPS
3. Discovers HTTPS is working
4. Saves: `https://example.onion:443`
5. Future requests use HTTPS

### Scenario 3: Completely Dead Target

**Problem:** Target is offline

**Before:** Script would timeout after long delays

**After:**
1. Quick reachability check (30s total)
2. Clearly reports: `[✗] Target NOT reachable`
3. Option to skip or retry
4. Doesn't waste time on full enumeration

---

## 🔐 Security Considerations

### Network Exposure

- All port scans go through Tor SOCKS proxy
- No direct connections to .onion addresses
- Anonymity preserved

### Detection Risk

- Port scanning may be detected by target
- Each port test creates connection attempt
- Consider operational security (OpSec)
- Use with caution on production targets

### False Positives

- Firewall may silently drop packets (appears closed)
- Tor circuit issues may cause false negatives
- Some services may rate-limit, causing timeouts

---

## ⚙️ Configuration

### Timeout Tuning

Edit these values in the script:

**Reachability Check:**
```bash
test_onion_reachable(){
  local timeout=30         # Overall timeout
  ...
  --max-time "$timeout" \
  --connect-timeout 15     # Connection timeout
```

**Port Scanner:**
```bash
scan_onion_ports(){
  ...
  timeout 10 "$CURL_BIN" --socks5-hostname "$SOCKS" -sS --max-time 8 \
     --connect-timeout 5   # 5 second connection timeout, 8 second max
```

### Custom Ports

Add more ports to scan by editing:

```bash
local common_ports=(
  "80:HTTP"
  "443:HTTPS"
  # Add your custom ports here:
  "8888:Custom-Web"
  "31337:Custom-Service"
)
```

---

## 📈 Performance

### Reachability Check (per target)

- **Best case:** 1-3 seconds (first port succeeds)
- **Worst case:** 180 seconds (all 6 ports timeout at 30s each)
- **Typical:** 10-30 seconds

### Full Port Scan (12 ports)

- **Best case:** 12 seconds (all ports respond quickly)
- **Worst case:** 120 seconds (all ports timeout at 10s each)
- **Typical:** 60-90 seconds

### Optimization Tips

1. Use **R)** quick check before full enumeration
2. Skip unreachable targets
3. Port scan only interesting targets
4. Reduce timeout values for faster scanning

---

## 🐛 Troubleshooting

### Port Scan Shows All Closed

**Possible causes:**
- Target is behind firewall
- Tor circuit has issues
- Target is completely offline

**Solutions:**
- Try new Tor circuit: `sudo systemctl restart tor`
- Wait and retry (Tor circuit may be slow)
- Verify target with external tools

### Reachability Check Takes Too Long

**Cause:** Multiple ports timing out

**Solutions:**
- Reduce timeout values
- Add `--no-auto-enum` to manually control
- Use specific port if known: `target.onion:9000`

### False Negatives

**Cause:** Tor circuit issues or rate limiting

**Solutions:**
- Retry the check
- Use different Tor exit node
- Increase timeout values
- Try at different time of day

---

## 📝 Output Files

### Reachability Cache

```
.reachable_<sanitized-hostname>.txt
```

**Contents:** Working protocol and port
**Example:** `https://example.onion:443`

### Port Scan Report

```
port_scan_<sanitized-hostname>.txt
```

**Contents:**
- Timestamp
- Per-port results
- Summary statistics

**Example:**
```
═══════════════════════════════════════════════════════════
 Port Scan Results: example.onion
 Timestamp: 2025-10-02T15:30:45Z
═══════════════════════════════════════════════════════════

Port 80 (HTTP): CLOSED/FILTERED
Port 443 (HTTPS): OPEN
Port 8080 (HTTP-Alt): CLOSED/FILTERED
...

Summary: 1 open, 11 closed/filtered
```

---

## 🎓 Best Practices

1. **Always run quick reachability check first**
   - Saves time on dead targets
   - Identifies working protocols early

2. **Use port scanner judiciously**
   - Only on high-value targets
   - Consider detection risk
   - May alert target operators

3. **Document findings**
   - Review port scan reports
   - Note exposed services
   - Cross-reference with other intel

4. **Respect timeouts**
   - Don't hammer unresponsive targets
   - Allow Tor circuit time to establish
   - Consider rate limiting

5. **Verify results**
   - False positives/negatives possible
   - Retry if suspicious
   - Use multiple techniques

---

## 📚 Related Features

- **Tor Status Check (T)** - Verify Tor connectivity
- **Advanced Menu (A)** - Access full port scanner
- **Dashboard (S)** - View scan results summary

---

## 🔄 Version History

**v2.1 (Current)**
- Added multi-protocol reachability testing
- Added comprehensive port scanner
- Integrated into main and advanced menus
- Added quick reachability check option

**v2.0**
- Basic reachability testing
- HTTP-only support

---

**Remember:** Port scanning should be done ethically and legally. Only scan infrastructure you have authorization to test.
