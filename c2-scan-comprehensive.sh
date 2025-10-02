#!/usr/bin/env bash
# c2-scan-comprehensive.sh - Aggressive C2 endpoint scanning
# Designed for Docker isolation - more aggressive than standalone version
set -euo pipefail
IFS=$'\n\t'

# ---------- Configuration ----------
SOCKS="${SOCKS:-127.0.0.1:9050}"
TIMEOUT_SHORT=5
TIMEOUT_MEDIUM=15
TIMEOUT_LONG=30
MAX_PARALLEL_JOBS=20  # Docker can handle more
VERBOSE="${VERBOSE:-true}"

# ---------- Extended Port List ----------
COMMON_PORTS=(
    "21:FTP"
    "22:SSH"
    "23:Telnet"
    "25:SMTP"
    "53:DNS"
    "80:HTTP"
    "110:POP3"
    "143:IMAP"
    "443:HTTPS"
    "445:SMB"
    "587:SMTP-Submission"
    "993:IMAPS"
    "995:POP3S"
    "1080:SOCKS"
    "1433:MSSQL"
    "1521:Oracle"
    "3000:Node.js"
    "3306:MySQL"
    "3389:RDP"
    "4444:Metasploit"
    "5000:Flask"
    "5432:PostgreSQL"
    "5900:VNC"
    "6379:Redis"
    "6667:IRC"
    "8000:HTTP-Alt"
    "8080:HTTP-Proxy"
    "8081:HTTP-Alt2"
    "8443:HTTPS-Alt"
    "8888:HTTP-Alt3"
    "9000:Custom"
    "9001:Tor-Dir"
    "9050:Tor-SOCKS"
    "9090:Webmin"
    "9150:Tor-Browser"
    "27017:MongoDB"
    "50000:SAP"
)

# ---------- Extended Path List ----------
COMPREHENSIVE_PATHS=(
    # Standard web files
    "/"
    "/index.html"
    "/index.php"
    "/index.asp"
    "/index.aspx"
    "/index.jsp"
    "/default.html"
    "/home.html"

    # Discovery files
    "/robots.txt"
    "/sitemap.xml"
    "/humans.txt"
    "/security.txt"
    "/.well-known/security.txt"
    "/crossdomain.xml"
    "/clientaccesspolicy.xml"

    # Static assets
    "/favicon.ico"
    "/apple-touch-icon.png"
    "/logo.png"
    "/logo.svg"

    # Admin panels
    "/admin"
    "/admin.php"
    "/administrator"
    "/wp-admin"
    "/phpmyadmin"
    "/cpanel"
    "/webadmin"
    "/adminpanel"
    "/admin/login"
    "/admin/index.php"
    "/manager/html"
    "/panel"
    "/control"
    "/c2"
    "/c2panel"

    # API endpoints
    "/api"
    "/api/v1"
    "/api/v2"
    "/api/status"
    "/api/health"
    "/api/info"
    "/api/config"
    "/api/version"
    "/rest/api"
    "/graphql"

    # Status/Health endpoints
    "/status"
    "/health"
    "/healthz"
    "/ping"
    "/alive"
    "/ready"
    "/metrics"
    "/stats"
    "/info"
    "/version"

    # Configuration files (should be blocked but often aren't)
    "/config.json"
    "/config.php"
    "/configuration.php"
    "/settings.json"
    "/app.json"
    "/package.json"
    "/composer.json"
    "/.env"
    "/.env.local"
    "/.env.production"
    "/web.config"
    "/app.config"

    # Git/Version control (should be blocked but often aren't)
    "/.git"
    "/.git/config"
    "/.git/HEAD"
    "/.git/logs/HEAD"
    "/.gitignore"
    "/.svn"
    "/.hg"

    # Backup files
    "/backup"
    "/backup.sql"
    "/backup.tar.gz"
    "/db_backup.sql"
    "/site_backup.zip"

    # Common directories
    "/static"
    "/assets"
    "/uploads"
    "/media"
    "/files"
    "/download"
    "/downloads"
    "/images"
    "/img"
    "/css"
    "/js"
    "/javascript"
    "/scripts"
    "/includes"
    "/lib"
    "/vendor"
    "/node_modules"

    # Docker/Container artifacts
    "/static/docker-init.sh"
    "/docker-compose.yml"
    "/Dockerfile"
    "/.dockerignore"

    # Binary endpoints
    "/binary"
    "/binaries"
    "/download/binary"
    "/files/binary"
    "/static/binary"

    # C2-specific
    "/beacon"
    "/checkin"
    "/task"
    "/tasks"
    "/command"
    "/commands"
    "/agent"
    "/implant"
    "/payload"
    "/stage"
    "/stager"

    # Database dumps
    "/dump"
    "/database"
    "/db"
    "/sql"
    "/mysql"
    "/postgres"

    # Logs
    "/logs"
    "/log"
    "/access.log"
    "/error.log"
    "/debug.log"

    # Test/Debug
    "/test"
    "/debug"
    "/phpinfo.php"
    "/info.php"
    "/test.php"

    # Common CMSs
    "/wp-content"
    "/wp-includes"
    "/wp-json"
    "/wordpress"
    "/joomla"
    "/drupal"

    # Mobile app endpoints
    "/mobile"
    "/app"
    "/android"
    "/ios"
)

