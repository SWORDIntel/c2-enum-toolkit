#!/usr/bin/env bash
# Content Analysis & Recursive Enumeration
# HTML parsing, link discovery, comment extraction, recursive crawling
set -euo pipefail

TARGET_URL="$1"
OUTDIR="${2:-.}"
MAX_DEPTH="${3:-2}"
SOCKS="${SOCKS:-127.0.0.1:9050}"

[[ -z "$TARGET_URL" ]] && { echo "Usage: $0 <url> [outdir] [max_depth]"; exit 1; }

mkdir -p "$OUTDIR/content_analysis"
REPORT="$OUTDIR/content_analysis/content_analysis.txt"
DISCOVERED_URLS="$OUTDIR/content_analysis/discovered_urls.txt"
DISCOVERED_ENDPOINTS="$OUTDIR/content_analysis/discovered_endpoints.txt"
COMMENTS="$OUTDIR/content_analysis/extracted_comments.txt"

: > "$DISCOVERED_URLS"
: > "$DISCOVERED_ENDPOINTS"
: > "$COMMENTS"

log() { echo "[$(date -u +'%Y-%m-%dT%H:%M:%SZ')] $*"; }

log "Starting content analysis: $TARGET_URL (max depth: $MAX_DEPTH)"

{
cat <<EOF
═══════════════════════════════════════════════════════════════════
CONTENT ANALYSIS & RECURSIVE ENUMERATION REPORT
═══════════════════════════════════════════════════════════════════
Target: $TARGET_URL
Max Depth: $MAX_DEPTH
Timestamp: $(date -u +'%Y-%m-%dT%H:%M:%SZ')
═══════════════════════════════════════════════════════════════════

EOF

# ========== 1. DOWNLOAD & PARSE HTML ==========
echo "───────────────────────────────────────────────────────────────────"
echo "1. HTML CONTENT RETRIEVAL & PARSING"
echo "───────────────────────────────────────────────────────────────────"
echo ""

HTML_FILE="$OUTDIR/content_analysis/page.html"

if curl --socks5-hostname "$SOCKS" -s --max-time 30 "$TARGET_URL" -o "$HTML_FILE" 2>/dev/null; then
    FILE_SIZE=$(stat -f%z "$HTML_FILE" 2>/dev/null || stat -c%s "$HTML_FILE" 2>/dev/null || echo "0")
    echo "[✓] Page downloaded: $FILE_SIZE bytes"

    # Detect content type
    echo ""
    echo "[*] Content analysis:"
    if grep -q "<!DOCTYPE html" "$HTML_FILE" 2>/dev/null; then
        echo "  → HTML document detected"
    elif grep -q "{" "$HTML_FILE" 2>/dev/null && grep -q "}" "$HTML_FILE" 2>/dev/null; then
        echo "  → JSON response detected"
    elif grep -q "<\?xml" "$HTML_FILE" 2>/dev/null; then
        echo "  → XML document detected"
    else
        echo "  → Unknown content type"
    fi
else
    echo "[✗] Failed to download page"
    exit 1
fi

echo ""

# ========== 2. LINK EXTRACTION ==========
echo "───────────────────────────────────────────────────────────────────"
echo "2. LINK DISCOVERY & EXTRACTION"
echo "───────────────────────────────────────────────────────────────────"
echo ""

echo "[*] Extracting links from HTML..."

# Extract href links
grep -oE 'href="([^"]+)"' "$HTML_FILE" 2>/dev/null | \
    sed 's/href="//;s/"$//' | sort -u | while read -r link; do

    # Categorize link
    if [[ "$link" == http* ]]; then
        echo "$link" >> "$DISCOVERED_URLS"
        echo "  [External] $link"
    elif [[ "$link" == //* ]]; then
        echo "  [Protocol-relative] $link"
    elif [[ "$link" == /* ]]; then
        echo "$link" >> "$DISCOVERED_ENDPOINTS"
        echo "  [Absolute] $link"
    elif [[ "$link" == "#"* ]]; then
        echo "  [Anchor] $link"
    else
        echo "$link" >> "$DISCOVERED_ENDPOINTS"
        echo "  [Relative] $link"
    fi
done | head -50

echo ""
echo "[*] Total unique links found: $(wc -l < "$DISCOVERED_URLS" "$DISCOVERED_ENDPOINTS" 2>/dev/null | tail -1 | awk '{print $1}')"

echo ""

# ========== 3. COMMENT EXTRACTION ==========
echo "───────────────────────────────────────────────────────────────────"
echo "3. HTML/JAVASCRIPT COMMENT EXTRACTION"
echo "───────────────────────────────────────────────────────────────────"
echo ""

echo "[*] Extracting HTML comments:"

grep -oE "<!--.*-->" "$HTML_FILE" 2>/dev/null | \
    sed 's/<!--//;s/-->//' | \
    grep -v "^$" | head -20 | tee -a "$COMMENTS" | sed 's/^/  → /' || echo "  (none found)"

echo ""
echo "[*] Looking for sensitive info in comments:"

grep -iE "TODO|FIXME|HACK|XXX|password|admin|debug|test|key|token" "$COMMENTS" 2>/dev/null | \
    head -10 | sed 's/^/  ⚠️  /' || echo "  (none found)"

echo ""

# ========== 4. FORM ANALYSIS ==========
echo "───────────────────────────────────────────────────────────────────"
echo "4. FORM & INPUT FIELD ANALYSIS"
echo "───────────────────────────────────────────────────────────────────"
echo ""

echo "[*] Forms detected:"
FORM_COUNT=$(grep -c "<form" "$HTML_FILE" 2>/dev/null || echo 0)
echo "  Count: $FORM_COUNT"

if [[ $FORM_COUNT -gt 0 ]]; then
    echo ""
    echo "[*] Form actions:"
    grep -oE '<form[^>]+action="([^"]+)"' "$HTML_FILE" 2>/dev/null | \
        sed 's/.*action="//;s/".*$//' | sort -u | sed 's/^/  → /' || echo "  (no actions)"

    echo ""
    echo "[*] Input fields:"
    grep -oE '<input[^>]+name="([^"]+)"' "$HTML_FILE" 2>/dev/null | \
        sed 's/.*name="//;s/".*$//' | sort -u | head -20 | sed 's/^/  → /' || echo "  (none)"

    echo ""
    echo "[*] Suspicious input fields:"
    grep -oE '<input[^>]+name="([^"]+)"' "$HTML_FILE" 2>/dev/null | \
        sed 's/.*name="//;s/".*$//' | grep -iE "password|passwd|user|login|admin|token|key|secret" | \
        sed 's/^/  ⚠️  /' || echo "  (none)"
fi

echo ""

# ========== 5. META TAG ANALYSIS ==========
echo "───────────────────────────────────────────────────────────────────"
echo "5. META TAGS & PAGE METADATA"
echo "───────────────────────────────────────────────────────────────────"
echo ""

echo "[*] Meta tags:"
grep -oE '<meta[^>]+>' "$HTML_FILE" 2>/dev/null | head -15 | sed 's/^/  → /' || echo "  (none)"

echo ""

# ========== 6. EMBEDDED RESOURCES ==========
echo "───────────────────────────────────────────────────────────────────"
echo "6. EMBEDDED RESOURCES (Images, CSS, JS)"
echo "───────────────────────────────────────────────────────────────────"
echo ""

echo "[*] Images:"
grep -oE '<img[^>]+src="([^"]+)"' "$HTML_FILE" 2>/dev/null | \
    sed 's/.*src="//;s/".*$//' | sort -u | head -10 | sed 's/^/  → /' || echo "  (none)"

echo ""
echo "[*] Stylesheets:"
grep -oE '<link[^>]+href="([^"]+\.css[^"]*)"' "$HTML_FILE" 2>/dev/null | \
    sed 's/.*href="//;s/".*$//' | sort -u | head -10 | sed 's/^/  → /' || echo "  (none)"

echo ""
echo "[*] JavaScript files:"
grep -oE '<script[^>]+src="([^"]+)"' "$HTML_FILE" 2>/dev/null | \
    sed 's/.*src="//;s/".*$//' | sort -u | head -10 | sed 's/^/  → /' || echo "  (none)"

echo ""

# ========== 7. RECURSIVE ENUMERATION ==========
echo "───────────────────────────────────────────────────────────────────"
echo "7. RECURSIVE LINK FOLLOWING (Depth: $MAX_DEPTH)"
echo "───────────────────────────────────────────────────────────────────"
echo ""

if [[ $MAX_DEPTH -gt 0 ]]; then
    echo "[*] Following discovered links (depth $MAX_DEPTH)..."

    VISITED_FILE="$OUTDIR/content_analysis/.visited"
    : > "$VISITED_FILE"

    CURRENT_DEPTH=0
    CURRENT_URLS=("$TARGET_URL")

    while [[ $CURRENT_DEPTH -lt $MAX_DEPTH ]]; do
        ((CURRENT_DEPTH++))
        echo ""
        echo "  [Depth $CURRENT_DEPTH]"

        NEXT_URLS=()

        for url in "${CURRENT_URLS[@]}"; do
            # Check if already visited
            if grep -qF "$url" "$VISITED_FILE" 2>/dev/null; then
                continue
            fi

            echo "$url" >> "$VISITED_FILE"
            echo "    Crawling: $url"

            # Download and extract links
            TMP_PAGE="$OUTDIR/content_analysis/.tmp_$(echo "$url" | md5sum | awk '{print $1}').html"

            if curl --socks5-hostname "$SOCKS" -s --max-time 15 "$url" -o "$TMP_PAGE" 2>/dev/null; then
                # Extract new links
                grep -oE 'href="(/[^"]+)"' "$TMP_PAGE" 2>/dev/null | \
                    sed 's/href="//;s/"$//' | while read -r path; do

                    # Build full URL
                    new_url="${TARGET_URL%/}${path}"
                    echo "$new_url" >> "$DISCOVERED_ENDPOINTS"

                    # Add to next depth if not visited
                    if ! grep -qF "$new_url" "$VISITED_FILE" 2>/dev/null; then
                        NEXT_URLS+=("$new_url")
                    fi
                done

                rm -f "$TMP_PAGE"
            fi
        done

        CURRENT_URLS=("${NEXT_URLS[@]}")

        [[ ${#CURRENT_URLS[@]} -eq 0 ]] && break
    done

    echo ""
    echo "[✓] Recursive crawl complete"
    echo "  Total pages visited: $(wc -l < "$VISITED_FILE")"
    echo "  Total endpoints discovered: $(sort -u "$DISCOVERED_ENDPOINTS" | wc -l)"
else
    echo "[!] Recursive crawling disabled (depth: 0)"
fi

echo ""

# ========== 8. CONTENT INTELLIGENCE ==========
echo "───────────────────────────────────────────────────────────────────"
echo "8. CONTENT INTELLIGENCE SUMMARY"
echo "───────────────────────────────────────────────────────────────────"
echo ""

echo "[*] Technology indicators from HTML:"
for tech in "React" "Vue" "Angular" "jQuery" "Bootstrap" "WordPress" "Django" "Flask" "Laravel"; do
    if grep -qi "$tech" "$HTML_FILE" 2>/dev/null; then
        echo "  → $tech detected"
    fi
done

echo ""
echo "[*] Page title:"
grep -oE "<title>([^<]+)</title>" "$HTML_FILE" 2>/dev/null | \
    sed 's/<title>//;s/<\/title>//' | sed 's/^/  → /' || echo "  (no title)"

echo ""

# ========== SUMMARY ==========
echo "═══════════════════════════════════════════════════════════════════"
echo "CONTENT ANALYSIS COMPLETE"
echo "═══════════════════════════════════════════════════════════════════"
echo ""
echo "Report: $REPORT"
echo "Discovered URLs: $DISCOVERED_URLS"
echo "Discovered endpoints: $DISCOVERED_ENDPOINTS"
echo "Extracted comments: $COMMENTS"
echo ""
echo "Total discoveries:"
echo "  External URLs: $(wc -l < "$DISCOVERED_URLS" 2>/dev/null || echo 0)"
echo "  Internal endpoints: $(sort -u "$DISCOVERED_ENDPOINTS" | wc -l)"
echo "  Comments extracted: $(wc -l < "$COMMENTS" 2>/dev/null || echo 0)"

} | tee "$REPORT"

log "Content analysis complete"
echo ""
echo "To enumerate discovered endpoints:"
echo "  while read endpoint; do echo \"Testing: \$endpoint\"; curl --socks5-hostname $SOCKS -I \"\$endpoint\"; done < $DISCOVERED_ENDPOINTS"
