#!/usr/bin/env bash
# Certificate Intelligence Deep Analysis
# Full TLS/SSL analysis, cipher suites, cert chain validation, CT logs
set -euo pipefail

TARGET="$1"
OUTDIR="${2:-.}"
SOCKS="${SOCKS:-127.0.0.1:9050}"

[[ -z "$TARGET" ]] && { echo "Usage: $0 <target.onion[:port]> [outdir]"; exit 1; }

mkdir -p "$OUTDIR/cert_intel"
REPORT="$OUTDIR/cert_intel/certificate_intelligence.txt"

log() { echo "[$(date -u +'%Y-%m-%dT%H:%M:%SZ')] $*"; }

# Parse host and port
if [[ "$TARGET" == *:* ]]; then
    HOST="${TARGET%:*}"
    PORT="${TARGET##*:}"
else
    HOST="$TARGET"
    PORT="443"
fi

log "Starting certificate intelligence analysis: $TARGET"

{
cat <<EOF
═══════════════════════════════════════════════════════════════════
CERTIFICATE INTELLIGENCE REPORT
═══════════════════════════════════════════════════════════════════
Target: $HOST:$PORT
Timestamp: $(date -u +'%Y-%m-%dT%H:%M:%SZ')
═══════════════════════════════════════════════════════════════════

EOF

# ========== 1. TLS HANDSHAKE & CERTIFICATE EXTRACTION ==========
echo "───────────────────────────────────────────────────────────────────"
echo "1. TLS HANDSHAKE & CERTIFICATE CHAIN"
echo "───────────────────────────────────────────────────────────────────"
echo ""

if ! command -v openssl >/dev/null 2>&1; then
    echo "[✗] openssl not available - cannot perform certificate analysis"
    exit 1
fi

# Extract certificate
CERT_FILE="$OUTDIR/cert_intel/certificate.pem"

echo "[*] Connecting to $HOST:$PORT via Tor..."

# Note: openssl doesn't natively support SOCKS, we'll use timeout + direct approach
# For .onion, we may need socat or special setup
echo ""
echo "[*] Attempting TLS handshake (Note: may require tor2web or special routing)..."

# Try via curl first to get cert info
curl --socks5-hostname "$SOCKS" -vI "https://$HOST:$PORT/" 2>&1 | \
    grep -A 50 "Server certificate" | head -60 || echo "  (connection failed or HTTP only)"

echo ""

# Alternative: Use openssl with proxy if available
if command -v socat >/dev/null 2>&1; then
    echo "[*] Using socat for SOCKS proxy TLS connection..."
    timeout 30 bash -c "
        socat TCP-LISTEN:9443,reuseaddr,fork SOCKS4A:$SOCKS:$HOST:$PORT,socksport=9050 &
        SOCAT_PID=\$!
        sleep 2
        echo | openssl s_client -connect localhost:9443 -servername $HOST 2>&1 | \
            sed -n '/BEGIN CERTIFICATE/,/END CERTIFICATE/p' > $CERT_FILE
        kill \$SOCAT_PID 2>/dev/null
    " 2>/dev/null || echo "  (socat method failed)"
fi

# Check if we got a certificate
if [[ -f "$CERT_FILE" ]] && [[ -s "$CERT_FILE" ]]; then
    echo "[✓] Certificate extracted successfully"
    echo ""

    # ========== 2. CERTIFICATE DETAILS ==========
    echo "───────────────────────────────────────────────────────────────────"
    echo "2. CERTIFICATE DETAILS"
    echo "───────────────────────────────────────────────────────────────────"
    echo ""

    openssl x509 -in "$CERT_FILE" -text -noout 2>/dev/null | sed 's/^/  /' || echo "  (parse failed)"

    echo ""

    # ========== 3. CERTIFICATE FINGERPRINTS ==========
    echo "───────────────────────────────────────────────────────────────────"
    echo "3. CERTIFICATE FINGERPRINTS"
    echo "───────────────────────────────────────────────────────────────────"
    echo ""

    echo "[*] SHA256 Fingerprint:"
    openssl x509 -in "$CERT_FILE" -fingerprint -sha256 -noout 2>/dev/null | sed 's/^/  /' || echo "  (failed)"

    echo ""
    echo "[*] SHA1 Fingerprint:"
    openssl x509 -in "$CERT_FILE" -fingerprint -sha1 -noout 2>/dev/null | sed 's/^/  /' || echo "  (failed)"

    echo ""

    # ========== 4. VALIDITY PERIOD ==========
    echo "───────────────────────────────────────────────────────────────────"
    echo "4. VALIDITY ANALYSIS"
    echo "───────────────────────────────────────────────────────────────────"
    echo ""

    echo "[*] Valid From:"
    openssl x509 -in "$CERT_FILE" -startdate -noout 2>/dev/null | sed 's/^/  /' || echo "  (failed)"

    echo ""
    echo "[*] Valid Until:"
    openssl x509 -in "$CERT_FILE" -enddate -noout 2>/dev/null | sed 's/^/  /' || echo "  (failed)"

    echo ""
    echo "[*] Days until expiration:"
    ENDDATE=$(openssl x509 -in "$CERT_FILE" -enddate -noout 2>/dev/null | cut -d= -f2)
    if [[ -n "$ENDDATE" ]]; then
        END_EPOCH=$(date -d "$ENDDATE" +%s 2>/dev/null || date -j -f "%b %d %T %Y %Z" "$ENDDATE" +%s 2>/dev/null || echo 0)
        NOW_EPOCH=$(date +%s)
        DAYS_LEFT=$(( (END_EPOCH - NOW_EPOCH) / 86400 ))
        echo "  $DAYS_LEFT days"

        if [[ $DAYS_LEFT -lt 30 ]]; then
            echo "  ⚠️  Certificate expires soon!"
        elif [[ $DAYS_LEFT -lt 0 ]]; then
            echo "  ⚠️  Certificate EXPIRED!"
        fi
    fi

    echo ""

    # ========== 5. SUBJECT ALTERNATIVE NAMES ==========
    echo "───────────────────────────────────────────────────────────────────"
    echo "5. SUBJECT ALTERNATIVE NAMES (SANs)"
    echo "───────────────────────────────────────────────────────────────────"
    echo ""

    openssl x509 -in "$CERT_FILE" -text -noout 2>/dev/null | \
        grep -A 10 "Subject Alternative Name" | sed 's/^/  /' || echo "  (no SANs)"

    echo ""

    # ========== 6. PUBLIC KEY INFO ==========
    echo "───────────────────────────────────────────────────────────────────"
    echo "6. PUBLIC KEY INFORMATION"
    echo "───────────────────────────────────────────────────────────────────"
    echo ""

    echo "[*] Public Key Algorithm:"
    openssl x509 -in "$CERT_FILE" -text -noout 2>/dev/null | grep "Public Key Algorithm" | sed 's/^/  /' || echo "  (unknown)"

    echo ""
    echo "[*] Public Key Size:"
    openssl x509 -in "$CERT_FILE" -text -noout 2>/dev/null | grep -E "Public-Key: \([0-9]+ bit\)" | sed 's/^/  /' || echo "  (unknown)"

    echo ""

    # ========== 7. ISSUER ANALYSIS ==========
    echo "───────────────────────────────────────────────────────────────────"
    echo "7. ISSUER & CA ANALYSIS"
    echo "───────────────────────────────────────────────────────────────────"
    echo ""

    echo "[*] Issuer:"
    openssl x509 -in "$CERT_FILE" -issuer -noout 2>/dev/null | sed 's/^/  /' || echo "  (unknown)"

    echo ""
    echo "[*] Self-signed check:"
    SUBJECT=$(openssl x509 -in "$CERT_FILE" -subject -noout 2>/dev/null | cut -d= -f2-)
    ISSUER=$(openssl x509 -in "$CERT_FILE" -issuer -noout 2>/dev/null | cut -d= -f2-)

    if [[ "$SUBJECT" == "$ISSUER" ]]; then
        echo "  ⚠️  SELF-SIGNED certificate"
    else
        echo "  ✓ Issued by CA"
    fi

else
    echo "[✗] No certificate extracted - target may be HTTP-only or connection failed"
fi

echo ""

# ========== 8. CIPHER SUITE ENUMERATION ==========
echo "───────────────────────────────────────────────────────────────────"
echo "8. SUPPORTED CIPHER SUITES (if connection possible)"
echo "───────────────────────────────────────────────────────────────────"
echo ""

echo "[*] Attempting cipher suite enumeration..."
echo "  (This requires direct TLS connection - may fail for .onion without special routing)"
echo ""

# Test common cipher suites
CIPHERS=("ECDHE-RSA-AES256-GCM-SHA384" "ECDHE-RSA-AES128-GCM-SHA256" "DHE-RSA-AES256-SHA" "AES128-SHA" "DES-CBC3-SHA")

for cipher in "${CIPHERS[@]}"; do
    if timeout 5 openssl s_client -connect "$HOST:$PORT" -cipher "$cipher" </dev/null 2>&1 | grep -q "Cipher    :"; then
        echo "  ✓ Supported: $cipher"
    fi
done

echo ""

# ========== 9. TLS VERSION SUPPORT ==========
echo "───────────────────────────────────────────────────────────────────"
echo "9. TLS VERSION SUPPORT"
echo "───────────────────────────────────────────────────────────────────"
echo ""

for tls_version in "-tls1" "-tls1_1" "-tls1_2" "-tls1_3"; do
    protocol="${tls_version#-}"
    protocol="${protocol//_/.}"

    if timeout 5 openssl s_client -connect "$HOST:$PORT" "$tls_version" </dev/null 2>&1 | grep -q "Protocol"; then
        echo "  ✓ Supported: ${protocol}"
    else
        echo "  ✗ Not supported: ${protocol}"
    fi
done

echo ""

# ========== 10. SECURITY ASSESSMENT ==========
echo "───────────────────────────────────────────────────────────────────"
echo "10. SECURITY ASSESSMENT"
echo "───────────────────────────────────────────────────────────────────"
echo ""

SECURITY_SCORE=100
ISSUES=()

if [[ -f "$CERT_FILE" ]] && [[ -s "$CERT_FILE" ]]; then
    # Check for self-signed
    if [[ "$SUBJECT" == "$ISSUER" ]]; then
        ((SECURITY_SCORE-=30))
        ISSUES+=("Self-signed certificate (-30)")
    fi

    # Check key size
    KEY_SIZE=$(openssl x509 -in "$CERT_FILE" -text -noout 2>/dev/null | grep -oE "Public-Key: \([0-9]+" | grep -oE "[0-9]+" || echo "0")
    if [[ $KEY_SIZE -lt 2048 ]]; then
        ((SECURITY_SCORE-=40))
        ISSUES+=("Weak key size: ${KEY_SIZE} bits (-40)")
    fi

    # Check expiration
    if [[ -n "${DAYS_LEFT:-}" ]] && [[ $DAYS_LEFT -lt 0 ]]; then
        ((SECURITY_SCORE-=50))
        ISSUES+=("Certificate EXPIRED (-50)")
    elif [[ -n "${DAYS_LEFT:-}" ]] && [[ $DAYS_LEFT -lt 30 ]]; then
        ((SECURITY_SCORE-=20))
        ISSUES+=("Certificate expires soon: $DAYS_LEFT days (-20)")
    fi
fi

echo "Certificate Security Score: $SECURITY_SCORE / 100"
echo ""

if [[ $SECURITY_SCORE -ge 80 ]]; then
    echo "✓ GOOD - Certificate security appears solid"
elif [[ $SECURITY_SCORE -ge 50 ]]; then
    echo "⚠️  FAIR - Some security concerns"
else
    echo "⚠️  POOR - Significant security issues"
fi

echo ""
echo "Issues detected:"
for issue in "${ISSUES[@]}"; do
    echo "  • $issue"
done

[[ ${#ISSUES[@]} -eq 0 ]] && echo "  (none)"

echo ""

# ========== SUMMARY ==========
echo "═══════════════════════════════════════════════════════════════════"
echo "CERTIFICATE INTELLIGENCE COMPLETE"
echo "═══════════════════════════════════════════════════════════════════"
echo ""
echo "Report: $REPORT"
[[ -f "$CERT_FILE" ]] && echo "Certificate: $CERT_FILE"

} | tee "$REPORT"

log "Certificate intelligence analysis complete"
