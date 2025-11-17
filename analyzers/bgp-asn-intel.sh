#!/usr/bin/env bash
#
# bgp-asn-intel.sh - BGP and ASN Intelligence Analyzer
# Part of the C2 Enumeration Toolkit v2.6
#
# Purpose: Gather BGP routing, ASN, and network infrastructure intelligence
# Usage: ./bgp-asn-intel.sh <ip_or_domain> <output_file>
#
# Features:
# - ASN lookups via multiple sources
# - BGP prefix information
# - Network ownership details
# - Geolocation data
# - Historical routing data analysis
# - Peer relationship mapping

set -euo pipefail
IFS=$'\n\t'

# === Configuration ===
TIMEOUT=10
USER_AGENT="Mozilla/5.0 (X11; Linux x86_64)"

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

    case "$level" in
        INFO)
            echo -e "${BLUE}[INFO]${NC} $message" >&2
            ;;
        SUCCESS)
            echo -e "${GREEN}[SUCCESS]${NC} $message" >&2
            ;;
        WARNING)
            echo -e "${YELLOW}[WARNING]${NC} $message" >&2
            ;;
        ERROR)
            echo -e "${RED}[ERROR]${NC} $message" >&2
            ;;
    esac
}

# Check if input is IP address
is_ip() {
    local input="$1"
    if [[ $input =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        return 0
    else
        return 1
    fi
}

# Resolve domain to IP
resolve_ip() {
    local domain="$1"
    local ip
    ip=$(dig +short A "$domain" 2>/dev/null | head -1)
    echo "$ip"
}

# Team Cymru ASN lookup
cymru_asn_lookup() {
    local ip="$1"

    log INFO "Querying Team Cymru for ASN information"

    {
        echo "=== Team Cymru ASN Lookup ==="
        echo "IP: $ip"
        echo ""
        whois -h whois.cymru.com " -v $ip" 2>/dev/null || echo "Query failed"
    }
}

# RIPE Stat API lookup
ripe_stat_lookup() {
    local ip="$1"

    log INFO "Querying RIPE Stat API"

    {
        echo ""
        echo "=== RIPE Stat Information ==="
        echo "IP: $ip"
        echo ""

        # ASN overview
        echo "--- ASN Overview ---"
        timeout "$TIMEOUT" curl -s "https://stat.ripe.net/data/whois/data.json?resource=$ip" 2>/dev/null | \
            jq -r '.data.records[] | select(.key != null) | "\(.key): \(.value)"' 2>/dev/null || echo "Query failed"

        echo ""
        echo "--- Network Info ---"
        timeout "$TIMEOUT" curl -s "https://stat.ripe.net/data/network-info/data.json?resource=$ip" 2>/dev/null | \
            jq -r '.data | "Prefix: \(.prefix // "N/A")\nASN: \(.asns[0] // "N/A")"' 2>/dev/null || echo "Query failed"

        echo ""
        echo "--- Announced Prefixes ---"
        timeout "$TIMEOUT" curl -s "https://stat.ripe.net/data/announced-prefixes/data.json?resource=$ip" 2>/dev/null | \
            jq -r '.data.prefixes[]? | "\(.prefix) - Timefirst: \(.timefirst)"' 2>/dev/null | head -10 || echo "Query failed"

        echo ""
        echo "--- Geolocation ---"
        timeout "$TIMEOUT" curl -s "https://stat.ripe.net/data/geoloc/data.json?resource=$ip" 2>/dev/null | \
            jq -r '.data.locations[]? | "Country: \(.country // "N/A"), City: \(.city // "N/A"), Lat: \(.latitude // "N/A"), Long: \(.longitude // "N/A")"' 2>/dev/null || echo "Query failed"

        echo ""
        echo "--- Abuse Contact ---"
        timeout "$TIMEOUT" curl -s "https://stat.ripe.net/data/abuse-contact-finder/data.json?resource=$ip" 2>/dev/null | \
            jq -r '.data | "Abuse Email: \(.abuse_contacts[0] // "N/A")"' 2>/dev/null || echo "Query failed"
    }
}

# BGPView API lookup
bgpview_lookup() {
    local ip="$1"

    log INFO "Querying BGPView API"

    {
        echo ""
        echo "=== BGPView Information ==="
        echo "IP: $ip"
        echo ""

        # Get prefix information
        local response
        response=$(timeout "$TIMEOUT" curl -s "https://api.bgpview.io/ip/$ip" 2>/dev/null || echo "{}")

        echo "--- IP Details ---"
        echo "$response" | jq -r '.data | "IP: \(.ip // "N/A")\nPTR: \(.ptr_record // "N/A")\nPrefix: \(.prefixes[0].prefix // "N/A")\nASN: \(.prefixes[0].asn.asn // "N/A")\nAS Name: \(.prefixes[0].asn.name // "N/A")\nAS Description: \(.prefixes[0].asn.description // "N/A")\nCountry: \(.prefixes[0].asn.country_code // "N/A")"' 2>/dev/null || echo "Parse failed"

        # Get ASN if available
        local asn
        asn=$(echo "$response" | jq -r '.data.prefixes[0].asn.asn' 2>/dev/null)

        if [[ -n "$asn" ]] && [[ "$asn" != "null" ]]; then
            echo ""
            echo "--- ASN Details (AS$asn) ---"
            timeout "$TIMEOUT" curl -s "https://api.bgpview.io/asn/$asn" 2>/dev/null | \
                jq -r '.data | "Name: \(.name // "N/A")\nDescription: \(.description_short // "N/A")\nWebsite: \(.website // "N/A")\nEmail Contacts: \(.email_contacts[0] // "N/A")\nAbuse Contacts: \(.abuse_contacts[0] // "N/A")\nLooking Glass: \(.looking_glass // "N/A")\nTraffic Estimation: \(.traffic_estimation // "N/A")\nTraffic Ratio: \(.traffic_ratio // "N/A")"' 2>/dev/null || echo "Parse failed"

            echo ""
            echo "--- Announced Prefixes ---"
            timeout "$TIMEOUT" curl -s "https://api.bgpview.io/asn/$asn/prefixes" 2>/dev/null | \
                jq -r '.data.ipv4_prefixes[]? | "IPv4: \(.prefix) - \(.name // "N/A")"' 2>/dev/null | head -10 || echo "Parse failed"

            echo ""
            echo "--- Upstream Providers ---"
            timeout "$TIMEOUT" curl -s "https://api.bgpview.io/asn/$asn/upstreams" 2>/dev/null | \
                jq -r '.data.ipv4_upstreams[]? | "AS\(.asn) - \(.name) (\(.country_code))"' 2>/dev/null | head -10 || echo "Parse failed"

            echo ""
            echo "--- Downstream Peers ---"
            timeout "$TIMEOUT" curl -s "https://api.bgpview.io/asn/$asn/downstreams" 2>/dev/null | \
                jq -r '.data.ipv4_downstreams[]? | "AS\(.asn) - \(.name) (\(.country_code))"' 2>/dev/null | head -10 || echo "Parse failed"
        fi
    }
}

# IP Geolocation
geoip_lookup() {
    local ip="$1"

    log INFO "Performing GeoIP lookup"

    {
        echo ""
        echo "=== GeoIP Information ==="
        echo "IP: $ip"
        echo ""

        # Using ip-api.com (free, no API key required)
        timeout "$TIMEOUT" curl -s "http://ip-api.com/json/$ip" 2>/dev/null | \
            jq -r '"Country: \(.country // "N/A")\nCountry Code: \(.countryCode // "N/A")\nRegion: \(.regionName // "N/A")\nCity: \(.city // "N/A")\nZIP: \(.zip // "N/A")\nLatitude: \(.lat // "N/A")\nLongitude: \(.lon // "N/A")\nTimezone: \(.timezone // "N/A")\nISP: \(.isp // "N/A")\nOrganization: \(.org // "N/A")\nAS: \(.as // "N/A")"' 2>/dev/null || echo "Query failed"
    }
}

# RIPEstat looking glass
ripe_looking_glass() {
    local ip="$1"

    log INFO "Checking RIPE looking glass data"

    {
        echo ""
        echo "=== RIPE Looking Glass ==="
        echo "IP: $ip"
        echo ""

        echo "--- BGP State ---"
        timeout "$TIMEOUT" curl -s "https://stat.ripe.net/data/bgp-state/data.json?resource=$ip" 2>/dev/null | \
            jq -r '.data.bgp_state[]? | "Prefix: \(.target.prefix)\nPath: \(."path" | join(" "))\nCommunity: \(.community | join(", "))\nOrigin: \(.origin)"' 2>/dev/null | head -20 || echo "Query failed"

        echo ""
        echo "--- BGP Updates (Recent activity) ---"
        timeout "$TIMEOUT" curl -s "https://stat.ripe.net/data/bgp-updates/data.json?resource=$ip" 2>/dev/null | \
            jq -r '.data.updates[]? | "\(.timestamp) - Type: \(.type), Prefix: \(.attrs.target_prefix // "N/A")"' 2>/dev/null | head -10 || echo "Query failed"
    }
}

# WHOIS detailed lookup
detailed_whois() {
    local target="$1"

    log INFO "Performing detailed WHOIS lookup"

    {
        echo ""
        echo "=== Detailed WHOIS ==="
        echo "Target: $target"
        echo ""

        if command -v whois &>/dev/null; then
            whois "$target" 2>&1 || echo "WHOIS query failed"
        else
            echo "whois command not available"
        fi
    }
}

# Check for malicious indicators
threat_intel_check() {
    local ip="$1"

    log INFO "Checking threat intelligence sources"

    {
        echo ""
        echo "=== Threat Intelligence ==="
        echo "IP: $ip"
        echo ""

        # AbuseIPDB check (requires API key for detailed info)
        echo "--- AbuseIPDB Check ---"
        echo "Manual check recommended: https://www.abuseipdb.com/check/$ip"
        echo ""

        # VirusTotal check
        echo "--- VirusTotal Check ---"
        echo "Manual check recommended: https://www.virustotal.com/gui/ip-address/$ip"
        echo ""

        # AlienVault OTX
        echo "--- AlienVault OTX ---"
        echo "Manual check recommended: https://otx.alienvault.com/indicator/ip/$ip"
        echo ""

        # URLhaus check
        echo "--- URLhaus Check ---"
        timeout "$TIMEOUT" curl -s -X POST -d "url_or_ip=$ip" "https://urlhaus-api.abuse.ch/v1/host/" 2>/dev/null | \
            jq -r 'if .query_status == "ok" then "Host found in URLhaus\nURLs: \(.urls | length)\nFirst seen: \(.firstseen // "N/A")" else "Not found in URLhaus" end' 2>/dev/null || echo "Query failed"
    }
}

# Reverse DNS lookup
reverse_dns_lookup() {
    local ip="$1"

    log INFO "Performing reverse DNS lookup"

    {
        echo ""
        echo "=== Reverse DNS ==="
        echo "IP: $ip"
        echo ""
        dig +short -x "$ip" 2>/dev/null || echo "No PTR record found"
    }
}

# BGP hijack detection
bgp_hijack_check() {
    local ip="$1"

    log INFO "Checking for BGP anomalies"

    {
        echo ""
        echo "=== BGP Hijack/Anomaly Detection ==="
        echo "IP: $ip"
        echo ""

        # Check for routing inconsistencies
        echo "--- Routing Visibility ---"
        timeout "$TIMEOUT" curl -s "https://stat.ripe.net/data/routing-status/data.json?resource=$ip" 2>/dev/null | \
            jq -r '.data | "First Seen Prefix: \(.first_seen.prefix // "N/A")\nFirst Seen Time: \(.first_seen.time // "N/A")\nLast Seen: \(.last_seen // "N/A")\nObserved Neighbours: \(.observed_neighbours // "N/A")"' 2>/dev/null || echo "Query failed"

        echo ""
        echo "--- Prefix Overview ---"
        timeout "$TIMEOUT" curl -s "https://stat.ripe.net/data/prefix-overview/data.json?resource=$ip" 2>/dev/null | \
            jq -r '.data | "Block: \(.block.resource // "N/A")\nName: \(.block.name // "N/A")\nDescription: \(.block.desc // "N/A")\nASNs: \(.asns[].asn // "N/A" | @csv)"' 2>/dev/null || echo "Query failed"
    }
}

# === Main ===

main() {
    if [[ $# -lt 2 ]]; then
        echo "Usage: $0 <ip_or_domain> <output_file>"
        echo ""
        echo "Arguments:"
        echo "  ip_or_domain  - IP address or domain name to analyze"
        echo "  output_file   - Output file for the analysis results"
        echo ""
        echo "Example:"
        echo "  $0 8.8.8.8 bgp_analysis.txt"
        echo "  $0 example.com bgp_analysis.txt"
        exit 1
    fi

    local target="$1"
    local output_file="$2"
    local ip="$target"

    log INFO "Starting BGP/ASN intelligence gathering for $target"

    # Resolve domain to IP if necessary
    if ! is_ip "$target"; then
        log INFO "Resolving domain: $target"
        ip=$(resolve_ip "$target")
        if [[ -z "$ip" ]]; then
            log ERROR "Failed to resolve domain: $target"
            exit 1
        fi
        log SUCCESS "Resolved $target to $ip"
    fi

    # Generate report
    {
        echo "╔═══════════════════════════════════════════════════════════════╗"
        echo "║  BGP and ASN Intelligence Report                             ║"
        echo "╚═══════════════════════════════════════════════════════════════╝"
        echo ""
        echo "Target: $target"
        echo "IP Address: $ip"
        echo "Timestamp: $(date -u +"%Y-%m-%dT%H:%M:%S.%NZ")"
        echo "Tool: bgp-asn-intel.sh v2.6"
        echo ""
        echo "═══════════════════════════════════════════════════════════════"

        # Run all checks
        cymru_asn_lookup "$ip"
        ripe_stat_lookup "$ip"
        bgpview_lookup "$ip"
        geoip_lookup "$ip"
        ripe_looking_glass "$ip"
        reverse_dns_lookup "$ip"
        detailed_whois "$ip"
        bgp_hijack_check "$ip"
        threat_intel_check "$ip"

        echo ""
        echo "═══════════════════════════════════════════════════════════════"
        echo "Report generation complete"
        echo "═══════════════════════════════════════════════════════════════"

    } > "$output_file"

    log SUCCESS "Analysis complete. Results saved to: $output_file"
}

# Run main function
main "$@"
