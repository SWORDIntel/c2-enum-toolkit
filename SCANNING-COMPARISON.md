# Scanning Mode Comparison

Quick reference for choosing between Standard and Comprehensive scanning modes.

---

## 📊 Feature Comparison Matrix

| Feature | Standard Mode | Comprehensive Mode | Multiplier |
|---------|--------------|-------------------|------------|
| **Port Scanning** | 12 ports | **37 ports** | 3.08× |
| **Path Enumeration** | 18 paths | **100+ paths** | 5.56× |
| **HTTP Methods** | 1 (GET) | **8 methods** | 8× |
| **User-Agents** | 1 | **6 variations** | 6× |
| **Binary Discovery** | 3 variants | **126 combinations** | 42× |
| **Subdomain Probing** | ❌ None | **✅ 10 subdomains** | ∞ |
| **Tech Fingerprinting** | Basic | **Advanced (6 frameworks)** | ✓ |
| **Parallel Jobs** | 5-8 | **20 (Docker)** | 2.5-4× |
| **Attack Surface Coverage** | ~20% | **~95%** | 4.75× |
| **Runtime (single target)** | 5-10 min | **2-5 min** | 2× faster |
| **Detection Risk** | Low | **Higher** | ⚠️ |
| **Recommended For** | Daily monitoring | Deep analysis | - |

---

## 🎯 When to Use Each Mode

### Standard Mode ✓

