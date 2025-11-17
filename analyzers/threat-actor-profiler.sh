#!/usr/bin/env bash
# threat-actor-profiler.sh - Synthesizes all attribution data into a comprehensive dossier.
set -euo pipefail
IFS=$'\n\t'

# --- Utilities ---
log() {
    echo "[PROFILER] [$(date -u +'%Y-%m-%dT%H:%M:%SZ')] $*"
}

# --- Main ---
main() {
    if [[ $# -ne 2 ]]; then
        echo "Usage: $0 <scan_directory> <output_dossier_file>"
        exit 1
    fi

    local scan_dir="$1"
    local output_dossier_file="$2"
    local intel_dir="$scan_dir/intelligent_analysis"

    log "Starting threat actor profiling..."

    {
        echo "# Threat Actor Dossier"
        echo "## Target: $(cat "$scan_dir/.target_domain" 2>/dev/null || echo "unknown")"
        echo "Generated at: $(date -u +'%Y-%m-%dT%H:%M:%SZ')"
        echo ""
        echo "---"
        echo ""
    } > "$output_dossier_file"

    # --- Append all attribution reports ---

    if [[ -f "$intel_dir/attribution_crypto_report.md" ]]; then
        cat "$intel_dir/attribution_crypto_report.md" >> "$output_dossier_file"
        echo "" >> "$output_dossier_file"
    fi

    if [[ -f "$intel_dir/attribution_footprint_report.md" ]]; then
        cat "$intel_dir/attribution_footprint_report.md" >> "$output_dossier_file"
        echo "" >> "$output_dossier_file"
    fi

    if [[ -f "$intel_dir/darkweb_monitoring_report.md" ]]; then
        cat "$intel_dir/darkweb_monitoring_report.md" >> "$output_dossier_file"
        echo "" >> "$output_dossier_file"
    fi

    if [[ -f "$intel_dir/threat_intel_report.md" ]]; then
        cat "$intel_dir/threat_intel_report.md" >> "$output_dossier_file"
        echo "" >> "$output_dossier_file"
    fi

    # --- Add C2 Map Image ---
    if [[ -f "$intel_dir/c2_map.png" ]]; then
        {
            echo "## C2 Infrastructure Map"
            echo "![C2 Infrastructure Map](c2_map.png)"
            echo ""
        } >> "$output_dossier_file"
    fi

    log "Threat actor dossier created: $output_dossier_file"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    main "$@"
fi