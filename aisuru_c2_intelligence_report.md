# AISURU Botnet C2 Infrastructure Intelligence Report

**Generated:** 2025-11-17
**Tool:** C2 Enumeration Toolkit v2.6
**Source:** XLab Threat Intelligence Report on AISURU Botnet
**Classification:** DEFENSIVE SECURITY RESEARCH ONLY

---

## Executive Summary

This report documents the Command & Control (C2) infrastructure of the AISURU botnet, a large-scale DDoS botnet responsible for record-breaking attacks including an 11.5 Tbps attack in September 2025. The botnet compromised approximately 300,000 devices, primarily Totolink routers, through a firmware update server breach in April 2025.

### Key Findings

- **Botnet Scale:** ~300,000 compromised devices
- **Peak Attack Capacity:** 11.5 Tbps (world record at the time)
- **Primary Infection Vector:** Compromised Totolink firmware update server (April 2025)
- **C2 Infrastructure:** Clearnet domains (.su, .tw, .ru TLDs) and direct IP addresses
- **Additional Capabilities:** DDoS attacks + Residential proxy services
- **Operational Period:** 2024-2025 (still partially active as of report date)

---

## Threat Actors

According to anonymous intelligence sources, the AISURU group consists of three key operators:

| Codename | Role | Responsibilities |
|----------|------|------------------|
| **Snow** | Developer | Botnet development and maintenance |
| **Tom** | Exploitation | Vulnerability research, 0-day/N-day integration |
| **Forky** | Sales/Operations | Botnet service sales and customer relations |

### Group Characteristics

- **Motivation:** Financial gain (DDoS-for-hire, proxy services)
- **Behavior:** Flamboyant, provocative, antagonistic toward competitors
- **Reputation:** Known as "mentally unstable" in DDoS community due to destructive ISP attacks
- **Previous Operations:** catddos botnet (2022)

---

## C2 Infrastructure Analysis

### 1. Command & Control Domains

| Domain | TLD | Status | Purpose | Notes |
|--------|-----|--------|---------|-------|
| coerece.ilovegaysex.su | .su | Unknown | C2 Commands | Part of main C2 infrastructure |
| approach.ilovegaysex.su | .su | Unknown | C2 Commands | DNS TXT-based IP delivery |
| ministry.ilovegaysex.su | .su | Unknown | C2 Commands | Part of distributed C2 |
| lane.ilovegaysex.su | .su | Unknown | C2 Commands | Part of distributed C2 |
| a.6mv1eyr328y6due83u3js6whtzuxfyhw.ru | .ru | Unknown | C2 Commands | Obfuscated subdomain |

**Technical Notes:**
- All .su domains use DNS TXT records for C2 IP distribution
- TXT records encoded with base64+XOR (previously base64+ChaCha20 in older versions)
- C2 extraction method: Decrypt strings from binary, split by `|` and `,` to form FQDNs

### 2. Report/Download Servers

| Server | Purpose | Status | Notes |
|--------|---------|--------|-------|
| u.ilovegaysex.su | Sample distribution | Unknown | Malware download endpoint |
| updatetoto.tw | Malicious update server | **TAKEN DOWN** | Compromised Totolink update server (patched) |

**updatetoto.tw Analysis:**
- **Created:** April 25, 2025
- **Infection Period:** April 26 - ~May 30, 2025
- **Global Rank (Tranco):** Rose to #672,588 within one month
- **Malicious Script:** `t.sh` - dropper script for AISURU bot
- **Current Status:** Patched, nameservers refusing queries (likely sinkholed)
- **Impact:** Responsible for rapid botnet growth from <100k to 300k+ devices

### 3. GRE Tunnel C2 Servers

