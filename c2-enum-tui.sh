#!/usr/bin/env bash
# c2-enum-tui.sh — Safe, TUI-driven Tor .onion C2 enumeration + static analysis + PCAP (default ON)
# Hardened: quoted heredocs, safer loops, auto OUTDIR from first target if not provided, no exec of remote code.
set -euo pipefail
IFS=$'\n\t'

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

# PCAP defaults (ON)
PCAP_ON=true
PCAP_IF="${PCAP_IF:-lo}"
PCAP_FILTER_DEFAULT='tcp and (port 9050 or 9150 or 9000)'
PCAP_FILTER="${PCAP_FILTER:-$PCAP_FILTER_DEFAULT}"
PCAP_DIR=""

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
TIMEOUT=$(command -v timeout || command -v gtimeout || true)
OBJDUMP=$(command -v objdump || true)
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
ADD_TARGETS=()

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
    --add) IFS=',' read -r -a ADD_TARGETS <<< "$2"; shift 2 ;;
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
JOB_COUNT=0
wait_for_jobs(){
  local max="${1:-$MAX_JOBS}"
  while [[ $(jobs -r | wc -l) -ge $max ]]; do
    sleep 0.5
  done
}

# Test .onion reachability before enumeration with port checking
test_onion_reachable(){
  local target="$1" timeout=30
  local host port protocol

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
      ( "$TCPDUMP" -i "$PCAP_IF" -U -s 0 -w "$PCAP_FILE" $PCAP_FILTER ) >/dev/null 2>&1 & PCAP_PID=$!
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

  local filesize=$(stat -f%z "$PCAP_FILE" 2>/dev/null || stat -c%s "$PCAP_FILE" 2>/dev/null || echo "unknown")
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
  local safe_base; safe_base="$OUTDIR/$(echo "$T" | sed 's/[^A-Za-z0-9._-]/_/g')"
  local enum_start=$(date +%s)

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
  local archs=("x86_64" "amd64" "arm64" "aarch64" "$(uname -m)")
  # Remove duplicates
  archs=($(printf "%s\n" "${archs[@]}" | sort -u))

  for arch in "${archs[@]}"; do
    wait_for_jobs 3

    local artifact="$OUTDIR/$(echo "${T}_system-linux-${arch}.zst" | sed 's/[^A-Za-z0-9._-]/_/g')"
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
  local analysis_start=$(date +%s)

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
    local size=$(stat -f%z "$f" 2>/dev/null || stat -c%s "$f" 2>/dev/null || echo "unknown")
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
    for item in "${items[@]}"; do dlg_items+=("$item" "$item"); end=''; done
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
    curl --socks5-hostname "$SOCKS" -fsSL --max-time 30 -r 0-16383 "http://$tgt$p" -o "$d/snap_${ts}_$(echo "$p"|tr/ _).bin" 2>>"$LOG" || true
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
  for p in /nope /admin/../admin '/api/..\'; do
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
    echo >> "$out"; echo "=== tshark conversations (TCP) ===" >> "$out"
    "$TSHARK" -r "$PCAP_FILE" -q -z conv,tcp >> "$out" 2>>"$LOG" || true
    echo >> "$out"; echo "=== SYN timing histogram (sec) ===" >> "$out"
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
            local sz=$(stat -f%z "$f" 2>/dev/null || stat -c%s "$f" 2>/dev/null || echo "?")
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
  echo "╔════════════════════════════════════════════════════════════════════╗"
  echo "║                      C2 Enumeration Dashboard                      ║"
  echo "╚════════════════════════════════════════════════════════════════════╝"
  echo ""

  echo "═══ Session Info ═══"
  echo "OUTDIR:       $OUTDIR"
  echo "Start time:   $(stat -f%SB "$LOG" 2>/dev/null || stat -c%y "$LOG" 2>/dev/null | cut -d. -f1)"
  echo "SOCKS proxy:  $SOCKS"
  echo ""

  echo "═══ Targets (${#TARGETS[@]}) ═══"
  local idx=1
  for t in "${TARGETS[@]}"; do
    echo "  $idx) $t"
    ((idx++))
  done
  echo ""

  echo "═══ Files Collected ═══"
  local head_files=$(find "$OUTDIR" -maxdepth 1 -name "*.head" 2>/dev/null | wc -l)
  local sample_files=$(find "$OUTDIR" -maxdepth 1 -name "*.sample" 2>/dev/null | wc -l)
  local zst_files=$(find "$OUTDIR" -maxdepth 1 -name "*.zst" 2>/dev/null | wc -l)
  local bin_files=$(find "$OUTDIR" -maxdepth 1 -name "*.bin" 2>/dev/null | wc -l)

  echo "  Headers:      $head_files"
  echo "  Samples:      $sample_files"
  echo "  Archives:     $zst_files"
  echo "  Binaries:     $bin_files"
  echo ""

  echo "═══ Reports ═══"
  [[ -f "$OUTDIR/report.txt" ]] && echo "  [✓] Main report" || echo "  [✗] Main report"
  [[ -f "$OUTDIR/static_analysis.txt" ]] && echo "  [✓] Static analysis" || echo "  [✗] Static analysis"
  [[ -f "$OUTDIR/yara_seed.yar" ]] && echo "  [✓] YARA seed" || echo "  [✗] YARA seed"
  [[ -f "$OUTDIR/suricata_c2_host.rule" ]] && echo "  [✓] Suricata rule" || echo "  [✗] Suricata rule"
  [[ -f "$OUTDIR/c2-enum-report.json" ]] && echo "  [✓] JSON export" || echo "  [✗] JSON export"
  echo ""

  echo "═══ PCAP ═══"
  echo "  Status: $(pcap_status)"
  if [[ -n "$PCAP_FILE" && -f "$PCAP_FILE" ]]; then
    local pcap_sz=$(stat -f%z "$PCAP_FILE" 2>/dev/null || stat -c%s "$PCAP_FILE" 2>/dev/null || echo "?")
    echo "  Size:   $pcap_sz bytes"
  fi
  echo ""

  echo "═══ Disk Usage ═══"
  du -sh "$OUTDIR" 2>/dev/null || echo "  (unable to calculate)"
  echo ""

  echo "Press Enter to continue..."
  read -r
}

