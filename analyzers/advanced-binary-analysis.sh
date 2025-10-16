#!/usr/bin/env bash
# advanced-binary-analysis.sh - Unpacks binaries and extracts C2 configs.
set -euo pipefail
IFS=$'\n\t'

# --- Dependencies ---
UPX_BIN=$(command -v upx-ucl || command -v upx || true)
STRINGS_BIN=$(command -v strings || true)

# --- Utilities ---
log() {
    echo "[ADV-BIN] [$(date -u +'%Y-%m-%dT%H:%M:%SZ')] $*"
}

# --- Functions ---

# Ensure UPX is installed, if not, try to install it
ensure_upx() {
    if [[ -z "$UPX_BIN" ]]; then
        log "UPX not found. Attempting to install upx-ucl..."
        if command -v apt-get >/dev/null; then
            sudo apt-get update && sudo apt-get install -y upx-ucl
            UPX_BIN=$(command -v upx-ucl || true)
            if [[ -z "$UPX_BIN" ]]; then
                log "ERROR: Failed to install UPX. Unpacking will be skipped."
                return 1
            fi
        else
            log "ERROR: apt-get not found. Cannot install UPX automatically."
            return 1
        fi
    fi
    log "UPX is available at: $UPX_BIN"
    return 0
}

# Unpack a file if it's packed with UPX
unpack_file() {
    local file_path="$1"
    local output_dir="$2"
    local unpacked_file

    if [[ -z "$UPX_BIN" ]]; then
        log "Skipping unpacking for $file_path because UPX is not available."
        return 1
    fi

    log "Checking if $file_path is packed with UPX..."
    if "$UPX_BIN" -t "$file_path" 2>&1 | grep -q 'Ultimate Packer for eXecutables'; then
        log "File is packed with UPX. Unpacking..."
        unpacked_file="${output_dir}/$(basename "$file_path").unpacked"
        if "$UPX_BIN" -d "$file_path" -o "$unpacked_file" >/dev/null 2>&1; then
            log "Successfully unpacked to $unpacked_file"
            echo "$unpacked_file"
            return 0
        else
            log "ERROR: Failed to unpack $file_path"
            return 1
        fi
    else
        log "File does not appear to be UPX packed."
        return 1
    fi
}

# Extract C2 configuration from a binary file
extract_c2_config() {
    local file_path="$1"
    local output_file="$2"

    if [[ ! -f "$file_path" || -z "$STRINGS_BIN" ]]; then
        log "Strings binary not found or file does not exist. Skipping config extraction."
        return 1
    fi

    log "Extracting potential C2 indicators from $file_path..."

    {
        echo "### C2 Configuration Analysis for $(basename "$file_path") ###"
        echo ""

        # Common C2 patterns (expand this list significantly)
        echo "--- Potential C2 Domains/IPs ---"
        "$STRINGS_BIN" -a -n 8 "$file_path" | grep -Eo '([a-zA-Z0-9-]+\.onion|[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3})' | sort -u
        echo ""

        echo "--- Potential User-Agents ---"
        "$STRINGS_BIN" -a -n 10 "$file_path" | grep -iE 'User-Agent:|Mozilla|curl|wget|python-requests' | sort -u
        echo ""

        echo "--- Potential API Paths & Keys ---"
        "$STRINGS_BIN" -a -n 8 "$file_path" | grep -iE '/api/|/gate.php|/beacon.php|api-key|auth-token' | sort -u
        echo ""

        echo "--- Crypto Constants (Suspected Keys/IVs) ---"
        "$STRINGS_BIN" -a "$file_path" | grep -Eo '[A-Fa-f0-9]{32,}' | sort -u
        echo ""

    } > "$output_file"

    log "Configuration extraction complete. Report at $output_file"
}

# --- Main ---
main() {
    if [[ $# -ne 2 ]]; then
        echo "Usage: $0 <binary_file_or_dir> <output_dir>"
        exit 1
    fi

    local target_path="$1"
    local output_dir="$2"
    mkdir -p "$output_dir"

    log "Starting advanced binary analysis..."
    ensure_upx

    if [[ -d "$target_path" ]]; then
        log "Target is a directory. Analyzing all binaries within..."
        for bin_file in "$target_path"/binary_* "$target_path"/*.bin; do
            if [[ -f "$bin_file" ]]; then
                main "$bin_file" "$output_dir"
            fi
        done
    elif [[ -f "$target_path" ]]; then
        log "Analyzing file: $target_path"
        local file_to_analyze="$target_path"
        local unpacked_path
        local config_report

        # Try to unpack
        unpacked_path=$(unpack_file "$target_path" "$output_dir")
        if [[ -n "$unpacked_path" ]]; then
            file_to_analyze="$unpacked_path"
        fi

        # Extract config from the (potentially unpacked) file
        config_report="${output_dir}/config_analysis_$(basename "$target_path").txt"
        extract_c2_config "$file_to_analyze" "$config_report"
    else
        log "ERROR: Target path $target_path is not a valid file or directory."
        exit 1
    fi

    log "Advanced binary analysis finished."
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    main "$@"
fi