| IP Address | Status | Configuration | Purpose |
|------------|--------|---------------|---------|
| 151.242.2.22 | Active (as of report) | GRE Tunnel enabled | Primary C2 traffic distribution |
| 151.242.2.23 | Active (as of report) | GRE Tunnel enabled | Primary C2 traffic distribution |
| 151.242.2.24 | Active (as of report) | GRE Tunnel enabled | Primary C2 traffic distribution |
| 151.242.2.25 | Active (as of report) | GRE Tunnel enabled | Primary C2 traffic distribution |

**Technical Details:**
- Configured in April 2025 to handle massive botnet scale
- GRE tunnels used for traffic distribution and load balancing
- All four IPs detected in DNS TXT record for `approach.ilovegaysex.su`

### 4. Proxy Relay C2 Infrastructure

| IP Address | Geolocation | ASN | Organization |
|------------|-------------|-----|--------------|
| 194.46.59.169 | United Kingdom, England, Exeter | AS206509 | KCOM GROUP LIMITED |
| 104.171.170.241 | United States, Virginia, Ashburn | AS7922 | Comcast Cable Communications, LLC |
| 104.171.170.253 | United States, Virginia, Ashburn | AS7922 | Comcast Cable Communications, LLC |
| 107.173.196.189 | United States, New York, Buffalo | AS36352 | ColoCrossing |
| 64.188.68.193 | United States, District of Columbia, Washington | AS46339 | CSDVRS, LLC |
| 78.108.178.100 | Czech Republic, Praha, Prague | AS62160 | Yes Networks Un |

**Purpose:** Residential proxy relay infrastructure for monetizing bot network

**Business Model:** AISURU expanded from DDoS-only to offering residential proxy services, using compromised devices as proxy nodes.

---

## Infrastructure Distribution

### Geographic Distribution

```
United States:     4 proxy relays
United Kingdom:    1 proxy relay
Czech Republic:    1 proxy relay
France:            4 GRE tunnel C2s (likely based on 151.242.x.x range)
Russia:            1 domain (.ru)
Soviet Union (legacy): 5 domains (.su TLD)
Taiwan:            1 domain (.tw)
```

### ASN Distribution

```
AS7922 (Comcast):         2 IPs
AS206509 (KCOM):          1 IP
AS36352 (ColoCrossing):   1 IP
AS46339 (CSDVRS):         1 IP
AS62160 (Yes Networks):   1 IP
```

---

## Technical Analysis

### Malware Characteristics

**Version Progression:**
- **Version 1 (March 2025):** ECDH-P256 key exchange, ChaCha20 encryption
- **Version 2 (April 2025+):** Streamlined protocol, modified RC4, modified xxhash

**Key Technical Features:**

1. **Anti-Analysis:**
   - Environment detection (tcpdump, wireshark, tshark, dumpcap)
   - VM detection (VMware, VirtualBox, KVM, QEMU, Microsoft)
   - Process hiding techniques

2. **Encryption:**
   - Modified RC4 with key `PJbiNbbeasddDfsc` (possible Fodcha botnet reference)
   - XOR-based DNS TXT decoding
   - Custom message integrity verification (modified xxhash)

3. **Network Protocol:**
   - Message types: 0-10 (C2 commands), 101 (telnet scan), 201-202 (reports)
   - Support for: DDoS attacks, remote shell, proxy functionality, command execution
   - Speed test feature using Speedtest service (identifies high-bandwidth bots)

4. **Competition/Persistence:**
   - Killer evasion (OOM score manipulation)
   - Shared library mapping to avoid detection
   - Process renaming to common daemon names
   - Active competition with Rapperbot over nvms9000 devices

### Attack Capabilities

**Supported Commands (Message Types):**
- `0-2`: Key exchange and authentication
- `3`: Bot login/registration
- `4`: Heartbeat/keep-alive
- `5`: Exit command
- `6`: **DDoS attack** (primary function)
- `7`: Execute arbitrary commands
- `8`: Update C2 server
- `9`: Reverse shell
- `10`: **Proxy mode** (residential proxy service)
- `101`: Report telnet scan results
- `201-202`: Status reports