# ---------- User Agents ----------
USER_AGENTS=(
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36"
    "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36"
    "curl/7.68.0"
    "python-requests/2.31.0"
    "Go-http-client/1.1"
)

# ---------- HTTP Methods ----------
HTTP_METHODS=("GET" "POST" "HEAD" "OPTIONS" "PUT" "DELETE" "TRACE" "CONNECT")

# ---------- Utilities ----------
log() {
    echo "[$(date -u +'%Y-%m-%dT%H:%M:%SZ')] $*"
}

say() {
    if $VERBOSE; then
        echo "$*"
    fi
}

# ---------- Enhanced Port Scanner ----------
comprehensive_port_scan() {
    local target="$1"
    local outdir="$2"
    local host port

    if [[ "$target" == *:* ]]; then
        host="${target%:*}"
    else
        host="$target"
    fi

    log "Starting comprehensive port scan: $host"

    local scan_file="$outdir/port_scan_comprehensive.txt"
    {
        echo "═══════════════════════════════════════════════════════════"
        echo " Comprehensive Port Scan: $host"
        echo " Timestamp: $(date -u +'%Y-%m-%dT%H:%M:%SZ')"
        echo " Ports: ${#COMMON_PORTS[@]}"
        echo "═══════════════════════════════════════════════════════════"
        echo ""
    } > "$scan_file"

    local open_ports=()
    local job_count=0

    for port_info in "${COMMON_PORTS[@]}"; do
        port="${port_info%%:*}"
        service="${port_info##*:}"

        # Parallel scanning with job control
        while [ $(jobs -r | wc -l) -ge $MAX_PARALLEL_JOBS ]; do
            sleep 0.2
        done

        (
            if timeout $TIMEOUT_SHORT curl --socks5-hostname "$SOCKS" \
               -s --max-time $TIMEOUT_SHORT --connect-timeout 3 \
               "http://${host}:${port}/" >/dev/null 2>&1; then
                echo "Port $port ($service): OPEN" >> "$scan_file"
                echo "$port:$service"
            else
                echo "Port $port ($service): CLOSED/FILTERED" >> "$scan_file"
            fi
        ) &

        ((job_count++))
    done

    wait  # Wait for all port scans to complete

    # Read open ports
    while IFS=: read -r port service; do
        open_ports+=("$port:$service")
    done < <(grep "OPEN" "$scan_file" | awk '{print $2}' | tr -d '():')

    {
        echo ""
        echo "Summary: ${#open_ports[@]} open ports found"
        for p in "${open_ports[@]}"; do
            echo "  → $p"
        done
    } >> "$scan_file"

    log "Port scan complete: ${#open_ports[@]} open ports"

    # Return open ports
    printf '%s\n' "${open_ports[@]}"
}

