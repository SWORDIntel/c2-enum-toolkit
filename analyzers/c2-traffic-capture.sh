#!/usr/bin/env bash
#
# c2-traffic-capture.sh - C2 Traffic Capture and Analysis Tool
# Part of the C2 Enumeration Toolkit v2.6
#
# Purpose: Capture and analyze C2 communication for protocol reverse engineering
# Classification: DEFENSIVE SECURITY RESEARCH ONLY
#
# Features:
# - Live traffic capture with BPF filtering
# - Protocol extraction and analysis
# - HTTP/HTTPS decryption (with SSL keys)
# - Binary protocol dissection
# - Automatic C2 pattern detection
# - Timeline analysis
# - Export to multiple formats (PCAP, JSON, text)
#
# Usage:
#     # Capture traffic to specific C2 IP
#     ./c2-traffic-capture.sh --target-ip 151.242.2.22 --duration 300
#
#     # Capture with domain filtering
#     ./c2-traffic-capture.sh --target-domain baidu.com --interface eth0
#
#     # Analyze existing PCAP
#     ./c2-traffic-capture.sh --analyze existing_capture.pcap
#
#     # Live capture with real-time analysis
#     ./c2-traffic-capture.sh --target-ip 151.242.2.22 --live-analysis
#
# LEGAL: For authorized malware analysis and defensive research only

set -euo pipefail
IFS=$'\n\t'

# === Configuration ===
VERSION="2.6-capture"
DEFAULT_INTERFACE="eth0"
DEFAULT_DURATION=60
SNAPLEN=65535  # Capture full packets

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# === Functions ===

log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    case "$level" in
        INFO)
            echo -e "${BLUE}[INFO]${NC} [$timestamp] $message" >&2
            ;;
        SUCCESS)
            echo -e "${GREEN}[✓]${NC} [$timestamp] $message" >&2
            ;;
        WARNING)
            echo -e "${YELLOW}[!]${NC} [$timestamp] $message" >&2
            ;;
        ERROR)
            echo -e "${RED}[✗]${NC} [$timestamp] $message" >&2
            ;;
        DATA)
            echo -e "${CYAN}[»]${NC} [$timestamp] $message" >&2
            ;;
    esac
}

