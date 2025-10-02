# Comprehensive C2 Endpoint Scanning

## Overview

The comprehensive scanning module provides **aggressive, in-depth enumeration** of C2 endpoints, designed to leverage Docker's isolation for safe, parallel analysis at scale.

---

## 🎯 Why Comprehensive Scanning?

### Standard vs Comprehensive Mode

| Feature | Standard Mode | Comprehensive Mode |
|---------|--------------|-------------------|
| Ports Scanned | 12 | **37** |
| Paths Tested | 18 | **100+** |
| HTTP Methods | GET only | **8 methods** |
| User-Agents | 1 | **6** |
| Binary Variants | 3 | **126** (7 archs × 6 endpoints × 3 platforms) |
| Subdomain Probing | No | **Yes (10 common)** |
| Tech Fingerprinting | Basic | **Advanced** |
| Parallel Jobs | 5-8 | **20** (Docker-optimized) |
| Detection Risk | Low | **Higher** |

---

## 📊 What Gets Scanned

### 1. Port Scanning (37 Ports)

**Extended port list includes:**

#### Web Services
- 80, 443 (HTTP/HTTPS)
- 8000, 8080, 8081, 8443, 8888, 9000, 9090 (HTTP alternatives)

#### Admin/Control
- 3000 (Node.js)
- 5000 (Flask)
- 9001 (Tor directory)
- 9050, 9150 (Tor SOCKS)

#### Databases
- 3306 (MySQL)
- 5432 (PostgreSQL)
- 6379 (Redis)
- 27017 (MongoDB)
- 1433 (MSSQL)
- 1521 (Oracle)

#### Remote Access
- 21 (FTP)
- 22 (SSH)
- 23 (Telnet)
- 3389 (RDP)
- 5900 (VNC)
- 1080 (SOCKS proxy)

#### Mail Services
- 25 (SMTP)
- 110, 995 (POP3/POP3S)
- 143, 993 (IMAP/IMAPS)
- 587 (SMTP submission)

#### Other
- 53 (DNS)
- 445 (SMB)
- 4444 (Metasploit)
- 6667 (IRC)
- 50000 (SAP)

### 2. Path Enumeration (100+ Paths)

#### Discovery Files
```
/robots.txt
/sitemap.xml
/humans.txt
/.well-known/security.txt
/crossdomain.xml
```

#### Admin Panels
```
/admin
/administrator
/wp-admin
/phpmyadmin
/cpanel
/webadmin
/panel
/control
/c2
/c2panel
/admin/login
```

#### API Endpoints
```
/api
/api/v1
/api/v2
/api/status
/api/health
/api/config
/graphql
/rest/api
```

#### Status/Health
```
/status
/health
/healthz
/ping
/alive
/metrics
/stats
/info
/version
```

#### Configuration Files
```
/config.json
/config.php
/.env
/.env.local
/.env.production
/settings.json
/app.json
/package.json
/composer.json
/web.config
```

#### Version Control (often exposed)
```
/.git
/.git/config
/.git/HEAD
/.git/logs/HEAD
/.gitignore
/.svn
/.hg
```

#### Backup Files
```
/backup
/backup.sql
/backup.tar.gz
/db_backup.sql
/site_backup.zip
```

#### C2-Specific
```
/beacon
/checkin
/task
/tasks
/command
/commands
/agent
/implant
/payload
/stage
/stager
```

#### Binary Endpoints
```
/binary
/binaries
/download/binary
/static/binary
```

#### Docker Artifacts
```
/static/docker-init.sh
/docker-compose.yml
/Dockerfile
/.dockerignore
```

### 3. HTTP Method Testing

Tests **8 HTTP methods** against each endpoint:
- GET
- POST
- HEAD
- OPTIONS
- PUT
- DELETE
- TRACE
- CONNECT

**Why:** Reveals:
- Allowed methods (security misconfiguration)
- RESTful API capabilities
- Potential upload endpoints (PUT)
- Debug methods enabled (TRACE)

### 4. Header Analysis

**Tests with 6 different User-Agents:**
```
Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36
Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36
Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36
curl/7.68.0
python-requests/2.31.0
Go-http-client/1.1
```

**Analyzes:**
- Server header disclosure
- X-Powered-By headers
- Security headers (CSP, HSTS, etc.)
- Content-Type variations
- User-Agent-specific responses

