#!/usr/bin/env bash
#
# protocol-analysis.sh - C2 Protocol Reverse Engineering Analyzer
# Part of the C2 Enumeration Toolkit v2.6
#
# Purpose: Analyze malware binaries to extract C2 communication patterns
# Usage: ./protocol-analysis.sh <binary_sample> <output_dir>
#
# Features:
# - String extraction (domains, IPs, URLs, API endpoints)
# - Cryptographic constant detection
# - Network indicator extraction
# - HTTP pattern analysis
# - Update mechanism identification
# - Signature verification analysis

set -euo pipefail
IFS=$'\n\t'

# === Configuration ===
VERSION="2.6-protocol"
TIMEOUT=30

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
            echo -e "${GREEN}[✓]${NC} $message" >&2
            ;;
        WARNING)
            echo -e "${YELLOW}[!]${NC} $message" >&2
            ;;
        ERROR)
            echo -e "${RED}[✗]${NC} $message" >&2
            ;;
    esac
}

# Extract printable strings from binary
extract_strings() {
    local binary="$1"
    local output_file="$2"

    log INFO "Extracting strings from binary..."

    {
        echo "=== Extracted Strings ==="
        echo "Binary: $(basename "$binary")"
        echo "Timestamp: $(date -u +"%Y-%m-%dT%H:%M:%S.%NZ")"
        echo ""

        # ASCII strings
        echo "--- ASCII Strings (min length 6) ---"
        strings -a -n 6 "$binary" 2>/dev/null || echo "strings command failed"
        echo ""

        # Unicode strings
        echo "--- Unicode Strings (min length 6) ---"
        strings -a -n 6 -e l "$binary" 2>/dev/null || echo "Unicode extraction failed"
        echo ""

    } > "$output_file"

    log SUCCESS "Strings extracted to: $output_file"
}

# Extract network indicators (domains, IPs, URLs)
extract_network_indicators() {
    local strings_file="$1"
    local output_file="$2"

    log INFO "Extracting network indicators..."

    {
        echo "=== Network Indicators ==="
        echo "Timestamp: $(date -u +"%Y-%m-%dT%H:%M:%S.%NZ")"
        echo ""

        # Domain patterns
        echo "--- Domains ---"
        grep -oE '([a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,}' "$strings_file" 2>/dev/null | \
            sort -u | \
            grep -vE '(microsoft\.com|windows\.com|adobe\.com|google\.com)' || echo "No domains found"
        echo ""

        # IP addresses
        echo "--- IP Addresses ---"
        grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' "$strings_file" 2>/dev/null | \
            sort -u | \
            grep -vE '^(127\.|0\.|192\.168\.|10\.|172\.(1[6-9]|2[0-9]|3[0-1])\.)' || echo "No IPs found"
        echo ""

        # URLs
        echo "--- URLs ---"
        grep -oE '(http|https|ftp)://[a-zA-Z0-9./?=_%:-]*' "$strings_file" 2>/dev/null | \
            sort -u || echo "No URLs found"
        echo ""

        # API endpoints
        echo "--- Potential API Endpoints ---"
        grep -oE '/[a-zA-Z0-9/_-]+\.(php|asp|aspx|jsp|cgi|action|do|json|xml|api)' "$strings_file" 2>/dev/null | \
            sort -u | head -50 || echo "No API endpoints found"
        echo ""

        # Update-related patterns
        echo "--- Update-Related Strings ---"
        grep -iE '(update|version|download|install|upgrade|patch)' "$strings_file" 2>/dev/null | \
            sort -u | head -30 || echo "No update strings found"
        echo ""

    } > "$output_file"

    log SUCCESS "Network indicators saved to: $output_file"
}