# ---------- HTTP Method Testing ----------
test_http_methods() {
    local url="$1"
    local outdir="$2"

    log "Testing HTTP methods: $url"

    local method_file="$outdir/http_methods.txt"
    {
        echo "═══════════════════════════════════════════════════════════"
        echo " HTTP Method Testing: $url"
        echo " Timestamp: $(date -u +'%Y-%m-%dT%H:%M:%SZ')"
        echo "═══════════════════════════════════════════════════════════"
        echo ""
    } > "$method_file"

    for method in "${HTTP_METHODS[@]}"; do
        say "  Testing $method..."

        response=$(curl --socks5-hostname "$SOCKS" -s -X "$method" \
                   --max-time $TIMEOUT_MEDIUM -I "$url" 2>&1 || echo "FAILED")

        {
            echo "[$method]"
            echo "$response"
            echo ""
        } >> "$method_file"
    done

    log "HTTP method testing complete"
}

# ---------- Header Analysis ----------
analyze_headers() {
    local url="$1"
    local outdir="$2"

    log "Analyzing HTTP headers: $url"

    local header_file="$outdir/headers_analysis.txt"
    {
        echo "═══════════════════════════════════════════════════════════"
        echo " HTTP Header Analysis: $url"
        echo " Timestamp: $(date -u +'%Y-%m-%dT%H:%M:%SZ')"
        echo "═══════════════════════════════════════════════════════════"
        echo ""
    } > "$header_file"

    # Standard request
    echo "=== Standard Request ===" >> "$header_file"
    curl --socks5-hostname "$SOCKS" -I -s --max-time $TIMEOUT_MEDIUM "$url" \
        >> "$header_file" 2>&1 || echo "FAILED" >> "$header_file"
    echo "" >> "$header_file"

    # With different User-Agents
    for ua in "${USER_AGENTS[@]}"; do
        echo "=== User-Agent: $ua ===" >> "$header_file"
        curl --socks5-hostname "$SOCKS" -I -s --max-time $TIMEOUT_SHORT \
             -A "$ua" "$url" >> "$header_file" 2>&1 || echo "FAILED" >> "$header_file"
        echo "" >> "$header_file"
    done

    # Security headers check
    echo "=== Security Headers ===" >> "$header_file"
    curl --socks5-hostname "$SOCKS" -I -s --max-time $TIMEOUT_MEDIUM "$url" 2>/dev/null | \
        grep -iE "X-|Content-Security|Strict-Transport|Referrer-Policy|Permissions-Policy" \
        >> "$header_file" || echo "No security headers found" >> "$header_file"

    log "Header analysis complete"
}

# ---------- Path Enumeration ----------
enumerate_paths() {
    local base_url="$1"
    local outdir="$2"

    log "Enumerating paths (${#COMPREHENSIVE_PATHS[@]} paths)..."

    local path_file="$outdir/path_enumeration.txt"
    local found_file="$outdir/found_paths.txt"

    {
        echo "═══════════════════════════════════════════════════════════"
        echo " Path Enumeration: $base_url"
        echo " Paths tested: ${#COMPREHENSIVE_PATHS[@]}"
        echo " Timestamp: $(date -u +'%Y-%m-%dT%H:%M:%SZ')"
        echo "═══════════════════════════════════════════════════════════"
        echo ""
    } > "$path_file"

    : > "$found_file"

    local found_count=0
    local tested_count=0

    for path in "${COMPREHENSIVE_PATHS[@]}"; do
        # Parallel path testing with job control
        while [ $(jobs -r | wc -l) -ge $MAX_PARALLEL_JOBS ]; do
            sleep 0.1
        done

        (
            local url="${base_url}${path}"
            local response=$(curl --socks5-hostname "$SOCKS" -s -I \
                            --max-time $TIMEOUT_SHORT --connect-timeout 3 \
                            "$url" 2>&1)

            local status_code=$(echo "$response" | grep -i "^HTTP" | awk '{print $2}' | head -1)

            if [[ -n "$status_code" ]]; then
                echo "[$status_code] $path" >> "$path_file"

                # Interesting status codes
                if [[ "$status_code" =~ ^(200|201|204|301|302|401|403|500)$ ]]; then
                    echo "$status_code $path" >> "$found_file"

                    # Get content length
                    local content_length=$(echo "$response" | grep -i "content-length" | awk '{print $2}' | tr -d '\r')
                    echo "  Size: ${content_length:-unknown}" >> "$path_file"
                fi
            fi
        ) &

        ((tested_count++))
    done

    wait  # Wait for all path tests to complete

    found_count=$(wc -l < "$found_file" 2>/dev/null || echo "0")

    {
        echo ""
        echo "Summary: $found_count interesting paths found (out of $tested_count tested)"
        echo ""
        echo "Found paths:"
        sort -u "$found_file" 2>/dev/null || echo "None"
    } >> "$path_file"

    log "Path enumeration complete: $found_count found"
}