### 5. Binary Artifact Discovery

**Tests 126 combinations:**
- **7 architectures:** x86_64, amd64, i386, arm64, aarch64, armv7, mips
- **3 platforms:** linux, windows, darwin
- **6 endpoints:** /binary, /binaries, /download, /files, /static, /assets
- **Multiple naming patterns:**
  - `/binary/system-{platform}-{arch}`
  - `/binary/agent-{platform}-{arch}`
  - `/binary/implant-{platform}-{arch}`
  - `/binary/{platform}/{arch}/binary`

**Automatically downloads and analyzes:**
- File type detection
- SHA256 hashing
- ELF header analysis
- Size and metadata

### 6. Subdomain Probing

Tests **10 common subdomains:**
```
www.{target}.onion
api.{target}.onion
admin.{target}.onion
panel.{target}.onion
c2.{target}.onion
control.{target}.onion
manage.{target}.onion
portal.{target}.onion
app.{target}.onion
mobile.{target}.onion
```

### 7. Technology Fingerprinting

**Detects frameworks:**
- Flask (Python)
- Django (Python)
- Express (Node.js)
- Laravel (PHP)
- WordPress (PHP)
- ASP.NET

**Analyzes:**
- Server headers
- X-Powered-By headers
- Framework-specific patterns
- Technology stack disclosure

---

## 🚀 Usage

### From TUI Menu

```bash
./c2-enum-tui.sh

# In menu:
Press 'C' → COMPREHENSIVE SCAN (aggressive)
# Confirm warning
# Select target
# Wait for completion
```

### Standalone Script

```bash
# Basic usage
./c2-scan-comprehensive.sh target.onion

# With custom output directory
./c2-scan-comprehensive.sh target.onion /path/to/output

# In Docker
docker run -v $(pwd)/output:/home/c2enum/output c2-enum-toolkit:2.1 \
  /home/c2enum/toolkit/c2-scan-comprehensive.sh target.onion /home/c2enum/output
```

### Environment Variables

```bash
# Increase parallelism (default: 20)
MAX_PARALLEL_JOBS=50 ./c2-scan-comprehensive.sh target.onion

# Adjust timeouts
TIMEOUT_SHORT=10 TIMEOUT_MEDIUM=30 ./c2-scan-comprehensive.sh target.onion

# Quiet mode
VERBOSE=false ./c2-scan-comprehensive.sh target.onion
```

---

## 📂 Output Structure

```
comprehensive_scan_20251002_143045/
├── port_scan_comprehensive.txt      # Full port scan results
├── open_ports.txt                   # List of open ports only
├── http_methods.txt                 # HTTP method test results
├── headers_analysis.txt             # Header analysis (all User-Agents)
├── path_enumeration.txt             # All 100+ paths tested
├── found_paths.txt                  # Interesting paths found
├── binary_discovery.txt             # Binary artifact findings
├── subdomain_probe.txt              # Subdomain test results
├── technology_fingerprint.txt       # Detected technologies
└── binary_*                         # Downloaded binaries
```

---

## ⚙️ Performance & Optimization

### Parallelization

**Comprehensive mode uses aggressive parallelization:**

```bash
# Standard mode
MAX_JOBS=5-8

# Comprehensive mode (Docker-optimized)
MAX_JOBS=20

# Custom (for powerful systems)
MAX_JOBS=50
```

**Performance scaling:**
```
1 parallel:   100 paths in ~500 seconds
10 parallel:  100 paths in ~50 seconds
20 parallel:  100 paths in ~25 seconds (Docker default)
50 parallel:  100 paths in ~10 seconds (high-end)
```

### Resource Usage

**Expected resource consumption:**

| Metric | Standard | Comprehensive |
|--------|----------|---------------|
| CPU | 0.5-1 core | 1-2 cores |
| Memory | 256MB | 512MB |
| Network | Low (serial) | High (parallel) |
| Duration | 5-10 min | 2-5 min |
| Detection Risk | Low | Higher |

### Docker Advantages

**Why comprehensive scanning works better in Docker:**

1. **Isolation:** Aggressive scanning can't affect host
2. **Resource Limits:** CPU/memory bounded by container
3. **Parallelism:** 20+ jobs safe in container
4. **Cleanup:** Destroy container = instant cleanup
5. **Reproducibility:** Same results every time

