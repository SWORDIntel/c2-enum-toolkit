#!/usr/bin/env bash
# threat-intel-correlator.sh - Correlates discovered indicators with external TI feeds.
set -euo pipefail
IFS=$'\n\t'

# --- Dependencies ---
CURL_BIN=$(command -v curl || true)
JQ_BIN=$(command -v jq || true)

# --- Configuration ---
VT_API_KEY="${VT_API_KEY:-}"
VT_API_URL="https://www.virustotal.com/api/v3"

# --- Utilities ---
log() {
    echo "[TI-CORRELATE] [$(date -u +'%Y-%m-%dT%H:%M:%SZ')] $*"
}

# --- Functions ---

check_deps() {
    if [[ -z "$CURL_BIN" || -z "$JQ_BIN" ]]; then
        log "ERROR: curl and jq are required for this script."
        return 1
    fi
    if [[ -z "$VT_API_KEY" ]]; then
        log "ERROR: VT_API_KEY environment variable is not set."
        log "Get a key from virustotal.com and export it."
        return 1
    fi
    return 0
}

# Query VirusTotal for a file hash
query_vt_hash() {
    local hash="$1"
    local report

    log "Querying VirusTotal for hash: $hash"
    report=$(curl -s --request GET \
        --url "$VT_API_URL/files/$hash" \
        --header "x-apikey: $VT_API_KEY")

    local malicious_count
    malicious_count=$(echo "$report" | jq -r '.data.attributes.last_analysis_stats.malicious // 0')
    local suspicious_count
    suspicious_count=$(echo "$report" | jq -r '.data.attributes.last_analysis_stats.suspicious // 0')
    local total_votes=$((malicious_count + suspicious_count))

    local result
    result=$(echo "$report" | jq -r '[.data.attributes.meaningful_name, .data.attributes.last_analysis_stats.malicious, .data.attributes.last_analysis_stats.suspicious, .data.attributes.reputation] | @tsv')

    echo -e "$hash\t$result\t$total_votes"
}

# Query VirusTotal for a domain
query_vt_domain() {
    local domain="$1"
    local report

    log "Querying VirusTotal for domain: $domain"
    report=$(curl -s --request GET \
        --url "$VT_API_URL/domains/$domain" \
        --header "x-apikey: $VT_API_KEY")

    local malicious_count
    malicious_count=$(echo "$report" | jq -r '.data.attributes.last_analysis_stats.malicious // 0')
    local suspicious_count
    suspicious_count=$(echo "$report" | jq -r '.data.attributes.last_analysis_stats.suspicious // 0')
    local total_votes=$((malicious_count + suspicious_count))

    local result
    result=$(echo "$report" | jq -r '[.data.attributes.last_analysis_stats.malicious, .data.attributes.last_analysis_stats.suspicious, .data.attributes.reputation] | @tsv')

    echo -e "$domain\t$result\t$total_votes"
}


# --- Main ---
main() {
    if [[ $# -ne 2 ]]; then
        echo "Usage: $0 <scan_directory> <output_file>"
        exit 1
    fi

    local scan_dir="$1"
    local output_file="$2"

    if ! check_deps; then
        exit 1
    fi

    log "Starting threat intelligence correlation..."

    {
        echo "### Threat Intelligence Correlation Report ###"
        echo "Generated at: $(date -u +'%Y-%m-%dT%H:%M:%SZ')"
        echo ""
    } > "$output_file"

    # Correlate file hashes
    local hash_file="$scan_dir/download.hashes.txt"
    if [[ -f "$hash_file" ]]; then
        {
            echo "--- File Hash Reputations (VirusTotal) ---"
            echo "| Hash | Filename | Malicious | Suspicious | Reputation |"
            echo "|------|----------|-----------|------------|------------|"

            while read -r line; do
                local hash
                hash=$(echo "$line" | awk '{print $1}')
                local vt_result
                vt_result=$(query_vt_hash "$hash")
                local fields
                IFS=$'\t' read -r -a fields <<< "$vt_result"
                printf "| %s | %s | %s | %s | %s |\n" "${fields[0]}" "${fields[1]}" "${fields[2]}" "${fields[3]}" "${fields[4]}"
            done < <(grep -v '^#' "$hash_file")
            echo ""
        } >> "$output_file"
    fi

    # Correlate domains
    local domain_file="$scan_dir/intelligent_analysis/all_discovered_endpoints.txt"
    if [[ -f "$domain_file" ]]; then
        {
            echo "--- Domain Reputations (VirusTotal) ---"
            echo "| Domain | Malicious | Suspicious | Reputation |"
            echo "|--------|-----------|------------|------------|"

            while read -r line; do
                local domain
                domain=$(echo "$line" | awk '{print $1}' | sed 's/:.*//') # remove port
                local vt_result
                vt_result=$(query_vt_domain "$domain")
                local fields
                IFS=$'\t' read -r -a fields <<< "$vt_result"
                printf "| %s | %s | %s | %s |\n" "${fields[0]}" "${fields[1]}" "${fields[2]}" "${fields[3]}"
            done < <(grep -v '^#' "$domain_file" | sort -u)
            echo ""
        } >> "$output_file"
    fi

    log "Threat intelligence correlation finished. Report: $output_file"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    main "$@"
fi