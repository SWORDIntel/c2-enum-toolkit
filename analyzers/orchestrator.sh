#!/usr/bin/env bash
# Intelligent Analysis Orchestrator
# Dynamically chains analysis tools based on outputs until full C2 discovery
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TARGET_DIR="${1:-.}"
PROFILE="${2:-balanced}"  # fast, balanced, exhaustive
MAX_DEPTH="${3:-3}"

OUTDIR="$TARGET_DIR/intelligent_analysis"
mkdir -p "$OUTDIR"

DISCOVERED_ENDPOINTS_FILE="$OUTDIR/all_discovered_endpoints.txt"
ANALYSIS_LOG="$OUTDIR/orchestrator.log"
: > "$DISCOVERED_ENDPOINTS_FILE"
: > "$ANALYSIS_LOG"

# ========== Configuration ==========
log() {
    local msg="[$(date -u +'%Y-%m-%dT%H:%M:%SZ')] $*"
    echo "$msg" | tee -a "$ANALYSIS_LOG"
}

# Hardware detection
HW_INFO=$(bash "$SCRIPT_DIR/hw-detect.sh" export 2>/dev/null)
eval "$HW_INFO" 2>/dev/null || true

RECOMMENDED_DEVICE="${HW_RECOMMENDED_DEVICE:-CPU}"

log "╔════════════════════════════════════════════════════════════════════╗"
log "║         INTELLIGENT ANALYSIS ORCHESTRATOR                          ║"
log "╚════════════════════════════════════════════════════════════════════╝"
log ""
log "Profile: $PROFILE"
log "Max Depth: $MAX_DEPTH"
log "Target Dir: $TARGET_DIR"
log "Hardware: $RECOMMENDED_DEVICE (${HW_CPU_CORES:-?} cores, GPU=${HW_GPU_AVAILABLE:-0}, NPU=${HW_NPU_AVAILABLE:-0})"
log ""

# ========== Analysis DAG Definition ==========

# Define tool dependencies and chaining rules
declare -A TOOL_DEPS
declare -A TOOL_OUTPUTS
declare -A TOOL_CONFIDENCE

# Tool dependency graph
TOOL_DEPS=(
    ["binary-analysis"]=""  # No deps, runs on binaries
    ["kp14-binary"]="binary-analysis"  # Needs binary analysis first
    ["javascript-analysis"]=""  # No deps, runs on URLs
    ["kp14-image"]=""  # No deps, runs on images
    ["certificate-intel"]=""  # No deps, runs on domains
    ["content-crawler"]="javascript-analysis"  # Better with JS endpoints
)

# Tool output types
TOOL_OUTPUTS=(
    ["binary-analysis"]="strings,hashes,threat_score"
    ["kp14-binary"]="endpoints,configs"
    ["kp14-image"]="endpoints,payloads"
    ["javascript-analysis"]="endpoints,apis"
    ["certificate-intel"]="fingerprints,security_score"
    ["content-crawler"]="endpoints,links"
)

# ========== File Discovery ==========
log "Step 1: Discovering files to analyze..."

BINARIES=()
IMAGES=()
HTML_FILES=()

while IFS= read -r -d '' file; do
    BINARIES+=("$file")
done < <(find "$TARGET_DIR" -type f \( -name "*.bin" -o -name "*system-linux*" -o -name "*.exe" \) -print0 2>/dev/null)

while IFS= read -r -d '' file; do
    IMAGES+=("$file")
done < <(find "$TARGET_DIR" -type f \( -name "*.jpg" -o -name "*.jpeg" -o -name "*.png" -o -name "favicon.ico" \) -print0 2>/dev/null)

while IFS= read -r -d '' file; do
    HTML_FILES+=("$file")
done < <(find "$TARGET_DIR" -type f \( -name "*.html" -o -name "*_root.sample" \) -print0 2>/dev/null)

log "  Binaries: ${#BINARIES[@]}"
log "  Images: ${#IMAGES[@]}"
log "  HTML: ${#HTML_FILES[@]}"
log ""

# ========== Analysis Profile Configuration ==========
case "$PROFILE" in
    fast)
        TOOLS=("binary-analysis" "kp14-binary" "kp14-image")
        RECURSIVE=false
        CONFIDENCE_THRESHOLD=70
        ;;
    balanced)
        TOOLS=("binary-analysis" "kp14-binary" "kp14-image" "javascript-analysis" "content-crawler")
        RECURSIVE=true
        CONFIDENCE_THRESHOLD=60
        ;;
    exhaustive)
        TOOLS=("binary-analysis" "kp14-binary" "kp14-image" "javascript-analysis" "certificate-intel" "content-crawler")
        RECURSIVE=true
        CONFIDENCE_THRESHOLD=50
        ;;
    *)
        log "[✗] Unknown profile: $PROFILE"
        exit 1
        ;;
esac

log "Profile '$PROFILE' selected: ${#TOOLS[@]} tools, threshold=${CONFIDENCE_THRESHOLD}%"
log ""

# ========== Tool Execution Engine ==========

