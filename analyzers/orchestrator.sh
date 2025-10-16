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
    local msg
    msg="[$(date -u +'%Y-%m-%dT%H:%M:%SZ')] $*"
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

# ========== URL Context Extraction ==========

get_url_context() {
    local context_type="$1"  # 'url' or 'domain'
    local url=""
    local domain=""

    # Method 1: Check for saved context file (from comprehensive scan)
    if [[ -f "$TARGET_DIR/.target_url" ]]; then
        url=$(cat "$TARGET_DIR/.target_url" 2>/dev/null)
        domain=$(echo "$url" | sed 's|https\?://||; s|/.*||')
        log "  [Context] Loaded from .target_url: $url"
    fi

    # Method 2: Extract from directory name (intel_<onion>_<timestamp>)
    if [[ -z "$url" ]]; then
        local dirname
        dirname=$(basename "$TARGET_DIR")
        # Pattern: intel_<onion-address>_<timestamp>
        if [[ "$dirname" =~ intel_([a-z2-7]{16,56}\.onion[^_]*) ]]; then
            domain="${BASH_REMATCH[1]}"
            url="http://${domain}"
            log "  [Context] Extracted from dirname: $url"
        fi
    fi

    # Method 3: Check downloaded HEAD files for original URL
    if [[ -z "$url" ]]; then
        local head_file
        head_file=$(find "$TARGET_DIR" -maxdepth 1 -name "*_root.head" | head -1)
        if [[ -f "$head_file" ]]; then
            # Extract target from filename: <target>_root.head
            local target_from_file
            target_from_file=$(basename "$head_file" | sed 's/_root\.head$//')
            if [[ "$target_from_file" =~ [a-z2-7]{16,56}\.onion ]]; then
                domain="$target_from_file"
                url="http://${domain}"
                log "  [Context] Extracted from HEAD file: $url"
            fi
        fi
    fi

    # Method 4: Parse from any downloaded sample files
    if [[ -z "$url" ]]; then
        local sample_file
        sample_file=$(find "$TARGET_DIR" -maxdepth 1 -name "*.sample" | head -1)
        if [[ -f "$sample_file" ]]; then
            local onion
            onion=$(basename "$sample_file" | grep -oE '[a-z2-7]{16,56}\.onion[^_]*' | head -1)
            if [[ -n "$onion" ]]; then
                domain="$onion"
                url="http://${domain}"
                log "  [Context] Extracted from sample file: $url"
            fi
        fi
    fi

    # Method 5: Fallback - try to find any .onion reference
    if [[ -z "$url" ]]; then
        local found_onion
        found_onion=$(find "$TARGET_DIR" -type f \( -name "*.txt" -o -name "*.log" \) -print0 2>/dev/null | \
            xargs -0 grep -ohE '[a-z2-7]{16,56}\.onion(:[0-9]+)?' 2>/dev/null | head -1)
        if [[ -n "$found_onion" ]]; then
            domain="$found_onion"
            url="http://${domain}"
            log "  [Context] Found in files: $url"
        fi
    fi

    # Return requested context type
    if [[ "$context_type" == "domain" ]]; then
        echo "${domain:-placeholder.onion:443}"
    else
        echo "${url:-http://placeholder.onion}"
    fi
}

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
with open('$output_dir/$(basename \""$input_file"\").json') as f:
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
                # Get URL from context
                local url
                url=$(get_url_context "url")

                if [[ "$url" != *"placeholder"* ]]; then
                    log "  [URL] Using: $url"
                    bash "$SCRIPT_DIR/javascript-analysis.sh" "$url" "$output_dir" 2>&1 | tee -a "$ANALYSIS_LOG"
                else
                    log "  [Skip] No URL context available for JavaScript analysis"
                fi
            fi
            ;;

        content-crawler)
            if [[ -f "$SCRIPT_DIR/content-crawler.sh" ]]; then
                local url
                url=$(get_url_context "url")

                if [[ "$url" != *"placeholder"* ]]; then
                    log "  [URL] Using: $url"
                    bash "$SCRIPT_DIR/content-crawler.sh" "$url" "$output_dir" 2 2>&1 | tee -a "$ANALYSIS_LOG"

                    # Extract discovered endpoints from crawler
                    if [[ -f "$output_dir/content_analysis/discovered_endpoints.txt" ]]; then
                        cat "$output_dir/content_analysis/discovered_endpoints.txt" >> "$DISCOVERED_ENDPOINTS_FILE" 2>/dev/null || true
                    fi
                else
                    log "  [Skip] No URL context available for content crawler"
                fi
            fi
            ;;

        certificate-intel)
            if [[ -f "$SCRIPT_DIR/certificate-intel.sh" ]]; then
                local domain
                domain=$(get_url_context "domain")

                if [[ "$domain" != *"placeholder"* ]]; then
                    log "  [Domain] Using: $domain"
                    bash "$SCRIPT_DIR/certificate-intel.sh" "$domain" "$output_dir" 2>&1 | tee -a "$ANALYSIS_LOG"
                else
                    log "  [Skip] No domain context available for certificate analysis"
                fi
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
            for t in "${TOOLS[@]}"; do
                if [[ "$t" == "$tool" ]]; then
                    for binary in "${BINARIES[@]}"; do
                        run_tool "$tool" "$binary"
                    done
                fi
            done
        done
    fi

    if [[ ${#IMAGES[@]} -gt 0 ]]; then
        for t in "${TOOLS[@]}"; do
            if [[ "$t" == "kp14-image" ]]; then
                for image in "${IMAGES[@]}"; do
                    run_tool "kp14-image" "$image"
                done
            fi
        done
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