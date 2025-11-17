#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════════
# C2-ENUM-TUI v3.0 — TEMPEST CLASS C COMPLIANT INTERFACE
# Secure Terminal User Interface for C2 Infrastructure Analysis
# Classification: UNCLASSIFIED // FOR OFFICIAL USE ONLY
# ═══════════════════════════════════════════════════════════════════════════════
# Hardened: quoted heredocs, safer loops, auto OUTDIR, no exec of remote code.
set -euo pipefail
IFS=$'\n\t'

# ═══════════════════════════════════════════════════════════════════════════════
# TEMPEST CLASS C VISUAL STANDARDS
# Government-grade terminal display specifications
# ═══════════════════════════════════════════════════════════════════════════════

# ANSI Color Definitions - TEMPEST Amber/Green on Black
readonly TEMPEST_AMBER='\033[38;5;214m'      # Primary text - Amber
readonly TEMPEST_GREEN='\033[38;5;46m'       # Success/Active indicators
readonly TEMPEST_RED='\033[38;5;196m'        # Critical/Error/Classified
readonly TEMPEST_CYAN='\033[38;5;51m'        # Information/Headers
readonly TEMPEST_WHITE='\033[38;5;255m'      # High contrast text
readonly TEMPEST_YELLOW='\033[38;5;226m'     # Warnings
readonly TEMPEST_GRAY='\033[38;5;244m'       # Secondary/Disabled
readonly TEMPEST_BG_BLACK='\033[48;5;232m'   # Background
readonly NC='\033[0m'                         # Reset
readonly BOLD='\033[1m'
readonly DIM='\033[2m'
readonly BLINK='\033[5m'

# Classification Banner Settings
readonly CLASSIFICATION="UNCLASSIFIED // FOR OFFICIAL USE ONLY"
readonly SYSTEM_ID="C2-ENUM-TUI"
readonly VERSION="3.0-TEMPEST"
readonly BUILD_DATE="2024-01"

# Status Indicator Symbols (MIL-STD-2525 inspired)
readonly SYM_ACTIVE="●"
readonly SYM_INACTIVE="○"
readonly SYM_SUCCESS="✓"
readonly SYM_FAILURE="✗"
readonly SYM_WARNING="⚠"
readonly SYM_SECURE="◆"
readonly SYM_CLASSIFIED="■"
readonly SYM_PENDING="◌"

# ---------- Known C2 targets ----------
KNOWN_TARGETS=(
  "wtxqf54djhp5pskv2lfyduub5ievxbyvlzjgjopk6hxge5umombr63ad.onion"
  "2hdv5kven4m422wx4dmqabotumkeisrstzkzaotvuhwx3aebdig573qd.onion:9000"
)

# ---------- Defaults ----------
SOCKS="${SOCKS:-127.0.0.1:9050}"
OUTDIR=""
AUTO_ENUM=true
VERBOSE=true
OPERATOR_ID="${OPERATOR_ID:-UNIDENTIFIED}"
SESSION_ID="$(date +%Y%m%d%H%M%S)-$$"

# PCAP defaults (ON)
PCAP_ON=true
PCAP_IF="${PCAP_IF:-lo}"
PCAP_FILTER_DEFAULT='tcp and (port 9050 or 9150 or 9000)'
PCAP_FILTER="${PCAP_FILTER:-$PCAP_FILTER_DEFAULT}"
PCAP_DIR=""

# ═══════════════════════════════════════════════════════════════════════════════
# TEMPEST DISPLAY FUNCTIONS
# ═══════════════════════════════════════════════════════════════════════════════

