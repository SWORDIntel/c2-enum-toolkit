#!/usr/bin/env bash
# KP14 Auto-Discovery Integration
# Automatically discovers hidden C2 endpoints from images and binaries using KP14
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
KP14_BRIDGE="$SCRIPT_DIR/kp14-bridge.py"
INPUT_DIR="${1:-.}"
OUTPUT_DIR="${2:-./kp14_discovery}"
SOCKS="${SOCKS:-127.0.0.1:9050}"

log() { echo "[$(date -u +'%Y-%m-%dT%H:%M:%SZ')] $*"; }

log "KP14 Auto-Discovery Starting..."

# Check dependencies
if ! command -v python3 >/dev/null 2>&1; then
    echo "[✗] Python3 required for KP14 integration" >&2
    exit 1
fi

if [[ ! -f "$KP14_BRIDGE" ]]; then
    echo "[✗] KP14 bridge not found: $KP14_BRIDGE" >&2
    exit 1
fi

mkdir -p "$OUTPUT_DIR"

DISCOVERED_FILE="$OUTPUT_DIR/discovered_endpoints.txt"
REPORT_FILE="$OUTPUT_DIR/kp14_discovery_report.txt"
: > "$DISCOVERED_FILE"

{
cat <<EOF
═══════════════════════════════════════════════════════════════════
KP14 AUTO-DISCOVERY REPORT
═══════════════════════════════════════════════════════════════════
Input Directory: $INPUT_DIR
Output Directory: $OUTPUT_DIR
Timestamp: $(date -u +'%Y-%m-%dT%H:%M:%SZ')
═══════════════════════════════════════════════════════════════════

EOF

# ========== 1. DISCOVER FILES TO ANALYZE ==========
echo "───────────────────────────────────────────────────────────────────"
echo "1. FILE DISCOVERY"
echo "───────────────────────────────────────────────────────────────────"
echo ""

IMAGE_FILES=()
BINARY_FILES=()

# Find JPEG images
while IFS= read -r -d '' file; do
    IMAGE_FILES+=("$file")
done < <(find "$INPUT_DIR" -type f \( -name "*.jpg" -o -name "*.jpeg" -o -name "favicon.ico" \) -print0 2>/dev/null)

# Find binaries
while IFS= read -r -d '' file; do
    BINARY_FILES+=("$file")
done < <(find "$INPUT_DIR" -type f \( -name "*.bin" -o -name "*.exe" -o -name "*.dll" -o -name "*system-linux*" \) -print0 2>/dev/null)

echo "Images found: ${#IMAGE_FILES[@]}"
echo "Binaries found: ${#BINARY_FILES[@]}"
echo ""

if [[ ${#IMAGE_FILES[@]} -eq 0 ]] && [[ ${#BINARY_FILES[@]} -eq 0 ]]; then
    echo "[!] No files to analyze"
    exit 0
fi

# ========== 2. ANALYZE IMAGES ==========
if [[ ${#IMAGE_FILES[@]} -gt 0 ]]; then
    echo "───────────────────────────────────────────────────────────────────"
    echo "2. IMAGE STEGANOGRAPHY ANALYSIS (${#IMAGE_FILES[@]} files)"
    echo "───────────────────────────────────────────────────────────────────"
    echo ""

    for img in "${IMAGE_FILES[@]}"; do
        echo "Analyzing: $(basename "$img")"

        # Run KP14 bridge
        JSON_OUT="$OUTPUT_DIR/$(basename "$img").json"

        if python3 "$KP14_BRIDGE" "$img" -t jpeg -o "$JSON_OUT" -v 2>&1 | tee -a "$OUTPUT_DIR/kp14.log"; then
            # Parse JSON for discovered endpoints
            if [[ -f "$JSON_OUT" ]]; then
                # Extract .onion addresses
                python3 -c "
import json, sys
try:
    with open('$JSON_OUT') as f:
        data = json.load(f)
    for ep in data.get('discovered_endpoints', []):
        if ep.get('type') in ['onion', 'url']:
            print(f\"{ep['value']} (confidence: {ep['confidence']}%, key: {ep['decryption_key']})\")
except: pass
" | tee -a "$DISCOVERED_FILE" || true
            fi
        fi

        echo ""
    done
fi

# ========== 3. ANALYZE BINARIES ==========
if [[ ${#BINARY_FILES[@]} -gt 0 ]]; then
    echo "───────────────────────────────────────────────────────────────────"
    echo "3. BINARY CONFIGURATION EXTRACTION (${#BINARY_FILES[@]} files)"
    echo "───────────────────────────────────────────────────────────────────"
    echo ""

    for bin in "${BINARY_FILES[@]}"; do
        echo "Analyzing: $(basename "$bin")"

        JSON_OUT="$OUTPUT_DIR/$(basename "$bin").json"

        if python3 "$KP14_BRIDGE" "$bin" -t binary -o "$JSON_OUT" -v 2>&1 | tee -a "$OUTPUT_DIR/kp14.log"; then
            if [[ -f "$JSON_OUT" ]]; then
                python3 -c "
import json, sys
try:
    with open('$JSON_OUT') as f:
        data = json.load(f)
    for ep in data.get('discovered_endpoints', []):
        if ep.get('type') in ['onion', 'url']:
            print(f\"{ep['value']} (confidence: {ep['confidence']}%, key: {ep['decryption_key']})\")
except: pass
" | tee -a "$DISCOVERED_FILE" || true
            fi
        fi

        echo ""
    done
fi

# ========== 4. SUMMARY ==========
echo "═══════════════════════════════════════════════════════════════════"
echo "DISCOVERY SUMMARY"
echo "═══════════════════════════════════════════════════════════════════"
echo ""

UNIQUE_ENDPOINTS=$(sort -u "$DISCOVERED_FILE" | wc -l)

echo "Total unique endpoints discovered: $UNIQUE_ENDPOINTS"
echo ""

if [[ $UNIQUE_ENDPOINTS -gt 0 ]]; then
    echo "Discovered endpoints:"
    sort -u "$DISCOVERED_FILE" | nl -w2 -s') '
else
    echo "(no endpoints discovered)"
fi

echo ""
echo "Report: $REPORT_FILE"
echo "Endpoints: $DISCOVERED_FILE"
echo "Individual results: $OUTPUT_DIR/*.json"

} | tee "$REPORT_FILE"

log "KP14 Auto-Discovery Complete"

# ========== 5. AUTO-ADD TO TARGETS (Optional) ==========
if [[ $UNIQUE_ENDPOINTS -gt 0 ]]; then
    echo ""
    echo "═══════════════════════════════════════════════════════════════════"
    echo "AUTO-ENUMERATION OPTION"
    echo "═══════════════════════════════════════════════════════════════════"
    echo ""
    echo "Discovered endpoints can be automatically enumerated."
    echo ""
    echo "To enumerate discovered endpoints:"
    echo "  while read ep; do"
    echo "    onion=\$(echo \"\$ep\" | awk '{print \$1}')"
    echo "    echo \"Enumerating: \$onion\""
    echo "    ./c2-enum-cli.sh \"\$onion\""
    echo "  done < \"$DISCOVERED_FILE\""
    echo ""
fi

exit 0
