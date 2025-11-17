#!/usr/bin/env bash
#
# c2-enum-clearnet.sh - Comprehensive Clearnet C2 Enumeration Tool
# Part of the C2 Enumeration Toolkit v2.6
#
# Purpose: Enumerate and analyze clearnet C2 infrastructure (domains and IPs)
# Usage: ./c2-enum-clearnet.sh <target_file> [output_dir]
#
# Features:
# - DNS resolution and validation
# - Port scanning (standard and comprehensive modes)
# - HTTP/HTTPS enumeration
# - Certificate analysis
# - Service fingerprinting
# - Integration with existing analyzers
# - BGP/ASN lookups
# - GeoIP resolution
# - Compatible with takeover functionality

set -euo pipefail
IFS=$'\n\t'

# === Configuration ===
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ANALYZERS_DIR="$SCRIPT_DIR/analyzers"
VERSION="2.6-clearnet"
TIMEOUT=10
USER_AGENT="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# === Standard Ports ===
STANDARD_PORTS=(
    21    # FTP
    22    # SSH
    23    # Telnet
    25    # SMTP
    53    # DNS
    80    # HTTP
    110   # POP3
    143   # IMAP
    443   # HTTPS
    465   # SMTPS
    587   # SMTP Submission
    993   # IMAPS
    995   # POP3S
    3306  # MySQL
    3389  # RDP
    5432  # PostgreSQL
    5900  # VNC
    6379  # Redis
    8080  # HTTP Alt
    8443  # HTTPS Alt
    9000  # HTTP Alt
    9050  # Tor SOCKS
    9999  # Common C2
)

# === Comprehensive Ports ===
COMPREHENSIVE_PORTS=(
    "${STANDARD_PORTS[@]}"
    1080  # SOCKS Proxy
    1433  # MSSQL
    1521  # Oracle
    2049  # NFS
    2082  # cPanel
    2083  # cPanel SSL
    2086  # WHM
    2087  # WHM SSL
    2181  # Zookeeper
    2375  # Docker
    2376  # Docker SSL
    3000  # Various web services
    3128  # Squid Proxy
    4444  # Metasploit
    4567  # Common C2
    5000  # Flask/Python
    5555  # Android Debug Bridge
    6000  # X11
    6667  # IRC
    7000  # Common services
    7001  # WebLogic
    8000  # HTTP Alt
    8001  # HTTP Alt
    8008  # HTTP Alt
    8081  # HTTP Alt
    8082  # HTTP Alt
    8083  # HTTP Alt
    8088  # HTTP Alt
    8181  # HTTP Alt
    8888  # HTTP Alt
    9001  # Tor/HTTP Alt
    9002  # HTTP Alt
    9090  # HTTP Alt
    9200  # Elasticsearch
    27017 # MongoDB
    50000 # SAP
    50070 # Hadoop
)

# === Common C2 Paths ===
C2_PATHS=(
    "/"
    "/admin"
    "/api"
    "/bot"
    "/c2"
    "/cmd"
    "/config"
    "/control"
    "/download"
    "/gate"
    "/panel"
    "/ping"
    "/report"
    "/upload"
    "/status"
    "/heartbeat"
    "/check"
    "/update"
    "/register"
    "/task"
)

# === Functions ===

log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    case "$level" in
        INFO)
            echo -e "${BLUE}[INFO]${NC} [$timestamp] $message" | tee -a "$LOG_FILE"
            ;;
        SUCCESS)
            echo -e "${GREEN}[SUCCESS]${NC} [$timestamp] $message" | tee -a "$LOG_FILE"
            ;;
        WARNING)
            echo -e "${YELLOW}[WARNING]${NC} [$timestamp] $message" | tee -a "$LOG_FILE"
            ;;
        ERROR)
            echo -e "${RED}[ERROR]${NC} [$timestamp] $message" | tee -a "$LOG_FILE"
            ;;
        *)
            echo "[$timestamp] $message" | tee -a "$LOG_FILE"
            ;;
    esac
}