# ---------- Binary Artifact Discovery ----------
discover_binaries() {
    local base_url="$1"
    local outdir="$2"

    log "Discovering binary artifacts..."

    local binary_file="$outdir/binary_discovery.txt"
    {
        echo "═══════════════════════════════════════════════════════════"
        echo " Binary Artifact Discovery"
        echo " Base URL: $base_url"
        echo "═══════════════════════════════════════════════════════════"
        echo ""
    } > "$binary_file"

    local architectures=("x86_64" "amd64" "i386" "arm64" "aarch64" "armv7" "mips")
    local platforms=("linux" "windows" "darwin" "freebsd")
    local endpoints=("/binary" "/binaries" "/download" "/files" "/static")

    for endpoint in "${endpoints[@]}"; do
        for platform in "${platforms[@]}"; do
            for arch in "${architectures[@]}"; do
                # Parallel binary discovery
                while [ $(jobs -r | wc -l) -ge $MAX_PARALLEL_JOBS ]; do
                    sleep 0.1
                done

                (
                    local variations=(
                        "${endpoint}/system-${platform}-${arch}"
                        "${endpoint}/system-${platform}-${arch}.zst"
                        "${endpoint}/agent-${platform}-${arch}"
                        "${endpoint}/implant-${platform}-${arch}"
                        "${endpoint}/${platform}/${arch}/binary"
                        "${endpoint}/${platform}-${arch}"
                    )

                    for variant in "${variations[@]}"; do
                        local url="${base_url}${variant}"

                        if curl --socks5-hostname "$SOCKS" -s -I \
                           --max-time $TIMEOUT_SHORT "$url" 2>&1 | \
                           grep -q "200 OK"; then
                            echo "[FOUND] $variant" >> "$binary_file"

                            # Try to download
                            local outfile="$outdir/binary_$(echo "$variant" | tr '/' '_')"
                            if curl --socks5-hostname "$SOCKS" -s \
                               --max-time $TIMEOUT_LONG "$url" \
                               -o "$outfile" 2>&1; then
                                echo "  Downloaded: $outfile" >> "$binary_file"
                                file "$outfile" >> "$binary_file" 2>&1 || true
                                sha256sum "$outfile" >> "$binary_file" 2>&1 || true
                            fi
                        fi
                    done
                ) &
            done
        done
    done

    wait
    log "Binary discovery complete"
}

# ---------- DNS/Subdomain Probing ----------
probe_subdomains() {
    local onion_host="$1"
    local outdir="$2"

    log "Probing subdomains/variations..."

    local subdomain_file="$outdir/subdomain_probe.txt"
    {
        echo "═══════════════════════════════════════════════════════════"
        echo " Subdomain/Variation Probing"
        echo " Base: $onion_host"
        echo "═══════════════════════════════════════════════════════════"
        echo ""
    } > "$subdomain_file"

    local subdomains=("www" "api" "admin" "panel" "c2" "control" "manage" "portal" "app" "mobile")

    for sub in "${subdomains[@]}"; do
        (
            local test_host="${sub}.${onion_host}"

            if curl --socks5-hostname "$SOCKS" -s -I \
               --max-time $TIMEOUT_MEDIUM "http://${test_host}/" 2>&1 | \
               grep -q "200 OK"; then
                echo "[FOUND] $test_host" >> "$subdomain_file"
            else
                echo "[NOT FOUND] $test_host" >> "$subdomain_file"
            fi
        ) &
    done

    wait
    log "Subdomain probing complete"
}

