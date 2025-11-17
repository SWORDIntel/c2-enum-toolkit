#!/usr/bin/env bash
# darkweb-monitor.sh - Monitors dark web and paste sites for indicators.
set -euo pipefail
IFS=$'\n\t'

# --- Dependencies ---
CURL_BIN=$(command -v curl || true)
SOCKS_PROXY="${SOCKS:-127.0.0.1:9050}"

# --- Configuration ---
# Using AHMIA as a public-facing search engine for Tor
AHMIA_URL="https://ahmia.fi/search/"

# --- Utilities ---
log() {
    echo "[DARKWEB-MONITOR] [$(date -u +'%Y-%m-%dT%H:%M:%SZ')] $*"
}

# --- Functions ---

# Query Ahmia for a given term
query_ahmia() {
    local term="$1"
    local results

    log "Querying Ahmia for: $term"
    results=$(curl -s --socks5-hostname "$SOCKS_PROXY" \
        -G "$AHMIA_URL" --data-urlencode "q=$term" | \
        grep -oE 'https://[a-z2-7]{16,56}\.onion[^"''< >]+' | \
        sort -u | head -n 5)

    echo "$results"
}

# --- Main ---
main() {
    if [[ $# -ne 2 ]]; then
        echo "Usage: $0 <scan_directory> <output_file>"
        exit 1
    fi

    local scan_dir="$1"
    local output_file="$2"

    if [[ -z "$CURL_BIN" ]]; then
        log "ERROR: curl is required for this script."
        exit 1
    fi

    log "Starting Dark Web & Pastebin monitoring..."

    {
        echo "### Dark Web & Pastebin Monitoring Report ###"
        echo "Scan Directory: $scan_dir"
        echo "Generated at: $(date -u +'%Y-%m-%dT%H:%M:%SZ')"
        echo ""
    } > "$output_file"

    # --- Collect all indicators ---
    local indicators_file
    indicators_file=$(mktemp)

    # Get domains
    if [[ -f "$scan_dir/intelligent_analysis/all_discovered_endpoints.txt" ]]; then
        awk '{print $1}' "$scan_dir/intelligent_analysis/all_discovered_endpoints.txt" | sed 's/:.*//' >> "$indicators_file"
    fi
    # Get crypto addresses
    if [[ -f "$scan_dir/intelligent_analysis/attribution_crypto_report.md" ]]; then
        grep -oE '\b(bc1|[13])[a-zA-HJ-NP-Z0-9]{25,39}\b|\b4[0-9AB][1-9A-HJ-NP-Za-km-z]{93}\b|\b0x[a-fA-F0-9]{40}\b' "$scan_dir/intelligent_analysis/attribution_crypto_report.md" >> "$indicators_file"
    fi

    # --- Query for each indicator ---
    {
        echo "--- Ahmia.fi Search Results ---"
        while read -r indicator; do
            if [[ -n "$indicator" ]]; then
                echo "Indicator: $indicator"
                local results
                results=$(query_ahmia "$indicator")
                if [[ -n "$results" ]]; then
                    echo "  → $results"
                else
                    echo "  → No results found."
                fi
                echo ""
            fi
        done < <(sort -u "$indicators_file")
    } >> "$output_file"


    rm "$indicators_file"
    log "Dark Web & Pastebin monitoring finished. Report: $output_file"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    main "$@"
fi