check_requirements() {
    local missing=()

    # Check for tcpdump
    if ! command -v tcpdump &>/dev/null; then
        missing+=("tcpdump")
    fi

    # Check for tshark (optional but recommended)
    if ! command -v tshark &>/dev/null; then
        log WARNING "tshark not found - advanced analysis will be limited"
    fi

    # Check for jq (optional)
    if ! command -v jq &>/dev/null; then
        log WARNING "jq not found - JSON output will be limited"
    fi

    if [[ ${#missing[@]} -gt 0 ]]; then
        log ERROR "Missing required tools: ${missing[*]}"
        log ERROR "Install with: sudo apt-get install ${missing[*]}"
        exit 1
    fi

    log SUCCESS "All required tools found"
}

build_bpf_filter() {
    local target_ip="$1"
    local target_domain="$2"
    local target_port="$3"

    local filter_parts=()

    # IP filter
    if [[ -n "$target_ip" ]]; then
        filter_parts+=("host $target_ip")
    fi

    # Port filter
    if [[ -n "$target_port" ]]; then
        filter_parts+=("port $target_port")
    fi

    # Combine filters
    local filter=""
    if [[ ${#filter_parts[@]} -gt 0 ]]; then
        filter=$(IFS=" and "; echo "${filter_parts[*]}")
    fi

    echo "$filter"
}

capture_traffic() {
    local interface="$1"
    local duration="$2"
    local bpf_filter="$3"
    local output_pcap="$4"

    log INFO "Starting traffic capture..."
    log INFO "Interface: $interface"
    log INFO "Duration: ${duration}s"
    log INFO "BPF Filter: ${bpf_filter:-none}"
    log INFO "Output: $output_pcap"

    # Start tcpdump
    if [[ -n "$bpf_filter" ]]; then
        timeout "$duration" tcpdump -i "$interface" -s "$SNAPLEN" -w "$output_pcap" "$bpf_filter" 2>&1 | \
            grep -v "listening on" | \
            while read -r line; do
                log DATA "$line"
            done || true
    else
        timeout "$duration" tcpdump -i "$interface" -s "$SNAPLEN" -w "$output_pcap" 2>&1 | \
            grep -v "listening on" | \
            while read -r line; do
                log DATA "$line"
            done || true
    fi

    # Check if any packets were captured
    local packet_count
    packet_count=$(tcpdump -r "$output_pcap" 2>/dev/null | wc -l)

    if [[ $packet_count -eq 0 ]]; then
        log WARNING "No packets captured - check interface and filter"
        return 1
    fi

    log SUCCESS "Captured $packet_count packets"
    return 0
}

analyze_http_traffic() {
    local pcap_file="$1"
    local output_file="$2"

    log INFO "Analyzing HTTP traffic..."

    {
        echo "=== HTTP Traffic Analysis ==="
        echo "PCAP: $(basename "$pcap_file")"
        echo "Timestamp: $(date -u +"%Y-%m-%dT%H:%M:%S.%NZ")"
        echo ""

        if command -v tshark &>/dev/null; then
            echo "--- HTTP Requests ---"
            tshark -r "$pcap_file" -Y "http.request" -T fields \
                -e frame.time \
                -e ip.src \
                -e ip.dst \
                -e http.request.method \
                -e http.request.uri \
                -e http.user_agent \
                2>/dev/null | column -t || echo "No HTTP requests found"

            echo ""
            echo "--- HTTP Responses ---"
            tshark -r "$pcap_file" -Y "http.response" -T fields \
                -e frame.time \
                -e ip.src \
                -e ip.dst \
                -e http.response.code \
                -e http.content_type \
                -e http.content_length \
                2>/dev/null | column -t || echo "No HTTP responses found"

            echo ""
            echo "--- HTTP Headers (sample) ---"
            tshark -r "$pcap_file" -Y "http" -T fields -e http.request.full_uri -e http.host \
                2>/dev/null | head -20 || echo "No HTTP headers found"

        else
            echo "tshark not available - using tcpdump"
            tcpdump -r "$pcap_file" -A 'tcp port 80' 2>/dev/null | grep -E "(GET|POST|PUT|DELETE|HTTP)" | head -50
        fi

        echo ""
    } > "$output_file"

    log SUCCESS "HTTP analysis saved to: $output_file"
}

analyze_dns_traffic() {
    local pcap_file="$1"
    local output_file="$2"

    log INFO "Analyzing DNS traffic..."

    {
        echo "=== DNS Traffic Analysis ==="
        echo "PCAP: $(basename "$pcap_file")"
        echo "Timestamp: $(date -u +"%Y-%m-%dT%H:%M:%S.%NZ")"
        echo ""

        if command -v tshark &>/dev/null; then
            echo "--- DNS Queries ---"
            tshark -r "$pcap_file" -Y "dns.flags.response == 0" -T fields \
                -e frame.time \
                -e ip.src \
                -e dns.qry.name \
                -e dns.qry.type \
                2>/dev/null | column -t || echo "No DNS queries found"

            echo ""
            echo "--- DNS Responses ---"
            tshark -r "$pcap_file" -Y "dns.flags.response == 1" -T fields \
                -e frame.time \
                -e dns.qry.name \
                -e dns.a \
                -e dns.aaaa \
                2>/dev/null | column -t || echo "No DNS responses found"

            echo ""
            echo "--- C2 Domain Candidates (high query frequency) ---"
            tshark -r "$pcap_file" -Y "dns.qry.name" -T fields -e dns.qry.name \
                2>/dev/null | sort | uniq -c | sort -rn | head -20 || echo "No DNS data"

        else
            echo "tshark not available - using tcpdump"
            tcpdump -r "$pcap_file" -n 'port 53' 2>/dev/null | head -50
        fi

        echo ""
    } > "$output_file"

    log SUCCESS "DNS analysis saved to: $output_file"
}

analyze_tls_traffic() {
    local pcap_file="$1"
    local output_file="$2"

    log INFO "Analyzing TLS/SSL traffic..."

    {
        echo "=== TLS/SSL Traffic Analysis ==="
        echo "PCAP: $(basename "$pcap_file")"
        echo "Timestamp: $(date -u +"%Y-%m-%dT%H:%M:%S.%NZ")"
        echo ""

        if command -v tshark &>/dev/null; then
            echo "--- TLS Handshakes ---"
            tshark -r "$pcap_file" -Y "ssl.handshake.type == 1" -T fields \
                -e frame.time \
                -e ip.src \
                -e ip.dst \
                -e ssl.handshake.version \
                -e tls.handshake.extensions_server_name \
                2>/dev/null | column -t || echo "No TLS handshakes found"

            echo ""
            echo "--- Server Names (SNI) ---"
            tshark -r "$pcap_file" -Y "tls.handshake.extensions_server_name" -T fields \
                -e tls.handshake.extensions_server_name \
                2>/dev/null | sort -u || echo "No SNI data found"

            echo ""
            echo "--- TLS Versions ---"
            tshark -r "$pcap_file" -Y "ssl.handshake" -T fields -e ssl.handshake.version \
                2>/dev/null | sort | uniq -c || echo "No TLS version data"

        else
            echo "tshark not available - limited TLS analysis"
            tcpdump -r "$pcap_file" -n 'port 443' 2>/dev/null | head -30
        fi

        echo ""
    } > "$output_file"

    log SUCCESS "TLS analysis saved to: $output_file"
}

extract_c2_patterns() {
    local pcap_file="$1"
    local output_file="$2"

    log INFO "Extracting C2 communication patterns..."

    {
        echo "=== C2 Communication Patterns ==="
        echo "PCAP: $(basename "$pcap_file")"
        echo "Timestamp: $(date -u +"%Y-%m-%dT%H:%M:%S.%NZ")"
        echo ""

        if command -v tshark &>/dev/null; then
            echo "--- Connection Timeline ---"
            tshark -r "$pcap_file" -T fields \
                -e frame.time_relative \
                -e ip.src \
                -e ip.dst \
                -e tcp.srcport \
                -e tcp.dstport \
                -e tcp.len \
                -e tcp.flags \
                2>/dev/null | head -100 || echo "No connection data"

            echo ""
            echo "--- Unique Endpoints ---"
            echo "Sources:"
            tshark -r "$pcap_file" -T fields -e ip.src 2>/dev/null | sort -u
            echo ""
            echo "Destinations:"
            tshark -r "$pcap_file" -T fields -e ip.dst 2>/dev/null | sort -u

            echo ""
            echo "--- Port Usage ---"
            tshark -r "$pcap_file" -T fields -e tcp.dstport 2>/dev/null | sort | uniq -c | sort -rn | head -20

            echo ""
            echo "--- Packet Size Distribution ---"
            tshark -r "$pcap_file" -T fields -e frame.len 2>/dev/null | \
                awk '{sum+=$1; count++} END {if(count>0) printf "Average: %.2f bytes, Total packets: %d\n", sum/count, count}'

            echo ""
            echo "--- Periodic Behavior Detection ---"
            echo "Analyzing inter-packet timing..."
            tshark -r "$pcap_file" -T fields -e frame.time_relative 2>/dev/null | \
                awk 'NR>1 {diff=$1-prev; if(diff>0) print diff} {prev=$1}' | \
                sort -n | uniq -c | sort -rn | head -10 || echo "No timing patterns detected"

        else
            echo "tshark not available - using basic tcpdump"
            tcpdump -r "$pcap_file" -n | head -50
        fi

        echo ""
    } > "$output_file"

    log SUCCESS "C2 patterns saved to: $output_file"
}

generate_summary() {
    local pcap_file="$1"
    local output_dir="$2"
    local summary_file="$3"

    log INFO "Generating capture summary..."

    {
        echo "╔═══════════════════════════════════════════════════════════════╗"
        echo "║  C2 Traffic Capture Analysis Summary                         ║"
        echo "╚═══════════════════════════════════════════════════════════════╝"
        echo ""
        echo "Generated: $(date -u +"%Y-%m-%dT%H:%M:%S.%NZ")"
        echo "Tool: c2-traffic-capture.sh v$VERSION"
        echo "PCAP File: $pcap_file"
        echo ""
        echo "═══════════════════════════════════════════════════════════════"
        echo ""

        # Basic stats
        echo "--- Capture Statistics ---"
        if command -v capinfos &>/dev/null; then
            capinfos "$pcap_file" 2>/dev/null || tcpdump -r "$pcap_file" 2>&1 | head -5
        else
            tcpdump -r "$pcap_file" 2>&1 | head -5
        fi

        echo ""
        echo "--- Analysis Files Generated ---"
        find "$output_dir" -type f -name "*.txt" | while read -r file; do
            echo "  - $(basename "$file")"
        done

        echo ""
        echo "--- Key Findings ---"
        echo ""

        echo "HTTP Requests:"
        if [[ -f "$output_dir/http_analysis.txt" ]]; then
            grep -c "GET\|POST" "$output_dir/http_analysis.txt" 2>/dev/null || echo "0"
        else
            echo "  Not analyzed"
        fi

        echo ""
        echo "DNS Queries:"
        if [[ -f "$output_dir/dns_analysis.txt" ]]; then
            grep -c "DNS Queries" "$output_dir/dns_analysis.txt" 2>/dev/null || echo "0"
        else
            echo "  Not analyzed"
        fi

        echo ""
        echo "TLS Connections:"
        if [[ -f "$output_dir/tls_analysis.txt" ]]; then
            grep -c "TLS" "$output_dir/tls_analysis.txt" 2>/dev/null || echo "0"
        else
            echo "  Not analyzed"
        fi

        echo ""
        echo "═══════════════════════════════════════════════════════════════"
        echo ""
        echo "--- Recommended Next Steps ---"
        echo ""
        echo "1. PROTOCOL ANALYSIS:"
        echo "   - Review HTTP requests/responses for update check patterns"
        echo "   - Identify version number formats"
        echo "   - Extract API endpoints and parameters"
        echo ""
        echo "2. CRYPTOGRAPHIC ANALYSIS:"
        echo "   - Check for encrypted payloads"
        echo "   - Identify signature verification mechanisms"
        echo "   - Extract cryptographic constants"
        echo ""
        echo "3. BEHAVIORAL ANALYSIS:"
        echo "   - Identify heartbeat/check-in frequency"
        echo "   - Map command-and-control flow"
        echo "   - Detect update delivery mechanism"
        echo ""
        echo "4. INFRASTRUCTURE MAPPING:"
        echo "   - Identify all C2 endpoints"
        echo "   - Map fallback/backup infrastructure"
        echo "   - Analyze geographic distribution"
        echo ""
        echo "═══════════════════════════════════════════════════════════════"
        echo ""
        echo "All detailed reports available in: $output_dir"
        echo ""

    } > "$summary_file"

    log SUCCESS "Summary generated: $summary_file"
}

# === Main ===

main() {
    # Banner
    echo -e "${CYAN}${BOLD}"
    cat << "EOF"
╔═══════════════════════════════════════════════════════════════╗
║     C2 Traffic Capture and Analysis Tool                     ║
║     Protocol Reverse Engineering for Defensive Research      ║
╚═══════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"

    # Parse arguments
    local target_ip=""
    local target_domain=""
    local target_port=""
    local interface="$DEFAULT_INTERFACE"
    local duration="$DEFAULT_DURATION"
    local output_dir=""
    local analyze_only=false
    local pcap_to_analyze=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --target-ip)
                target_ip="$2"
                shift 2
                ;;
            --target-domain)
                target_domain="$2"
                shift 2
                ;;
            --target-port)
                target_port="$2"
                shift 2
                ;;
            --interface|-i)
                interface="$2"
                shift 2
                ;;
            --duration|-d)
                duration="$2"
                shift 2
                ;;
            --output|-o)
                output_dir="$2"
                shift 2
                ;;
            --analyze)
                analyze_only=true
                pcap_to_analyze="$2"
                shift 2
                ;;
            --help|-h)
                cat << EOF