advanced_menu(){
  local items=("Port-Scanner" "Select-Target-for-Deep-Scan" "Run-All-Advanced-On-Target" "Differential-Snapshots" "Asset-Hash-Correlation" "Header-Fingerprint-Matrix" "Binary-Lineage-Analysis" "PCAP-Deep-Analysis" "Certificate-Analysis" "Back")

  while true; do
    local act; act=$(menu_impl "Advanced Analysis Menu" "${items[@]}")
    case "$act" in
      "Port-Scanner")
        local tgt; tgt=$(menu_impl "Pick target for port scan" "${TARGETS[@]}")
        if [[ -n "$tgt" ]]; then
          scan_onion_ports "$tgt"
          echo ""
          echo "Press Enter to continue..."
          read -r
        fi
        ;;

      "Select-Target-for-Deep-Scan")
        local tgt; tgt=$(menu_impl "Pick target" "${TARGETS[@]}")
        if [[ -n "$tgt" ]]; then
          say "[*] Deep scanning: $tgt"
          scan_onion_ports "$tgt"
          adv_snapshots "$tgt"
          adv_assets_hash "$tgt"
          adv_header_matrix "$tgt"
          say "[✓] Deep scan complete for $tgt"
        fi
        ;;

      "Run-All-Advanced-On-Target")
        local tgt; tgt=$(menu_impl "Pick target" "${TARGETS[@]}")
        if [[ -n "$tgt" ]]; then
          say "[*] Running all advanced modules on: $tgt"
          scan_onion_ports "$tgt"
          adv_snapshots "$tgt"
          adv_assets_hash "$tgt"
          adv_header_matrix "$tgt"
          adv_binary_lineage
          adv_cert_analysis "$tgt"
          say "[✓] All advanced analysis complete"
        fi
        ;;

      "Differential-Snapshots")
        local tgt; tgt=$(menu_impl "Pick target" "${TARGETS[@]}")
        [[ -n "$tgt" ]] && adv_snapshots "$tgt"
        ;;

      "Asset-Hash-Correlation")
        local tgt; tgt=$(menu_impl "Pick target" "${TARGETS[@]}")
        [[ -n "$tgt" ]] && adv_assets_hash "$tgt"
        ;;

      "Header-Fingerprint-Matrix")
        local tgt; tgt=$(menu_impl "Pick target" "${TARGETS[@]}")
        [[ -n "$tgt" ]] && adv_header_matrix "$tgt"
        ;;

      "Binary-Lineage-Analysis")
        adv_binary_lineage
        ;;

      "PCAP-Deep-Analysis")
        adv_pcap_summaries
        ;;

      "Certificate-Analysis")
        local tgt; tgt=$(menu_impl "Pick target" "${TARGETS[@]}")
        [[ -n "$tgt" ]] && adv_cert_analysis "$tgt"
        ;;

      "Back"|*)
        break
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
echo "╔════════════════════════════════════════════════════════════════════╗"
echo "║                    C2 Enumeration TUI v2.0                         ║"
echo "║           Safe .onion C2 Analysis + PCAP + Static Analysis         ║"
echo "╚════════════════════════════════════════════════════════════════════╝"
echo ""

# Check dependencies
if ! check_dependencies; then
  echo ""
  echo "Press Enter to continue anyway, or Ctrl+C to exit..."
  read -r
fi

log "Starting c2-enum-tui v2.0-enhanced"
log "OUTDIR=$OUTDIR SOCKS=$SOCKS"
log "TARGETS: ${TARGETS[*]}"
log "PCAP: enabled=$PCAP_ON iface=$PCAP_IF filter='$PCAP_FILTER'"

if [[ -z "${PCAP_DIR:-}" ]]; then PCAP_DIR="$OUTDIR/pcap"; fi

