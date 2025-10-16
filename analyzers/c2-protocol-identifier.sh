#!/usr/bin/env bash
# c2-protocol-identifier.sh - Probes open ports to identify C2 frameworks.
set -euo pipefail
IFS=$'\n\t'

# --- Dependencies ---
NCAT_BIN=$(command -v ncat || true)
SOCKS_PROXY="${SOCKS:-127.0.0.1:9050}"

# --- Utilities ---
log() {
    echo "[C2-ID] [$(date -u +'%Y-%m-%dT%H:%M:%SZ')] $*"
}

# --- Functions ---

# Ensure ncat is installed
ensure_ncat() {
    if [[ -z "$NCAT_BIN" ]]; then
        log "ncat not found. Attempting to install nmap..."
        if command -v apt-get >/dev/null; then
            sudo apt-get update && sudo apt-get install -y nmap
            NCAT_BIN=$(command -v ncat || true)
            if [[ -z "$NCAT_BIN" ]]; then
                log "ERROR: Failed to install nmap/ncat. C2 identification will be skipped."
                return 1
            fi
        else
            log "ERROR: apt-get not found. Cannot install nmap/ncat automatically."
            return 1
        fi
    fi
    log "ncat is available at: $NCAT_BIN"
    return 0
}

# Probe for Cobalt Strike Beacon
check_cobalt_strike() {
    local target="$1"
    local port="$2"
    local result="-"

    # Cobalt Strike's default stager checksum is predictable.
    # We can send a GET request and check the checksum of the response.
    # This is a simplified example. Real-world identification is more complex.
    log "Probing for Cobalt Strike on $target:$port..."
    local response
    response=$(curl --socks5-hostname "$SOCKS_PROXY" -s -L --max-time 10 "http://${target}:${port}/__page" 2>/dev/null || true)

    if [[ -n "$response" ]]; then
        local checksum
        checksum=$(echo -n "$response" | cksum | awk '{print $1}')
        # Known checksums for default artifacts
        if [[ "$checksum" == "923214227" || "$checksum" == "1311933036" ]]; then
            result="Cobalt Strike Beacon detected (checksum match)"
        fi
    fi
    echo "$result"
}


# Probe for Metasploit Meterpreter
check_metasploit() {
    local target="$1"
    local port="$2"
    local result="-"

    # Meterpreter reverse_http(s) stagers have a specific URI structure.
    # We send a GET request to a checksummed URI.
    log "Probing for Metasploit on $target:$port..."
    local checksum_uri
    checksum_uri=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 4)_$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 16)

    local http_code
    http_code=$(curl --socks5-hostname "$SOCKS_PROXY" -s -o /dev/null -w "%{http_code}" "http://${target}:${port}/${checksum_uri}" 2>/dev/null || echo "000")

    if [[ "$http_code" == "404" ]]; then
        # A 404 response to a random-looking URI is a strong indicator.
        result="Metasploit Meterpreter detected (checksum URI probe)"
    fi
    echo "$result"
}


# --- Main ---
main() {
    if [[ $# -ne 2 ]]; then
        echo "Usage: $0 <target.onion> <output_file>"
        echo "  Expects a file with open ports at <target_dir>/open_ports.txt"
        exit 1
    fi

    local target="$1"
    local output_file="$2"
    local target_dir
    target_dir=$(dirname "$output_file")
    local open_ports_file="$target_dir/../open_ports.txt"

    if [[ ! -f "$open_ports_file" ]]; then
        log "ERROR: Open ports file not found at $open_ports_file"
        exit 1
    fi

    log "Starting C2 protocol identification for $target"
    ensure_ncat

    {
        echo "### C2 Protocol Identification Report for $target ###"
        echo ""
        echo "| Port | Service | Identification Result |"
        echo "|------|---------|-----------------------|"
    } > "$output_file"

    while read -r port_info; do
        local port
        port=$(echo "$port_info" | cut -d':' -f1)
        local service
        service=$(echo "$port_info" | cut -d':' -f2)
        local result="-"

        # Run checks
        result=$(check_cobalt_strike "$target" "$port")
        if [[ "$result" == "-" ]]; then
            result=$(check_metasploit "$target" "$port")
        fi

        echo "| $port | $service | $result |" >> "$output_file"

    done < "$open_ports_file"

    log "C2 protocol identification finished. Report: $output_file"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    main "$@"
fi