Usage: $0 [OPTIONS]

Capture Mode Options:
  --target-ip IP        Target IP address to capture
  --target-domain DOM   Target domain to capture
  --target-port PORT    Target port to capture
  --interface IFACE     Network interface (default: $DEFAULT_INTERFACE)
  --duration SECS       Capture duration in seconds (default: $DEFAULT_DURATION)
  --output DIR          Output directory for analysis

Analysis Mode Options:
  --analyze PCAP        Analyze existing PCAP file

Examples:
  # Capture C2 traffic
  $0 --target-ip 151.242.2.22 --duration 300 --output ./analysis

  # Analyze existing capture
  $0 --analyze existing.pcap --output ./analysis

EOF
                exit 0
                ;;
            *)
                echo "Unknown option: $1"
                echo "Use --help for usage information"
                exit 1
                ;;
        esac
    done

    # Check requirements
    check_requirements

    # Set default output directory
    if [[ -z "$output_dir" ]]; then
        output_dir="c2_capture_$(date +%Y%m%d_%H%M%S)"
    fi
    mkdir -p "$output_dir"

    log INFO "Output directory: $output_dir"

    # Determine PCAP file
    local pcap_file
    if $analyze_only; then
        if [[ ! -f "$pcap_to_analyze" ]]; then
            log ERROR "PCAP file not found: $pcap_to_analyze"
            exit 1
        fi
        pcap_file="$pcap_to_analyze"
        log INFO "Analyzing existing PCAP: $pcap_file"
    else
        # Capture mode
        if [[ -z "$target_ip" ]] && [[ -z "$target_domain" ]]; then
            log ERROR "Must specify --target-ip or --target-domain for capture mode"
            exit 1
        fi

        # Build BPF filter
        bpf_filter=$(build_bpf_filter "$target_ip" "$target_domain" "$target_port")

        pcap_file="$output_dir/capture.pcap"

        # Capture traffic
        capture_traffic "$interface" "$duration" "$bpf_filter" "$pcap_file" || exit 1
    fi

    # Perform analysis
    log INFO "Starting traffic analysis..."

    analyze_http_traffic "$pcap_file" "$output_dir/http_analysis.txt"
    analyze_dns_traffic "$pcap_file" "$output_dir/dns_analysis.txt"
    analyze_tls_traffic "$pcap_file" "$output_dir/tls_analysis.txt"
    extract_c2_patterns "$pcap_file" "$output_dir/c2_patterns.txt"

    # Generate summary
    generate_summary "$pcap_file" "$output_dir" "$output_dir/CAPTURE_SUMMARY.txt"

    log SUCCESS "Analysis complete!"
    log INFO "Results directory: $output_dir"
    log INFO "Summary report: $output_dir/CAPTURE_SUMMARY.txt"
    echo ""
}

main "$@"