---

## Exploitation Vectors

AISURU spreads via multiple vulnerabilities (0-day and N-day):

| CVE/ID | Vendor | Affected Devices | Year |
|--------|--------|------------------|------|
| **CNPILOT-0DAY-RCE** | Cambium Networks | cnPilot routers | **0-DAY** (June 2024) |
| CVE-2024-3721 | TBK | DVR | 2024 |
| CVE-2023-50381 | Realtek | rtl819x Jungle SDK v3.4.11 | 2023 |
| CVE-2023-28771 | Zyxel | ATP/USG FLEX/VPN/ZyWALL | 2023 |
| CVE-2022-44149 | Nexxt | Routers | 2022 |
| CVE-2022-35733 | UNIMO | DVR | 2022 |
| CVE-2017-5259 | Cambium Networks | cnPilot R190V | 2017 |
| CVE-2013-5948 | T-Mobile | TM-AC1900 | 2013 |
| CVE-2013-3307 | Linksys | X3000 | 2013 |
| CVE-2013-1599 | D-Link | DCS-3411 | 2013 |
| AMTK-CAMERA-CMD-RCE | A-MTK | Cameras | N/A |
| LILIN-DVR-RCE | LILIN | DVR | N/A |
| SANHUI-GATEWAY-DEBUG-PHP-RCE | Sanhui | Gateway Management | N/A |
| TVT-OEM-API-RCE | Shenzhen TVT | DVR | N/A |

**Primary Infection (April 2025):**
- **Vector:** Compromised Totolink firmware update server
- **Method:** Modified firmware download URL to serve malicious script `t.sh`
- **Impact:** 100k → 300k devices in ~1 month

---

## Attack History

### Notable Incidents

| Date | Target | Traffic Volume | Notes |
|------|--------|----------------|-------|
| **September 2025** | 185.211.78.117 | **11.5 Tbps** | World record DDoS attack at the time |
| May 2025 | krebsonsecurity.com | Unknown | Attack on security journalist Brian Krebs |
| Various 2025 | Multiple ISPs | Various | "For fun" attacks, contributed to bad reputation |

**Cloudflare Incident:**
- Attack mitigated by Cloudflare
- Confirmed source: 340k Totolink routers (per leaked intel)
- Public exposure led to increased law enforcement attention

---

## Threat Intelligence

### Group Behavior

**Provocative Actions:**
- Mocking Rapperbot author "Ethan J Foltz" (arrested 2025-08-06)
- Public taunting of competitors and security researchers
- "Easter egg" messages in samples with ideological content
- "RIP TOTOLINK 2025-2025" message after patching

**Sample Messages:**
- "I don't feel right as myself, with my failing mental health"
- "tHiS mOnTh At qiAnXin shitlab a NeW aisurU vErSiOn hIt oUr bOtMoN sYsTeM dOiNg tHe CHAaCha sLiDe"

### Community Response

- Multiple "enemies" in DDoS community
- Social media leaks exposing botnet panel (300k+ bots screenshot)
- Tags to Totolink and Interpol to attract law enforcement
- Reputation as "mentally unstable" due to destructive behavior

---

## IoC Summary

### Domains
```
coerece.ilovegaysex.su
approach.ilovegaysex.su
ministry.ilovegaysex.su
lane.ilovegaysex.su
a.6mv1eyr328y6due83u3js6whtzuxfyhw.ru
u.ilovegaysex.su
updatetoto.tw
```

### IP Addresses
```
# GRE Tunnel C2
151.242.2.22
151.242.2.23
151.242.2.24
151.242.2.25

# Proxy Relay C2
194.46.59.169
104.171.170.241
104.171.170.253
107.173.196.189
64.188.68.193
78.108.178.100

# Attack Targets (for correlation)
185.211.78.117
```