---

## 🔒 Security & Detection

### Detection Risk

**Comprehensive scanning is MORE likely to be detected:**

| Activity | Detection Likelihood |
|----------|---------------------|
| Port scanning (37 ports) | **High** |
| Path enumeration (100+ paths) | **High** |
| HTTP method testing | **Medium** |
| Subdomain probing | **Low-Medium** |
| Multiple User-Agents | **Low** |

**Indicators of compromise (from target's perspective):**
- High request volume in short time
- Sequential port connections
- 404 patterns (path enumeration)
- Unusual User-Agents
- Method testing (PUT, DELETE, TRACE)

### Mitigation Strategies

**To reduce detection risk:**

1. **Throttle requests:**
   ```bash
   # Add delays (modify script)
   sleep 1  # Between requests
   ```

2. **Use fewer parallel jobs:**
   ```bash
   MAX_PARALLEL_JOBS=5 ./c2-scan-comprehensive.sh target.onion
   ```

3. **Selective scanning:**
   - Skip port scan if ports known
   - Target specific paths only
   - Limit binary discovery

4. **Tor circuit rotation:**
   ```bash
   # Between scans
   docker restart c2-enum-toolkit  # Fresh Tor circuits
   ```

### Operational Security

**Best practices:**

✅ **DO:**
- Run in Docker (isolation)
- Review outputs before sharing
- Use on authorized targets only
- Understand legal implications
- Document findings properly

❌ **DON'T:**
- Run on production C2 during ops
- Scan without authorization
- Ignore rate limiting
- Scan from personal IP (use Tor!)
- Execute downloaded binaries

---

## 📊 Comparison: Standard vs Comprehensive

### Standard Mode

**Good for:**
- Quick reconnaissance
- Low detection risk
- Daily monitoring
- Known targets

**Characteristics:**
- 18 paths
- 12 ports
- GET requests only
- Single User-Agent
- 5-8 parallel jobs
- 5-10 minute runtime

### Comprehensive Mode

**Good for:**
- Deep analysis
- New/unknown targets
- Binary discovery
- Technology mapping

**Characteristics:**
- 100+ paths
- 37 ports
- 8 HTTP methods
- 6 User-Agents
- 20 parallel jobs (Docker)
- 2-5 minute runtime
- **Higher detection risk**

---

## 🎯 Use Cases

### Use Case 1: Initial Target Assessment

**Scenario:** New C2 infrastructure discovered

**Action:**
```bash
# Comprehensive scan
docker run -v $(pwd)/output:/home/c2enum/output \
  c2-enum-toolkit:2.1 \
  /home/c2enum/toolkit/c2-scan-comprehensive.sh new-c2.onion

# Results:
# - 3 open ports found (80, 443, 9000)
# - Admin panel at /c2panel
# - Flask framework detected
# - Binary artifacts: linux-x86_64, windows-amd64
# - No subdomains
```

**Benefit:** Complete picture in 3 minutes

### Use Case 2: Binary Artifact Collection

**Scenario:** Need all available implant binaries

**Action:**
```bash
# Comprehensive scan focuses on binary discovery
./c2-scan-comprehensive.sh c2.onion

# Check results
ls comprehensive_*/binary_*

# Found:
# binary_binary_system-linux-x86_64
# binary_binary_system-linux-arm64
# binary_binary_agent-windows-amd64
```

**Benefit:** Automated artifact collection

### Use Case 3: Technology Stack Mapping

**Scenario:** Understanding C2 implementation

**Action:**
```bash
# Comprehensive scan
./c2-scan-comprehensive.sh c2.onion

# Review technology_fingerprint.txt
cat comprehensive_*/technology_fingerprint.txt

# Findings:
# - Flask (Python)
# - Nginx server
# - Gunicorn WSGI
# - Redis (port 6379 open)
```

**Benefit:** Attack surface understanding

### Use Case 4: Parallel Multi-Target Analysis

**Scenario:** 20 new C2 targets to analyze

**Action:**
```bash
# Docker Compose with scaling
cat > targets.txt <<EOF
c2-1.onion
c2-2.onion
...
c2-20.onion
EOF

# Parallel comprehensive scans
while read target; do
  docker run -d --name scan-$target \
    -v $(pwd)/output:/home/c2enum/output \
    c2-enum-toolkit:2.1 \
    /home/c2enum/toolkit/c2-scan-comprehensive.sh $target
done < targets.txt

# Wait for all
docker wait $(docker ps -q --filter name=scan-)

# Aggregate results
find output/ -name "port_scan_comprehensive.txt"
```

**Benefit:** 20 targets analyzed simultaneously

---

## 🔧 Customization

### Adding Custom Ports

Edit `c2-scan-comprehensive.sh`:

```bash
COMMON_PORTS=(
    # ... existing ports ...
    "31337:Custom-Backdoor"
    "12345:NetBus"
    "54321:Custom-C2"
)
```

### Adding Custom Paths

```bash
COMPREHENSIVE_PATHS=(
    # ... existing paths ...
    "/my-custom-endpoint"
    "/api/v3/status"
    "/secret-panel"
)
```

### Changing Parallelism

```bash
# In script or via environment
MAX_PARALLEL_JOBS=50  # Very aggressive

# Or moderate
MAX_PARALLEL_JOBS=10  # Lower detection risk
```

### Adjusting Timeouts

```bash
TIMEOUT_SHORT=10      # Slow connections
TIMEOUT_MEDIUM=30
TIMEOUT_LONG=60
```

---

## 📈 Output Interpretation

### Port Scan Results

```
Port 80 (HTTP): OPEN
Port 443 (HTTPS): OPEN
Port 9000 (Custom): OPEN
Port 3306 (MySQL): CLOSED/FILTERED
```

**Interpretation:**
- Web services on 80, 443 (standard)
- Custom service on 9000 (investigate)
- MySQL filtered (firewall or not installed)

### Path Enumeration

```
[200] /admin
  Size: 15234
[401] /c2panel
[403] /.git/config
[404] /wp-admin
```

**Interpretation:**
- `/admin` accessible (potential issue)
- `/c2panel` requires auth (good)
- `.git` directory exposed (leak!)
- Not WordPress-based

### HTTP Methods

```
[GET] 200 OK
[POST] 200 OK
[PUT] 405 Method Not Allowed
[DELETE] 403 Forbidden
[TRACE] 501 Not Implemented
```

**Interpretation:**
- GET/POST work (standard)
- PUT disallowed (good)
- DELETE forbidden (good)
- TRACE not implemented (good security)

---

## ⚠️ Warnings & Limitations

### Limitations

1. **Tor latency:** Slower than direct connections
2. **False negatives:** Firewalls may block scans
3. **Rate limiting:** Targets may throttle requests
4. **Circuit failures:** Tor circuits can fail mid-scan

### Warnings

⚠️ **Detection Risk:** Comprehensive scanning WILL be noticed by sophisticated C2 operators

⚠️ **Legal:** Only scan authorized targets - unauthorized scanning is illegal

⚠️ **Operational Impact:** May trigger C2 alerts, affecting ongoing operations

⚠️ **Resource Usage:** 20 parallel jobs can saturate Tor circuits

---

## ✅ Best Practices

1. **Start with standard mode** - Only use comprehensive when needed
2. **Review legal authorization** - Ensure you have permission
3. **Use Docker** - Leverage isolation for safety
4. **Throttle if needed** - Reduce parallel jobs for stealth
5. **Rotate Tor circuits** - Fresh circuits between scans
6. **Document findings** - Proper evidence collection
7. **Never execute** - Don't run downloaded binaries
8. **Share securely** - Encrypt outputs before transfer

---

## 🔮 Future Enhancements

- [ ] Machine learning-based path prediction
- [ ] Automated exploit detection
- [ ] SSL/TLS certificate analysis
- [ ] JavaScript enumeration
- [ ] GraphQL introspection
- [ ] WebSocket detection
- [ ] Automated report generation
- [ ] MITRE ATT&CK mapping

---

## 📚 Related Documentation

- **DOCKER.md** - Docker deployment
- **PORT-SCANNING.md** - Standard port scanning
- **QUICKSTART.md** - Basic usage
- **ENHANCEMENTS.md** - Technical details

---

**Remember:** With great scanning power comes great responsibility. Use comprehensive mode ethically and legally.
