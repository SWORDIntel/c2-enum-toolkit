#!/usr/bin/env bash
# C2 Enumeration CLI - JSON output mode for automation/piping
# Non-interactive, scriptable interface with structured output
set -euo pipefail

VERSION="2.2-cli"

# ========== Configuration ==========
SOCKS="${SOCKS:-127.0.0.1:9050}"
OUTPUT_FORMAT="${OUTPUT_FORMAT:-json}"  # json, text, csv
SCAN_MODE="${SCAN_MODE:-standard}"      # standard, comprehensive
VERBOSE="${VERBOSE:-false}"

# ========== Usage ==========
usage() {
    cat <<EOF
C2 Enumeration CLI v$VERSION - Scriptable JSON Output

Usage:
  $0 [OPTIONS] <target.onion>

Options:
  -m, --mode MODE          Scan mode: standard, comprehensive (default: standard)
  -o, --output FORMAT      Output format: json, text, csv (default: json)
  -s, --socks PROXY        SOCKS proxy (default: 127.0.0.1:9050)
  -t, --timeout SECONDS    Request timeout (default: 30)
  -v, --verbose            Verbose output to stderr
  -q, --quiet              Suppress all stderr output
  --no-port-scan          Skip port scanning
  --no-path-enum          Skip path enumeration
  --no-binary             Skip binary discovery
  --ports PORT,PORT        Custom port list
  --paths FILE             Custom path list from file
  -h, --help              Show this help

Output:
  JSON is written to stdout for piping
  Logs written to stderr (unless --quiet)

Examples:
  # Basic scan with JSON output
  $0 target.onion

  # Comprehensive scan, save to file
  $0 --mode comprehensive target.onion > results.json

  # Pipe to jq for processing
  $0 target.onion | jq '.ports[] | select(.state=="open")'

  # Custom ports only
  $0 --ports 80,443,9000 target.onion

  # Quiet mode (only JSON)
  $0 --quiet target.onion 2>/dev/null

Exit Codes:
  0 - Success
  1 - Invalid arguments
  2 - Connection failed
  3 - Analysis failed
EOF
}

# ========== Argument Parsing ==========
TARGET=""
TIMEOUT=30
SKIP_PORTS=false
SKIP_PATHS=false
SKIP_BINARY=false
CUSTOM_PORTS=""
CUSTOM_PATHS_FILE=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        -m|--mode) SCAN_MODE="$2"; shift 2 ;;
        -o|--output) OUTPUT_FORMAT="$2"; shift 2 ;;
        -s|--socks) SOCKS="$2"; shift 2 ;;
        -t|--timeout) TIMEOUT="$2"; shift 2 ;;
        -v|--verbose) VERBOSE=true; shift ;;
        -q|--quiet) VERBOSE=false; exec 2>/dev/null; shift ;;
        --no-port-scan) SKIP_PORTS=true; shift ;;
        --no-path-enum) SKIP_PATHS=true; shift ;;
        --no-binary) SKIP_BINARY=true; shift ;;
        --ports) CUSTOM_PORTS="$2"; shift 2 ;;
        --paths) CUSTOM_PATHS_FILE="$2"; shift 2 ;;
        -h|--help) usage; exit 0 ;;
        -*) echo "Unknown option: $1" >&2; usage; exit 1 ;;
        *) TARGET="$1"; shift ;;
    esac
done

[[ -z "$TARGET" ]] && { echo "Error: Target required" >&2; usage; exit 1; }

# ========== Logging ==========
log() {
    if $VERBOSE; then
        echo "[$(date -u +'%Y-%m-%dT%H:%M:%SZ')] $*" >&2
    fi
}

error() {
    echo "[ERROR] $*" >&2
}

# ========== JSON Helpers ==========
json_escape() {
    echo "$1" | sed 's/\\/\\\\/g; s/"/\\"/g; s/$/\\n/g' | tr -d '\n'
}