# Extract cryptographic constants and indicators
extract_crypto_indicators() {
    local binary="$1"
    local output_file="$2"

    log INFO "Detecting cryptographic indicators..."

    {
        echo "=== Cryptographic Analysis ==="
        echo "Binary: $(basename "$binary")"
        echo "Timestamp: $(date -u +"%Y-%m-%dT%H:%M:%S.%NZ")"
        echo ""

        # Common crypto library strings
        echo "--- Crypto Library Indicators ---"
        strings -a "$binary" 2>/dev/null | grep -iE '(openssl|crypto|cipher|aes|rsa|sha|md5|base64|encrypt|decrypt)' | \
            sort -u | head -30 || echo "No crypto library strings found"
        echo ""

        # Known crypto constants (partial - would need extensive list)
        echo "--- Known Crypto Constants ---"

        # AES S-box start
        if od -An -t x1 "$binary" | grep -q "63 7c 77 7b f2 6b 6f c5"; then
            echo "✓ AES S-box detected"
        fi

        # SHA-256 initial hash values
        if od -An -t x1 "$binary" | grep -q "6a 09 e6 67"; then
            echo "✓ Possible SHA-256 constants detected"
        fi

        # MD5 constants
        if od -An -t x1 "$binary" | grep -q "01 23 45 67 89 ab cd ef"; then
            echo "✓ Possible MD5 constants detected"
        fi

        # RSA/public key indicators
        echo ""
        echo "--- Public Key Indicators ---"
        strings -a "$binary" 2>/dev/null | grep -E '(BEGIN|END).*(PUBLIC KEY|PRIVATE KEY|CERTIFICATE)' | head -10 || echo "No PEM-format keys found"
        echo ""

        # Base64-encoded data (potential encrypted config)
        echo "--- Base64-Encoded Data (first 10) ---"
        strings -a "$binary" 2>/dev/null | grep -E '^[A-Za-z0-9+/]{32,}={0,2}$' | head -10 || echo "No base64 strings found"
        echo ""

    } > "$output_file"

    log SUCCESS "Crypto analysis saved to: $output_file"
}

# Extract HTTP/network patterns
extract_http_patterns() {
    local strings_file="$1"
    local output_file="$2"

    log INFO "Analyzing HTTP patterns..."

    {
        echo "=== HTTP Communication Patterns ==="
        echo "Timestamp: $(date -u +"%Y-%m-%dT%H:%M:%S.%NZ")"
        echo ""

        # HTTP headers
        echo "--- HTTP Headers ---"
        grep -iE '^(User-Agent|Accept|Content-Type|Authorization|X-|Cookie):' "$strings_file" 2>/dev/null | \
            sort -u | head -20 || echo "No HTTP headers found"
        echo ""

        # User-Agent strings
        echo "--- User-Agent Strings ---"
        grep -i 'User-Agent' "$strings_file" 2>/dev/null | \
            sort -u || grep -iE '(Mozilla|Chrome|Safari|Opera|MSIE|Trident)' "$strings_file" 2>/dev/null | sort -u | head -10
        echo ""

        # HTTP methods
        echo "--- HTTP Methods ---"
        grep -oE '\b(GET|POST|PUT|DELETE|HEAD|OPTIONS|PATCH|TRACE|CONNECT)\b' "$strings_file" 2>/dev/null | \
            sort -u || echo "No HTTP methods found"
        echo ""

        # JSON/XML patterns
        echo "--- JSON/XML Patterns ---"
        grep -oE '\{[^}]*"[a-zA-Z_]+":' "$strings_file" 2>/dev/null | head -10 || echo "No JSON patterns found"
        grep -oE '<[a-zA-Z_]+>' "$strings_file" 2>/dev/null | head -10 || echo "No XML tags found"
        echo ""

        # Query parameters
        echo "--- Query Parameters ---"
        grep -oE '[?&][a-zA-Z_]+=([^&\s]*)' "$strings_file" 2>/dev/null | \
            cut -d= -f1 | sort -u | head -20 || echo "No query parameters found"
        echo ""

    } > "$output_file"

    log SUCCESS "HTTP patterns saved to: $output_file"
}

# Extract update mechanism indicators
extract_update_mechanisms() {
    local strings_file="$1"
    local output_file="$2"

    log INFO "Analyzing update mechanisms..."

    {
        echo "=== Update Mechanism Analysis ==="
        echo "Timestamp: $(date -u +"%Y-%m-%dT%H:%M:%S.%NZ")"
        echo ""

        # Version strings
        echo "--- Version Strings ---"
        grep -iE '(version|ver|v[0-9]|build|release)' "$strings_file" 2>/dev/null | \
            grep -E '[0-9]+\.[0-9]+' | \
            sort -u | head -20 || echo "No version strings found"
        echo ""

        # Update URLs
        echo "--- Update URLs ---"
        grep -iE '(update|upgrade|download|patch)' "$strings_file" 2>/dev/null | \
            grep -oE '(http|https)://[^\s]+' | \
            sort -u || echo "No update URLs found"
        echo ""

        # File download patterns
        echo "--- Download Patterns ---"
        grep -iE '\.(exe|dll|msi|zip|rar|7z|tar|gz|pkg|dmg|deb|rpm)' "$strings_file" 2>/dev/null | \
            grep -v '\\\\' | \
            sort -u | head -20 || echo "No download patterns found"
        echo ""

        # Signature verification
        echo "--- Signature Verification Indicators ---"
        grep -iE '(signature|verify|sign|cert|certificate|hash|sha|md5|checksum)' "$strings_file" 2>/dev/null | \
            sort -u | head -20 || echo "No signature verification strings found"
        echo ""

        # Registry keys (Windows)
        echo "--- Registry Keys (Update-related) ---"
        grep -iE 'HKEY_(LOCAL_MACHINE|CURRENT_USER).*\\\\(Run|Software|Update)' "$strings_file" 2>/dev/null | \
            sort -u | head -15 || echo "No registry keys found"
        echo ""

    } > "$output_file"

    log SUCCESS "Update mechanism analysis saved to: $output_file"
}

