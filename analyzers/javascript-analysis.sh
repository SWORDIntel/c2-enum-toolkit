#!/usr/bin/env bash
# JavaScript Analysis & Endpoint Extraction Module
# Extracts API endpoints, deobfuscates code, analyzes client-side logic
set -euo pipefail

TARGET_URL="$1"
OUTDIR="${2:-.}"
SOCKS="${SOCKS:-127.0.0.1:9050}"

[[ -z "$TARGET_URL" ]] && { echo "Usage: $0 <url> [outdir]"; exit 1; }

mkdir -p "$OUTDIR/js_analysis"
REPORT="$OUTDIR/js_analysis/javascript_analysis.txt"

log() { echo "[$(date -u +'%Y-%m-%dT%H:%M:%SZ')] $*"; }

log "Starting JavaScript analysis: $TARGET_URL"

{
cat <<EOF
═══════════════════════════════════════════════════════════════════
JAVASCRIPT ANALYSIS REPORT
═══════════════════════════════════════════════════════════════════
Target: $TARGET_URL
Timestamp: $(date -u +'%Y-%m-%dT%H:%M:%SZ')
═══════════════════════════════════════════════════════════════════

EOF

# ========== 1. DISCOVER JS FILES ==========
echo "───────────────────────────────────────────────────────────────────"
echo "1. JAVASCRIPT FILE DISCOVERY"
echo "───────────────────────────────────────────────────────────────────"
echo ""

# Download main page
MAIN_PAGE="$OUTDIR/js_analysis/index.html"
log "Downloading main page..."

if curl --socks5-hostname "$SOCKS" -s --max-time 30 "$TARGET_URL" -o "$MAIN_PAGE" 2>/dev/null; then
    echo "[✓] Main page downloaded"

    # Extract JS file references
    echo ""
    echo "[*] Discovered JavaScript files:"

    grep -oE '<script[^>]+src="([^"]+)"' "$MAIN_PAGE" 2>/dev/null | \
        sed 's/.*src="//;s/".*$//' | sort -u | while read js_path; do

        # Handle relative vs absolute URLs
        if [[ "$js_path" == http* ]]; then
            js_url="$js_path"
        elif [[ "$js_path" == /* ]]; then
            js_url="${TARGET_URL}${js_path}"
        else
            js_url="${TARGET_URL}/${js_path}"
        fi

        echo "  → $js_path"

        # Download JS file
        js_file="$OUTDIR/js_analysis/$(basename "$js_path" | tr '/' '_' | tr '?' '_')"
        curl --socks5-hostname "$SOCKS" -s --max-time 20 "$js_url" -o "$js_file" 2>/dev/null || true

    done || echo "  (none found in HTML)"

    # Also look for inline scripts
    echo ""
    echo "[*] Inline scripts found: $(grep -c '<script' "$MAIN_PAGE" 2>/dev/null || echo 0)"

else
    echo "[✗] Failed to download main page"
fi

echo ""

# ========== 2. ENDPOINT EXTRACTION ==========
echo "───────────────────────────────────────────────────────────────────"
echo "2. API ENDPOINT EXTRACTION FROM JAVASCRIPT"
echo "───────────────────────────────────────────────────────────────────"
echo ""

ENDPOINTS_FILE="$OUTDIR/js_analysis/extracted_endpoints.txt"
: > "$ENDPOINTS_FILE"

echo "[*] Extracting API endpoints from JavaScript files:"

for js_file in "$OUTDIR"/js_analysis/*.js; do
    [[ ! -f "$js_file" ]] && continue

    echo ""
    echo "  Analyzing: $(basename "$js_file")"

    # Extract URL patterns
    grep -oE "(https?://[^\"']+|/api/[^\"']+|/[a-z0-9_-]+/[a-z0-9_-]+)" "$js_file" 2>/dev/null | \
        sort -u | head -30 | sed 's/^/    → /' | tee -a "$ENDPOINTS_FILE" || echo "    (no endpoints found)"
done

echo ""
echo "[*] Unique endpoints extracted: $(sort -u "$ENDPOINTS_FILE" | wc -l)"

echo ""

# ========== 3. DEOBFUSCATION ANALYSIS ==========
echo "───────────────────────────────────────────────────────────────────"
echo "3. OBFUSCATION DETECTION & ANALYSIS"
echo "───────────────────────────────────────────────────────────────────"
echo ""

for js_file in "$OUTDIR"/js_analysis/*.js; do
    [[ ! -f "$js_file" ]] && continue

    echo "File: $(basename "$js_file")"

    # Check for common obfuscation patterns
    local obfuscation_score=0

    # Eval usage
    if grep -qE "eval\(|Function\(|setTimeout\(.*,|setInterval\(" "$js_file" 2>/dev/null; then
        echo "  ⚠️  Dynamic code execution detected (eval/Function)"
        ((obfuscation_score+=30))
    fi

    # String array obfuscation
    if grep -qE "_0x[a-f0-9]{4,}" "$js_file" 2>/dev/null; then
        echo "  ⚠️  Hex-encoded string arrays detected"
        ((obfuscation_score+=25))
    fi

    # Minification
    local avg_line_length=$(awk '{total += length; count++} END {print int(total/count)}' "$js_file" 2>/dev/null || echo 0)
    if [[ $avg_line_length -gt 200 ]]; then
        echo "  ℹ️  Minified (avg line length: $avg_line_length chars)"
        ((obfuscation_score+=10))
    fi

    # Base64 encoding
    if grep -qE "atob\(|btoa\(|fromCharCode\(|charCodeAt\(" "$js_file" 2>/dev/null; then
        echo "  ⚠️  Base64 encoding functions detected"
        ((obfuscation_score+=20))
    fi

    # Unicode escape sequences
    if grep -qE "\\\\u[0-9a-f]{4}" "$js_file" 2>/dev/null; then
        echo "  ℹ️  Unicode escape sequences present"
        ((obfuscation_score+=5))
    fi

    echo "  Obfuscation score: $obfuscation_score / 100"

    if [[ $obfuscation_score -ge 50 ]]; then
        echo "  Assessment: HEAVILY OBFUSCATED"
    elif [[ $obfuscation_score -ge 25 ]]; then
        echo "  Assessment: MODERATELY OBFUSCATED"
    else
        echo "  Assessment: MINIMAL OBFUSCATION"
    fi

    echo ""
done

# ========== 4. SENSITIVE DATA DETECTION ==========
echo "───────────────────────────────────────────────────────────────────"
echo "4. SENSITIVE DATA IN JAVASCRIPT"
echo "───────────────────────────────────────────────────────────────────"
echo ""

for js_file in "$OUTDIR"/js_analysis/*.js; do
    [[ ! -f "$js_file" ]] && continue

    echo "File: $(basename "$js_file")"

    # API keys
    grep -oE "(api.?key|apikey|api_key).*['\"]([A-Za-z0-9_-]{20,})['\"]" "$js_file" 2>/dev/null | head -5 | sed 's/^/  ⚠️  /' || true

    # JWT tokens
    grep -oE "eyJ[A-Za-z0-9_-]+\\.eyJ[A-Za-z0-9_-]+\\.[A-Za-z0-9_-]+" "$js_file" 2>/dev/null | head -3 | sed 's/^/  ⚠️  JWT: /' || true

    # AWS keys
    grep -oE "AKIA[0-9A-Z]{16}" "$js_file" 2>/dev/null | head -3 | sed 's/^/  ⚠️  AWS Access Key: /' || true

    # Private keys
    grep -E "BEGIN (RSA |)PRIVATE KEY" "$js_file" 2>/dev/null | sed 's/^/  ⚠️  PRIVATE KEY FOUND: /' || true

    echo ""
done

# ========== 5. C2 COMMUNICATION PATTERNS ==========
echo "───────────────────────────────────────────────────────────────────"
echo "5. C2 COMMUNICATION PATTERN DETECTION"
echo "───────────────────────────────────────────────────────────────────"
echo ""

for js_file in "$OUTDIR"/js_analysis/*.js; do
    [[ ! -f "$js_file" ]] && continue

    echo "File: $(basename "$js_file")"

    # WebSocket connections
    if grep -qE "new WebSocket|ws://|wss://" "$js_file" 2>/dev/null; then
        echo "  ⚠️  WebSocket communication detected"
        grep -oE "(ws|wss)://[^\"'<>]+" "$js_file" 2>/dev/null | head -5 | sed 's/^/    → /' || true
    fi

    # AJAX/Fetch patterns
    if grep -qE "\.fetch\(|XMLHttpRequest|axios\.|ajax\(" "$js_file" 2>/dev/null; then
        echo "  ℹ️  AJAX/Fetch API usage detected"
    fi

    # Polling intervals
    if grep -E "setInterval\(|setTimeout\(" "$js_file" 2>/dev/null | head -3; then
        echo "  ℹ️  Polling/timer functions detected (potential beaconing)"
    fi

    echo ""
done

# ========== 6. FUNCTION MAPPING ==========
echo "───────────────────────────────────────────────────────────────────"
echo "6. FUNCTION & METHOD MAPPING"
echo "───────────────────────────────────────────────────────────────────"
echo ""

for js_file in "$OUTDIR"/js_analysis/*.js; do
    [[ ! -f "$js_file" ]] && continue

    echo "File: $(basename "$js_file")"

    # Extract function names
    echo "  Functions defined:"
    grep -oE "function [a-zA-Z_][a-zA-Z0-9_]*" "$js_file" 2>/dev/null | \
        awk '{print $2}' | sort -u | head -20 | sed 's/^/    • /' || echo "    (none found)"

    echo ""

    # Extract class names
    echo "  Classes defined:"
    grep -oE "class [a-zA-Z_][a-zA-Z0-9_]*" "$js_file" 2>/dev/null | \
        awk '{print $2}' | sort -u | head -10 | sed 's/^/    • /' || echo "    (none found)"

    echo ""
done

# ========== 7. THIRD-PARTY LIBRARIES ==========
echo "───────────────────────────────────────────────────────────────────"
echo "7. THIRD-PARTY LIBRARY DETECTION"
echo "───────────────────────────────────────────────────────────────────"
echo ""

for js_file in "$OUTDIR"/js_analysis/*.js; do
    [[ ! -f "$js_file" ]] && continue

    echo "File: $(basename "$js_file")"

    # Common libraries
    grep -oE "(jQuery|React|Angular|Vue|Bootstrap|Lodash|Underscore|Backbone|Socket\.io)" "$js_file" 2>/dev/null | \
        sort -u | sed 's/^/  → /' || echo "  (no common libraries detected)"

    echo ""
done

# ========== SUMMARY ==========
echo "═══════════════════════════════════════════════════════════════════"
echo "JAVASCRIPT ANALYSIS COMPLETE"
echo "═══════════════════════════════════════════════════════════════════"
echo ""
echo "Files analyzed: $(find "$OUTDIR/js_analysis" -name "*.js" 2>/dev/null | wc -l)"
echo "Endpoints extracted: $(sort -u "$ENDPOINTS_FILE" | wc -l)"
echo "Report: $REPORT"
echo ""
echo "Extracted endpoints saved to: $ENDPOINTS_FILE"

} | tee "$REPORT"

log "JavaScript analysis complete"
echo ""
echo "To test extracted endpoints, run:"
echo "  while read endpoint; do curl --socks5-hostname $SOCKS -I \"\$endpoint\"; done < $ENDPOINTS_FILE"