# ---------- Technology Fingerprinting ----------
fingerprint_technology() {
    local url="$1"
    local outdir="$2"

    log "Fingerprinting technology stack..."

    local tech_file="$outdir/technology_fingerprint.txt"
    {
        echo "═══════════════════════════════════════════════════════════"
        echo " Technology Fingerprinting"
        echo " URL: $url"
        echo "═══════════════════════════════════════════════════════════"
        echo ""
    } > "$tech_file"

    # Get full response
    local response=$(curl --socks5-hostname "$SOCKS" -s \
                     --max-time $TIMEOUT_LONG "$url" 2>&1)

    # Check for common frameworks
    echo "=== Framework Detection ===" >> "$tech_file"

    if echo "$response" | grep -qi "flask"; then
        echo "✓ Flask (Python)" >> "$tech_file"
    fi

    if echo "$response" | grep -qi "django"; then
        echo "✓ Django (Python)" >> "$tech_file"
    fi

    if echo "$response" | grep -qi "express"; then
        echo "✓ Express (Node.js)" >> "$tech_file"
    fi

    if echo "$response" | grep -qi "laravel"; then
        echo "✓ Laravel (PHP)" >> "$tech_file"
    fi

    if echo "$response" | grep -qi "wordpress"; then
        echo "✓ WordPress (PHP)" >> "$tech_file"
    fi

    if echo "$response" | grep -qi "asp.net"; then
        echo "✓ ASP.NET" >> "$tech_file"
    fi

    # Check headers
    echo "" >> "$tech_file"
    echo "=== Server Headers ===" >> "$tech_file"
    curl --socks5-hostname "$SOCKS" -I -s --max-time $TIMEOUT_MEDIUM "$url" 2>&1 | \
        grep -iE "server:|x-powered-by:|x-aspnet-version:" >> "$tech_file" || \
        echo "No server headers disclosed" >> "$tech_file"

    log "Technology fingerprinting complete"
}

# ---------- Main Comprehensive Scan ----------
main() {
    local target="$1"
    local outdir="${2:-./comprehensive_scan_$(date +%Y%m%d_%H%M%S)}"

    mkdir -p "$outdir"

    log "╔════════════════════════════════════════════════════════════════════╗"
    log "║         COMPREHENSIVE C2 ENDPOINT SCANNING INITIATED               ║"
    log "╚════════════════════════════════════════════════════════════════════╝"
    log ""
    log "Target:     $target"
    log "Output:     $outdir"
    log "SOCKS:      $SOCKS"
    log "Max Parallel: $MAX_PARALLEL_JOBS"
    log ""

    # Extract host for various tests
    local host protocol base_url
    if [[ "$target" == *:* ]]; then
        host="${target%:*}"
    else
        host="$target"
    fi

    # Try both HTTP and HTTPS
    for protocol in "http" "https"; do
        base_url="${protocol}://${target}"

        log "Testing ${protocol}://${target}..."

        if curl --socks5-hostname "$SOCKS" -s -I \
           --max-time $TIMEOUT_MEDIUM "$base_url/" 2>&1 | \
           grep -q "HTTP"; then
            log "✓ ${protocol}://${target} is responsive"

            # Run all comprehensive scans
            log ""
            log "═══ Running Comprehensive Scans ═══"

            # Port scan
            comprehensive_port_scan "$target" "$outdir" > "$outdir/open_ports.txt" &

            # HTTP methods
            test_http_methods "$base_url" "$outdir" &

            # Headers
            analyze_headers "$base_url" "$outdir" &

            # Path enumeration
            enumerate_paths "$base_url" "$outdir" &

            # Binary discovery
            discover_binaries "$base_url" "$outdir" &

            # Subdomain probing
            probe_subdomains "$host" "$outdir" &

            # Technology fingerprinting
            fingerprint_technology "$base_url" "$outdir" &

            # Wait for all scans
            wait

            log ""
            log "✓ All scans complete for $protocol"
        fi
    done

    log ""
    log "╔════════════════════════════════════════════════════════════════════╗"
    log "║              COMPREHENSIVE SCAN COMPLETE                           ║"
    log "╚════════════════════════════════════════════════════════════════════╝"
    log ""
    log "Results saved to: $outdir"
    log ""
    log "Generated files:"
    ls -lh "$outdir" | tail -n +2 | awk '{print "  -", $9, "("$5")"}'
}

# ---------- Entry Point ----------
if [[ $# -eq 0 ]]; then
    echo "Usage: $0 <target.onion[:port]> [output_directory]"
    echo ""
    echo "Example:"
    echo "  $0 example.onion"
    echo "  $0 example.onion:9000 /tmp/scan_results"
    exit 1
fi

main "$@"