# Analyze binary metadata
analyze_binary_metadata() {
    local binary="$1"
    local output_file="$2"

    log INFO "Analyzing binary metadata..."

    {
        echo "=== Binary Metadata ==="
        echo "File: $(basename "$binary")"
        echo "Timestamp: $(date -u +"%Y-%m-%dT%H:%M:%S.%NZ")"
        echo ""

        # File info
        echo "--- File Information ---"
        echo "Size: $(stat -f%z "$binary" 2>/dev/null || stat -c%s "$binary" 2>/dev/null) bytes"
        echo "SHA256: $(sha256sum "$binary" 2>/dev/null | awk '{print $1}' || shasum -a 256 "$binary" 2>/dev/null | awk '{print $1}')"
        echo "MD5: $(md5sum "$binary" 2>/dev/null | awk '{print $1}' || md5 -q "$binary" 2>/dev/null)"
        echo ""

        # File type
        echo "--- File Type ---"
        file "$binary" 2>/dev/null || echo "file command not available"
        echo ""

        # ELF/PE header info
        if command -v readelf &>/dev/null && file "$binary" | grep -q ELF; then
            echo "--- ELF Header ---"
            readelf -h "$binary" 2>/dev/null | head -20
            echo ""
        fi

        # Entropy (indicator of packing/encryption)
        if command -v ent &>/dev/null; then
            echo "--- Entropy Analysis ---"
            ent "$binary" 2>/dev/null || echo "Entropy analysis failed"
            echo ""
            echo "Note: Entropy > 7.5 suggests packing or encryption"
            echo ""
        fi

        # Imports/Exports (if available)
        if command -v objdump &>/dev/null; then
            echo "--- Imported Functions (first 50) ---"
            objdump -p "$binary" 2>/dev/null | grep "DLL Name" | head -50 || echo "Not applicable or objdump failed"
            echo ""
        fi

    } > "$output_file"

    log SUCCESS "Binary metadata saved to: $output_file"
}

