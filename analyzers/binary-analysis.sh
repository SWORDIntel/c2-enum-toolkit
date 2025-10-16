#!/usr/bin/env bash
# Advanced Binary Analysis Module
# Entropy analysis, packer detection, crypto constants, anti-debug detection
set -euo pipefail

BINARY="$1"
OUTDIR="${2:-.}"

[[ ! -f "$BINARY" ]] && { echo "Error: Binary not found: $BINARY"; exit 1; }

mkdir -p "$OUTDIR"
REPORT="$OUTDIR/advanced_binary_analysis.txt"

log() { echo "[$(date -u +'%Y-%m-%dT%H:%M:%SZ')] $*"; }

log "Starting advanced binary analysis: $BINARY"

{
cat <<EOF
═══════════════════════════════════════════════════════════════════
ADVANCED BINARY ANALYSIS REPORT
═══════════════════════════════════════════════════════════════════
Binary: $(basename "$BINARY")
Full Path: $BINARY
Timestamp: $(date -u +'%Y-%m-%dT%H:%M:%SZ')
Size: $(stat -f%z "$BINARY" 2>/dev/null || stat -c%s "$BINARY" 2>/dev/null) bytes
═══════════════════════════════════════════════════════════════════

EOF

# ========== 1. ENTROPY ANALYSIS ==========
echo "───────────────────────────────────────────────────────────────────"
echo "1. ENTROPY ANALYSIS (Packing/Encryption Detection)"
echo "───────────────────────────────────────────────────────────────────"
echo ""

if command -v ent >/dev/null 2>&1; then
    echo "[*] Using 'ent' for entropy calculation:"
    ent "$BINARY" 2>/dev/null || echo "  (entropy calculation failed)"
else
    echo "[*] Calculating Shannon entropy (Python alternative):"
    python3 -c "
import sys, math
from collections import Counter

with open('$BINARY', 'rb') as f:
    data = f.read()

if len(data) == 0:
    print('  Empty file')
    sys.exit(0)

counter = Counter(data)
length = len(data)
entropy = -sum((count/length) * math.log2(count/length) for count in counter.values())

print(f'  Entropy: {entropy:.4f} bits per byte')
print(f'  File size: {length} bytes')
print(f'  Unique bytes: {len(counter)} / 256')
print()

if entropy > 7.5:
    print('  ⚠️  HIGH ENTROPY (>7.5) - Likely packed/encrypted!')
elif entropy > 6.5:
    print('  ⚠️  MEDIUM-HIGH ENTROPY (6.5-7.5) - Possibly compressed')
elif entropy > 5.5:
    print('  ✓ NORMAL ENTROPY (5.5-6.5) - Typical compiled code')
else:
    print('  ℹ️  LOW ENTROPY (<5.5) - Sparse data or padding')
" 2>/dev/null || echo "  (Python not available for entropy calc)"
fi

echo ""

# ========== 2. PACKER DETECTION ==========
echo "───────────────────────────────────────────────────────────────────"
echo "2. PACKER/OBFUSCATOR DETECTION"
echo "───────────────────────────────────────────────────────────────────"
echo ""

# Check for common packer signatures
echo "[*] Checking for known packers:"

if command -v strings >/dev/null 2>&1; then
    strings "$BINARY" 2>/dev/null | grep -iE "UPX|upx|ASPack|PECompact|Themida|VMProtect|Enigma|Armadillo" | head -5 | sed 's/^/  → /' || echo "  (no obvious packer signatures)"
fi

echo ""
echo "[*] Section analysis (unusual characteristics):"

if command -v readelf >/dev/null 2>&1; then
    # High entropy sections suggest packing
    readelf -S "$BINARY" 2>/dev/null | awk '
    /\[.*\]/ {
        if ($2 ~ /\.text/ || $2 ~ /\.data/ || $2 ~ /\.rodata/) {
            size = strtonum("0x" $6)
            if (size > 100000) {
                print "  → Large section: " $2 " (" size " bytes)"
            }
        }
        if ($2 ~ /UPX|upx|packed/) {
            print "  ⚠️  Suspicious section name: " $2
        }
    }' || echo "  (readelf failed)"

    # Check for unusual section names
    echo ""
    echo "[*] Unusual section names:"
    readelf -S "$BINARY" 2>/dev/null | grep -vE "\.text|\.data|\.rodata|\.bss|\.init|\.fini|\.plt|\.got|\.dynamic|\.shstrtab|\.symtab|\.strtab|NULL" | grep "\[" | head -10 | sed 's/^/  → /' || echo "  (none detected)"
fi

echo ""

# ========== 3. CRYPTO CONSTANTS ==========
echo "───────────────────────────────────────────────────────────────────"
echo "3. CRYPTOGRAPHIC CONSTANTS DETECTION"
echo "───────────────────────────────────────────────────────────────────"
echo ""

echo "[*] Searching for crypto algorithm constants:"

if command -v strings >/dev/null 2>&1 && command -v xxd >/dev/null 2>&1; then
    # Common crypto constants (hex patterns)
    xxd -p "$BINARY" 2>/dev/null | tr -d '\n' | grep -oE "(67452301|efcdab89|98badcfe|10325476|c3d2e1f0)" | head -5 | while read -r const; do
        echo "  ⚠️  MD5/SHA1 constant detected: 0x$const"
    done || echo "  (no MD5/SHA1 constants)"

    # AES S-box constants
    xxd -p "$BINARY" 2>/dev/null | tr -d '\n' | grep -oE "637c777bf26b6fc5" | head -1 | while read -r const; do
        echo "  ⚠️  AES S-box constant detected: 0x$const"
    done || true

    # RSA/Crypto library strings
    strings "$BINARY" 2>/dev/null | grep -iE "openssl|libcrypto|mbedtls|polarssl|boringssl|cryptography|AES|RSA|SHA256|SHA512" | sort -u | head -10 | sed 's/^/  → /' || echo "  (no crypto library strings)"
fi

echo ""

# ========== 4. ANTI-DEBUGGING TECHNIQUES ==========
echo "───────────────────────────────────────────────────────────────────"
echo "4. ANTI-DEBUGGING / ANTI-ANALYSIS DETECTION"
echo "───────────────────────────────────────────────────────────────────"
echo ""

echo "[*] Checking for anti-debug techniques:"

if command -v strings >/dev/null 2>&1; then
    # Common anti-debug strings
    strings "$BINARY" 2>/dev/null | grep -iE "ptrace|IsDebuggerPresent|CheckRemoteDebugger|NtQueryInformation|OutputDebugString|/proc/self/status|TracerPid" | head -10 | sed 's/^/  ⚠️  /' || echo "  (no obvious anti-debug strings)"
fi

echo ""
echo "[*] Checking for VM/sandbox detection:"

if command -v strings >/dev/null 2>&1; then
    strings "$BINARY" 2>/dev/null | grep -iE "VirtualBox|VMware|QEMU|Xen|vbox|vmtoolsd|Sandboxie|Cuckoo|wine" | head -10 | sed 's/^/  ⚠️  /' || echo "  (no VM detection strings)"
fi

echo ""

# ========== 5. IMPORT/EXPORT ANALYSIS ==========
echo "───────────────────────────────────────────────────────────────────"
echo "5. IMPORT/EXPORT TABLE ANALYSIS"
echo "───────────────────────────────────────────────────────────────────"
echo ""

if command -v readelf >/dev/null 2>&1; then
    echo "[*] Dynamic symbol imports (top 30):"
    readelf -s "$BINARY" 2>/dev/null | grep -E "UND|FUNC" | awk '{print $8}' | grep -v "^$" | sort -u | head -30 | sed 's/^/  → /' || echo "  (no symbols)"

    echo ""
    echo "[*] Suspicious/dangerous functions:"
    readelf -s "$BINARY" 2>/dev/null | grep -E "UND|FUNC" | grep -iE "system|exec|popen|fork|socket|connect|bind|listen|accept|send|recv" | awk '{print $8}' | sort -u | sed 's/^/  ⚠️  /' || echo "  (none detected)"
fi

echo ""

# ========== 6. STRING ANALYSIS WITH CONTEXT ==========
echo "───────────────────────────────────────────────────────────────────"
echo "6. INTELLIGENT STRING ANALYSIS"
echo "───────────────────────────────────────────────────────────────────"
echo ""

if command -v strings >/dev/null 2>&1; then
    echo "[*] URLs and endpoints:"
    strings "$BINARY" 2>/dev/null | grep -E "^https?://|^wss?://|\.onion" | sort -u | head -20 | sed 's/^/  → /' || echo "  (none found)"

    echo ""
    echo "[*] IP addresses:"
    strings "$BINARY" 2>/dev/null | grep -oE "\b([0-9]{1,3}\.){3}[0-9]{1,3}\b" | sort -u | head -20 | sed 's/^/  → /' || echo "  (none found)"

    echo ""
    echo "[*] File paths:"
    strings "$BINARY" 2>/dev/null | grep -E "^/[a-z]|^C:\\\\" | sort -u | head -20 | sed 's/^/  → /' || echo "  (none found)"

    echo ""
    echo "[*] Credentials/API keys patterns:"
    strings "$BINARY" 2>/dev/null | grep -iE "password|passwd|api.?key|token|secret|bearer|jwt|credential" | head -10 | sed 's/^/  ⚠️  /' || echo "  (none found)"

    echo ""
    echo "[*] C2 indicators:"
    strings "$BINARY" 2>/dev/null | grep -iE "beacon|checkin|command|task|payload|implant|agent|callback|c2|cnc" | sort -u | head -15 | sed 's/^/  ⚠️  /' || echo "  (none found)"
fi

echo ""

# ========== 7. CODE SIGNING & CERTIFICATES ==========
echo "───────────────────────────────────────────────────────────────────"
echo "7. CODE SIGNING VERIFICATION"
echo "───────────────────────────────────────────────────────────────────"
echo ""

# Linux: check for signatures (rare but possible)
if command -v readelf >/dev/null 2>&1; then
    echo "[*] Checking for embedded certificates/signatures:"
    readelf -p .note.gnu.build-id "$BINARY" 2>/dev/null | sed 's/^/  → /' || echo "  (no build ID)"

    strings "$BINARY" 2>/dev/null | grep -E "BEGIN CERTIFICATE|BEGIN RSA|BEGIN PUBLIC KEY" | head -5 | sed 's/^/  ⚠️  /' || echo "  (no embedded certificates)"
fi

echo ""

# ========== 8. BUILD METADATA ==========
echo "───────────────────────────────────────────────────────────────────"
echo "8. BUILD METADATA & COMPILER FINGERPRINTING"
echo "───────────────────────────────────────────────────────────────────"
echo ""

if command -v strings >/dev/null 2>&1; then
    echo "[*] Compiler/toolchain information:"
    strings "$BINARY" 2>/dev/null | grep -iE "gcc|clang|go build|rustc|g\+\+|visual studio|msvc" | head -10 | sed 's/^/  → /' || echo "  (none detected)"

    echo ""
    echo "[*] Go build information:"
    strings "$BINARY" 2>/dev/null | grep -E "go1\.[0-9]|Go build ID" | head -10 | sed 's/^/  → /' || echo "  (not a Go binary)"

    echo ""
    echo "[*] Rust metadata:"
    strings "$BINARY" 2>/dev/null | grep -E "rustc|cargo|\.rs|/rustc/" | head -10 | sed 's/^/  → /' || echo "  (not a Rust binary)"

    echo ""
    echo "[*] Build paths (may reveal dev environment):"
    strings "$BINARY" 2>/dev/null | grep -E "/home/|/Users/|C:\\\\Users|/tmp/|/var/tmp" | head -15 | sed 's/^/  ℹ️  /' || echo "  (none found)"
fi

echo ""

# ========== 9. SECTION HASHING ==========
echo "───────────────────────────────────────────────────────────────────"
echo "9. SECTION-LEVEL HASHING (for correlation)"
echo "───────────────────────────────────────────────────────────────────"
echo ""

if command -v readelf >/dev/null 2>&1 && command -v sha256sum >/dev/null 2>&1; then
    echo "[*] Section hashes (for variant detection):"

    for section in .text .rodata .data .bss; do
        hash=$(readelf -x "$section" "$BINARY" 2>/dev/null | sha256sum 2>/dev/null | awk '{print $1}')
        if [[ -n "$hash" ]]; then
            echo "  $section: $hash"
        fi
    done || echo "  (section extraction failed)"
fi

echo ""

# ========== 10. YARA SIGNATURE GENERATION ==========
echo "───────────────────────────────────────────────────────────────────"
echo "10. AUTO-GENERATED YARA SIGNATURE"
echo "───────────────────────────────────────────────────────────────────"
echo ""

if command -v strings >/dev/null 2>&1; then
    echo "rule detected_c2_binary_$(basename "$BINARY" | tr '.-' '_') {"
    echo "  meta:"
    echo "    description = \"Auto-generated from $(basename "$BINARY")\""
    echo "    date = \"$(date -u +'%Y-%m-%d')\""
    echo "    hash = \"$(sha256sum "$BINARY" 2>/dev/null | awk '{print $1}')\""
    echo ""
    echo "  strings:"

    # Extract unique strings for signatures
    strings "$BINARY" 2>/dev/null | grep -E "^[A-Za-z0-9/_.-]{10,60}$" | sort -u | head -15 | nl -w1 -s' ' | while read -r n str; do
        escaped=$(echo "$str" | sed 's/\\/\\\\/g; s/"/\\"/g')
        echo "    \$s${n} = \"${escaped}\" ascii"
    done

    echo ""
    echo "  condition:"
    echo "    uint32(0) == 0x464c457f and  // ELF magic"
    echo "    3 of (\$s*)"
    echo "}"
fi

echo ""

# ========== 11. THREAT ASSESSMENT ==========
echo "───────────────────────────────────────────────────────────────────"
echo "11. AUTOMATED THREAT ASSESSMENT"
echo "───────────────────────────────────────────────────────────────────"
echo ""

THREAT_SCORE=0
INDICATORS=()

# High entropy
if command -v python3 >/dev/null 2>&1; then
    ENTROPY=$(python3 -c "
import sys, math
from collections import Counter
try:
    with open('$BINARY', 'rb') as f:
        data = f.read()
    counter = Counter(data)
    entropy = -sum((c/len(data)) * math.log2(c/len(data)) for c in counter.values())
    print(f'{entropy:.2f}')
except: print('0')
" 2>/dev/null)

    if (( $(echo "$ENTROPY > 7.5" | bc -l 2>/dev/null || echo 0) )); then
        ((THREAT_SCORE+=30))
        INDICATORS+=("High entropy ($ENTROPY) - likely packed")
    fi
fi

# Anti-debug strings
if strings "$BINARY" 2>/dev/null | grep -qiE "ptrace|IsDebuggerPresent"; then
    ((THREAT_SCORE+=20))
    INDICATORS+=("Anti-debugging techniques detected")
fi

# Crypto constants
if xxd -p "$BINARY" 2>/dev/null | tr -d '\n' | grep -qE "67452301|efcdab89"; then
    ((THREAT_SCORE+=15))
    INDICATORS+=("Crypto constants found (MD5/SHA)")
fi

# Suspicious imports
if readelf -s "$BINARY" 2>/dev/null | grep -qiE "socket|connect|send|recv"; then
    ((THREAT_SCORE+=25))
    INDICATORS+=("Network socket functions present")
fi

# Credential strings
if strings "$BINARY" 2>/dev/null | grep -qiE "password|api.?key|token"; then
    ((THREAT_SCORE+=10))
    INDICATORS+=("Credential-related strings found")
fi

echo "Threat Score: $THREAT_SCORE / 100"
echo ""

if [[ $THREAT_SCORE -ge 60 ]]; then
    echo "⚠️  HIGH THREAT - Multiple suspicious indicators"
elif [[ $THREAT_SCORE -ge 30 ]]; then
    echo "⚠️  MEDIUM THREAT - Some suspicious indicators"
else
    echo "✓ LOW THREAT - Few concerning indicators"
fi

echo ""
echo "Indicators detected:"
for ind in "${INDICATORS[@]}"; do
    echo "  • $ind"
done

[[ ${#INDICATORS[@]} -eq 0 ]] && echo "  (none)"

echo ""

# ========== 12. IMPHASH (Import Hash) ==========
echo "───────────────────────────────────────────────────────────────────"
echo "12. IMPORT HASH (for correlation)"
echo "───────────────────────────────────────────────────────────────────"
echo ""

if command -v readelf >/dev/null 2>&1 && command -v md5sum >/dev/null 2>&1; then
    echo "[*] Generating import hash (imphash equivalent):"
    IMPHASH=$(readelf -s "$BINARY" 2>/dev/null | grep -E "UND.*FUNC" | awk '{print $8}' | sort | tr '\n' ',' | md5sum | awk '{print $1}')
    echo "  Import Hash: $IMPHASH"
    echo "  (Use for correlation with other samples)"
fi

echo ""

# ========== SUMMARY ==========
echo "═══════════════════════════════════════════════════════════════════"
echo "ANALYSIS COMPLETE"
echo "═══════════════════════════════════════════════════════════════════"
echo ""
echo "Report saved to: $REPORT"

} | tee "$REPORT"

log "Advanced binary analysis complete: $REPORT"
echo ""
echo "To view: less $REPORT"
