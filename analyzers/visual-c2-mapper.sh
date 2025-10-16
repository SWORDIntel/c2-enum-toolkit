#!/usr/bin/env bash
# visual-c2-mapper.sh - Generates a Graphviz diagram of the C2 infrastructure.
set -euo pipefail
IFS=$'\n\t'

# --- Dependencies ---
DOT_BIN=$(command -v dot || true)

# --- Utilities ---
log() {
    echo "[VISUAL-MAPPER] [$(date -u +'%Y-%m-%dT%H:%M:%SZ')] $*"
}

# --- Functions ---

# Ensure graphviz is installed
ensure_graphviz() {
    if [[ -z "$DOT_BIN" ]]; then
        log "Graphviz (dot) not found. Attempting to install..."
        if command -v apt-get >/dev/null; then
            sudo apt-get update && sudo apt-get install -y graphviz
            DOT_BIN=$(command -v dot || true)
            if [[ -z "$DOT_BIN" ]]; then
                log "ERROR: Failed to install Graphviz. Visual mapping will be skipped."
                return 1
            fi
        else
            log "ERROR: apt-get not found. Cannot install Graphviz automatically."
            return 1
        fi
    fi
    log "Graphviz is available at: $DOT_BIN"
    return 0
}

# --- Main ---
main() {
    if [[ $# -ne 2 ]]; then
        echo "Usage: $0 <scan_directory> <output_dot_file>"
        exit 1
    fi

    local scan_dir="$1"
    local output_dot_file="$2"
    local endpoints_file="$scan_dir/intelligent_analysis/all_discovered_endpoints.txt"
    local output_png_file="${output_dot_file%.dot}.png"

    if ! ensure_graphviz; then
        exit 1
    fi

    if [[ ! -f "$endpoints_file" ]]; then
        log "ERROR: Endpoints file not found at $endpoints_file"
        exit 1
    fi

    log "Starting C2 infrastructure mapping..."

    {
        echo "digraph C2_Infrastructure {"
        echo "  rankdir=LR;"
        echo "  node [shape=box, style=rounded];"
        echo "  graph [bgcolor=transparent];"
    } > "$output_dot_file"

    # Add nodes and edges
    local initial_target
    initial_target=$(cat "$scan_dir/.target_domain" 2>/dev/null || echo "start")

    # Add initial target node
    echo "  \"$initial_target\" [style=filled, fillcolor=lightblue];" >> "$output_dot_file"

    while read -r line; do
        local endpoint
        endpoint=$(echo "$line" | awk '{print $1}')
        local source
        source=$(echo "$line" | awk -F'source=' '{print $2}' | awk '{print $1}' | tr -d '()')
        local method
        method=$(echo "$line" | awk -F'method=' '{print $2}' | awk '{print $1}' | tr -d '()')

        if [[ -z "$source" ]]; then
            source="$initial_target"
        fi

        echo "  \"$source\" -> \"$endpoint\" [label=\"$method\"];" >> "$output_dot_file"
    done < "$endpoints_file"

    echo "}" >> "$output_dot_file"

    log "DOT file generated: $output_dot_file"

    # Render the DOT file to a PNG image
    if "$DOT_BIN" -Tpng "$output_dot_file" -o "$output_png_file"; then
        log "Successfully rendered C2 map to: $output_png_file"
    else
        log "ERROR: Failed to render C2 map image."
    fi

    log "Visual C2 mapping finished."
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    main "$@"
fi