# Generate protocol summary
generate_protocol_summary() {
    local output_dir="$1"
    local summary_file="$2"

    log INFO "Generating protocol analysis summary..."

    {
        echo "╔═══════════════════════════════════════════════════════════════╗"
        echo "║  C2 Protocol Analysis Summary                                ║"
        echo "╚═══════════════════════════════════════════════════════════════╝"
        echo ""
        echo "Generated: $(date -u +"%Y-%m-%dT%H:%M:%S.%NZ")"
        echo "Tool: protocol-analysis.sh v$VERSION"
        echo ""
        echo "═══════════════════════════════════════════════════════════════"
        echo ""

        # Extract key findings from individual reports
        echo "--- Key Network Indicators ---"
        if [[ -f "$output_dir/network_indicators.txt" ]]; then
            echo "Domains found:"
            grep -A 20 "--- Domains ---" "$output_dir/network_indicators.txt" | tail -n +2 | head -10
            echo ""
            echo "IPs found:"
            grep -A 20 "--- IP Addresses ---" "$output_dir/network_indicators.txt" | tail -n +2 | head -10
            echo ""
        fi

        echo "--- Update Mechanism Summary ---"
        if [[ -f "$output_dir/update_mechanisms.txt" ]]; then
            echo "Version patterns:"
            grep -A 10 "--- Version Strings ---" "$output_dir/update_mechanisms.txt" | tail -n +2 | head -5
            echo ""
            echo "Update URLs:"
            grep -A 10 "--- Update URLs ---" "$output_dir/update_mechanisms.txt" | tail -n +2 | head -5
            echo ""
        fi

        echo "--- HTTP Communication ---"
        if [[ -f "$output_dir/http_patterns.txt" ]]; then
            echo "User-Agent:"
            grep -A 5 "--- User-Agent Strings ---" "$output_dir/http_patterns.txt" | tail -n +2 | head -3
            echo ""
            echo "HTTP Methods:"
            grep -A 5 "--- HTTP Methods ---" "$output_dir/http_patterns.txt" | tail -n +2
            echo ""
        fi

        echo "--- Cryptographic Indicators ---"
        if [[ -f "$output_dir/crypto_indicators.txt" ]]; then
            grep -E '(✓|AES|SHA|MD5|RSA|key)' "$output_dir/crypto_indicators.txt" | head -10
            echo ""
        fi

        echo "═══════════════════════════════════════════════════════════════"
        echo ""
        echo "--- Analysis Recommendations ---"
        echo ""
        echo "1. NETWORK MONITORING:"
        echo "   - Monitor traffic to identified domains/IPs"
        echo "   - Capture C2 communication for protocol analysis"
        echo "   - Identify update check frequency"
        echo ""
        echo "2. DYNAMIC ANALYSIS:"
        echo "   - Run sample in sandbox with network interception"
        echo "   - Capture full HTTP requests/responses"
        echo "   - Identify authentication mechanisms"
        echo ""
        echo "3. SIGNATURE ANALYSIS:"
        echo "   - Determine if updates are cryptographically signed"
        echo "   - Extract public keys if present"
        echo "   - Test signature verification robustness"
        echo ""
        echo "4. TAKEOVER FEASIBILITY:"
        echo "   - Assess if C2 can be sinkholed"
        echo "   - Determine if cleanup payloads can be distributed"
        echo "   - Evaluate signature bypass options"
        echo ""
        echo "═══════════════════════════════════════════════════════════════"
        echo ""
        echo "All detailed reports available in: $output_dir"
        echo ""

    } > "$summary_file"

    log SUCCESS "Protocol summary generated: $summary_file"
}

# === Main ===

main() {
    if [[ $# -lt 2 ]]; then
        echo "Usage: $0 <binary_sample> <output_dir>"
        echo ""
        echo "Arguments:"
        echo "  binary_sample  - Malware binary to analyze"
        echo "  output_dir     - Output directory for analysis results"
        echo ""
        echo "Example:"
        echo "  $0 zemana_sample.exe ./analysis_output"
        echo ""
        echo "Capabilities:"
        echo "  - String extraction (domains, IPs, URLs)"
        echo "  - Network indicator identification"
        echo "  - Cryptographic constant detection"
        echo "  - HTTP pattern analysis"
        echo "  - Update mechanism identification"
        echo "  - Binary metadata analysis"
        exit 1
    fi

    local binary="$1"
    local output_dir="$2"

    # Validation
    if [[ ! -f "$binary" ]]; then
        log ERROR "Binary file not found: $binary"
        exit 1
    fi

    # Create output directory
    mkdir -p "$output_dir"

    log INFO "Starting C2 protocol analysis"
    log INFO "Binary: $binary"
    log INFO "Output: $output_dir"
    echo ""

    # Run analysis modules
    extract_strings "$binary" "$output_dir/strings_raw.txt"
    extract_network_indicators "$output_dir/strings_raw.txt" "$output_dir/network_indicators.txt"
    extract_crypto_indicators "$binary" "$output_dir/crypto_indicators.txt"
    extract_http_patterns "$output_dir/strings_raw.txt" "$output_dir/http_patterns.txt"
    extract_update_mechanisms "$output_dir/strings_raw.txt" "$output_dir/update_mechanisms.txt"
    analyze_binary_metadata "$binary" "$output_dir/binary_metadata.txt"

    # Generate summary
    generate_protocol_summary "$output_dir" "$output_dir/PROTOCOL_SUMMARY.txt"

    echo ""
    log SUCCESS "Protocol analysis complete!"
    log INFO "Results directory: $output_dir"
    log INFO "Summary report: $output_dir/PROTOCOL_SUMMARY.txt"
    echo ""
    echo "Next steps:"
    echo "  1. Review PROTOCOL_SUMMARY.txt for key findings"
    echo "  2. Perform dynamic analysis in sandbox"
    echo "  3. Capture and analyze C2 traffic"
    echo "  4. Assess takeover feasibility"
}

main "$@"
