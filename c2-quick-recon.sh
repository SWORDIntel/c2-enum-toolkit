#!/usr/bin/env bash
#
# c2-quick-recon.sh - Quick Reconnaissance of C2 Infrastructure
# Part of the C2 Enumeration Toolkit v2.6
#
# Purpose: Fast intelligence gathering on clearnet C2 servers
# Usage: ./c2-quick-recon.sh <targets_file> [output_dir]
#
# Features:
# - Quick DNS resolution and validation
# - Ping/ICMP reachability
# - Fast HTTP/HTTPS checks on common ports
# - Certificate grabbing
# - Basic BGP/ASN lookup
# - GeoIP resolution

set -euo pipefail
IFS=$'\n\t'

# === Configuration ===
VERSION="2.6-quick"
TIMEOUT=5
USER_AGENT="Mozilla/5.0 (X11; Linux x86_64)"

# Common C2 ports to check
QUICK_PORTS=(80 443 8080 8443 9000)

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
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
            echo -e "${BLUE}[INFO]${NC} [$timestamp] $message"
            ;;
        SUCCESS)
            echo -e "${GREEN}[✓]${NC} [$timestamp] $message"
            ;;
        WARNING)
            echo -e "${YELLOW}[!]${NC} [$timestamp] $message"
            ;;
        ERROR)
            echo -e "${RED}[✗]${NC} [$timestamp] $message"
            ;;
    esac
}