### Cryptographic Indicators
```
RC4 Key: PJbiNbbeasddDfsc
Message Format: Modified xxhash + Modified RC4
DNS Encoding: base64 + XOR (Version 2)
Previous Encoding: base64 + ChaCha20 (Version 1)
```

### Process Names (Hiding)
```
telnetd
udhcpc
inetd
ntpclient
watchdog
klogd
upnpd
dhclient
```

### Binary Artifacts
```
Renamed to: libcow.so (evasion technique)
Search paths: /lib/*.so (for library mapping)
```

---

## Detection & Mitigation

### Network-Based Detection

1. **DNS Monitoring:**
   - Monitor for `.ilovegaysex.su` domain queries
   - Detect base64-encoded TXT record lookups
   - Alert on `updatetoto.tw` queries (known malicious)

2. **Traffic Analysis:**
   - GRE tunnel traffic to 151.242.2.22-25
   - Suspicious connections to proxy relay IPs
   - High-volume UDP/TCP floods from IoT devices

3. **Behavioral:**
   - Speedtest API calls from IoT devices
   - Connections to Speedtest servers from routers/DVRs
   - Unusual proxy traffic patterns

### Host-Based Detection

1. **Process Monitoring:**
   - Processes named `libcow.so`
   - Common daemon names with unusual behavior
   - Memory-mapped shared libraries in unusual contexts

2. **File System:**
   - Check for deleted binaries still running
   - OOM score of `-1000` on suspicious processes
   - Unexpected `.so` files in non-standard locations

3. **Binary Analysis:**
   - Strings containing "PJbiNbbeasddDfsc"
   - Modified RC4/xxhash implementations
   - VM/debugger detection code

### Firmware/Device Protection

**High-Risk Devices:**
- Totolink routers (any model with auto-update)
- Cambium Networks cnPilot routers
- Zyxel ATP/USG FLEX/VPN series
- Various DVR systems (LILIN, TVT, TBK, UNIMO)

**Recommendations:**
1. Disable automatic firmware updates
2. Manually verify firmware integrity before updates
3. Segment IoT devices from critical networks
4. Monitor for unexpected outbound connections
5. Apply all available security patches

---

## YARA Rule (Generated)

```yara
rule AISURU_Botnet_Sample {
    meta:
        description = "Detects AISURU botnet samples"
        author = "C2 Enumeration Toolkit v2.6"
        date = "2025-11-17"
        reference = "XLab AISURU Threat Report"

    strings:
        $rc4_key = "PJbiNbbeasddDfsc" ascii
        $domain1 = "ilovegaysex.su" ascii
        $domain2 = "updatetoto.tw" ascii

        $process1 = "telnetd" ascii
        $process2 = "udhcpc" ascii
        $process3 = "libcow.so" ascii

        $vm_check1 = "VMware" ascii
        $vm_check2 = "VirtualBox" ascii
        $vm_check3 = "QEMU" ascii

        $tool_check1 = "tcpdump" ascii
        $tool_check2 = "wireshark" ascii
        $tool_check3 = "tshark" ascii

        $speedtest = "speedtest-servers-static.php" ascii
        $oom = "/proc/self/oom_score_adj" ascii

    condition:
        uint32(0) == 0x464c457f and // ELF header
        (
            $rc4_key or
            any of ($domain*) or
            (3 of ($process*)) or
            (2 of ($vm_check*) and 2 of ($tool_check*)) or
            ($speedtest and $oom)
        )
}
```

---

## Suricata Rules (Generated)

