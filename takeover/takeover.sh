#!/usr/bin/env bash
# takeover.sh - Orchestrates the C2 evidence acquisition and packaging process.
set -euo pipefail
IFS=$'\n\t'

# --- Configuration ---
LEGAL_LOGGER_SCRIPT="$(dirname "$0")/legal_logger.sh"
if [[ ! -f "$LEGAL_LOGGER_SCRIPT" ]]; then
    echo "Error: Legal logger script not found at $LEGAL_LOGGER_SCRIPT" >&2
    exit 1
fi
# shellcheck source=takeover/legal_logger.sh
source "$LEGAL_LOGGER_SCRIPT"

# --- Functions ---

log_action() {
    local log_file="$1"
    local operator_id="$2"
    local action="$3"
    local details="$4"
    append_log "$log_file" "$operator_id" "$action" "$details"
    echo "[TAKEOVER] [$action] $details"
}

# Creates a human-readable summary report
create_summary_report() {
    local scan_dir="$1"
    local report_file="$2"
    local target_domain

    target_domain=$(cat "$scan_dir/.target_domain" 2>/dev/null || echo "unknown_target")

    # Extract key information from the scan results
    local open_ports
    open_ports=$(wc -l < "$scan_dir/open_ports.txt" 2>/dev/null)
    local found_paths
    found_paths=$(wc -l < "$scan_dir/found_paths.txt" 2>/dev/null)
    local downloaded_binaries
    downloaded_binaries=$(find "$scan_dir" -name 'binary_*' | wc -l)
    local kp14_discovered
    kp14_discovered=$(wc -l < "$scan_dir/kp14_discovery/discovered_endpoints.txt" 2>/dev/null)

    # Generate the Markdown report
    cat <<EOF > "$report_file"
# C2 Server Handover Package Summary
## Target: \`$target_domain\`

| Metric                  | Value |
|-------------------------|-------|
| Open Ports              | $open_ports        |
| Interesting Paths Found | $found_paths     |
| Downloaded Binaries     | $downloaded_binaries |
| Hidden Endpoints (KP14) | $kp14_discovered |

**This package contains a complete snapshot of all intelligence gathered on the specified C2 server.**

### Contents:
- **Comprehensive Logs & Reports:** All raw output from the \`c2-enum-toolkit\`.
- **Evidence Log:** A detailed, legally-admissible JSON log of all actions taken.
- **Chain of Custody:** A manifest of all files and their SHA256 hashes to ensure integrity.

**This data is provided for legal handover to appropriate authorities.**
EOF
}

# Generates a chain of custody manifest
create_chain_of_custody() {
    local directory="$1"
    local manifest_file="$2"

    {
        echo "# Chain of Custody Manifest"
        echo "# All file hashes are SHA256"
        echo "# Generated at: $(date -u +"%Y-%m-%dT%H:%M:%S.%NZ")"
        echo ""
    } > "$manifest_file"

    # Find all files, calculate their hashes, and format the output
    find "$directory" -type f -not -name "$(basename "$manifest_file")" -print0 | \
        xargs -0 sha256sum >> "$manifest_file"
}


# --- Main ---

if [[ $# -ne 2 ]]; then
    echo "Usage: $0 <scan_directory> <operator_id>"
    echo "  <scan_directory>: The directory containing results from a comprehensive scan."
    echo "  <operator_id>: The ID of the operator initiating the takeover process."
    exit 1
fi

SCAN_DIR="$1"
OPERATOR_ID="$2"
TARGET_DOMAIN=$(cat "$SCAN_DIR/.target_domain" 2>/dev/null || echo "unknown_target")
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
TAKEOVER_DIR="takeover_${TARGET_DOMAIN}_${TIMESTAMP}"
LOG_FILE="$TAKEOVER_DIR/evidence_log.json"
PACKAGE_NAME="takeover_package_${TARGET_DOMAIN}_${TIMESTAMP}.tar.gz"

# 1. Initialization
echo "--- Initializing Takeover Process ---"
mkdir -p "$TAKEOVER_DIR"
log_action "$LOG_FILE" "$OPERATOR_ID" "TAKEOVER_INITIATED" "Created takeover directory: $TAKEOVER_DIR"

# 2. Copy Evidence
echo "--- Copying Evidence ---"
log_action "$LOG_FILE" "$OPERATOR_ID" "EVIDENCE_COPIED" "Copying all files from source scan directory: $SCAN_DIR"
cp -a "$SCAN_DIR"/* "$TAKEOVER_DIR/"
log_action "$LOG_FILE" "$OPERATOR_ID" "EVIDENCE_COPY_COMPLETE" "Finished copying evidence."

# 3. Create Summary Report
echo "--- Creating Summary Report ---"
SUMMARY_REPORT_FILE="$TAKEOVER_DIR/summary_report.md"
create_summary_report "$SCAN_DIR" "$SUMMARY_REPORT_FILE"
log_action "$LOG_FILE" "$OPERATOR_ID" "REPORT_GENERATED" "Created summary report: $SUMMARY_REPORT_FILE"

# 4. Create Chain of Custody
echo "--- Creating Chain of Custody ---"
CHAIN_OF_CUSTODY_FILE="$TAKEOVER_DIR/chain_of_custody.txt"
create_chain_of_custody "$TAKEOVER_DIR" "$CHAIN_OF_CUSTODY_FILE"
log_action "$LOG_FILE" "$OPERATOR_ID" "CHAIN_OF_CUSTODY_GENERATED" "Created chain of custody manifest: $CHAIN_OF_CUSTODY_FILE"

# 5. Package the Evidence
echo "--- Packaging Evidence ---"
log_action "$LOG_FILE" "$OPERATOR_ID" "PACKAGING_STARTED" "Creating handover package: $PACKAGE_NAME"
tar -czf "$PACKAGE_NAME" -C "$TAKEOVER_DIR" .
log_action "$LOG_FILE" "$OPERATOR_ID" "PACKAGING_COMPLETE" "Successfully created handover package. Hash: $(sha256sum "$PACKAGE_NAME" | awk '{print $1}')"

# 6. Finalization
echo "--- Takeover Process Complete ---"
log_action "$LOG_FILE" "$OPERATOR_ID" "TAKEOVER_COMPLETE" "Process finished. Handover package is ready."
echo ""
echo "✅ Handover package created: $PACKAGE_NAME"
echo "    - To view contents: tar -tzf $PACKAGE_NAME"
echo "    - To extract: tar -xzf $PACKAGE_NAME"
echo ""
echo "Please handle this data with extreme care and according to legal and ethical guidelines."

# 6. Finalization
echo "--- Takeover Process Complete ---"
log_action "$LOG_FILE" "$OPERATOR_ID" "TAKEOVER_COMPLETE" "Process finished. Handover package is ready."

# Move the log file to the parent directory before cleanup
mv "$LOG_FILE" .

# Clean up the temporary directory
rm -rf "$TAKEOVER_DIR"

# Create final package directory and move artifacts
FINAL_DIR="final_package_${TARGET_DOMAIN}_${TIMESTAMP}"
mkdir "$FINAL_DIR"
mv "$PACKAGE_NAME" "$FINAL_DIR/"
mv "$(basename "$LOG_FILE")" "$FINAL_DIR/"


echo ""
echo "✅ Handover package created: $FINAL_DIR/$PACKAGE_NAME"
echo "✅ Evidence log: $FINAL_DIR/$(basename "$LOG_FILE")"
echo ""
echo "Please handle this data with extreme care and according to legal and ethical guidelines."

exit 0