is_ip() {
    [[ $1 =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]
}

resolve_dns() {
    local target="$1"
    dig +short +timeout=3 A "$target" 2>/dev/null | head -1
}

check_reachability() {
    local target="$1"
    if timeout 3 ping -c 1 -W 1 "$target" &>/dev/null; then
        return 0
    else
        return 1
    fi
}

quick_port_check() {
    local target="$1"
    local port="$2"
    timeout 2 bash -c "echo >/dev/tcp/$target/$port" 2>/dev/null
}

grab_http_info() {
    local target="$1"
    local port="$2"
    local proto="http"
    [[ "$port" == "443" ]] || [[ "$port" == "8443" ]] && proto="https"

    local url="${proto}://${target}:${port}/"
    local output
    output=$(timeout "$TIMEOUT" curl -s -I -L -A "$USER_AGENT" "$url" 2>/dev/null | head -20)
    echo "$output"
}

grab_cert() {
    local target="$1"
    local port="$2"
    echo | timeout "$TIMEOUT" openssl s_client -connect "$target:$port" -servername "$target" 2>/dev/null | \
        openssl x509 -text -noout 2>/dev/null | head -50
}

quick_asn() {
    local ip="$1"
    timeout 5 curl -s "https://ipinfo.io/${ip}/json" 2>/dev/null | jq -r '"\(.org // "N/A")|\(.country // "N/A")|\(.city // "N/A")"' 2>/dev/null || echo "N/A|N/A|N/A"
}

# === Main Processing ===

process_target() {
    local target="$1"
    local output_dir="$2"

    echo ""
    echo "═══════════════════════════════════════════════════════════════"
    log INFO "Target: $target"
    echo "═══════════════════════════════════════════════════════════════"

    local target_file="$output_dir/${target//[:\/]/_}.txt"

    {
        echo "╔═══════════════════════════════════════════════════════════════╗"
        echo "║  Quick C2 Reconnaissance Report                              ║"
        echo "╚═══════════════════════════════════════════════════════════════╝"
        echo ""
        echo "Target: $target"
        echo "Timestamp: $(date -u +"%Y-%m-%dT%H:%M:%S.%NZ")"
        echo "Tool: c2-quick-recon v$VERSION"
        echo ""
        echo "═══════════════════════════════════════════════════════════════"
        echo ""

        # Determine IP
        local ip="$target"
        if ! is_ip "$target"; then
            log INFO "Resolving DNS..."
            ip=$(resolve_dns "$target")
            if [[ -n "$ip" ]]; then
                echo "--- DNS Resolution ---"
                echo "Domain: $target"
                echo "IP: $ip"
                echo ""
                log SUCCESS "Resolved to $ip"
            else
                echo "--- DNS Resolution ---"
                echo "FAILED: Could not resolve $target"
                echo ""
                log ERROR "DNS resolution failed"
                return 1
            fi
        else
            echo "--- Target Type ---"
            echo "IP Address: $ip"
            echo ""
        fi

        # Reachability
        echo "--- Reachability ---"
        if check_reachability "$ip"; then
            echo "Status: REACHABLE (ICMP)"
            log SUCCESS "Target is reachable via ICMP"
        else
            echo "Status: NOT REACHABLE via ICMP (firewall may be blocking)"
            log WARNING "ICMP blocked or host down"
        fi
        echo ""

        # ASN/GeoIP
        echo "--- Network Information ---"
        local asn_info
        asn_info=$(quick_asn "$ip")
        IFS='|' read -r org country city <<< "$asn_info"
        echo "Organization: $org"
        echo "Country: $country"
        echo "City: $city"
        echo ""

        # Quick port scan
        echo "--- Port Scan (Quick) ---"
        local found_open=0
        for port in "${QUICK_PORTS[@]}"; do
            if quick_port_check "$ip" "$port"; then
                echo "Port $port/tcp: OPEN"
                log SUCCESS "Port $port is open"
                found_open=1

                # HTTP/HTTPS enumeration
                echo ""
                echo "  --- HTTP Info (Port $port) ---"
                grab_http_info "$ip" "$port" | grep -E "^(HTTP|Server|Content-Type|Location|X-|Set-Cookie)" || echo "  No headers retrieved"

                # Certificate for HTTPS
                if [[ "$port" == "443" ]] || [[ "$port" == "8443" ]]; then
                    echo ""
                    echo "  --- SSL Certificate (Port $port) ---"
                    grab_cert "$ip" "$port" | grep -E "(Subject:|Issuer:|DNS:|Not Before|Not After)" || echo "  No certificate retrieved"
                fi
                echo ""
            fi
        done

        if [[ $found_open -eq 0 ]]; then
            echo "No open ports found on quick scan"
            log WARNING "No open ports detected"
        fi
        echo ""

        # WHOIS snippet
        echo "--- WHOIS (abbreviated) ---"
        if command -v whois &>/dev/null; then
            timeout 5 whois "$ip" 2>/dev/null | grep -iE "(netname|orgname|country|descr)" | head -10 || echo "WHOIS unavailable"
        else
            echo "whois command not available"
        fi
        echo ""

        echo "═══════════════════════════════════════════════════════════════"
        echo "Reconnaissance complete for $target"
        echo "═══════════════════════════════════════════════════════════════"

    } | tee "$target_file"

    log SUCCESS "Report saved: $target_file"
}

# === Main ===

main() {
    if [[ $# -lt 1 ]]; then
        echo "Usage: $0 <targets_file> [output_dir]"
        echo ""
        echo "Arguments:"
        echo "  targets_file  - File containing list of domains/IPs"
        echo "  output_dir    - Output directory (default: quick_recon_TIMESTAMP)"
        echo ""
        echo "Example:"
        echo "  $0 aisuru_targets.txt"
        exit 1
    fi

    local targets_file="$1"
    local output_dir="${2:-quick_recon_$(date +%Y%m%d_%H%M%S)}"

    if [[ ! -f "$targets_file" ]]; then
        echo "Error: Targets file not found: $targets_file"
        exit 1
    fi

    mkdir -p "$output_dir"

    cat << "EOF"
╔═══════════════════════════════════════════════════════════════╗
║     C2 Quick Reconnaissance Tool v2.6                        ║
║     Fast Intelligence Gathering for C2 Infrastructure        ║
╚═══════════════════════════════════════════════════════════════╝
EOF

    log INFO "Starting quick reconnaissance"
    log INFO "Targets: $targets_file"
    log INFO "Output: $output_dir"
    echo ""

    # Process targets
    local target_count=0
    local success_count=0

    while IFS= read -r line; do
        [[ "$line" =~ ^#.*$ ]] && continue
        [[ -z "$line" ]] && continue

        local target
        target=$(echo "$line" | awk '{print $1}')

        ((target_count++))

        if process_target "$target" "$output_dir"; then
            ((success_count++))
        fi

    done < "$targets_file"

    # Summary
    echo ""
    echo "╔═══════════════════════════════════════════════════════════════╗"
    echo "║                    Reconnaissance Summary                     ║"
    echo "╚═══════════════════════════════════════════════════════════════╝"
    echo ""
    echo "Total targets processed: $target_count"
    echo "Successful enumerations: $success_count"
    echo "Output directory: $output_dir"
    echo ""

    # Generate master report
    local master_report="$output_dir/MASTER_REPORT.txt"
    {
        echo "═══════════════════════════════════════════════════════════════"
        echo "  AISURU Botnet C2 Quick Reconnaissance Summary"
        echo "═══════════════════════════════════════════════════════════════"
        echo ""
        echo "Generated: $(date -u +"%Y-%m-%dT%H:%M:%S.%NZ")"
        echo "Total Targets: $target_count"
        echo "Successful: $success_count"
        echo ""
        echo "═══════════════════════════════════════════════════════════════"
        echo ""

        for report in "$output_dir"/*.txt; do
            [[ "$report" == "$master_report" ]] && continue
            [[ -f "$report" ]] || continue
            cat "$report"
            echo ""
            echo "---"
            echo ""
        done
    } > "$master_report"

    log SUCCESS "Master report: $master_report"
    log SUCCESS "Reconnaissance complete!"
}

main "$@"