json_array() {
    local items=("$@")
    local json="["

    for i in "${!items[@]}"; do
        json+="\"${items[$i]}\""
        [[ $i -lt $((${#items[@]} - 1)) ]] && json+=","
    done

    json+="]"
    echo "$json"
}

# ========== Main Analysis ==========
log "Starting CLI analysis: $TARGET (mode: $SCAN_MODE, format: $OUTPUT_FORMAT)"

# Initialize result structure
START_TIME=$(date -u +'%Y-%m-%dT%H:%M:%SZ')
START_EPOCH=$(date +%s)

OPEN_PORTS=()
FOUND_PATHS=()
BINARIES=()
ERRORS=()

# ========== Port Scanning ==========
if ! $SKIP_PORTS; then
    log "Port scanning..."

    if [[ -n "$CUSTOM_PORTS" ]]; then
        IFS=',' read -ra PORT_LIST <<< "$CUSTOM_PORTS"
    else
        if [[ "$SCAN_MODE" == "comprehensive" ]]; then
            PORT_LIST=(21 22 80 443 3306 5432 6379 8080 8443 9000 9001 27017)
        else
            PORT_LIST=(80 443 8080 9000)
        fi
    fi

    for port in "${PORT_LIST[@]}"; do
        if timeout 5 curl --socks5-hostname "$SOCKS" -s --max-time 5 \
           "http://$TARGET:$port/" >/dev/null 2>&1; then
            OPEN_PORTS+=("$port")
            log "  Port $port: OPEN"
        fi
    done

    log "Port scan complete: ${#OPEN_PORTS[@]} open"
fi

# ========== Path Enumeration ==========
if ! $SKIP_PATHS; then
    log "Path enumeration..."

    if [[ -n "$CUSTOM_PATHS_FILE" ]] && [[ -f "$CUSTOM_PATHS_FILE" ]]; then
        mapfile -t PATH_LIST < "$CUSTOM_PATHS_FILE"
    else
        PATH_LIST=("/" "/robots.txt" "/admin" "/api" "/status" "/health")
    fi

    for path in "${PATH_LIST[@]}"; do
        response=$(timeout "$TIMEOUT" curl --socks5-hostname "$SOCKS" -s -I \
                   --max-time "$TIMEOUT" "http://$TARGET$path" 2>&1 || echo "FAIL")

        status_code=$(echo "$response" | grep -i "^HTTP" | awk '{print $2}' | head -1)

        if [[ "$status_code" =~ ^(200|201|301|302|401|403)$ ]]; then
            FOUND_PATHS+=("$path:$status_code")
            log "  $path: $status_code"
        fi
    done

    log "Path enumeration complete: ${#FOUND_PATHS[@]} found"
fi

# ========== Calculate Duration ==========
END_EPOCH=$(date +%s)
DURATION=$((END_EPOCH - START_EPOCH))

# ========== Output Generation ==========
case "$OUTPUT_FORMAT" in
    json)
        cat <<EOF
{
  "metadata": {
    "version": "$VERSION",
    "target": "$TARGET",
    "scan_mode": "$SCAN_MODE",
    "start_time": "$START_TIME",
    "duration_seconds": $DURATION,
    "socks_proxy": "$SOCKS"
  },
  "ports": {
    "scanned": ${#PORT_LIST[@]},
    "open": ${#OPEN_PORTS[@]},
    "list": $(json_array "${OPEN_PORTS[@]}")
  },
  "paths": {
    "tested": ${#PATH_LIST[@]},
    "found": ${#FOUND_PATHS[@]},
    "list": [
$(for i in "${!FOUND_PATHS[@]}"; do
    path="${FOUND_PATHS[$i]%:*}"
    code="${FOUND_PATHS[$i]##*:}"
    echo "      {\"path\": \"$path\", \"status_code\": $code}"
    [[ $i -lt $((${#FOUND_PATHS[@]} - 1)) ]] && echo ","
done)
    ]
  },
  "errors": $(json_array "${ERRORS[@]}")
}
EOF
        ;;

    text)
        cat <<EOF
C2 Enumeration Results
Target: $TARGET
Mode: $SCAN_MODE
Duration: ${DURATION}s

Open Ports (${#OPEN_PORTS[@]}):
$(printf '  %s\n' "${OPEN_PORTS[@]}")

Found Paths (${#FOUND_PATHS[@]}):
$(printf '  %s\n' "${FOUND_PATHS[@]}")
EOF
        ;;

    csv)
        echo "type,value,status"
        for port in "${OPEN_PORTS[@]}"; do
            echo "port,$port,open"
        done
        for path_status in "${FOUND_PATHS[@]}"; do
            path="${path_status%:*}"
            status="${path_status##*:}"
            echo "path,$path,$status"
        done
        ;;

    *)
        error "Unknown output format: $OUTPUT_FORMAT"
        exit 1
        ;;
esac

log "Analysis complete: $TARGET (${DURATION}s)"

exit 0