# Start PCAP if enabled
if $PCAP_ON; then
  start_pcap || say "[!] PCAP failed to start, continuing without capture"
fi

# Tor connectivity check
if ! tor_check; then
  say ""
  say "[!] Tor connectivity issues detected!"
  say "    Continue anyway? (y/N)"
  read -r response
  if [[ ! "$response" =~ ^[Yy]$ ]]; then
    say "Exiting."
    exit 1
  fi
fi

if $AUTO_ENUM; then
T=""
  for T in "${TARGETS[@]}"; do enumerate_target "$T"; done
  REPORT_PATH=$(build_report)
  ANALYSIS_PATH=$(static_analysis)
  say "Report: $REPORT_PATH"
  say "Static analysis: $ANALYSIS_PATH"
fi

while true; do
  echo ""
  echo "═══════════════════════════════════════════════════════════════"
  echo " PCAP: $(pcap_status) | Targets: ${#TARGETS[@]} | OUTDIR: $(basename "$OUTDIR")"
  echo "═══════════════════════════════════════════════════════════════"

  choice=$(menu_impl "C2 Enumeration — Main Menu" \
    "1) Re-enumerate all targets" \
    "2) Enumerate a specific target" \
    "3) Add a new target" \
    "R) Quick reachability check" \
    "4) File picker (inspect outputs)" \
    "5) Decompress *.zst to *.bin (read-only)" \
    "6) Build YARA seed" \
    "7) Build Suricata host rule" \
    "8) View report" \
    "9) View static analysis" \
    "0) View log" \
    "P) PCAP controls (Start/Stop/Status/Stats)" \
    "T) Tor status check" \
    "A) Advanced (port scan, snapshots, assets, headers)" \
    "E) Export JSON report" \
    "S) Summary dashboard" \
    "Q) Quit")

  case "$choice" in
    "1) Re-enumerate all targets")
      say "[*] Re-enumerating ${#TARGETS[@]} targets..."
      for T in "${TARGETS[@]}"; do
        enumerate_target "$T" || true
      done
      REPORT_PATH=$(build_report)
      ANALYSIS_PATH=$(static_analysis)
      say "[✓] Enumeration complete. Report: $REPORT_PATH"
      ;;

    "2) Enumerate a specific target")
      tgt=$(menu_impl "Pick target" "${TARGETS[@]}")
      if [[ -n "$tgt" ]]; then
        enumerate_target "$tgt"
        REPORT_PATH=$(build_report)
        ANALYSIS_PATH=$(static_analysis)
      fi
      ;;

    "3) Add a new target")
      echo "Enter .onion address (with optional :port):"
      read -r new_target
      if [[ -n "$new_target" ]]; then
        TARGETS+=("$new_target")
        say "[✓] Added: $new_target (Total targets: ${#TARGETS[@]})"
        log "Target added: $new_target"
      fi
      ;;

    "R) Quick reachability check")
      say "═══ Quick Reachability Check ═══"
      say ""
      for tgt in "${TARGETS[@]}"; do
        test_onion_reachable "$tgt" || true
        say ""
      done
      echo "Press Enter to continue..."
      read -r
      ;;

    "4) File picker (inspect outputs)")
      file_picker_menu
      ;;

    "5) Decompress *.zst to *.bin (read-only)")
      decompress_artifacts
      ;;

    "6) Build YARA seed")
      y=$(make_yara_seed)
      say "[✓] YARA seed: $y"
      [[ -f "$y" ]] && "$LESS_BIN" -R "$y"
      ;;

    "7) Build Suricata host rule")
      r=$(make_suricata_rule)
      say "[✓] Suricata rule: $r"
      [[ -f "$r" ]] && "$LESS_BIN" -R "$r"
      ;;

    "8) View report")
      if [[ -f "$OUTDIR/report.txt" ]]; then
        "$LESS_BIN" -R "$OUTDIR/report.txt"
      else
        say "[!] No report yet. Run enumeration first."
      fi
      ;;

    "9) View static analysis")
      if [[ -f "$OUTDIR/static_analysis.txt" ]]; then
        "$LESS_BIN" -R "$OUTDIR/static_analysis.txt"
      else
        say "[!] No analysis yet. Run enumeration first."
      fi
      ;;

    "0) View log")
      "$LESS_BIN" -R "$LOG"
      ;;

    "P) PCAP controls (Start/Stop/Status/Stats)")
      pcap_menu
      ;;

    "T) Tor status check")
      tor_status
      echo ""
      echo "Press Enter to continue..."
      read -r
      ;;

    "A) Advanced (snapshots, assets, headers, lineage)")
      advanced_menu
      ;;

    "E) Export JSON report")
      export_json
      ;;

    "S) Summary dashboard")
      show_dashboard
      ;;

    "Q) Quit"|""|"Q"|"q")
      say "[*] Shutting down..."
      break
      ;;

    *)
      say "[!] Invalid choice"
      ;;
  esac
done

log "Done."
exit 0