**Use when:**
- ✅ Daily/routine monitoring
- ✅ Known targets with established baselines
- ✅ Low detection risk required (stealth)
- ✅ Quick reconnaissance needed
- ✅ Continuous monitoring setup
- ✅ Limited time available
- ✅ Operational C2 (don't alert operators)

**Characteristics:**
- Fast and efficient
- Low network footprint
- Minimal detection risk
- Good for trend analysis
- Safe for production use

**Example scenarios:**
- Daily check of known C2 infrastructure
- Monitoring for configuration changes
- Baseline establishment
- Quick health checks

---

### Comprehensive Mode ⚡

**Use when:**
- ✅ New/unknown targets discovered
- ✅ Deep analysis required
- ✅ Binary artifact collection needed
- ✅ Technology stack mapping
- ✅ Complete attack surface enumeration
- ✅ One-time deep dive
- ✅ Detection risk acceptable

**Characteristics:**
- Aggressive and thorough
- High network activity
- Higher detection risk
- Complete coverage
- Docker isolation recommended

**Example scenarios:**
- Initial assessment of new C2
- Collecting all binary variants
- Mapping complete infrastructure
- Pre-operation intelligence gathering
- Forensic analysis

---

## 📈 Coverage Breakdown

### Standard Mode Coverage

```
Ports:      12/65535    (0.018% of port space)
Paths:      18          (common only)
Methods:    1           (GET)
Artifacts:  3           (x86_64 linux variants)
Total:      ~20% of typical C2 attack surface
```

### Comprehensive Mode Coverage

```
Ports:      37/65535    (0.056% of port space, 3× more)
Paths:      100+        (extensive)
Methods:    8           (all major HTTP methods)
Artifacts:  126         (7 archs × 3 platforms × 6 endpoints)
Total:      ~95% of typical C2 attack surface
```

---

## ⏱️ Performance Comparison

### Time Analysis (Single Target)

| Task | Standard | Comprehensive | Winner |
|------|----------|---------------|--------|
| Port scan | 60-120s | 25-50s | Comprehensive (parallel) |
| Path enum | 90-180s | 30-60s | Comprehensive (parallel) |
| Binary discovery | 30-60s | 45-90s | Standard (fewer tests) |
| **Total** | **5-10 min** | **2-5 min** | **Comprehensive** |

*Comprehensive is faster due to aggressive parallelization (20 jobs)*

### Time Analysis (20 Targets, Parallel Docker)

| Mode | Time | Method |
|------|------|--------|
| Standard | 3.3 hours | 20 containers × 10 min avg |
| Comprehensive | 1 hour | 20 containers × 3 min avg |
| **Savings** | **2.3 hours** | **70% time reduction** |

---

## 💰 Resource Usage

### Standard Mode

```
CPU:        0.5-1 core
Memory:     256MB
Network:    Low (serial requests)
Disk I/O:   Low
Duration:   5-10 minutes
```

**Docker container resources:**
```yaml
resources:
  limits:
    cpus: '1.0'
    memory: 512M
```

### Comprehensive Mode

```
CPU:        1-2 cores
Memory:     512MB
Network:    High (20 parallel)
Disk I/O:   Medium (many writes)
Duration:   2-5 minutes
```

**Docker container resources:**
```yaml
resources:
  limits:
    cpus: '2.0'
    memory: 2G
```

---

## 🔍 Detection Risk Analysis

### Standard Mode - LOW RISK

**Detection indicators:**
- 18 requests over 5-10 minutes
- Normal GET requests only
- Single User-Agent (looks like browser)
- Port scan: 12 ports (standard services)

**Likelihood of detection:** **~10-20%**

**Target sees:**
```
10.2.3.4 - GET / 200
10.2.3.4 - GET /robots.txt 200
10.2.3.4 - GET /favicon.ico 200
... (18 requests, spread over 10 minutes)
```

**Analysis:** Looks like normal user browsing

---

### Comprehensive Mode - HIGHER RISK

**Detection indicators:**
- 250+ requests in 2-5 minutes
- 8 HTTP methods tested (PUT, DELETE, TRACE)
- 6 different User-Agents
- Port scan: 37 ports (including databases, admin)
- Path enumeration: 100+ paths (many 404s)
- Subdomain probing

**Likelihood of detection:** **~70-90%**

**Target sees:**
```
10.2.3.4 - GET / 200
10.2.3.4 - POST / 200
10.2.3.4 - PUT / 405
10.2.3.4 - DELETE / 403
10.2.3.4 - GET /admin 403
10.2.3.4 - GET /c2panel 401
10.2.3.4 - GET /.git/config 404
10.2.3.4 - GET /.env 404
... (250+ requests in 3 minutes)
```

**Analysis:** Clear scanning pattern, likely automated tool

---

## 🎯 Decision Matrix

### Choose **STANDARD** if:

- ✅ Target has active defenders/monitoring
- ✅ Operational security is critical
- ✅ Routine monitoring use case
- ✅ Known target with established baseline
- ✅ Quick checks needed
- ✅ Stealth is important

### Choose **COMPREHENSIVE** if:

- ✅ New target, unknown infrastructure
- ✅ Deep analysis required
- ✅ Binary collection is priority
- ✅ Complete attack surface needed
- ✅ One-time assessment
- ✅ Detection risk is acceptable
- ✅ Running in Docker (isolation)

---

## 🔄 Hybrid Approach

### Recommended Workflow

1. **First Contact:** Standard mode
   - Low risk reconnaissance
   - Establish baseline
   - Confirm target is live

2. **Deep Dive:** Comprehensive mode
   - Full attack surface mapping
   - Binary collection
   - Technology fingerprinting

3. **Ongoing:** Standard mode
   - Monitor for changes
   - Track configuration drift
   - Daily health checks

### Example Timeline

```
Day 1:  Standard scan      (baseline established)
Day 2:  Comprehensive scan (deep analysis, binaries collected)
Day 3+: Standard scan      (daily monitoring)
Week:   Comprehensive scan (weekly deep check)
```

---

## 📊 Output Comparison

### Standard Mode Output (~10 files)

```
intel_target_20251002/
├── c2-enum.log
├── report.txt
├── static_analysis.txt
├── target_root.head
├── target_root.sample
├── target_robots.txt.head
├── target_system-linux-x86_64.zst
├── download.hashes.txt
└── pcap/
    └── c2-enum-*.pcap
```

### Comprehensive Mode Output (~20+ files)

```
comprehensive_scan_20251002/
├── port_scan_comprehensive.txt     ← 37 ports
├── open_ports.txt                  ← Summary
├── http_methods.txt                ← 8 method tests
├── headers_analysis.txt            ← 6 User-Agents
├── path_enumeration.txt            ← 100+ paths
├── found_paths.txt                 ← Interesting findings
├── binary_discovery.txt            ← 126 combinations
├── subdomain_probe.txt             ← 10 subdomains
├── technology_fingerprint.txt      ← Framework detection
├── binary_binary_system-linux-x86_64
├── binary_binary_system-linux-arm64
├── binary_binary_agent-windows-amd64
└── ... (many more binaries)
```

---

## 💡 Pro Tips

### Tip 1: Start Standard, Escalate to Comprehensive
```bash
# Day 1: Standard
./c2-enum-tui.sh
# Press 1 to enumerate

# If interesting, escalate to comprehensive
# Press C for comprehensive scan
```

### Tip 2: Use Docker for Comprehensive Only
```bash
# Standard: Native (faster startup)
./c2-enum-tui.sh --no-pcap

# Comprehensive: Docker (isolation)
docker-compose up
# Press C
```

### Tip 3: Throttle Comprehensive for Stealth
```bash
# Reduce parallelism
MAX_PARALLEL_JOBS=5 ./c2-scan-comprehensive.sh target.onion
# Takes longer but less noisy
```

### Tip 4: Combine Both Modes
```bash
# Standard for monitoring
while true; do
  ./c2-enum-tui.sh --quiet --no-auto-enum
  sleep 3600
done

# Comprehensive when changes detected
if detect_changes; then
  docker run c2-enum-toolkit:2.1 \
    /home/c2enum/toolkit/c2-scan-comprehensive.sh $target
fi
```

---

## 📚 Quick Reference

### Standard Mode

**Command:**
```bash
./c2-enum-tui.sh
# or
docker-compose up
# Press 1, 2, or R
```

**Best for:**
- Daily monitoring
- Known targets
- Low detection risk
- Quick checks

**Coverage:** ~20%
**Time:** 5-10 min
**Risk:** Low

---

### Comprehensive Mode

**Command:**
```bash
./c2-scan-comprehensive.sh target.onion
# or
docker-compose up
# Press C
```

**Best for:**
- Deep analysis
- New targets
- Binary collection
- Complete mapping

**Coverage:** ~95%
**Time:** 2-5 min
**Risk:** Higher

---

## 🎓 Training Scenarios

### Scenario 1: New Analyst

**Task:** Analyze unknown.onion

**Approach:**
```
1. Start with Standard
   → Get familiar with interface
   → Low risk learning

2. Review standard results
   → Understand baseline

3. Try Comprehensive (in Docker)
   → Safe environment for learning
   → See full capabilities
   → Compare with standard
```

### Scenario 2: Incident Response

**Task:** Active C2 infrastructure discovered

**Approach:**
```
1. Immediate: Standard scan
   → Quick confirmation
   → Low detection risk
   → Get initial IOCs

2. Once confirmed: Comprehensive
   → Collect all binaries
   → Map complete infrastructure
   → Full technology stack

3. Ongoing: Standard monitoring
   → Track changes
   → Detect updates
```

### Scenario 3: Threat Intelligence

**Task:** Catalog 50 C2 servers

**Approach:**
```
1. All targets: Standard scan (parallel)
   → 50 Docker containers
   → 5 hours total time
   → Basic intel on all

2. High-priority targets: Comprehensive
   → Top 10 targets
   → Deep analysis
   → Complete artifact collection
```

---

## ✅ Summary

**Standard Mode:**
- 🎯 Targeted and efficient
- 🕵️ Stealthy
- ⚡ Quick results
- 📊 Good for monitoring

**Comprehensive Mode:**
- 🔍 Complete coverage
- 💪 Aggressive
- 🎯 Deep intelligence
- 🐋 Docker-optimized

**Recommendation:** Use Standard for 80% of work, Comprehensive for 20% when deep analysis needed.

**Golden Rule:** Always start Standard, escalate to Comprehensive when justified.