# Classification Banner - Top
print_classification_banner_top() {
    local width=78
    local padding=$(( (width - ${#CLASSIFICATION}) / 2 ))
    echo -e "${TEMPEST_BG_BLACK}${TEMPEST_RED}${BOLD}"
    printf "╔"
    printf '═%.0s' $(seq 1 $width)
    printf "╗\n"
    printf "║%*s%s%*s║\n" $padding "" "$CLASSIFICATION" $((width - padding - ${#CLASSIFICATION})) ""
    printf "╚"
    printf '═%.0s' $(seq 1 $width)
    printf "╝\n"
    echo -e "${NC}"
}

# Classification Banner - Bottom
print_classification_banner_bottom() {
    local width=78
    local padding=$(( (width - ${#CLASSIFICATION}) / 2 ))
    echo -e "${TEMPEST_RED}${BOLD}"
    printf "╔"
    printf '═%.0s' $(seq 1 $width)
    printf "╗\n"
    printf "║%*s%s%*s║\n" $padding "" "$CLASSIFICATION" $((width - padding - ${#CLASSIFICATION})) ""
    printf "╚"
    printf '═%.0s' $(seq 1 $width)
    printf "╝\n"
    echo -e "${NC}"
}

# System Identification Header
print_system_header() {
    echo -e "${TEMPEST_CYAN}${BOLD}"
    echo "┌──────────────────────────────────────────────────────────────────────────────┐"
    echo "│                    ${TEMPEST_AMBER}C2 ENUMERATION TOOLKIT${TEMPEST_CYAN}                                │"
    echo "│                  ${TEMPEST_WHITE}TEMPEST CLASS C INTERFACE${TEMPEST_CYAN}                              │"
    echo "├──────────────────────────────────────────────────────────────────────────────┤"
    printf "│ ${TEMPEST_GRAY}SYSTEM:${TEMPEST_AMBER} %-15s ${TEMPEST_GRAY}VERSION:${TEMPEST_AMBER} %-10s ${TEMPEST_GRAY}BUILD:${TEMPEST_AMBER} %-12s${TEMPEST_CYAN}     │\n" "$SYSTEM_ID" "$VERSION" "$BUILD_DATE"
    printf "│ ${TEMPEST_GRAY}SESSION:${TEMPEST_GREEN} %-14s ${TEMPEST_GRAY}OPERATOR:${TEMPEST_WHITE} %-28s${TEMPEST_CYAN}│\n" "$SESSION_ID" "$OPERATOR_ID"
    echo "└──────────────────────────────────────────────────────────────────────────────┘"
    echo -e "${NC}"
}

# Status Line
print_status_line() {
    local pcap_status="$1"
    local target_count="$2"
    local tor_status="$3"

    echo -e "${TEMPEST_GRAY}├──────────────────────────────────────────────────────────────────────────────┤${NC}"
    printf "${TEMPEST_GRAY}│${NC} "

    # PCAP Status
    if [[ "$pcap_status" == "ON" ]]; then
        printf "${TEMPEST_GREEN}${SYM_ACTIVE} PCAP${NC}"
    else
        printf "${TEMPEST_GRAY}${SYM_INACTIVE} PCAP${NC}"
    fi

    printf "  │  "

    # Target Count
    printf "${TEMPEST_AMBER}TARGETS: %02d${NC}" "$target_count"

    printf "  │  "

    # Tor Status
    if [[ "$tor_status" == "OK" ]]; then
        printf "${TEMPEST_GREEN}${SYM_SECURE} TOR${NC}"
    else
        printf "${TEMPEST_RED}${SYM_FAILURE} TOR${NC}"
    fi

    printf "  │  "

    # Timestamp
    printf "${TEMPEST_GRAY}%s${NC}" "$(date -u +'%H:%M:%S UTC')"

    printf "\n"
    echo -e "${TEMPEST_GRAY}└──────────────────────────────────────────────────────────────────────────────┘${NC}"
}

# Section Header
print_section_header() {
    local title="$1"
    local width=78
    local padding=$(( (width - ${#title} - 4) / 2 ))

    echo -e "${TEMPEST_CYAN}"
    printf "┌"
    printf '─%.0s' $(seq 1 $padding)
    printf "┤ ${TEMPEST_AMBER}%s${TEMPEST_CYAN} ├" "$title"
    printf '─%.0s' $(seq 1 $((width - padding - ${#title} - 4)))
    printf "┐\n"
    echo -e "${NC}"
}

# Audit Log Entry
audit_log() {
    local level="$1"
    local message="$2"
    local ts
    ts="$(date -u +'%Y-%m-%dT%H:%M:%SZ')"

    # Console output with TEMPEST colors
    case "$level" in
        "INFO")  printf "${TEMPEST_CYAN}[%s]${NC} ${TEMPEST_GRAY}[INFO]${NC}  %s\n" "$ts" "$message" ;;
        "WARN")  printf "${TEMPEST_CYAN}[%s]${NC} ${TEMPEST_YELLOW}[WARN]${NC}  %s\n" "$ts" "$message" ;;
        "ERROR") printf "${TEMPEST_CYAN}[%s]${NC} ${TEMPEST_RED}[ERROR]${NC} %s\n" "$ts" "$message" ;;
        "SEC")   printf "${TEMPEST_CYAN}[%s]${NC} ${TEMPEST_RED}[SEC]${NC}   %s\n" "$ts" "$message" ;;
        "AUDIT") printf "${TEMPEST_CYAN}[%s]${NC} ${TEMPEST_GREEN}[AUDIT]${NC} %s\n" "$ts" "$message" ;;
        *)       printf "${TEMPEST_CYAN}[%s]${NC} [%s] %s\n" "$ts" "$level" "$message" ;;
    esac

    # File logging
    [[ -n "${LOG:-}" ]] && printf "[%s] [%s] [%s] [%s] %s\n" "$ts" "$SESSION_ID" "$OPERATOR_ID" "$level" "$message" >> "$LOG"
}

# TEMPEST-styled menu item
tempest_menu_item() {
    local num="$1"
    local label="$2"
    local status="${3:-}"

    printf "${TEMPEST_AMBER}%3s${NC}) ${TEMPEST_WHITE}%-50s${NC}" "$num" "$label"

    if [[ -n "$status" ]]; then
        case "$status" in
            "NEW")    printf " ${TEMPEST_GREEN}[NEW]${NC}" ;;
            "HOT")    printf " ${TEMPEST_RED}[HOT]${NC}" ;;
            "SEC")    printf " ${TEMPEST_RED}[SECURED]${NC}" ;;
            "ACTIVE") printf " ${TEMPEST_GREEN}${SYM_ACTIVE}${NC}" ;;
        esac
    fi
    printf "\n"
}

# Progress indicator with TEMPEST styling
tempest_progress() {
    local pid="$1"
    local msg="$2"
    local spin='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    local i=0
    local elapsed=0

    while kill -0 "$pid" 2>/dev/null; do
        i=$(( (i+1) % 10 ))
        elapsed=$((elapsed + 1))
        printf "\r${TEMPEST_AMBER}[${spin:$i:1}]${NC} %s ${TEMPEST_GRAY}(%ds)${NC}" "$msg" "$elapsed"
        sleep 0.1
    done

    wait "$pid" 2>/dev/null
    local exit_code=$?

    if [[ $exit_code -eq 0 ]]; then
        printf "\r${TEMPEST_GREEN}[${SYM_SUCCESS}]${NC} %s ${TEMPEST_GRAY}(%ds)${NC}\n" "$msg" "$((elapsed/10))"
    else
        printf "\r${TEMPEST_RED}[${SYM_FAILURE}]${NC} %s ${TEMPEST_GRAY}(FAILED)${NC}\n" "$msg"
    fi

    return $exit_code
}

# ---------- Tools ----------
CURL_BIN=$(command -v curl || true)
DATE_CMD=$(command -v date)
SHA256SUM=$(command -v sha256sum || true)
FILECMD=$(command -v file || true)
READELF=$(command -v readelf || true)
STRINGS=$(command -v strings || true)
ZSTD_BIN=$(command -v zstd || true)
DIALOG=$(command -v dialog || true)
FZF=$(command -v fzf || true)
LESS_BIN=$(command -v less || echo "less")
GIT=$(command -v git || true)
TCPDUMP=$(command -v tcpdump || true)
DUMPCAP=$(command -v dumpcap || true)
TSHARK=$(command -v tshark || true)
XXD=$(command -v xxd || command -v hexdump || true)
JQ=$(command -v jq || true)
NC=$(command -v nc || command -v netcat || true)
NM=$(command -v nm || true)

# ---------- Dependency validation ----------
check_dependencies(){
  local missing=() recommended=()

  # Critical dependencies
  [[ -z "$CURL_BIN" ]] && missing+=("curl")
  [[ -z "$DATE_CMD" ]] && missing+=("date")

  # Recommended tools
  [[ -z "$DIALOG" && -z "$FZF" ]] && recommended+=("dialog or fzf (for TUI)")
  [[ -z "$TCPDUMP" && -z "$DUMPCAP" && -z "$TSHARK" ]] && recommended+=("tcpdump/tshark/dumpcap (for PCAP)")
  [[ -z "$ZSTD_BIN" ]] && recommended+=("zstd (for decompression)")
  [[ -z "$SHA256SUM" ]] && recommended+=("sha256sum (for hashing)")
  [[ -z "$READELF" ]] && recommended+=("readelf (for ELF analysis)")
  [[ -z "$XXD" ]] && recommended+=("xxd/hexdump (for hex dumps)")
  [[ -z "$JQ" ]] && recommended+=("jq (for JSON export)")

  if [[ ${#missing[@]} -gt 0 ]]; then
    echo "[ERROR] Missing critical dependencies: ${missing[*]}"
    echo "Please install: ${missing[*]}"
    return 1
  fi

  if [[ ${#recommended[@]} -gt 0 ]]; then
    echo "[WARN] Missing recommended tools: ${recommended[*]}"
    echo "Some features may be limited."
  fi

  return 0
}

TARGETS=()

# ---------- Usage ----------
usage() {
cat <<'USAGE'
Usage:
  ./c2-enum-tui.sh [-o OUTDIR] [--socks HOST:PORT] [--add a.onion,b.onion:9000] [--targets ...]
                   [--no-auto-enum] [--quiet]
                   [--no-pcap] [--pcap-if IFACE] [--pcap-filter 'BPF'] [--pcap-dir DIR]
Notes:
  * Safe by design: downloads are read-only; no execution of remote code.
  * If -o/--outdir is omitted, OUTDIR is auto-derived from the first target (e.g., ./intel_<host>_<UTC-timestamp>).
USAGE
}

# ---------- Arg parsing ----------
while [[ $# -gt 0 ]]; do
  case "$1" in
    -o|--outdir) OUTDIR="$2"; shift 2 ;;
    --socks) SOCKS="$2"; shift 2 ;;
    --add) shift 2 ;;
    --targets) IFS=',' read -r -a TARGETS <<< "$2"; shift 2 ;;
    --no-auto-enum) AUTO_ENUM=false; shift ;;
    --quiet) VERBOSE=false; shift ;;
    --no-pcap) PCAP_ON=false; shift ;;
    --pcap-if) PCAP_IF="$2"; shift 2 ;;
    --pcap-filter) PCAP_FILTER="$2"; shift 2 ;;
    --pcap-dir) PCAP_DIR="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1"; usage; exit 1 ;;
  esac
done

# ---------- Auto-derive OUTDIR when omitted ----------
if [[ -z "${OUTDIR:-}" ]]; then
  EFFECTIVE_TARGETS=()
  if [[ ${#TARGETS[@]} -gt 0 ]]; then
    EFFECTIVE_TARGETS=("${TARGETS[@]}")
  else
    EFFECTIVE_TARGETS=("${KNOWN_TARGETS[@]}")
  fi
  first="${EFFECTIVE_TARGETS[0]}"
  host="$(printf '%s\n' "$first" \
    | awk '{
        gsub(/^https?:\/\//,"");  # drop scheme
        sub(/\/.*/,"");            # drop path
        sub(/:.*/,"");             # drop :port
        h=$0; gsub(/[^A-Za-z0-9._-]/,"_",h);
        for(i=1;i<=length(h);i++){ c=substr(h,i,1); printf("%s", tolower(c)); }
      }')"
  ts="$($DATE_CMD -u +%Y%m%d-%H%M%S)"
  OUTDIR="$(pwd)/intel_${host}_${ts}"
  echo "[auto] --outdir not provided; using: $OUTDIR"
fi

# ---------- Init ----------
mkdir -p "$OUTDIR"
OUTDIR=$(cd "$OUTDIR" && pwd)
LOG="$OUTDIR/c2-enum.log"; : > "$LOG"
ADV_DIR="$OUTDIR/advanced"; SNAP_DIR="$ADV_DIR/snapshots"; ASSET_DIR="$ADV_DIR/assets"
mkdir -p "$ADV_DIR" "$SNAP_DIR" "$ASSET_DIR"
umask 027

log(){ local ts; ts="$($DATE_CMD -u +'%Y-%m-%dT%H:%M:%SZ')"; printf "[%s] %s\n" "$ts" "$*" | tee -a "$LOG" >/dev/null; }
say(){ if $VERBOSE; then echo -e "$*" | tee -a "$LOG" >/dev/null; else echo -e "$*" >>"$LOG"; fi; }
die(){ log "FATAL: $*"; exit 2; }

[[ -z "$CURL_BIN" ]] && die "curl is required."

# ---------- Net helpers ----------
# Enhanced curl wrappers with retry logic and better error handling
curl_head(){
  local url="$1" output="$2" retries=3 attempt=0
  while [[ $attempt -lt $retries ]]; do
    if "$CURL_BIN" --socks5-hostname "$SOCKS" -I -sS --max-time 30 \
       --connect-timeout 10 "$url" > "$output" 2>>"$LOG"; then
      log "HEAD success: $url"
      return 0
    fi
    ((attempt++))
    [[ $attempt -lt $retries ]] && { log "HEAD retry $attempt/$retries: $url"; sleep 2; }
  done
  log "HEAD failed after $retries attempts: $url"
  return 1
}

curl_range(){
  local url="$1" output="$2" range="${3:-0-8191}" retries=2 attempt=0
  while [[ $attempt -lt $retries ]]; do
    if "$CURL_BIN" --socks5-hostname "$SOCKS" -sS --max-time 60 \
       --connect-timeout 15 -r "$range" -fL "$url" -o "$output" 2>>"$LOG"; then
      log "RANGE success: $url (${range})"
      return 0
    fi
    ((attempt++))
    [[ $attempt -lt $retries ]] && { log "RANGE retry $attempt/$retries: $url"; sleep 3; }
  done
  log "RANGE failed after $retries attempts: $url"
  return 1
}

curl_download(){
  local url="$1" output="$2" retries=3 attempt=0
  while [[ $attempt -lt $retries ]]; do
    if "$CURL_BIN" --socks5-hostname "$SOCKS" -sS --max-time 180 \
       --connect-timeout 20 -fL "$url" -o "$output" 2>>"$LOG"; then
      log "DOWNLOAD success: $url -> $(basename "$output")"
      if [[ -n "$SHA256SUM" && -f "$output" ]]; then
        sha256sum "$output" >> "$OUTDIR/download.hashes.txt"
      fi
      chmod 0444 "$output" 2>/dev/null || true
      return 0
    fi
    ((attempt++))
    [[ $attempt -lt $retries ]] && { log "DOWNLOAD retry $attempt/$retries: $url"; sleep 5; }
  done
  log "DOWNLOAD failed after $retries attempts: $url"
  return 1
}

# Enhanced progress indicator with ETA
progress(){
  local pid="$1" msg="$2" spin='-\|/' i=0 elapsed=0
  while kill -0 "$pid" 2>/dev/null; do
    i=$(( (i+1) % 4 ))
    elapsed=$((elapsed + 1))
    printf "\r[%c] %s (${elapsed}s)" "${spin:$i:1}" "$msg"
    sleep 1
  done
  wait "$pid" 2>/dev/null
  local exit_code=$?
  if [[ $exit_code -eq 0 ]]; then
    printf "\r[✓] %s (${elapsed}s)\n" "$msg"
  else
    printf "\r[✗] %s (failed after ${elapsed}s)\n" "$msg"
  fi
  return $exit_code
}

# Parallel job manager
MAX_JOBS=5
wait_for_jobs(){
  local max="${1:-$MAX_JOBS}"
  while [[ $(jobs -r | wc -l) -ge $max ]]; do
    sleep 0.5
  done
}

# Test .onion reachability before enumeration with port checking
test_onion_reachable(){
  local target="$1" timeout=30
  local host port

  # Parse host and port
  if [[ "$target" == *:* ]]; then
    host="${target%:*}"
    port="${target##*:}"
  else
    host="$target"
    port="80"
  fi

  log "Testing reachability: $target (host=$host port=$port)"
  say "[*] Testing $target..."

  # Try multiple protocols and ports
  local protocols=("http" "https")
  local ports_to_try=("$port")

  # If default port 80, also try common alternatives
  if [[ "$port" == "80" ]]; then
    ports_to_try+=("443" "8080" "8443" "9000" "9001")
  fi

  local success=false
  local working_proto=""
  local working_port=""

  for proto in "${protocols[@]}"; do
    for test_port in "${ports_to_try[@]}"; do
      local test_url="${proto}://${host}"
      [[ "$test_port" != "80" && "$test_port" != "443" ]] && test_url="${test_url}:${test_port}"

      say "  → Trying ${proto}://${host}:${test_port}..."

      if "$CURL_BIN" --socks5-hostname "$SOCKS" -sS --max-time "$timeout" \
         --connect-timeout 15 -I "$test_url/" >/dev/null 2>>"$LOG"; then
        say "[✓] $target is reachable on ${proto}://${host}:${test_port}"
        log "Reachability confirmed: ${proto}://${host}:${test_port}"
        working_proto="$proto"
        working_port="$test_port"
        success=true
        break 2
      fi
    done
  done

  if $success; then
    # Store working protocol and port for later use
    echo "${working_proto}://${host}:${working_port}" > "$OUTDIR/.reachable_${host//[^A-Za-z0-9._-]/_}.txt"
    return 0
  else
    say "[✗] $target is NOT reachable on any tested port/protocol"
    say "    Tested: HTTP/HTTPS on ports ${ports_to_try[*]}"
    log "Reachability failed: $target (all protocols/ports failed)"
    return 1
  fi
}

# Advanced port scanner for .onion addresses
scan_onion_ports(){
  local target="$1"
  local host port

  if [[ "$target" == *:* ]]; then
    host="${target%:*}"
  else
    host="$target"
  fi

  say "[*] Scanning common ports on $host..."

  local common_ports=(
    "80:HTTP"
    "443:HTTPS"
    "8080:HTTP-Alt"
    "8443:HTTPS-Alt"
    "9000:Custom"
    "9001:Tor-Dir"
    "22:SSH"
    "21:FTP"
    "3306:MySQL"
    "5432:PostgreSQL"
    "6379:Redis"
    "27017:MongoDB"
  )

  local scan_results="$OUTDIR/port_scan_${host//[^A-Za-z0-9._-]/_}.txt"
  {
    echo "═══════════════════════════════════════════════════════════"
    echo " Port Scan Results: $host"
    echo " Timestamp: $($DATE_CMD -u +'%Y-%m-%dT%H:%M:%SZ')"
    echo "═══════════════════════════════════════════════════════════"
    echo ""
  } > "$scan_results"

  local open_ports=0
  local closed_ports=0

  for port_info in "${common_ports[@]}"; do
    local port="${port_info%%:*}"
    local service="${port_info##*:}"

    printf "  [*] %-5s (%s)... " "$port" "$service"

    # Try connecting via curl with short timeout
    if timeout 10 "$CURL_BIN" --socks5-hostname "$SOCKS" -sS --max-time 8 \
       --connect-timeout 5 "http://${host}:${port}/" >/dev/null 2>&1; then
      echo "[OPEN]"
      echo "Port $port ($service): OPEN" >> "$scan_results"
      ((open_ports++))
    else
      echo "[CLOSED/FILTERED]"
      echo "Port $port ($service): CLOSED/FILTERED" >> "$scan_results"
      ((closed_ports++))
    fi
  done

  {
    echo ""
    echo "Summary: $open_ports open, $closed_ports closed/filtered"
  } >> "$scan_results"

  say "[✓] Port scan complete: $open_ports open, $closed_ports closed/filtered"
  say "    Results: $scan_results"

  return 0
}

# ---------- PCAP ----------
PCAP_TOOL=""; PCAP_PID=""; PCAP_FILE=""
PCAP_START_TIME=""

detect_pcap_tool(){
  if [[ -n "$TCPDUMP" ]]; then
    PCAP_TOOL="tcpdump"
  elif [[ -n "$DUMPCAP" ]]; then
    PCAP_TOOL="dumpcap"
  elif [[ -n "$TSHARK" ]]; then
    PCAP_TOOL="tshark"
  else
    PCAP_TOOL=""
  fi
}

start_pcap(){
  detect_pcap_tool
  if [[ -z "$PCAP_TOOL" ]]; then
    say "[✗] PCAP: No capture tool found (tcpdump/dumpcap/tshark)"
    say "    Install: apt-get install tcpdump  OR  apt-get install wireshark-common"
    return 1
  fi

  # Check if already running
  if [[ -n "$PCAP_PID" ]] && kill -0 "$PCAP_PID" 2>/dev/null; then
    say "[!] PCAP already running (PID: $PCAP_PID)"
    return 0
  fi

  if [[ -z "${PCAP_DIR:-}" ]]; then PCAP_DIR="$OUTDIR/pcap"; fi
  mkdir -p "$PCAP_DIR"

  local ts; ts="$($DATE_CMD -u +'%Y%m%d-%H%M%S')"
  PCAP_FILE="$PCAP_DIR/c2-enum-${ts}.pcap"
  PCAP_START_TIME=$(date +%s)

  say "[*] Starting PCAP capture..."
  say "    Tool:   $PCAP_TOOL"
  say "    Iface:  $PCAP_IF"
  say "    Filter: $PCAP_FILTER"
  say "    Output: $PCAP_FILE"

  case "$PCAP_TOOL" in
    tcpdump)
      ( "$TCPDUMP" -i "$PCAP_IF" -U -s 0 -w "$PCAP_FILE" "$PCAP_FILTER" ) >/dev/null 2>&1 & PCAP_PID=$!
      ;;
    dumpcap)
      ( "$DUMPCAP" -i "$PCAP_IF" -s 0 -f "$PCAP_FILTER" -w "$PCAP_FILE" ) >/dev/null 2>&1 & PCAP_PID=$!
      ;;
    tshark)
      ( "$TSHARK" -i "$PCAP_IF" -f "$PCAP_FILTER" -w "$PCAP_FILE" ) >/dev/null 2>&1 & PCAP_PID=$!
      ;;
  esac

  sleep 1
  if ! kill -0 "$PCAP_PID" 2>/dev/null; then
    say "[✗] PCAP: Failed to start (check permissions or interface)"
    say "    Try: sudo setcap cap_net_raw,cap_net_admin=eip /usr/sbin/tcpdump"
    PCAP_FILE=""
    PCAP_PID=""
    return 1
  fi

  say "[✓] PCAP: Capture started (PID: $PCAP_PID)"
  log "PCAP started: tool=$PCAP_TOOL pid=$PCAP_PID file=$PCAP_FILE"
  return 0
}

stop_pcap(){
  if [[ -n "$PCAP_PID" ]] && kill -0 "$PCAP_PID" 2>/dev/null; then
    local duration=0
    if [[ -n "$PCAP_START_TIME" ]]; then
      duration=$(( $(date +%s) - PCAP_START_TIME ))
    fi

    say "[*] Stopping PCAP capture (PID: $PCAP_PID, duration: ${duration}s)..."
    kill "$PCAP_PID" 2>/dev/null || true
    wait "$PCAP_PID" 2>/dev/null || true

    if [[ -f "$PCAP_FILE" ]]; then
      local filesize=$(stat -f%z "$PCAP_FILE" 2>/dev/null || stat -c%s "$PCAP_FILE" 2>/dev/null || echo "unknown")
      say "[✓] PCAP stopped: $PCAP_FILE (${filesize} bytes)"
      log "PCAP stopped: file=$PCAP_FILE size=$filesize duration=${duration}s"
    else
      say "[✗] PCAP stopped but file not found"
    fi
  else
    say "[!] PCAP not running"
  fi

  PCAP_PID=""
}

pcap_status(){
  if [[ -n "$PCAP_PID" ]] && kill -0 "$PCAP_PID" 2>/dev/null; then
    local duration=0
    if [[ -n "$PCAP_START_TIME" ]]; then
      duration=$(( $(date +%s) - PCAP_START_TIME ))
    fi
    echo "ON (PID: $PCAP_PID, tool: $PCAP_TOOL, duration: ${duration}s)"
  else
    echo "OFF"
  fi
}

pcap_stats(){
  if [[ -z "$PCAP_FILE" || ! -f "$PCAP_FILE" ]]; then
    say "No PCAP file available"
    return 1
  fi

  say "=== PCAP Statistics ==="
  say "File: $PCAP_FILE"

  local filesize
      filesize=$(stat -f%z "$PCAP_FILE" 2>/dev/null || stat -c%s "$PCAP_FILE" 2>/dev/null || echo "unknown")
      say "Size: $filesize bytes"

  if [[ -n "$TSHARK" ]]; then
    say ""
    say "Packet count:"
    "$TSHARK" -r "$PCAP_FILE" -q -z io,stat,0 2>/dev/null | grep -E 'Frames|Bytes' || true
  elif [[ -n "$TCPDUMP" ]]; then
    say ""
    say "Quick peek (first 20 packets):"
    "$TCPDUMP" -nn -r "$PCAP_FILE" -c 20 2>/dev/null || true
  fi
}

trap 'stop_pcap' EXIT INT TERM

# ---------- Core enumeration ----------
COMMON_PATHS=(
  "/robots.txt"
  "/favicon.ico"
  "/static/docker-init.sh"
  "/index.php"
  "/index.html"
  "/api/status"
  "/api/v1/status"
  "/.git/config"
  "/.git/HEAD"
  "/admin"
  "/status"
  "/health"
  "/.well-known/security.txt"
  "/sitemap.xml"
  "/crossdomain.xml"
  "/.env"
  "/config.json"
  "/package.json"
)

enumerate_target(){
  local T="$1"
  local safe_base
  safe_base="${T//[^A-Za-z0-9._-]/_}"
  safe_base="$OUTDIR/$safe_base"
  local enum_start
  enum_start=$(date +%s)

  # Save URL context for orchestrator and analyzers
  echo "http://$T" > "$OUTDIR/.target_url"
  echo "$T" > "$OUTDIR/.target_domain"
  log "Saved URL context for target: $T"

  say ""
  say "╔════════════════════════════════════════════════════════════════╗"
  say "║ Enumerating: $T"
  say "╚════════════════════════════════════════════════════════════════╝"

  # Test reachability first
  if ! test_onion_reachable "$T"; then
    say "[!] Target unreachable, skipping detailed enumeration"
    return 1
  fi

  # Root page with progress
  say "[*] Fetching root page..."
  { curl_head "http://$T/" "${safe_base}_root.head"; } & progress $! "HEAD /"
  { curl_range "http://$T/" "${safe_base}_root.sample" "0-16383"; } & progress $! "SAMPLE / (16KB)"

  # Common paths with parallel processing
  say "[*] Probing common paths (${#COMMON_PATHS[@]} paths)..."
  local p sp path_count=0
  for p in "${COMMON_PATHS[@]}"; do
    sp="$OUTDIR/$(echo "${T}${p}" | sed 's/[^A-Za-z0-9._-]/_/g')"

    wait_for_jobs 8  # Limit parallel jobs

    { curl_head "http://$T${p}" "${sp}.head" && \
      curl_range "http://$T${p}" "${sp}.sample" "0-8191"; } &
    progress $! "Probe ${p}"

    ((path_count++))
  done

  wait  # Wait for all path probes to complete
  say "[✓] Path probing complete ($path_count paths)"

  # Binary artifacts
  say "[*] Attempting to fetch binary artifacts..."
  local baseurl host port
  if [[ "$T" == *:* ]]; then
    host="${T%:*}"
    port="${T##*:}"
    baseurl="http://${host}:${port}/binary"
  else
    baseurl="http://${T}/binary"
  fi

  local arch arch_count=0
  mapfile -t archs < <(printf "%s\n" "x86_64" "amd64" "arm64" "aarch64" "$(uname -m)" | sort -u)

  for arch in "${archs[@]}"; do
    wait_for_jobs 3

    local artifact
    artifact="$OUTDIR/$(echo "${T}_system-linux-${arch}.zst" | sed 's/[^A-Za-z0-9._-]/_/g')"
    { curl_download "${baseurl}/system-linux-${arch}.zst" "$artifact"; } &
    progress $! "Artifact ${arch}"

    ((arch_count++))
  done

  wait  # Wait for all downloads
  say "[✓] Artifact fetch complete ($arch_count architectures attempted)"

  local enum_duration=$(( $(date +%s) - enum_start ))
  say "[✓] Enumeration complete for $T (${enum_duration}s)"
  log "Enumeration completed: target=$T duration=${enum_duration}s"
}

build_report(){
  local REPORT="$OUTDIR/report.txt"; : > "$REPORT"
  {
    echo "C2 Enumeration Report"
    echo "Generated: $($DATE_CMD -u +'%Y-%m-%dT%H:%M:%SZ')"
    echo "SOCKS: $SOCKS"
    echo "Targets: ${TARGETS[*]}"
    echo "PCAP status: $(pcap_status)"
    echo
    echo "---- Root headers ----"
    for f in "$OUTDIR"/*_root.head; do
      [[ -f "$f" ]] || continue
      echo "File: $(basename "$f")"
      sed -n '1,200p' "$f"
      echo
    done
    echo "---- Small samples ----"
    for f in "$OUTDIR"/*.sample; do
      [[ -f "$f" ]] || continue
      echo "File: $(basename "$f")"
      sed -n '1,60p' "$f"
      echo
    done
  } >> "$REPORT"
  echo "$REPORT"
}

# ---------- Static analysis ----------
static_analysis(){
  local OUT="$OUTDIR/static_analysis.txt"; : > "$OUT"
  local analysis_start
  analysis_start=$(date +%s)

  say "[*] Running static analysis..."

  {
    echo "═══════════════════════════════════════════════════════════"
    echo " Static Analysis Report"
    echo " Generated: $($DATE_CMD -u +'%Y-%m-%dT%H:%M:%SZ')"
    echo "═══════════════════════════════════════════════════════════"
    echo ""
  } >> "$OUT"

  shopt -s nullglob
  local f file_count=0

  # Analyze compressed artifacts
  for f in "$OUTDIR"/*system-linux-*.zst "$OUTDIR"/*system*.zst "$OUTDIR"/*system*; do
    [[ -e "$f" ]] || continue
    ((file_count++))

    {
      echo "┌─────────────────────────────────────────────────────────────"
      echo "│ File: $(basename "$f")"
      echo "└─────────────────────────────────────────────────────────────"
      echo ""
    } >> "$OUT"

    # File magic
    if [[ -n "$FILECMD" ]]; then
      echo "[*] File type:" >> "$OUT"
      "$FILECMD" -b "$f" >> "$OUT" 2>>"$LOG" || echo "  (detection failed)" >> "$OUT"
      echo "" >> "$OUT"
    fi

    # Hash
    if [[ -n "$SHA256SUM" ]]; then
      echo "[*] SHA256:" >> "$OUT"
      sha256sum "$f" | awk '{print "  "$1}' >> "$OUT" 2>>"$LOG" || true
      echo "" >> "$OUT"
    fi

    # File size
    local size
    size=$(stat -f%z "$f" 2>/dev/null || stat -c%s "$f" 2>/dev/null || echo "unknown")
    echo "[*] Size: $size bytes" >> "$OUT"
    echo "" >> "$OUT"

    # Zstd-specific analysis
    if [[ "$f" =~ \.zst$ && -n "$ZSTD_BIN" ]]; then
      echo "[*] Zstandard compression info:" >> "$OUT"
      "$ZSTD_BIN" -l "$f" 2>>"$LOG" | sed 's/^/  /' >> "$OUT" || echo "  (analysis failed)" >> "$OUT"
      echo "" >> "$OUT"

      # Test decompression
      echo "[*] Decompression test:" >> "$OUT"
      if "$ZSTD_BIN" -t "$f" 2>>"$LOG"; then
        echo "  ✓ Archive integrity OK" >> "$OUT"
      else
        echo "  ✗ Archive corruption detected" >> "$OUT"
      fi
      echo "" >> "$OUT"
    fi

    echo "" >> "$OUT"
  done

  # Analyze any decompressed binaries
  for f in "$OUTDIR"/*.bin; do
    [[ -f "$f" ]] || continue
    ((file_count++))

    {
      echo "┌─────────────────────────────────────────────────────────────"
      echo "│ Binary: $(basename "$f")"
      echo "└─────────────────────────────────────────────────────────────"
      echo ""
    } >> "$OUT"

    # File type
    if [[ -n "$FILECMD" ]]; then
      echo "[*] File type:" >> "$OUT"
      "$FILECMD" -b "$f" >> "$OUT" 2>>"$LOG" || true
      echo "" >> "$OUT"
    fi

    # SHA256
    if [[ -n "$SHA256SUM" ]]; then
      echo "[*] SHA256:" >> "$OUT"
      sha256sum "$f" | awk '{print "  "$1}' >> "$OUT" 2>>"$LOG" || true
      echo "" >> "$OUT"
    fi

    # ELF analysis
    if [[ -n "$READELF" ]]; then
      echo "[*] ELF Header:" >> "$OUT"
      "$READELF" -h "$f" 2>>"$LOG" | grep -E 'Class|Data|Machine|Version|Entry|Type' | sed 's/^/  /' >> "$OUT" || true
      echo "" >> "$OUT"

      echo "[*] Program Headers:" >> "$OUT"
      "$READELF" -l "$f" 2>>"$LOG" | head -n 30 | sed 's/^/  /' >> "$OUT" || true
      echo "" >> "$OUT"

      echo "[*] Dynamic Section:" >> "$OUT"
      "$READELF" -d "$f" 2>>"$LOG" | head -n 40 | sed 's/^/  /' >> "$OUT" || true
      echo "" >> "$OUT"
    fi

    # Symbols (if available)
    if [[ -n "$NM" ]]; then
      echo "[*] Symbols (top 50):" >> "$OUT"
      "$NM" -D "$f" 2>>"$LOG" | head -n 50 | sed 's/^/  /' >> "$OUT" || echo "  (no dynamic symbols)" >> "$OUT"
      echo "" >> "$OUT"
    fi

    # Strings analysis
    if [[ -n "$STRINGS" ]]; then
      echo "[*] Interesting strings:" >> "$OUT"
      "$STRINGS" -n 8 "$f" 2>>"$LOG" | \
        grep -Ei 'http|https|onion|tor|socks|proxy|curl|wget|ssh|/tmp|/var|/etc|password|key|token|api|admin|debug|error|warning|version|build' | \
        sort -u | head -n 100 | sed 's/^/  /' >> "$OUT" || echo "  (none found)" >> "$OUT"
      echo "" >> "$OUT"
    fi

    echo "" >> "$OUT"
  done

  shopt -u nullglob

  local analysis_duration=$(( $(date +%s) - analysis_start ))
  {
    echo "═══════════════════════════════════════════════════════════"
    echo "Analysis complete: $file_count files analyzed in ${analysis_duration}s"
    echo "═══════════════════════════════════════════════════════════"
  } >> "$OUT"

  say "[✓] Static analysis complete ($file_count files, ${analysis_duration}s)"
  log "Static analysis completed: files=$file_count duration=${analysis_duration}s"
  echo "$OUT"
}

decompress_artifacts(){
  if [[ -z "$ZSTD_BIN" ]]; then say "zstd missing; cannot decompress."; return 0; fi
  shopt -s nullglob
  local f outbin
  for f in "$OUTDIR"/*.zst; do
    [[ -f "$f" ]] || continue
    outbin="${f%.zst}.bin"
    say "Decompress: $(basename "$f") -> $(basename "$outbin")"
    "$ZSTD_BIN" -d -q -o "$outbin" "$f" 2>>"$LOG" || say "Decompress failed: $f"
    chmod 0444 "$outbin" || true
    if [[ -n "$FILECMD" ]];  then "$FILECMD"  "$outbin" >> "$OUTDIR/static_analysis.txt" 2>>"$LOG" || true; fi
    if [[ -n "$READELF" ]];  then "$READELF" -h "$outbin" >> "$OUTDIR/static_analysis.txt" 2>>"$LOG" || true; fi
    if [[ -n "$STRINGS" ]];  then "$STRINGS" -n 8 "$outbin" | head -n 200 >> "$OUTDIR/static_analysis.txt" 2>>"$LOG" || true; fi
  done
  shopt -u nullglob
}

make_yara_seed(){
  local YARA="$OUTDIR/yara_seed.yar"; : > "$YARA"
  {
    echo "rule suspected_c2_sample {"
    echo "  meta: author=\"c2-enum-tui\" date=\"$($DATE_CMD -u +'%Y-%m-%dT%H:%M:%SZ')\""
    echo "  strings:"
    if [[ -f "$OUTDIR/static_analysis.txt" ]]; then
      grep -Eo '([/:A-Za-z0-9_.-]{6,120})' "$OUTDIR/static_analysis.txt" | sed 's/^\s*//' | sort -u | head -n 12 | nl -ba -w1 -s' ' \
      | while read -r n s; do
          s_esc=$(printf '%s' "$s" | sed 's/\\/\\\\/g; s/"/\\"/g')
          echo "    \$s${n} = \"${s_esc}\" ascii nocase"
        done
    fi
    echo "  condition: any of them"
    echo "}"
  } >> "$YARA"
  echo "$YARA"
}

make_suricata_rule(){
  local RULE="$OUTDIR/suricata_c2_host.rule"
  # quoted heredoc to avoid accidental expansion/redirection issues
  cat <<'EOF' > /tmp/_rule.tpl
alert http any any -> any any (msg:"C2 HTTP host match"; http.host; content:"REPLACE_HOST"; nocase; sid:1000001; rev:1;)
EOF
  sed "s/REPLACE_HOST/${KNOWN_TARGETS[0]//\//\\/}/" /tmp/_rule.tpl > "$RULE"
  rm -f /tmp/_rule.tpl
  echo "$RULE"
}

# ---------- TUI helpers ----------
menu_impl(){
  local title="$1"; shift
  local -a items=("$@")
  local choice=""
  if [[ -n "$DIALOG" ]]; then
    local dlg_items=() item
    for item in "${items[@]}"; do dlg_items+=("$item" "$item"); done
    if "$DIALOG" --clear --stdout --no-tags --title "$title" --menu "$title" 20 92 14 "${dlg_items[@]}" > "$OUTDIR/.choice"; then
      choice=$(cat "$OUTDIR/.choice")
      rm -f "$OUTDIR/.choice"
    fi
  elif [[ -n "$FZF" ]]; then
    choice=$(printf "%s\n" "${items[@]}" | "$FZF" --prompt="$title > " --height=20 --reverse || true)
  else
    echo; echo "$title"; select opt in "${items[@]}"; do choice="$opt"; break; done
  fi
  echo "$choice"
}

file_picker_menu(){
  mapfile -t files < <(find "$OUTDIR" -maxdepth 1 -type f \( -name "*root.head" -o -name "*.head" -o -name "*.sample" -o -name "*.zst" -o -name "*.bin" -o -name "*analysis*.txt" -o -name "report.txt" -o -name "download.hashes.txt" \) | sort)
  if [[ ${#files[@]} -eq 0 ]]; then say "No files yet. Run enumeration first."; return; fi
  local choice; choice=$(menu_impl "Select a file" "${files[@]}"); [[ -z "$choice" ]] && return
  local actions=("View" "Hash" "File-Magic" "ReadELF-Header" "Strings-Top200" "Back")
  while true; do
    local act; act=$(menu_impl "Action for $(basename "$choice")" "${actions[@]}")
    case "$act" in
      "View") "$LESS_BIN" -R "$choice" ;;
      "Hash") [[ -n "$SHA256SUM" ]] && sha256sum "$choice" | tee -a "$OUTDIR/manual.hashes.txt" ;;
      "File-Magic") [[ -n "$FILECMD" ]] && "$FILECMD" "$choice" | tee -a "$OUTDIR/manual.analysis.txt" ;;
      "ReadELF-Header") [[ -n "$READELF" ]] && "$READELF" -h "$choice" | sed -n '1,120p' | tee -a "$OUTDIR/manual.analysis.txt" ;;
      "Strings-Top200") [[ -n "$STRINGS" ]] && "$STRINGS" -n 8 "$choice" | head -n 200 | "$LESS_BIN" -R ;;
      "Back"|*) break ;;
    esac
  done
}

# ---------- Advanced modules ----------
adv_snapshots(){
  local tgt="$1" ts d p
  ts="$($DATE_CMD -u +%Y%m%d-%H%M%S)"; d="$SNAP_DIR/$tgt"
  mkdir -p "$d"
  for p in / /robots.txt /favicon.ico /static/docker-init.sh; do
    curl --socks5-hostname "$SOCKS" -fsSL --max-time 30 -r 0-16383 "http://$tgt$p" -o "$d/snap_${ts}_$(echo "$p"|tr '/' '_').bin" 2>>"$LOG" || true
  done
  if [[ -n "$GIT" ]]; then
    if [[ ! -d "$d/.git" ]]; then (cd "$d" && "$GIT" init -q); fi
    (cd "$d" && "$GIT" add -A && "$GIT" commit -q -m "$ts") || true
  else
    say "WARN: git not found; snapshot diffing disabled."
  fi
  say "Snapshots captured for $tgt -> $d"
}

adv_assets_hash(){
  local tgt="$1" pf
  pf="$ASSET_DIR/${tgt//[^A-Za-z0-9._-]/_}"
  mkdir -p "$pf"
  curl --socks5-hostname "$SOCKS" -fsSL --max-time 20 -r 0-65535 "http://$tgt/favicon.ico" -o "$pf/favicon.ico" 2>>"$LOG" || true
  local j
  for j in docker-init.sh app.js main.js; do
    curl --socks5-hostname "$SOCKS" -fsSL -r 0-8191 "http://$tgt/static/$j" -o "$pf/s_${j}" 2>>"$LOG" || true
  done
  {
    if [[ -n "$SHA256SUM" && -f "$pf/favicon.ico" ]]; then sha256sum "$pf/favicon.ico"; fi
    for f in "$pf"/s_*; do [[ -f "$f" ]] && sha256sum "$f"; done
  } | tee "$pf/asset.hashes" >/dev/null
  say "Asset hashes -> $pf/asset.hashes"
}

adv_header_matrix(){
  local tgt="$1" out
  out="$ADV_DIR/header_matrix_${tgt//[^A-Za-z0-9._-]/_}.txt"; : > "$out"
  local m
  for m in GET POST HEAD; do
    echo "=== $m $tgt ===" >> "$out"
    curl --socks5-hostname "$SOCKS" -sS -X "$m" -I "http://$tgt/" >> "$out" 2>>"$LOG" || true
  done
  echo >> "$out"
  echo "=== Error Fingerprints ===" >> "$out"
  local p
  for p in /nope /admin/../admin '/api/..\\\\'; do
    curl --socks5-hostname "$SOCKS" -sS "http://$tgt$p" -o "$ADV_DIR/resp.bin" -w 'code=%{http_code} size=%{size_download}\n' >> "$out"
    if [[ -n "$XXD" && -f "$ADV_DIR/resp.bin" ]]; then "$XXD" -l 64 -g1 "$ADV_DIR/resp.bin" >> "$out"; fi
    echo >> "$out"
  done
  echo "=== Encodings ===" >> "$out"
  curl --socks5-hostname "$SOCKS" -sS -I --compressed "http://$tgt/" | grep -Ei 'server:|x-powered-by:|content-encoding:|vary:|etag:|cache-control:' >> "$out" || true
  rm -f "$ADV_DIR/resp.bin" 2>/dev/null || true
  say "Header/behavior matrix -> $out"
}

adv_binary_lineage(){
  local out; out="$ADV_DIR/binary_lineage.txt"; : > "$out"
  shopt -s nullglob
  local z
  for z in "$OUTDIR"/*system*.zst; do
    [[ -f "$z" ]] || continue
    echo "== $z ==" >> "$out"
    if [[ -n "$FILECMD" ]]; then "$FILECMD" "$z" >> "$out" 2>>"$LOG" || true; fi
    if [[ -n "$ZSTD_BIN" ]]; then "$ZSTD_BIN" -l "$z" >> "$out" 2>>"$LOG" || true; fi
    local bin; bin="${z%.zst}.bin"
    if [[ ! -f "$bin" && -n "$ZSTD_BIN" ]]; then "$ZSTD_BIN" -d -q -o "$bin" "$z" 2>>"$LOG" || true; chmod 0444 "$bin" || true; fi
    if [[ -f "$bin" ]]; then
      if [[ -n "$FILECMD" ]];  then "$FILECMD"  "$bin" >> "$out" 2>>"$LOG" || true; fi
      if [[ -n "$READELF" ]];  then "$READELF" -h "$bin" | grep -E 'Class|Machine|Version|Entry' >> "$out"; "$READELF" -S "$bin" | head -n 80 >> "$out"; fi
      if [[ -n "$STRINGS" ]];  then "$STRINGS" -n 8 "$bin" | grep -Ei 'Go build ID|runtime\.main|GLIBC_|libssl|curl|socks5|http/' | head -n 200 >> "$out" || true; fi
      if [[ -n "$READELF" ]];  then local sec; for sec in .text .rodata .data .rdata .bss; do "$READELF" -x "$sec" "$bin" 2>/dev/null | sha256sum >> "$out" || true; done; fi
    fi
    echo >> "$out"
  done
  shopt -u nullglob
  say "Binary lineage -> $out"
}

adv_pcap_summaries(){
  if [[ -z "${PCAP_FILE:-}" || ! -f "$PCAP_FILE" ]]; then say "No active pcap file to summarize."; return 0; fi
  local out; out="$ADV_DIR/pcap_summary.txt"; : > "$out"
  if [[ -n "$TCPDUMP" ]]; then
    echo "=== tcpdump peek (first 60 matches) ===" >> "$out"
    "$TCPDUMP" -nn -r "$PCAP_FILE" 'tcp and (port 9050 or 9150 or 9000)' -tttt -c 60 >> "$out" 2>>"$LOG" || true
  fi
  if [[ -n "$TSHARK" ]]; then
    {
        echo ""
        echo "=== tshark conversations (TCP) ==="
    } >> "$out"
    "$TSHARK" -r "$PCAP_FILE" -q -z conv,tcp >> "$out" 2>>"$LOG" || true
    {
        echo ""
        echo "=== SYN timing histogram (sec) ==="
    } >> "$out"
    "$TSHARK" -r "$PCAP_FILE" -T fields -e frame.time_epoch -e ip.src -e tcp.dstport -Y 'tcp.flags.syn==1' 2>>"$LOG" \
      | awk '{printf "%.0f\n",$1}' | sort | uniq -c | sort -nr | head >> "$out"
  else
    echo "WARN: tshark not present; limited pcap summaries." >> "$out"
  fi
  say "PCAP summaries -> $out"
}

pcap_menu(){
  local items=("Start" "Stop" "Show-Status" "Show-Statistics" "Show-PCAP-Path" "Summarize-PCAP" "List-All-PCAPs" "Back")
  while true; do
    echo ""
    echo "Current PCAP: $(pcap_status)"
    echo ""

    local act; act=$(menu_impl "PCAP Capture Controls" "${items[@]}")
    case "$act" in
      "Start")
        start_pcap
        ;;
      "Stop")
        stop_pcap
        ;;
      "Show-Status")
        say "═══ PCAP Status ═══"
        say "Status: $(pcap_status)"
        say "Tool:   ${PCAP_TOOL:-none}"
        say "Iface:  $PCAP_IF"
        say "Filter: $PCAP_FILTER"
        [[ -n "$PCAP_FILE" ]] && say "File:   $PCAP_FILE"
        echo ""
        echo "Press Enter to continue..."
        read -r
        ;;
      "Show-Statistics")
        pcap_stats
        echo ""
        echo "Press Enter to continue..."
        read -r
        ;;
      "Show-PCAP-Path")
        if [[ -n "${PCAP_FILE:-}" ]]; then
          echo "Current PCAP: $PCAP_FILE"
        else
          echo "No active PCAP file"
        fi
        echo ""
        echo "Press Enter to continue..."
        read -r
        ;;
      "Summarize-PCAP")
        adv_pcap_summaries
        ;;
      "List-All-PCAPs")
        if [[ -d "$PCAP_DIR" ]]; then
          say "═══ All PCAP files ═══"
          find "$PCAP_DIR" -name "*.pcap" -o -name "*.pcapng" | while read -r f; do
            local sz
            sz=$(stat -f%z "$f" 2>/dev/null || stat -c%s "$f" 2>/dev/null || echo "?")
            echo "  $(basename "$f") - $sz bytes"
          done
          echo ""
          echo "Press Enter to continue..."
          read -r
        else
          say "No PCAP directory found"
        fi
        ;;
      "Back"|*)
        break
        ;;
    esac
  done
}

# ---------- Dashboard ----------
show_dashboard(){
  clear
  print_classification_banner_top

  echo -e "${TEMPEST_CYAN}${BOLD}"
  echo "┌──────────────────────────────────────────────────────────────────────────────┐"
  echo "│                        OPERATIONAL STATUS DASHBOARD                          │"
  echo "└──────────────────────────────────────────────────────────────────────────────┘"
  echo -e "${NC}"

  # Session Info
  print_section_header "SESSION INFORMATION"
  echo -e "  ${TEMPEST_GRAY}OUTDIR:${NC}     ${TEMPEST_WHITE}$OUTDIR${NC}"
  echo -e "  ${TEMPEST_GRAY}OPERATOR:${NC}   ${TEMPEST_GREEN}$OPERATOR_ID${NC}"
  echo -e "  ${TEMPEST_GRAY}SESSION:${NC}    ${TEMPEST_AMBER}$SESSION_ID${NC}"
  echo -e "  ${TEMPEST_GRAY}SOCKS:${NC}      ${TEMPEST_WHITE}$SOCKS${NC}"
  echo ""

  # Targets
  print_section_header "ACTIVE TARGETS (${#TARGETS[@]})"
  local idx=1
  for t in "${TARGETS[@]}"; do
    echo -e "  ${TEMPEST_AMBER}$idx)${NC} ${TEMPEST_WHITE}$t${NC}"
    ((idx++))
  done
  echo ""

  # Files Collected
  print_section_header "COLLECTED INTELLIGENCE"
  local head_files sample_files zst_files bin_files
  head_files=$(find "$OUTDIR" -maxdepth 1 -name "*.head" 2>/dev/null | wc -l)
  sample_files=$(find "$OUTDIR" -maxdepth 1 -name "*.sample" 2>/dev/null | wc -l)
  zst_files=$(find "$OUTDIR" -maxdepth 1 -name "*.zst" 2>/dev/null | wc -l)
  bin_files=$(find "$OUTDIR" -maxdepth 1 -name "*.bin" 2>/dev/null | wc -l)

  echo -e "  ${TEMPEST_CYAN}Headers:${NC}    ${TEMPEST_WHITE}$head_files${NC}"
  echo -e "  ${TEMPEST_CYAN}Samples:${NC}    ${TEMPEST_WHITE}$sample_files${NC}"
  echo -e "  ${TEMPEST_CYAN}Archives:${NC}   ${TEMPEST_WHITE}$zst_files${NC}"
  echo -e "  ${TEMPEST_CYAN}Binaries:${NC}   ${TEMPEST_WHITE}$bin_files${NC}"
  echo ""

  # Reports Status
  print_section_header "REPORT STATUS"
  if [[ -f "$OUTDIR/report.txt" ]]; then
    echo -e "  ${TEMPEST_GREEN}${SYM_SUCCESS}${NC} Main report"
  else
    echo -e "  ${TEMPEST_GRAY}${SYM_INACTIVE}${NC} Main report"
  fi
  if [[ -f "$OUTDIR/static_analysis.txt" ]]; then
    echo -e "  ${TEMPEST_GREEN}${SYM_SUCCESS}${NC} Static analysis"
  else
    echo -e "  ${TEMPEST_GRAY}${SYM_INACTIVE}${NC} Static analysis"
  fi
  if [[ -f "$OUTDIR/yara_seed.yar" ]]; then
    echo -e "  ${TEMPEST_GREEN}${SYM_SUCCESS}${NC} YARA seed"
  else
    echo -e "  ${TEMPEST_GRAY}${SYM_INACTIVE}${NC} YARA seed"
  fi
  if [[ -f "$OUTDIR/suricata_c2_host.rule" ]]; then
    echo -e "  ${TEMPEST_GREEN}${SYM_SUCCESS}${NC} Suricata rule"
  else
    echo -e "  ${TEMPEST_GRAY}${SYM_INACTIVE}${NC} Suricata rule"
  fi
  if [[ -f "$OUTDIR/c2-enum-report.json" ]]; then
    echo -e "  ${TEMPEST_GREEN}${SYM_SUCCESS}${NC} JSON export"
  else
    echo -e "  ${TEMPEST_GRAY}${SYM_INACTIVE}${NC} JSON export"
  fi
  echo ""

  # PCAP Status
  print_section_header "PCAP CAPTURE"
  echo -e "  ${TEMPEST_CYAN}Status:${NC}  ${TEMPEST_WHITE}$(pcap_status)${NC}"
  if [[ -n "$PCAP_FILE" && -f "$PCAP_FILE" ]]; then
    local pcap_sz
    pcap_sz=$(stat -f%z "$PCAP_FILE" 2>/dev/null || stat -c%s "$PCAP_FILE" 2>/dev/null || echo "?")
    echo -e "  ${TEMPEST_CYAN}Size:${NC}    ${TEMPEST_WHITE}$pcap_sz bytes${NC}"
  fi
  echo ""

  # Disk Usage
  print_section_header "STORAGE"
  echo -e "  ${TEMPEST_CYAN}Usage:${NC}   ${TEMPEST_WHITE}$(du -sh "$OUTDIR" 2>/dev/null | cut -f1 || echo 'N/A')${NC}"
  echo ""

  print_classification_banner_bottom
  echo -e "${TEMPEST_WHITE}Press Enter to continue...${NC}"
  read -r
}

advanced_menu(){
  while true; do
    clear
    print_classification_banner_top

    echo -e "${TEMPEST_CYAN}${BOLD}"
    echo "┌──────────────────────────────────────────────────────────────────────────────┐"
    echo "│                      ADVANCED ANALYSIS OPERATIONS                            │"
    echo "└──────────────────────────────────────────────────────────────────────────────┘"
    echo -e "${NC}"

    echo -e "${TEMPEST_CYAN}┌─────────────────────┤ ${TEMPEST_AMBER}DISCOVERY & SCANNING${TEMPEST_CYAN} ├────────────────────────────┐${NC}"
    tempest_menu_item "1" "KP14 Auto-Discovery (hidden endpoints)"
    tempest_menu_item "2" "Port Scanner"
    tempest_menu_item "3" "Deep Scan (all modules on target)"
    echo ""

    echo -e "${TEMPEST_CYAN}┌─────────────────────┤ ${TEMPEST_AMBER}FORENSIC ANALYSIS${TEMPEST_CYAN} ├──────────────────────────────┐${NC}"
    tempest_menu_item "4" "Differential Snapshots"
    tempest_menu_item "5" "Asset Hash Correlation"
    tempest_menu_item "6" "Header Fingerprint Matrix"
    tempest_menu_item "7" "Binary Lineage Analysis"
    tempest_menu_item "8" "Certificate Analysis"
    echo ""

    echo -e "${TEMPEST_CYAN}┌─────────────────────┤ ${TEMPEST_AMBER}PROTOCOL & TRAFFIC${TEMPEST_CYAN} ├──────────────────────────────┐${NC}"
    tempest_menu_item "9" "PCAP Deep Analysis"
    tempest_menu_item "P" "Protocol Analysis"
    tempest_menu_item "T" "Traffic Capture"
    echo ""

    echo -e "${TEMPEST_CYAN}┌─────────────────────┤ ${TEMPEST_AMBER}TAKEOVER OPERATIONS${TEMPEST_CYAN} ├─────────────────────────────┐${NC}"
    tempest_menu_item "S" "Sinkhole Server" "SEC"
    tempest_menu_item "C" "Cleanup Generator" "SEC"
    tempest_menu_item "B" "BGP Hijack Enforcement" "SEC"
    echo ""

    tempest_menu_item "X" "Return to Main Menu"
    echo ""

    print_classification_banner_bottom
    echo -e "${TEMPEST_WHITE}SELECT OPERATION: ${NC}"
    read -r act

    audit_log "AUDIT" "Advanced menu selection: $act"

    case "$act" in
      "1")
        print_section_header "KP14 AUTO-DISCOVERY"
        echo -e "${TEMPEST_AMBER}Analyze files for hidden C2 endpoints${NC}"
        echo ""
        echo -e "${TEMPEST_WHITE}Source: 1) Current OUTDIR  2) Custom${NC}"
        read -r choice

        scan_dir="$OUTDIR"
        if [[ "$choice" == "2" ]]; then
          echo -e "${TEMPEST_WHITE}Enter directory path:${NC} "
          read -r scan_dir
        fi

        if [[ -d "$scan_dir" ]]; then
          kp14_script="$(dirname "$0")/analyzers/kp14-autodiscover.sh"
          [[ ! -f "$kp14_script" ]] && kp14_script="/home/c2enum/toolkit/analyzers/kp14-autodiscover.sh"

          if [[ -f "$kp14_script" ]]; then
            audit_log "INFO" "KP14 auto-discovery: $scan_dir"
            bash "$kp14_script" "$scan_dir" "$scan_dir/kp14_discovery"

            if [[ -f "$scan_dir/kp14_discovery/discovered_endpoints.txt" ]]; then
              count=$(wc -l < "$scan_dir/kp14_discovery/discovered_endpoints.txt" 2>/dev/null || echo 0)
              if [[ $count -gt 0 ]]; then
                echo -e "${TEMPEST_GREEN}${SYM_SUCCESS} Discovered $count hidden endpoint(s)!${NC}"
                cat "$scan_dir/kp14_discovery/discovered_endpoints.txt"
                echo -e "${TEMPEST_WHITE}Add to target list? (y/N):${NC} "
                read -r add_choice
                if [[ "$add_choice" =~ ^[Yy]$ ]]; then
                  while read -r line; do
                    endpoint=$(echo "$line" | awk '{print $1}')
                    [[ "$endpoint" =~ \.onion ]] && TARGETS+=("$endpoint")
                  done < "$scan_dir/kp14_discovery/discovered_endpoints.txt"
                fi
              else
                echo -e "${TEMPEST_YELLOW}${SYM_WARNING} No hidden endpoints discovered${NC}"
              fi
            fi
          else
            echo -e "${TEMPEST_RED}${SYM_FAILURE} KP14 script not found${NC}"
          fi
        else
          echo -e "${TEMPEST_RED}${SYM_FAILURE} Directory not found${NC}"
        fi
        echo -e "${TEMPEST_WHITE}Press Enter to continue...${NC}"
        read -r
        ;;

      "2")
        local tgt; tgt=$(menu_impl "Pick target for port scan" "${TARGETS[@]}")
        if [[ -n "$tgt" ]]; then
          audit_log "INFO" "Port scan: $tgt"
          scan_onion_ports "$tgt"
          echo -e "${TEMPEST_WHITE}Press Enter to continue...${NC}"
          read -r
        fi
        ;;

      "3")
        local tgt; tgt=$(menu_impl "Pick target for deep scan" "${TARGETS[@]}")
        if [[ -n "$tgt" ]]; then
          audit_log "INFO" "Deep scan initiated: $tgt"
          scan_onion_ports "$tgt"
          adv_snapshots "$tgt"
          adv_assets_hash "$tgt"
          adv_header_matrix "$tgt"
          adv_binary_lineage
          adv_cert_analysis "$tgt"
          echo -e "${TEMPEST_GREEN}${SYM_SUCCESS} Deep scan complete${NC}"
          echo -e "${TEMPEST_WHITE}Press Enter to continue...${NC}"
          read -r
        fi
        ;;

      "4")
        local tgt; tgt=$(menu_impl "Pick target" "${TARGETS[@]}")
        [[ -n "$tgt" ]] && adv_snapshots "$tgt"
        echo -e "${TEMPEST_WHITE}Press Enter to continue...${NC}"
        read -r
        ;;

      "5")
        local tgt; tgt=$(menu_impl "Pick target" "${TARGETS[@]}")
        [[ -n "$tgt" ]] && adv_assets_hash "$tgt"
        echo -e "${TEMPEST_WHITE}Press Enter to continue...${NC}"
        read -r
        ;;

      "6")
        local tgt; tgt=$(menu_impl "Pick target" "${TARGETS[@]}")
        [[ -n "$tgt" ]] && adv_header_matrix "$tgt"
        echo -e "${TEMPEST_WHITE}Press Enter to continue...${NC}"
        read -r
        ;;

      "7")
        adv_binary_lineage
        echo -e "${TEMPEST_WHITE}Press Enter to continue...${NC}"
        read -r
        ;;

      "8")
        local tgt; tgt=$(menu_impl "Pick target" "${TARGETS[@]}")
        [[ -n "$tgt" ]] && adv_cert_analysis "$tgt"
        ;;

      "9")
        adv_pcap_summaries
        echo -e "${TEMPEST_WHITE}Press Enter to continue...${NC}"
        read -r
        ;;

      "P"|"p")
        print_section_header "PROTOCOL ANALYSIS"
        echo -e "${TEMPEST_WHITE}Enter path to binary sample:${NC} "
        read -r binary_path

        if [[ -f "$binary_path" ]]; then
          echo -e "${TEMPEST_WHITE}Output directory [protocol_analysis_$(date +%Y%m%d_%H%M%S)]:${NC} "
          read -r output_dir
          output_dir="${output_dir:-protocol_analysis_$(date +%Y%m%d_%H%M%S)}"

          protocol_script="$(dirname "$0")/analyzers/protocol-analysis.sh"
          if [[ -x "$protocol_script" ]]; then
            audit_log "INFO" "Protocol analysis: $binary_path"
            bash "$protocol_script" "$binary_path" "$output_dir"
            echo -e "${TEMPEST_GREEN}${SYM_SUCCESS} Analysis complete: $output_dir${NC}"
          else
            echo -e "${TEMPEST_RED}${SYM_FAILURE} Protocol analysis script not found${NC}"
          fi
        else
          echo -e "${TEMPEST_RED}${SYM_FAILURE} Binary file not found${NC}"
        fi
        echo -e "${TEMPEST_WHITE}Press Enter to continue...${NC}"
        read -r
        ;;

      "T"|"t")
        print_section_header "TRAFFIC CAPTURE"
        echo -e "${TEMPEST_WHITE}Mode: 1) IP  2) Domain  3) Analyze PCAP${NC}"
        read -r capture_mode

        capture_script="$(dirname "$0")/analyzers/c2-traffic-capture.sh"
        case "$capture_mode" in
          1|2)
            echo -e "${TEMPEST_WHITE}Enter target:${NC} "
            read -r target
            echo -e "${TEMPEST_WHITE}Duration (seconds) [60]:${NC} "
            read -r duration
            duration="${duration:-60}"
            audit_log "INFO" "Traffic capture: $target for ${duration}s"

            if [[ "$capture_mode" == "1" ]]; then
              bash "$capture_script" --target-ip "$target" --duration "$duration" --output "./traffic_$(date +%Y%m%d_%H%M%S)" 2>&1 || true
            else
              bash "$capture_script" --target-domain "$target" --duration "$duration" --output "./traffic_$(date +%Y%m%d_%H%M%S)" 2>&1 || true
            fi
            ;;
          3)
            echo -e "${TEMPEST_WHITE}PCAP file path:${NC} "
            read -r pcap_file
            [[ -f "$pcap_file" ]] && bash "$capture_script" --analyze "$pcap_file" --output "./analysis_$(date +%Y%m%d_%H%M%S)" 2>&1 || echo -e "${TEMPEST_RED}${SYM_FAILURE} File not found${NC}"
            ;;
        esac
        echo -e "${TEMPEST_WHITE}Press Enter to continue...${NC}"
        read -r
        ;;

      "S"|"s")
        print_section_header "SINKHOLE SERVER"
        echo -e "${TEMPEST_RED}${BOLD}${SYM_CLASSIFIED} LAW ENFORCEMENT ONLY ${SYM_CLASSIFIED}${NC}"
        echo -e "${TEMPEST_WHITE}Legal authorization confirmed? (yes/NO):${NC} "
        read -r auth_confirm

        if [[ "$auth_confirm" == "yes" ]]; then
          audit_log "SEC" "Sinkhole server authorized"
          echo -e "${TEMPEST_WHITE}Cleanup payload path:${NC} "
          read -r cleanup_path

          if [[ -f "$cleanup_path" ]]; then
            echo -e "${TEMPEST_WHITE}Phase (1-4) [1]:${NC} "
            read -r phase
            python3 "$(dirname "$0")/takeover/sinkhole-server.py" --cleanup "$cleanup_path" --phase "${phase:-1}" --legal-ack 2>&1 || true
          fi
        fi
        echo -e "${TEMPEST_WHITE}Press Enter to continue...${NC}"
        read -r
        ;;

      "C"|"c")
        print_section_header "CLEANUP GENERATOR"
        echo -e "${TEMPEST_RED}${BOLD}${SYM_CLASSIFIED} LAW ENFORCEMENT ONLY ${SYM_CLASSIFIED}${NC}"
        echo -e "${TEMPEST_WHITE}Legal authorization confirmed? (yes/NO):${NC} "
        read -r auth_confirm

        if [[ "$auth_confirm" == "yes" ]]; then
          audit_log "SEC" "Cleanup generator authorized"
          echo -e "${TEMPEST_WHITE}Platform (windows/linux) [windows]:${NC} "
          read -r platform
          platform="${platform:-windows}"

          python3 "$(dirname "$0")/takeover/cleanup-generator.py" --platform "$platform" --profile generic --output "cleanup_${platform}.py" --legal-ack 2>&1 || true
          echo -e "${TEMPEST_GREEN}${SYM_SUCCESS} Cleanup payload generated${NC}"
        fi
        echo -e "${TEMPEST_WHITE}Press Enter to continue...${NC}"
        read -r
        ;;

      "B"|"b")
        print_section_header "BGP HIJACK ENFORCEMENT"
        echo -e "${TEMPEST_RED}${BOLD}${BLINK}${SYM_CLASSIFIED} EXTREME - COURT ORDER REQUIRED ${SYM_CLASSIFIED}${NC}"
        echo -e "${TEMPEST_WHITE}COURT ORDER + ISP AUTHORIZATION? (yes/NO):${NC} "
        read -r auth_confirm

        if [[ "$auth_confirm" == "yes" ]]; then
          audit_log "SEC" "BGP hijack enforcement authorized"
          echo -e "${TEMPEST_WHITE}Action: 1) Advertise  2) Withdraw  3) Monitor${NC}"
          read -r bgp_action
          echo -e "${TEMPEST_WHITE}Target prefix (CIDR):${NC} "
          read -r target_prefix
          echo -e "${TEMPEST_WHITE}Legal auth file:${NC} "
          read -r legal_auth

          case "$bgp_action" in
            1)
              echo -e "${TEMPEST_WHITE}Sinkhole IP:${NC} "
              read -r sinkhole_ip
              bash "$(dirname "$0")/takeover/bgp-hijack-enforcement.sh" --action advertise --target-prefix "$target_prefix" --sinkhole-ip "$sinkhole_ip" --legal-auth "$legal_auth" 2>&1 || true
              ;;
            2)
              bash "$(dirname "$0")/takeover/bgp-hijack-enforcement.sh" --action withdraw --target-prefix "$target_prefix" --legal-auth "$legal_auth" 2>&1 || true
              ;;
            3)
              bash "$(dirname "$0")/takeover/bgp-hijack-enforcement.sh" --action monitor --target-prefix "$target_prefix" --legal-auth "$legal_auth" 2>&1 || true
              ;;
          esac
        fi
        echo -e "${TEMPEST_WHITE}Press Enter to continue...${NC}"
        read -r
        ;;

      "X"|"x"|"")
        break
        ;;

      *)
        echo -e "${TEMPEST_RED}${SYM_FAILURE} Invalid selection${NC}"
        sleep 1
        ;;
    esac
  done
}

# New: Certificate analysis for .onion services
adv_cert_analysis(){
  local tgt="$1" out
  out="$ADV_DIR/cert_analysis_${tgt//[^A-Za-z0-9._-]/_}.txt"
  : > "$out"

  say "[*] Analyzing TLS certificates for $tgt..."

  {
    echo "═══ TLS Certificate Analysis: $tgt ═══"
    echo "Generated: $($DATE_CMD -u +'%Y-%m-%dT%H:%M:%SZ')"
    echo ""
  } >> "$out"

  # Try HTTPS connection
  if command -v openssl >/dev/null 2>&1; then
    {
      echo "[*] Attempting TLS handshake..."
      echo ""
      timeout 30 openssl s_client -connect "$tgt:443" \
        -proxy "$SOCKS" \
        -servername "$tgt" \
        </dev/null 2>&1 | grep -A 30 'Certificate chain' || echo "No certificate found or connection failed"
      echo ""
    } >> "$out" 2>>"$LOG"
  else
    echo "openssl not available, skipping cert analysis" >> "$out"
  fi

  say "[✓] Certificate analysis -> $out"
  [[ -f "$out" ]] && "$LESS_BIN" -R "$out"
}

tor_check(){
  local port; port="${SOCKS##*:}"
  local host; host="${SOCKS%%:*}"

  say ">>> Tor connectivity check <<<"

  # Check if port is listening
  if ss -ltnp 2>/dev/null | grep -q ":${port} "; then
    say "[✓] Tor SOCKS proxy listening on $SOCKS"
  else
    say "[✗] WARN: No listener on $SOCKS"
    say "    Try: systemctl start tor  OR  tor &"
    return 1
  fi

  # Test actual Tor connectivity
  say "[*] Testing Tor connection to check.torproject.org..."
  local test_result
  test_result=$("$CURL_BIN" --socks5-hostname "$SOCKS" -s --max-time 15 \
    "https://check.torproject.org/api/ip" 2>>"$LOG" | grep -o '"IsTor":[^,}]*' || echo "fail")

  if [[ "$test_result" == *"true"* ]]; then
    say "[✓] Tor is working! Connection verified."
    # Get exit node IP
    local exit_ip
    exit_ip=$("$CURL_BIN" --socks5-hostname "$SOCKS" -s --max-time 10 \
      "https://check.torproject.org/api/ip" 2>>"$LOG" | grep -o '"IP":"[^"]*"' | cut -d'"' -f4)
    [[ -n "$exit_ip" ]] && say "    Exit node IP: $exit_ip"
    return 0
  else
    say "[✗] Tor connectivity test FAILED"
    say "    SOCKS proxy is running but Tor network unreachable"
    say "    Check: journalctl -u tor -n 50"
    return 1
  fi
}

# Enhanced Tor status with circuit info
tor_status(){
  local port; port="${SOCKS##*:}"

  echo "=== Tor Status ==="

  # Check listening port
  if ss -ltnp 2>/dev/null | grep -q ":${port} "; then
    echo "[✓] SOCKS proxy: $SOCKS (listening)"
  else
    echo "[✗] SOCKS proxy: $SOCKS (NOT listening)"
  fi

  # Check if tor process is running
  if pgrep -x tor >/dev/null 2>&1; then
    echo "[✓] Tor process: running (PID: $(pgrep -x tor | head -1))"
  else
    echo "[✗] Tor process: NOT running"
  fi

  # Try to get Tor version via control port (if available)
  if [[ -n "$NC" ]] && ss -ltnp 2>/dev/null | grep -q ":9051 "; then
    echo "[*] Control port: 9051 (available)"
  fi

  # Test connectivity
  if "$CURL_BIN" --socks5-hostname "$SOCKS" -s --max-time 10 "https://check.torproject.org" >/dev/null 2>&1; then
    echo "[✓] Connectivity: working"
  else
    echo "[✗] Connectivity: FAILED"
  fi
}

# ---------- JSON Export ----------
export_json(){
  if [[ -z "$JQ" ]]; then
    say "[✗] jq not installed, JSON export unavailable"
    say "    Install: apt-get install jq"
    return 1
  fi

  local JSON="$OUTDIR/c2-enum-report.json"
  local temp_json="/tmp/c2-enum-$$-temp.json"

  say "[*] Generating JSON export..."

  # Build JSON structure
  cat > "$temp_json" <<EOF
{
  "metadata": {
    "generated": "$($DATE_CMD -u +'%Y-%m-%dT%H:%M:%SZ')",
    "tool": "c2-enum-tui",
    "version": "2.0-enhanced",
    "socks_proxy": "$SOCKS",
    "output_dir": "$OUTDIR"
  },
  "targets": $(printf '%s\n' "${TARGETS[@]}" | "$JQ" -R . | "$JQ" -s .),
  "pcap": {
    "enabled": $PCAP_ON,
    "interface": "$PCAP_IF",
    "filter": "$PCAP_FILTER",
    "file": "${PCAP_FILE:-null}"
  },
  "files": {
    "report": "$OUTDIR/report.txt",
    "static_analysis": "$OUTDIR/static_analysis.txt",
    "log": "$LOG",
    "hashes": "$OUTDIR/download.hashes.txt"
  }
}
EOF

  if "$JQ" . "$temp_json" > "$JSON" 2>>"$LOG"; then
    say "[✓] JSON export: $JSON"
    rm -f "$temp_json"
    echo "$JSON"
    return 0
  else
    say "[✗] JSON export failed"
    rm -f "$temp_json"
    return 1
  fi
}

# ---------- MAIN ----------
clear

# TEMPEST Classification Banner
print_classification_banner_top

# System Header
print_system_header

# Operator Identification
echo -e "${TEMPEST_CYAN}┌──────────────────────────────────────────────────────────────────────────────┐${NC}"
echo -e "${TEMPEST_CYAN}│${NC} ${TEMPEST_AMBER}OPERATOR AUTHENTICATION REQUIRED${NC}                                            ${TEMPEST_CYAN}│${NC}"
echo -e "${TEMPEST_CYAN}└──────────────────────────────────────────────────────────────────────────────┘${NC}"
echo ""
echo -e "${TEMPEST_WHITE}Enter Operator ID (or press Enter for anonymous):${NC} "
read -r input_operator
if [[ -n "$input_operator" ]]; then
    OPERATOR_ID="$input_operator"
fi
audit_log "AUDIT" "Session initiated by operator: $OPERATOR_ID"

echo ""

# Check dependencies
if ! check_dependencies; then
  echo ""
  echo -e "${TEMPEST_YELLOW}${SYM_WARNING} Press Enter to continue with limited functionality...${NC}"
  read -r
fi

log "Starting c2-enum-tui $VERSION"
log "OUTDIR=$OUTDIR SOCKS=$SOCKS"
log "TARGETS: ${TARGETS[*]}"
log "PCAP: enabled=$PCAP_ON iface=$PCAP_IF filter='$PCAP_FILTER'"
audit_log "INFO" "System initialized - OUTDIR: $OUTDIR"

if [[ -z "${PCAP_DIR:-}" ]]; then PCAP_DIR="$OUTDIR/pcap"; fi

# Start PCAP if enabled
if $PCAP_ON; then
  start_pcap || audit_log "WARN" "PCAP failed to start, continuing without capture"
fi

# Tor connectivity check
if ! tor_check; then
  echo ""
  audit_log "WARN" "Tor connectivity issues detected"
  echo -e "${TEMPEST_YELLOW}${SYM_WARNING} Tor connectivity issues detected!${NC}"
  echo -e "${TEMPEST_WHITE}Continue anyway? (y/N):${NC} "
  read -r response
  if [[ ! "$response" =~ ^[Yy]$ ]]; then
    audit_log "INFO" "Session terminated by operator - Tor unavailable"
    echo -e "${TEMPEST_RED}Exiting.${NC}"
    exit 1
  fi
fi

if $AUTO_ENUM; then
T=""
  for T in "${TARGETS[@]}"; do enumerate_target "$T"; done
  REPORT_PATH=$(build_report)
  ANALYSIS_PATH=$(static_analysis)
  audit_log "INFO" "Auto-enumeration complete - Report: $REPORT_PATH"
fi

# Global TOR status for menu
TOR_STATUS="OK"
if ! "$CURL_BIN" --socks5-hostname "$SOCKS" -s --max-time 5 "https://check.torproject.org" >/dev/null 2>&1; then
    TOR_STATUS="FAIL"
fi

while true; do
  clear
  print_classification_banner_top

  # Get current statuses
  pcap_stat="OFF"
  [[ -n "$PCAP_PID" ]] && kill -0 "$PCAP_PID" 2>/dev/null && pcap_stat="ON"

  # Display TEMPEST-styled main menu
  echo -e "${TEMPEST_CYAN}${BOLD}"
  echo "┌──────────────────────────────────────────────────────────────────────────────┐"
  echo "│                         MAIN OPERATIONS CONSOLE                              │"
  echo "├──────────────────────────────────────────────────────────────────────────────┤"
  echo -e "${NC}"

  print_status_line "$pcap_stat" "${#TARGETS[@]}" "$TOR_STATUS"

  echo ""
  echo -e "${TEMPEST_CYAN}┌─────────────────────┤ ${TEMPEST_AMBER}RECONNAISSANCE${TEMPEST_CYAN} ├─────────────────────────────────────┐${NC}"
  tempest_menu_item "1" "Re-enumerate all targets"
  tempest_menu_item "2" "Enumerate specific target"
  tempest_menu_item "3" "Add new target"
  tempest_menu_item "R" "Quick reachability check"
  echo ""

  echo -e "${TEMPEST_CYAN}┌─────────────────────┤ ${TEMPEST_AMBER}CLEARNET OPERATIONS${TEMPEST_CYAN} ├────────────────────────────────┐${NC}"
  tempest_menu_item "N" "CLEARNET ENUMERATION (domains/IPs)" "NEW"
  tempest_menu_item "Q" "QUICK RECON (fast intel gathering)" "NEW"
  tempest_menu_item "B" "BGP/ASN ANALYSIS (network intel)" "NEW"
  echo ""

  echo -e "${TEMPEST_CYAN}┌─────────────────────┤ ${TEMPEST_AMBER}ADVANCED ANALYSIS${TEMPEST_CYAN} ├──────────────────────────────────┐${NC}"
  tempest_menu_item "C" "COMPREHENSIVE SCAN (aggressive)"
  tempest_menu_item "I" "INTELLIGENT ANALYSIS (AI-powered)"
  tempest_menu_item "A" "Advanced Analysis Menu"
  tempest_menu_item "J" "JavaScript Analysis" "NEW"
  tempest_menu_item "W" "Content Crawler" "NEW"
  echo ""

  echo -e "${TEMPEST_CYAN}┌─────────────────────┤ ${TEMPEST_AMBER}TAKEOVER OPERATIONS${TEMPEST_CYAN} ├────────────────────────────────┐${NC}"
  tempest_menu_item "K" "Initiate Takeover/Handover" "SEC"
  echo ""

  echo -e "${TEMPEST_CYAN}┌─────────────────────┤ ${TEMPEST_AMBER}REPORTS & ANALYSIS${TEMPEST_CYAN} ├─────────────────────────────────┐${NC}"
  tempest_menu_item "4" "File picker (inspect outputs)"
  tempest_menu_item "5" "Decompress *.zst to *.bin"
  tempest_menu_item "6" "Build YARA seed"
  tempest_menu_item "7" "Build Suricata host rule"
  tempest_menu_item "8" "View report"
  tempest_menu_item "9" "View static analysis"
  tempest_menu_item "0" "View audit log"
  tempest_menu_item "E" "Export JSON report"
  tempest_menu_item "S" "Summary dashboard"
  echo ""

  echo -e "${TEMPEST_CYAN}┌─────────────────────┤ ${TEMPEST_AMBER}SYSTEM CONTROLS${TEMPEST_CYAN} ├───────────────────────────────────┐${NC}"
  tempest_menu_item "P" "PCAP controls"
  tempest_menu_item "T" "Tor status check"
  tempest_menu_item "H" "Hardware status (NPU/GPU/CPU)"
  tempest_menu_item "X" "Terminate session"
  echo ""

  print_classification_banner_bottom

  echo -e "${TEMPEST_WHITE}SELECT OPERATION: ${NC}"
  read -r choice

  audit_log "AUDIT" "Menu selection: $choice"

  case "$choice" in
    "1")
      print_section_header "RE-ENUMERATION"
      audit_log "INFO" "Re-enumerating ${#TARGETS[@]} targets"
      for T in "${TARGETS[@]}"; do
        enumerate_target "$T" || true
      done
      REPORT_PATH=$(build_report)
      ANALYSIS_PATH=$(static_analysis)
      audit_log "INFO" "Enumeration complete - Report: $REPORT_PATH"
      echo -e "${TEMPEST_GREEN}${SYM_SUCCESS} Enumeration complete${NC}"
      echo -e "${TEMPEST_WHITE}Press Enter to continue...${NC}"
      read -r
      ;;

    "2")
      print_section_header "TARGET SELECTION"
      tgt=$(menu_impl "Pick target" "${TARGETS[@]}")
      if [[ -n "$tgt" ]]; then
        audit_log "INFO" "Enumerating single target: $tgt"
        enumerate_target "$tgt"
        REPORT_PATH=$(build_report)
        ANALYSIS_PATH=$(static_analysis)
      fi
      echo -e "${TEMPEST_WHITE}Press Enter to continue...${NC}"
      read -r
      ;;

    "3")
      print_section_header "ADD TARGET"
      echo -e "${TEMPEST_WHITE}Enter .onion address (with optional :port):${NC} "
      read -r new_target
      if [[ -n "$new_target" ]]; then
        TARGETS+=("$new_target")
        audit_log "INFO" "Target added: $new_target"
        echo -e "${TEMPEST_GREEN}${SYM_SUCCESS} Added: $new_target (Total: ${#TARGETS[@]})${NC}"
      fi
      echo -e "${TEMPEST_WHITE}Press Enter to continue...${NC}"
      read -r
      ;;

    "R"|"r")
      print_section_header "REACHABILITY CHECK"
      audit_log "INFO" "Performing reachability check on ${#TARGETS[@]} targets"
      for tgt in "${TARGETS[@]}"; do
        test_onion_reachable "$tgt" || true
        echo ""
      done
      echo -e "${TEMPEST_WHITE}Press Enter to continue...${NC}"
      read -r
      ;;

    "J"|"j")
      print_section_header "JAVASCRIPT ANALYSIS"
      echo -e "${TEMPEST_AMBER}Analyze JavaScript files for C2 indicators${NC}"
      echo ""
      echo -e "${TEMPEST_WHITE}Enter path to JavaScript file or directory:${NC} "
      read -r js_path

      if [[ -e "$js_path" ]]; then
        js_script="$(dirname "$0")/analyzers/javascript-analysis.sh"
        if [[ -x "$js_script" ]]; then
          echo -e "${TEMPEST_WHITE}Enter output directory:${NC} "
          read -r js_output
          js_output="${js_output:-js_analysis_$(date +%Y%m%d_%H%M%S)}"
          audit_log "INFO" "JavaScript analysis: $js_path -> $js_output"
          bash "$js_script" "$js_path" "$js_output" || true
          echo -e "${TEMPEST_GREEN}${SYM_SUCCESS} Analysis complete: $js_output${NC}"
        else
          echo -e "${TEMPEST_RED}${SYM_FAILURE} JavaScript analyzer not found${NC}"
        fi
      else
        echo -e "${TEMPEST_RED}${SYM_FAILURE} Path not found: $js_path${NC}"
      fi
      echo -e "${TEMPEST_WHITE}Press Enter to continue...${NC}"
      read -r
      ;;

    "W"|"w")
      print_section_header "CONTENT CRAWLER"
      echo -e "${TEMPEST_AMBER}Crawl and extract content from C2 infrastructure${NC}"
      echo ""

      if [[ ${#TARGETS[@]} -gt 0 ]]; then
        tgt=$(menu_impl "Select target to crawl" "${TARGETS[@]}")
        if [[ -n "$tgt" ]]; then
          crawler_script="$(dirname "$0")/analyzers/content-crawler.sh"
          if [[ -x "$crawler_script" ]]; then
            echo -e "${TEMPEST_WHITE}Max depth (1-5) [2]:${NC} "
            read -r crawl_depth
            crawl_depth="${crawl_depth:-2}"
            audit_log "INFO" "Content crawl initiated: $tgt depth=$crawl_depth"
            bash "$crawler_script" "$tgt" "$OUTDIR/crawl_${tgt//[^A-Za-z0-9._-]/_}" "$crawl_depth" || true
            echo -e "${TEMPEST_GREEN}${SYM_SUCCESS} Crawl complete${NC}"
          else
            echo -e "${TEMPEST_RED}${SYM_FAILURE} Content crawler not found${NC}"
          fi
        fi
      else
        echo -e "${TEMPEST_YELLOW}${SYM_WARNING} No targets available${NC}"
      fi
      echo -e "${TEMPEST_WHITE}Press Enter to continue...${NC}"
      read -r
      ;;

    "C"|"c")
      print_section_header "COMPREHENSIVE SCAN"
      echo -e "${TEMPEST_AMBER}Aggressive enumeration mode${NC}"
      echo ""
      echo -e "${TEMPEST_WHITE}Capabilities:${NC}"
      echo -e "  ${TEMPEST_CYAN}•${NC} Port scanning (37 common ports)"
      echo -e "  ${TEMPEST_CYAN}•${NC} Path enumeration (100+ paths)"
      echo -e "  ${TEMPEST_CYAN}•${NC} HTTP method testing"
      echo -e "  ${TEMPEST_CYAN}•${NC} Header analysis"
      echo -e "  ${TEMPEST_CYAN}•${NC} Binary artifact discovery"
      echo -e "  ${TEMPEST_CYAN}•${NC} Technology fingerprinting"
      echo ""
      echo -e "${TEMPEST_RED}${SYM_WARNING} WARNING: This scan is aggressive and may be detected!${NC}"
      echo ""
      echo -e "${TEMPEST_WHITE}Continue? (y/N):${NC} "
      read -r confirm

      if [[ "$confirm" =~ ^[Yy]$ ]]; then
        tgt=$(menu_impl "Select target for comprehensive scan" "${TARGETS[@]}")
        if [[ -n "$tgt" ]]; then
          comp_scan_script="$(dirname "$0")/c2-scan-comprehensive.sh"
          [[ ! -f "$comp_scan_script" ]] && comp_scan_script="/home/c2enum/toolkit/c2-scan-comprehensive.sh"

          if [[ -f "$comp_scan_script" ]]; then
            audit_log "INFO" "Comprehensive scan initiated: $tgt"
            bash "$comp_scan_script" "$tgt" "$OUTDIR/comprehensive_${tgt//[^A-Za-z0-9._-]/_}"
            echo -e "${TEMPEST_GREEN}${SYM_SUCCESS} Comprehensive scan complete!${NC}"
          else
            echo -e "${TEMPEST_RED}${SYM_FAILURE} Comprehensive scanner not found${NC}"
          fi
        fi
      else
        audit_log "INFO" "Comprehensive scan cancelled by operator"
      fi
      echo -e "${TEMPEST_WHITE}Press Enter to continue...${NC}"
      read -r
      ;;

    "I"|"i")
      print_section_header "INTELLIGENT ANALYSIS"
      echo -e "${TEMPEST_AMBER}AI-powered analysis with hardware acceleration${NC}"
      echo ""
      echo -e "${TEMPEST_WHITE}Select Analysis Profile:${NC}"
      echo -e "  ${TEMPEST_CYAN}1)${NC} Fast (CPU-only, basic tools)"
      echo -e "  ${TEMPEST_CYAN}2)${NC} Balanced (GPU/NPU, standard tools)"
      echo -e "  ${TEMPEST_CYAN}3)${NC} Exhaustive (All hardware, all tools)"
      echo ""
      echo -e "${TEMPEST_WHITE}Profile:${NC} "
      read -r profile_choice

      case "$profile_choice" in
        1) profile="fast" ;;
        2) profile="balanced" ;;
        3) profile="exhaustive" ;;
        *) echo -e "${TEMPEST_RED}Invalid choice${NC}"; continue ;;
      esac

      orchestrator_script="$(dirname "$0")/analyzers/orchestrator.sh"
      [[ ! -f "$orchestrator_script" ]] && orchestrator_script="/home/c2enum/toolkit/analyzers/orchestrator.sh"

      if [[ -f "$orchestrator_script" ]]; then
        audit_log "INFO" "Intelligent analysis initiated: profile=$profile"
        bash "$orchestrator_script" "$OUTDIR" "$profile" 3
        echo -e "${TEMPEST_GREEN}${SYM_SUCCESS} Intelligent analysis complete!${NC}"

        echo -e "${TEMPEST_WHITE}View results? (y/N):${NC} "
        read -r view_choice
        if [[ "$view_choice" =~ ^[Yy]$ ]]; then
          [[ -f "$OUTDIR/intelligent_analysis/all_discovered_endpoints.txt" ]] && \
            "$LESS_BIN" "$OUTDIR/intelligent_analysis/all_discovered_endpoints.txt"
        fi
      else
        echo -e "${TEMPEST_RED}${SYM_FAILURE} Orchestrator not found${NC}"
      fi
      echo -e "${TEMPEST_WHITE}Press Enter to continue...${NC}"
      read -r
      ;;

    "N"|"n")
      print_section_header "CLEARNET ENUMERATION"
      echo -e "${TEMPEST_AMBER}Comprehensive clearnet C2 infrastructure enumeration${NC}"
      echo ""
      echo -e "${TEMPEST_WHITE}Capabilities:${NC}"
      echo -e "  ${TEMPEST_CYAN}•${NC} DNS resolution & validation"
      echo -e "  ${TEMPEST_CYAN}•${NC} Port scanning (23-60+ ports)"
      echo -e "  ${TEMPEST_CYAN}•${NC} HTTP/HTTPS header analysis"
      echo -e "  ${TEMPEST_CYAN}•${NC} SSL certificate collection"
      echo -e "  ${TEMPEST_CYAN}•${NC} ASN/BGP lookups & GeoIP"
      echo ""
      echo -e "${TEMPEST_WHITE}Enter targets file path:${NC} "
      read -r targets_file
      if [[ -n "$targets_file" ]] && [[ -f "$targets_file" ]]; then
        echo -e "${TEMPEST_WHITE}Output directory [clearnet_enum_$(date +%Y%m%d_%H%M%S)]:${NC} "
        read -r output_dir
        output_dir="${output_dir:-clearnet_enum_$(date +%Y%m%d_%H%M%S)}"

        echo -e "${TEMPEST_WHITE}Scan mode (1=standard, 2=comprehensive) [2]:${NC} "
        read -r mode_choice
        case "$mode_choice" in
          1) scan_mode="standard" ;;
          *) scan_mode="comprehensive" ;;
        esac

        audit_log "INFO" "Clearnet enumeration: $targets_file mode=$scan_mode"

        if [[ -x "./c2-enum-clearnet.sh" ]]; then
          ./c2-enum-clearnet.sh "$targets_file" "$output_dir" "$scan_mode" || true
          echo -e "${TEMPEST_GREEN}${SYM_SUCCESS} Clearnet enumeration complete!${NC}"
          echo -e "${TEMPEST_CYAN}Report: $output_dir/MASTER_REPORT.txt${NC}"
        else
          echo -e "${TEMPEST_RED}${SYM_FAILURE} c2-enum-clearnet.sh not found${NC}"
        fi
      else
        echo -e "${TEMPEST_RED}${SYM_FAILURE} Invalid targets file${NC}"
      fi
      echo -e "${TEMPEST_WHITE}Press Enter to continue...${NC}"
      read -r
      ;;

    "Q"|"q")
      print_section_header "QUICK RECONNAISSANCE"
      echo -e "${TEMPEST_AMBER}Fast intelligence gathering (~5-10s per target)${NC}"
      echo ""
      echo -e "${TEMPEST_WHITE}Capabilities:${NC}"
      echo -e "  ${TEMPEST_CYAN}•${NC} Quick DNS resolution (3s timeout)"
      echo -e "  ${TEMPEST_CYAN}•${NC} Fast port scanning (5 C2 ports)"
      echo -e "  ${TEMPEST_CYAN}•${NC} HTTP header grabbing"
      echo -e "  ${TEMPEST_CYAN}•${NC} SSL certificate collection"
      echo -e "  ${TEMPEST_CYAN}•${NC} GeoIP resolution"
      echo ""
      echo -e "${TEMPEST_WHITE}Enter targets file path:${NC} "
      read -r targets_file
      if [[ -n "$targets_file" ]] && [[ -f "$targets_file" ]]; then
        echo -e "${TEMPEST_WHITE}Output directory [quick_recon_$(date +%Y%m%d_%H%M%S)]:${NC} "
        read -r output_dir
        output_dir="${output_dir:-quick_recon_$(date +%Y%m%d_%H%M%S)}"

        audit_log "INFO" "Quick reconnaissance: $targets_file"

        if [[ -x "./c2-quick-recon.sh" ]]; then
          ./c2-quick-recon.sh "$targets_file" "$output_dir" || true
          echo -e "${TEMPEST_GREEN}${SYM_SUCCESS} Quick reconnaissance complete!${NC}"
          echo -e "${TEMPEST_CYAN}Report: $output_dir/MASTER_REPORT.txt${NC}"
        else
          echo -e "${TEMPEST_RED}${SYM_FAILURE} c2-quick-recon.sh not found${NC}"
        fi
      else
        echo -e "${TEMPEST_RED}${SYM_FAILURE} Invalid targets file${NC}"
      fi
      echo -e "${TEMPEST_WHITE}Press Enter to continue...${NC}"
      read -r
      ;;

    "B"|"b")
      print_section_header "BGP/ASN INTELLIGENCE"
      echo -e "${TEMPEST_AMBER}Network infrastructure analysis${NC}"
      echo ""
      echo -e "${TEMPEST_WHITE}Capabilities:${NC}"
      echo -e "  ${TEMPEST_CYAN}•${NC} ASN lookups (Team Cymru, RIPE, BGPView)"
      echo -e "  ${TEMPEST_CYAN}•${NC} BGP routing information"
      echo -e "  ${TEMPEST_CYAN}•${NC} GeoIP & ownership details"
      echo -e "  ${TEMPEST_CYAN}•${NC} WHOIS & abuse contacts"
      echo -e "  ${TEMPEST_CYAN}•${NC} Threat intelligence cross-reference"
      echo ""
      echo -e "${TEMPEST_WHITE}Enter IP address or domain:${NC} "
      read -r target
      if [[ -n "$target" ]]; then
        echo -e "${TEMPEST_WHITE}Output file [bgp_analysis_${target//[:\/\.]/_}.txt]:${NC} "
        read -r output_file
        output_file="${output_file:-bgp_analysis_${target//[:\/\.]/_}.txt}"

        audit_log "INFO" "BGP/ASN analysis: $target"

        if [[ -x "./analyzers/bgp-asn-intel.sh" ]]; then
          ./analyzers/bgp-asn-intel.sh "$target" "$output_file" || true
          echo -e "${TEMPEST_GREEN}${SYM_SUCCESS} BGP/ASN analysis complete!${NC}"

          echo -e "${TEMPEST_WHITE}View report? (y/N):${NC} "
          read -r view_choice
          [[ "$view_choice" =~ ^[Yy]$ ]] && "$LESS_BIN" -R "$output_file"
        else
          echo -e "${TEMPEST_RED}${SYM_FAILURE} bgp-asn-intel.sh not found${NC}"
        fi
      else
        echo -e "${TEMPEST_RED}${SYM_FAILURE} No target specified${NC}"
      fi
      echo -e "${TEMPEST_WHITE}Press Enter to continue...${NC}"
      read -r
      ;;

    "H"|"h")
      print_section_header "HARDWARE STATUS"
      audit_log "INFO" "Hardware status check"

      hw_detect_script="$(dirname "$0")/analyzers/hw-detect.sh"
      [[ ! -f "$hw_detect_script" ]] && hw_detect_script="/home/c2enum/toolkit/analyzers/hw-detect.sh"

      if [[ -f "$hw_detect_script" ]]; then
        bash "$hw_detect_script" text
      else
        echo -e "${TEMPEST_RED}${SYM_FAILURE} Hardware detection script not found${NC}"
      fi

      # OpenVINO status
      if command -v python3 >/dev/null 2>&1; then
        ov_accel="$(dirname "$0")/analyzers/openvino-accelerator.py"
        [[ ! -f "$ov_accel" ]] && ov_accel="/home/c2enum/toolkit/analyzers/openvino-accelerator.py"
        [[ -f "$ov_accel" ]] && python3 "$ov_accel" --detect 2>&1 || true
      fi

      echo -e "${TEMPEST_WHITE}Press Enter to continue...${NC}"
      read -r
      ;;

    "4")
      print_section_header "FILE PICKER"
      file_picker_menu
      ;;

    "5")
      print_section_header "DECOMPRESS ARTIFACTS"
      audit_log "INFO" "Decompressing artifacts"
      decompress_artifacts
      echo -e "${TEMPEST_WHITE}Press Enter to continue...${NC}"
      read -r
      ;;

    "6")
      print_section_header "YARA SEED GENERATOR"
      y=$(make_yara_seed)
      audit_log "INFO" "YARA seed generated: $y"
      echo -e "${TEMPEST_GREEN}${SYM_SUCCESS} YARA seed: $y${NC}"
      [[ -f "$y" ]] && "$LESS_BIN" -R "$y"
      ;;

    "7")
      print_section_header "SURICATA RULE GENERATOR"
      r=$(make_suricata_rule)
      audit_log "INFO" "Suricata rule generated: $r"
      echo -e "${TEMPEST_GREEN}${SYM_SUCCESS} Suricata rule: $r${NC}"
      [[ -f "$r" ]] && "$LESS_BIN" -R "$r"
      ;;

    "8")
      print_section_header "VIEW REPORT"
      if [[ -f "$OUTDIR/report.txt" ]]; then
        "$LESS_BIN" -R "$OUTDIR/report.txt"
      else
        echo -e "${TEMPEST_YELLOW}${SYM_WARNING} No report yet. Run enumeration first.${NC}"
        echo -e "${TEMPEST_WHITE}Press Enter to continue...${NC}"
        read -r
      fi
      ;;

    "9")
      print_section_header "VIEW STATIC ANALYSIS"
      if [[ -f "$OUTDIR/static_analysis.txt" ]]; then
        "$LESS_BIN" -R "$OUTDIR/static_analysis.txt"
      else
        echo -e "${TEMPEST_YELLOW}${SYM_WARNING} No analysis yet. Run enumeration first.${NC}"
        echo -e "${TEMPEST_WHITE}Press Enter to continue...${NC}"
        read -r
      fi
      ;;

    "0")
      print_section_header "AUDIT LOG"
      "$LESS_BIN" -R "$LOG"
      ;;

    "P"|"p")
      pcap_menu
      ;;

    "T"|"t")
      print_section_header "TOR STATUS"
      tor_status
      echo -e "${TEMPEST_WHITE}Press Enter to continue...${NC}"
      read -r
      ;;

    "A"|"a")
      advanced_menu
      ;;

    "E"|"e")
      print_section_header "JSON EXPORT"
      export_json
      echo -e "${TEMPEST_WHITE}Press Enter to continue...${NC}"
      read -r
      ;;

    "S"|"s")
      show_dashboard
      ;;

    "K"|"k")
      print_section_header "TAKEOVER/HANDOVER INITIATION"
      echo -e "${TEMPEST_RED}${BOLD}${SYM_CLASSIFIED} CLASSIFIED OPERATION ${SYM_CLASSIFIED}${NC}"
      echo ""
      echo -e "${TEMPEST_YELLOW}WARNING: This action is for authorized personnel only.${NC}"
      echo -e "${TEMPEST_WHITE}Initiates formal evidence packaging for authority handover.${NC}"
      echo -e "${TEMPEST_WHITE}All actions are logged for legal purposes.${NC}"
      echo ""
      echo -e "${TEMPEST_WHITE}Enter Operator ID to proceed (blank to cancel):${NC} "
      read -r op_id

      if [[ -n "$op_id" ]]; then
        audit_log "SEC" "Takeover initiated by operator: $op_id"

        # Find scan directories
        mapfile -t scan_dirs < <(find . -maxdepth 1 -type d -name "intel_*" -o -name "comprehensive_scan_*" | sort -r)

        if [[ ${#scan_dirs[@]} -eq 0 ]]; then
            echo -e "${TEMPEST_YELLOW}${SYM_WARNING} No scan directories found${NC}"
        else
            selected_dir=$(menu_impl "Select Scan Directory" "${scan_dirs[@]}")

            if [[ -n "$selected_dir" && -d "$selected_dir" ]]; then
                takeover_script="$(dirname "$0")/takeover/takeover.sh"
                [[ ! -f "$takeover_script" ]] && takeover_script="/home/c2enum/toolkit/takeover/takeover.sh"

                if [[ -f "$takeover_script" ]]; then
                    audit_log "SEC" "Takeover processing: $selected_dir"
                    bash "$takeover_script" "$selected_dir" "$op_id"
                    echo -e "${TEMPEST_GREEN}${SYM_SUCCESS} Takeover process complete${NC}"
                else
                    echo -e "${TEMPEST_RED}${SYM_FAILURE} Takeover script not found${NC}"
                fi
            else
                echo -e "${TEMPEST_YELLOW}${SYM_WARNING} Invalid selection${NC}"
            fi
        fi
      else
        audit_log "INFO" "Takeover cancelled by operator"
      fi
      echo -e "${TEMPEST_WHITE}Press Enter to continue...${NC}"
      read -r
      ;;

    "X"|"x"|"")
      print_section_header "SESSION TERMINATION"
      audit_log "AUDIT" "Session terminated by operator: $OPERATOR_ID"
      echo -e "${TEMPEST_AMBER}Shutting down...${NC}"
      break
      ;;

    *)
      echo -e "${TEMPEST_RED}${SYM_FAILURE} Invalid selection${NC}"
      sleep 1
      ;;
  esac
done

audit_log "INFO" "System shutdown complete"
print_classification_banner_bottom
exit 0