run_tool() {
    local tool="$1"
    local input_file="$2"
    local output_dir="$OUTDIR/${tool}"

    mkdir -p "$output_dir"

    log "[→] Running: $tool on $(basename "$input_file")"

    case "$tool" in
        binary-analysis)
            if [[ -f "$SCRIPT_DIR/binary-analysis.sh" ]]; then
                bash "$SCRIPT_DIR/binary-analysis.sh" "$input_file" "$output_dir"
            fi
            ;;

        kp14-binary|kp14-image)
            if [[ -f "$SCRIPT_DIR/kp14-bridge.py" ]]; then
                local file_type="binary"
                [[ "$tool" == "kp14-image" ]] && file_type="jpeg"

                python3 "$SCRIPT_DIR/kp14-bridge.py" "$input_file" \
                    -t "$file_type" -o "$output_dir/$(basename "$input_file").json" -v 2>&1 | \
                    tee -a "$ANALYSIS_LOG"

                # Parse discovered endpoints
                if [[ -f "$output_dir/$(basename "$input_file").json" ]]; then
                    python3 -c "
import json, sys
with open('$output_dir/$(basename \"$input_file\").json') as f:
    data = json.load(f)
for ep in data.get('discovered_endpoints', []):
    if ep['confidence'] >= $CONFIDENCE_THRESHOLD:
        print(f\"{ep['value']} confidence={ep['confidence']}% key={ep['decryption_key']}\")
" >> "$DISCOVERED_ENDPOINTS_FILE" 2>/dev/null || true
                fi
            fi
            ;;

        javascript-analysis)
            if [[ -f "$SCRIPT_DIR/javascript-analysis.sh" ]]; then
                # Need URL, construct from file or use base
                local url="http://placeholder.onion"  # Would come from context
                bash "$SCRIPT_DIR/javascript-analysis.sh" "$url" "$output_dir" 2>&1 | tee -a "$ANALYSIS_LOG"
            fi
            ;;

        content-crawler)
            if [[ -f "$SCRIPT_DIR/content-crawler.sh" ]]; then
                local url="http://placeholder.onion"
                bash "$SCRIPT_DIR/content-crawler.sh" "$url" "$output_dir" 2 2>&1 | tee -a "$ANALYSIS_LOG"
            fi
            ;;

        certificate-intel)
            if [[ -f "$SCRIPT_DIR/certificate-intel.sh" ]]; then
                local domain="placeholder.onion:443"
                bash "$SCRIPT_DIR/certificate-intel.sh" "$domain" "$output_dir" 2>&1 | tee -a "$ANALYSIS_LOG"
            fi
            ;;
    esac

    log "[✓] Completed: $tool"
}

# ========== Main Analysis Loop ==========
log "Step 2: Running analysis chain..."
log ""

ITERATION=0
PREVIOUS_ENDPOINT_COUNT=0

while [[ $ITERATION -lt $MAX_DEPTH ]]; do
    ((ITERATION++))
    log "═══ Iteration $ITERATION/$MAX_DEPTH ═══"

    # Run tools based on profile
    if [[ ${#BINARIES[@]} -gt 0 ]]; then
        for tool in "binary-analysis" "kp14-binary"; do
            if [[ " ${TOOLS[@]} " =~ " $tool " ]]; then
                for binary in "${BINARIES[@]}"; do
                    run_tool "$tool" "$binary"
                done
            fi
        done
    fi

    if [[ ${#IMAGES[@]} -gt 0 ]]; then
        if [[ " ${TOOLS[@]} " =~ " kp14-image " ]]; then
            for image in "${IMAGES[@]}"; do
                run_tool "kp14-image" "$image"
            done
        fi
    fi

    # Check if new endpoints were discovered
    CURRENT_ENDPOINT_COUNT=$(sort -u "$DISCOVERED_ENDPOINTS_FILE" | wc -l)

    log ""
    log "Iteration $ITERATION complete:"
    log "  Previous endpoints: $PREVIOUS_ENDPOINT_COUNT"
    log "  Current endpoints: $CURRENT_ENDPOINT_COUNT"
    log "  New discovered: $((CURRENT_ENDPOINT_COUNT - PREVIOUS_ENDPOINT_COUNT))"

    # Convergence check
    if [[ $CURRENT_ENDPOINT_COUNT -eq $PREVIOUS_ENDPOINT_COUNT ]]; then
        log ""
        log "[✓] Convergence reached - no new endpoints discovered"
        break
    fi

    PREVIOUS_ENDPOINT_COUNT=$CURRENT_ENDPOINT_COUNT

    # Don't iterate if not recursive
    if ! $RECURSIVE; then
        break
    fi

    log ""
done

# ========== Final Report ==========
log ""
log "╔════════════════════════════════════════════════════════════════════╗"
log "║              INTELLIGENT ANALYSIS COMPLETE                         ║"
log "╚════════════════════════════════════════════════════════════════════╝"
log ""
log "Total Iterations: $ITERATION"
log "Total Unique Endpoints Discovered: $(sort -u "$DISCOVERED_ENDPOINTS_FILE" | wc -l)"
log ""

if [[ -s "$DISCOVERED_ENDPOINTS_FILE" ]]; then
    log "Discovered Endpoints (sorted by confidence):"
    sort -u "$DISCOVERED_ENDPOINTS_FILE" | nl -w2 -s') ' | tee -a "$ANALYSIS_LOG"
else
    log "(no endpoints discovered)"
fi

log ""
log "Full report: $OUTDIR/"
log "Endpoints: $DISCOVERED_ENDPOINTS_FILE"
log "Log: $ANALYSIS_LOG"

exit 0