```
# AISURU C2 Communication
alert dns any any -> any any (msg:"AISURU C2 DNS Query Detected"; dns_query; content:"ilovegaysex.su"; nocase; classtype:trojan-activity; sid:1000001; rev:1;)
alert dns any any -> any any (msg:"AISURU Malicious Update Server"; dns_query; content:"updatetoto.tw"; nocase; classtype:trojan-activity; sid:1000002; rev:1;)
alert dns any any -> any any (msg:"AISURU C2 Obfuscated Domain"; dns_query; content:"6mv1eyr328y6due83u3js6whtzuxfyhw.ru"; nocase; classtype:trojan-activity; sid:1000003; rev:1;)

# AISURU C2 IP Communication
alert ip any any -> 151.242.2.22 any (msg:"AISURU GRE Tunnel C2 Contact"; classtype:trojan-activity; sid:1000004; rev:1;)
alert ip any any -> 151.242.2.23 any (msg:"AISURU GRE Tunnel C2 Contact"; classtype:trojan-activity; sid:1000005; rev:1;)
alert ip any any -> 151.242.2.24 any (msg:"AISURU GRE Tunnel C2 Contact"; classtype:trojan-activity; sid:1000006; rev:1;)
alert ip any any -> 151.242.2.25 any (msg:"AISURU GRE Tunnel C2 Contact"; classtype:trojan-activity; sid:1000007; rev:1;)

# AISURU Proxy Infrastructure
alert ip any any -> [194.46.59.169,104.171.170.241,104.171.170.253,107.173.196.189,64.188.68.193,78.108.178.100] any (msg:"AISURU Proxy Relay Contact"; classtype:trojan-activity; sid:1000008; rev:1;)

# AISURU Behavioral Detection
alert http any any -> any any (msg:"AISURU Speedtest Bandwidth Check"; content:"speedtest"; http_uri; classtype:trojan-activity; sid:1000009; rev:1;)
```

---

## Recommendations for Law Enforcement / Defense

### Immediate Actions

1. **Sinkhole Domains:**
   - Coordinate with .su, .ru, .tw registries
   - Implement DNS sinkholing for known C2 domains
   - Monitor sinkhole traffic for bot census

2. **IP Takedowns:**
   - Contact hosting providers for 151.242.2.x range
   - Coordinate with ASN operators for proxy relay IPs
   - Preserve evidence before takedown

3. **Victim Notification:**
   - Identify compromised devices via ISP cooperation
   - Notify owners of Totolink routers
   - Provide remediation guidance

### Long-Term Actions

1. **Attribution:**
   - Investigate identities of Snow, Tom, and Forky
   - Analyze payment trails from DDoS-for-hire services
   - Track proxy service monetization

2. **Infrastructure Mapping:**
   - Continue monitoring for new C2 domains
   - Track botnet size and evolution
   - Identify backup C2 infrastructure

3. **Vendor Cooperation:**
   - Work with Totolink on update server security
   - Coordinate 0-day disclosure for cnPilot vulnerability
   - Improve IoT device security standards

---

## Conclusion

The AISURU botnet represents a significant threat to internet infrastructure, with demonstrated capability to generate record-breaking DDoS attacks. The compromise of the Totolink firmware update server in April 2025 highlights the risks of supply chain attacks against IoT devices.

**Current Status (as of 2025-11-17):**
- Botnet remains partially operational (~300k devices)
- updatetoto.tw taken down/sinkholed
- C2 infrastructure likely evolved since report publication
- Group continues operations despite public exposure

**Priority Recommendations:**
1. Immediate sinkholing of identified C2 domains
2. Takedown of GRE tunnel infrastructure (151.242.2.x)
3. Law enforcement investigation of threat actors
4. Coordinated disclosure of cnPilot 0-day to Cambium Networks

---

**Report Classification:** DEFENSIVE SECURITY RESEARCH
**Distribution:** Authorized security professionals, law enforcement, affected vendors
**Contact:** For additional intelligence or coordination, refer to XLab's original report

**DISCLAIMER:** This report is provided for defensive security research purposes only. Unauthorized access to computer systems is illegal. All information is derived from publicly available threat intelligence sources.

---

*Generated by C2 Enumeration Toolkit v2.6*
*Source: XLab AISURU Botnet Threat Intelligence Report*
*Analysis Date: 2025-11-17*