banner() {
    cat << "EOF"
╔═══════════════════════════════════════════════════════════════╗
║     C2 Clearnet Enumeration Tool v2.6                        ║
║     Comprehensive Intelligence Gathering for C2 Infrastructure║
╚═══════════════════════════════════════════════════════════════╝
EOF
}

# Check if target is IP or domain
is_ip() {
    local target="$1"
    if [[ $target =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        return 0
    else
        return 1
    fi
}

# DNS Resolution
resolve_dns() {
    local target="$1"
    local output_file="$2"

    log INFO "Performing DNS resolution for $target"

    {
        echo "=== DNS Resolution for $target ==="
        echo "Timestamp: $(date -u +"%Y-%m-%dT%H:%M:%S.%NZ")"
        echo ""

        # A records
        echo "--- A Records ---"
        dig +short A "$target" 2>/dev/null || echo "No A records found"
        echo ""

        # AAAA records
        echo "--- AAAA Records ---"
        dig +short AAAA "$target" 2>/dev/null || echo "No AAAA records found"
        echo ""

        # MX records
        echo "--- MX Records ---"
        dig +short MX "$target" 2>/dev/null || echo "No MX records found"
        echo ""

        # TXT records
        echo "--- TXT Records ---"
        dig +short TXT "$target" 2>/dev/null || echo "No TXT records found"
        echo ""

        # NS records
        echo "--- NS Records ---"
        dig +short NS "$target" 2>/dev/null || echo "No NS records found"
        echo ""

        # CNAME records
        echo "--- CNAME Records ---"
        dig +short CNAME "$target" 2>/dev/null || echo "No CNAME records found"
        echo ""

    } > "$output_file"

    # Extract primary IP
    primary_ip=$(dig +short A "$target" 2>/dev/null | head -1)
    if [[ -n "$primary_ip" ]]; then
        log SUCCESS "Resolved $target to $primary_ip"
        echo "$primary_ip" > "${output_file}.primary_ip"
        return 0
    else
        log WARNING "Could not resolve $target"
        return 1
    fi
}

# Reverse DNS lookup
reverse_dns() {
    local ip="$1"
    local output_file="$2"

    log INFO "Performing reverse DNS lookup for $ip"

    {
        echo "=== Reverse DNS for $ip ==="
        echo "Timestamp: $(date -u +"%Y-%m-%dT%H:%M:%S.%NZ")"
        echo ""
        dig +short -x "$ip" 2>/dev/null || echo "No PTR record found"
    } > "$output_file"
}

# WHOIS lookup
whois_lookup() {
    local target="$1"
    local output_file="$2"

    log INFO "Performing WHOIS lookup for $target"

    if command -v whois &>/dev/null; then
        whois "$target" > "$output_file" 2>&1 || log WARNING "WHOIS lookup failed for $target"
    else
        log WARNING "whois command not found, skipping WHOIS lookup"
        echo "whois command not available" > "$output_file"
    fi
}

# ASN lookup
asn_lookup() {
    local ip="$1"
    local output_file="$2"

    log INFO "Performing ASN lookup for $ip"

    {
        echo "=== ASN Lookup for $ip ==="
        echo "Timestamp: $(date -u +"%Y-%m-%dT%H:%M:%S.%NZ")"
        echo ""

        # Using Team Cymru's IP to ASN service
        whois -h whois.cymru.com " -v $ip" 2>/dev/null || echo "ASN lookup failed"
    } > "$output_file"
}

# Port scanning
port_scan() {
    local target="$1"
    local mode="$2"
    local output_file="$3"

    local ports_to_scan=()

    if [[ "$mode" == "comprehensive" ]]; then
        ports_to_scan=("${COMPREHENSIVE_PORTS[@]}")
        log INFO "Scanning ${#COMPREHENSIVE_PORTS[@]} ports on $target (comprehensive mode)"
    else
        ports_to_scan=("${STANDARD_PORTS[@]}")
        log INFO "Scanning ${#STANDARD_PORTS[@]} ports on $target (standard mode)"
    fi

    {
        echo "=== Port Scan Results for $target ==="
        echo "Mode: $mode"
        echo "Timestamp: $(date -u +"%Y-%m-%dT%H:%M:%S.%NZ")"
        echo ""
        echo "Port | State | Service"
        echo "-----|-------|--------"
    } > "$output_file"

    local open_ports_file="${output_file}.open"
    > "$open_ports_file"

    local open_count=0

    for port in "${ports_to_scan[@]}"; do
        # Attempt TCP connection with timeout
        if timeout 3 bash -c "echo >/dev/tcp/$target/$port" 2>/dev/null; then
            service=$(getent services "$port/tcp" 2>/dev/null | awk '{print $1}' || echo "unknown")
            echo "$port | OPEN | $service" >> "$output_file"
            echo "$port" >> "$open_ports_file"
            log SUCCESS "Port $port/tcp is OPEN on $target ($service)"
            ((open_count++))
        fi
    done

    log INFO "Port scan complete: $open_count open ports found"
    echo "" >> "$output_file"
    echo "Total open ports: $open_count" >> "$output_file"
}

# HTTP enumeration
http_enumerate() {
    local target="$1"
    local port="$2"
    local output_dir="$3"

    local proto="http"
    [[ "$port" == "443" ]] || [[ "$port" == "8443" ]] && proto="https"

    local base_url="${proto}://${target}:${port}"

    log INFO "Enumerating HTTP(S) on $base_url"

    # Headers
    local headers_file="$output_dir/${target}_${port}_headers.txt"
    {
        echo "=== HTTP Headers for $base_url ==="
        echo "Timestamp: $(date -u +"%Y-%m-%dT%H:%M:%S.%NZ")"
        echo ""
        timeout "$TIMEOUT" curl -s -I -A "$USER_AGENT" -L "$base_url/" 2>/dev/null || echo "Failed to retrieve headers"
    } > "$headers_file"

    # Test C2 paths
    local paths_file="$output_dir/${target}_${port}_paths.txt"
    {
        echo "=== Path Enumeration for $base_url ==="
        echo "Timestamp: $(date -u +"%Y-%m-%dT%H:%M:%S.%NZ")"
        echo ""
        echo "Path | Status | Size"
        echo "-----|--------|-----"
    } > "$paths_file"

    for path in "${C2_PATHS[@]}"; do
        local url="${base_url}${path}"
        local response
        response=$(timeout "$TIMEOUT" curl -s -o /dev/null -w "%{http_code}|%{size_download}" -A "$USER_AGENT" "$url" 2>/dev/null || echo "000|0")
        local status_code="${response%%|*}"
        local size="${response##*|}"

        if [[ "$status_code" != "000" ]] && [[ "$status_code" != "404" ]]; then
            echo "$path | $status_code | $size" >> "$paths_file"
            log SUCCESS "Found interesting path: $url (Status: $status_code)"

            # Download content for interesting responses
            if [[ "$status_code" =~ ^(200|301|302)$ ]]; then
                local content_file="$output_dir/${target}_${port}_${path//\//_}.sample"
                timeout "$TIMEOUT" curl -s -A "$USER_AGENT" "$url" > "$content_file" 2>/dev/null || true
            fi
        fi
    done
}

# Certificate analysis
cert_analyze() {
    local target="$1"
    local port="$2"
    local output_file="$3"

    log INFO "Analyzing SSL/TLS certificate for $target:$port"

    {
        echo "=== Certificate Analysis for $target:$port ==="
        echo "Timestamp: $(date -u +"%Y-%m-%dT%H:%M:%S.%NZ")"
        echo ""

        # Get certificate
        echo | timeout "$TIMEOUT" openssl s_client -connect "$target:$port" -servername "$target" 2>/dev/null | \
            openssl x509 -text -noout 2>/dev/null || echo "Failed to retrieve certificate"

        echo ""
        echo "--- Certificate Chain ---"
        echo | timeout "$TIMEOUT" openssl s_client -connect "$target:$port" -servername "$target" -showcerts 2>/dev/null || \
            echo "Failed to retrieve certificate chain"
    } > "$output_file"
}

# Banner grabbing
banner_grab() {
    local target="$1"
    local port="$2"
    local output_file="$3"

    log INFO "Grabbing banner from $target:$port"

    {
        echo "=== Banner from $target:$port ==="
        echo "Timestamp: $(date -u +"%Y-%m-%dT%H:%M:%S.%NZ")"
        echo ""

        # Try to grab banner
        timeout 5 bash -c "echo -e 'HEAD / HTTP/1.0\r\n\r\n' | nc -w 3 $target $port" 2>/dev/null || \
            echo "Failed to grab banner"
    } > "$output_file"
}

# Process single target
process_target() {
    local target="$1"
    local mode="$2"
    local output_base="$3"

    log INFO "Processing target: $target"

    # Create target-specific directory
    local target_dir="$output_base/intel_${target//[:\/]/_}"
    mkdir -p "$target_dir"

    # Save target context
    echo "$target" > "$target_dir/.target_domain"

    # Determine if IP or domain
    local resolved_ip="$target"
    if ! is_ip "$target"; then
        # Resolve DNS
        resolve_dns "$target" "$target_dir/dns_resolution.txt"
        if [[ -f "$target_dir/dns_resolution.txt.primary_ip" ]]; then
            resolved_ip=$(cat "$target_dir/dns_resolution.txt.primary_ip")
        else
            log ERROR "Failed to resolve $target, skipping"
            return 1
        fi

        # WHOIS lookup
        whois_lookup "$target" "$target_dir/whois.txt"
    else
        # Reverse DNS
        reverse_dns "$target" "$target_dir/reverse_dns.txt"
    fi

    # ASN lookup
    asn_lookup "$resolved_ip" "$target_dir/asn.txt"

    # Port scanning
    port_scan "$resolved_ip" "$mode" "$target_dir/port_scan.txt"

    # Process open ports
    if [[ -f "$target_dir/port_scan.txt.open" ]]; then
        while IFS= read -r port; do
            log INFO "Processing open port: $port"

            # HTTP/HTTPS enumeration
            if [[ "$port" =~ ^(80|443|8000|8080|8081|8443|8888|9000)$ ]]; then
                http_enumerate "$resolved_ip" "$port" "$target_dir"

                # Certificate analysis for HTTPS ports
                if [[ "$port" =~ ^(443|8443)$ ]]; then
                    cert_analyze "$resolved_ip" "$port" "$target_dir/cert_${port}.txt"
                fi
            fi

            # Banner grabbing for other services
            banner_grab "$resolved_ip" "$port" "$target_dir/banner_${port}.txt"

        done < "$target_dir/port_scan.txt.open"
    fi

    # Generate target report
    generate_target_report "$target_dir"

    log SUCCESS "Completed processing $target"
}

# Generate target report
generate_target_report() {
    local target_dir="$1"
    local report_file="$target_dir/report.txt"
    local target
    target=$(cat "$target_dir/.target_domain" 2>/dev/null || echo "unknown")

    {
        echo "╔═══════════════════════════════════════════════════════════════╗"
        echo "║  C2 Clearnet Enumeration Report                              ║"
        echo "╚═══════════════════════════════════════════════════════════════╝"
        echo ""
        echo "Target: $target"
        echo "Timestamp: $(date -u +"%Y-%m-%dT%H:%M:%S.%NZ")"
        echo "Tool: c2-enum-clearnet v$VERSION"
        echo ""
        echo "═══════════════════════════════════════════════════════════════"
        echo ""

        # DNS Summary
        if [[ -f "$target_dir/dns_resolution.txt" ]]; then
            echo "--- DNS Resolution ---"
            grep -A 1 "A Records" "$target_dir/dns_resolution.txt" | tail -1
            echo ""
        fi

        # Port Summary
        if [[ -f "$target_dir/port_scan.txt" ]]; then
            echo "--- Open Ports ---"
            grep "OPEN" "$target_dir/port_scan.txt" || echo "No open ports found"
            echo ""
        fi

        # HTTP Summary
        echo "--- HTTP/HTTPS Findings ---"
        find "$target_dir" -name "*_paths.txt" -exec cat {} \; 2>/dev/null || echo "No HTTP enumeration performed"
        echo ""

        # Files collected
        echo "--- Artifacts Collected ---"
        find "$target_dir" -type f | wc -l
        echo "files"
        echo ""

    } > "$report_file"

    log SUCCESS "Report generated: $report_file"
}

# Generate master report
generate_master_report() {
    local output_base="$1"
    local master_report="$output_base/MASTER_REPORT.txt"

    log INFO "Generating master report"

    {
        echo "╔═══════════════════════════════════════════════════════════════╗"
        echo "║  AISURU Botnet C2 Infrastructure Enumeration Report         ║"
        echo "╚═══════════════════════════════════════════════════════════════╝"
        echo ""
        echo "Generated: $(date -u +"%Y-%m-%dT%H:%M:%S.%NZ")"
        echo "Tool: c2-enum-clearnet v$VERSION"
        echo ""
        echo "═══════════════════════════════════════════════════════════════"
        echo ""

        # Summary
        local total_targets
        total_targets=$(find "$output_base" -type d -name "intel_*" | wc -l)
        echo "Total targets enumerated: $total_targets"
        echo ""

        # Individual summaries
        for target_dir in "$output_base"/intel_*; do
            if [[ -f "$target_dir/report.txt" ]]; then
                cat "$target_dir/report.txt"
                echo ""
                echo "═══════════════════════════════════════════════════════════════"
                echo ""
            fi
        done

    } > "$master_report"

    log SUCCESS "Master report generated: $master_report"
}

# === Main ===

main() {
    if [[ $# -lt 1 ]]; then
        echo "Usage: $0 <targets_file> [output_dir] [mode]"
        echo ""
        echo "Arguments:"
        echo "  targets_file  - File containing list of domains/IPs to enumerate"
        echo "  output_dir    - Output directory (default: aisuru_enum_TIMESTAMP)"
        echo "  mode          - 'standard' or 'comprehensive' (default: comprehensive)"
        echo ""
        echo "Example:"
        echo "  $0 aisuru_targets.txt"
        echo "  $0 aisuru_targets.txt ./output comprehensive"
        exit 1
    fi

    local targets_file="$1"
    local output_base="${2:-aisuru_enum_$(date +%Y%m%d_%H%M%S)}"
    local scan_mode="${3:-comprehensive}"

    # Validate inputs
    if [[ ! -f "$targets_file" ]]; then
        echo "Error: Targets file not found: $targets_file"
        exit 1
    fi

    # Create output directory
    mkdir -p "$output_base"
    LOG_FILE="$output_base/enumeration.log"

    # Display banner
    banner

    log INFO "Starting C2 clearnet enumeration"
    log INFO "Targets file: $targets_file"
    log INFO "Output directory: $output_base"
    log INFO "Scan mode: $scan_mode"

    # Process each target
    local target_count=0
    while IFS= read -r line; do
        # Skip comments and empty lines
        [[ "$line" =~ ^#.*$ ]] && continue
        [[ -z "$line" ]] && continue

        # Extract target (remove comments)
        local target
        target=$(echo "$line" | awk '{print $1}')

        ((target_count++))
        log INFO "Processing target $target_count: $target"

        process_target "$target" "$scan_mode" "$output_base" || log WARNING "Failed to fully process $target"

    done < "$targets_file"

    # Generate master report
    generate_master_report "$output_base"

    log SUCCESS "Enumeration complete!"
    log INFO "Results saved to: $output_base"
    log INFO "Master report: $output_base/MASTER_REPORT.txt"
}

# Run main function
main "$@"
