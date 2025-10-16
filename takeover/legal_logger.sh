#!/usr/bin/env bash
# legal_logger.sh - Handles structured, append-only JSON logging for legal purposes.
set -euo pipefail
IFS=$'\n\t'

# --- Functions ---

# Safely escapes a string for use in JSON
json_escape() {
    python3 -c 'import json, sys; print(json.dumps(sys.stdin.read()))'
}

# Appends a log entry to the specified JSON log file
# Usage: append_log <log_file> <operator_id> <action> <details>
append_log() {
    local log_file="$1"
    local operator_id="$2"
    local action="$3"
    local details="$4"
    local timestamp
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%S.%NZ")

    # Escape inputs
    local escaped_operator_id
    escaped_operator_id=$(echo -n "$operator_id" | json_escape)
    local escaped_action
    escaped_action=$(echo -n "$action" | json_escape)
    local escaped_details
    escaped_details=$(echo -n "$details" | json_escape)

    # Create the JSON entry
    local entry
    entry=$(cat <<EOF
{
    "timestamp": "$timestamp",
    "operator_id": $escaped_operator_id,
    "action": $escaped_action,
    "details": $escaped_details,
    "entry_hash": "$(echo -n "$timestamp$operator_id$action$details" | sha256sum | awk '{print $1}')"
}
EOF
)

    # Atomically append the entry to the log file
    if [[ ! -f "$log_file" ]]; then
        echo "[]" > "$log_file"
    fi

    # Use jq to safely append the new entry to the JSON array
    # This is safer than simple text manipulation
    jq --argjson new_entry "$entry" '. + [$new_entry]' "$log_file" > "${log_file}.tmp" && mv "${log_file}.tmp" "$log_file"

    return 0
}

# --- Main ---
# This script is intended to be sourced by other scripts.
# Example usage is provided below for direct execution.
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    echo "This script is a library for other scripts."
    echo "Usage: source legal_logger.sh && append_log <log_file> <operator_id> <action> <details>"
    echo ""
    echo "Example:"
    # Create a temporary log file for demonstration
    temp_log=$(mktemp)
    echo "Creating temporary log file: $temp_log"
    append_log "$temp_log" "test_operator" "TEST_ACTION" "This is a test log entry."
    append_log "$temp_log" "test_operator" "ANOTHER_ACTION" "This is another test log entry with 'quotes' and newlines."
    echo ""
    echo "Log content:"
    cat "$temp_log"
    rm "$temp_log"
    exit 0
fi