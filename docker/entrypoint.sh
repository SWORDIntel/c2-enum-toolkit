#!/bin/bash
# Entrypoint script for C2 Enumeration Toolkit Docker container
set -e

echo "╔════════════════════════════════════════════════════════════════════╗"
echo "║           C2 Enumeration Toolkit Docker Container v2.1            ║"
echo "╚════════════════════════════════════════════════════════════════════╝"
echo ""

# Function to check if Tor is running
wait_for_tor() {
    echo "[*] Starting Tor daemon..."

    # Start Tor in background (as debian-tor user via sudo)
    if [ -w /var/run ]; then
        sudo -u debian-tor tor -f /etc/tor/torrc &
        TOR_PID=$!
        echo "[*] Tor started with PID: $TOR_PID"
    else
        echo "[!] Cannot write to /var/run, trying alternative..."
        tor -f /etc/tor/torrc &
        TOR_PID=$!
    fi

    # Wait for Tor to be ready (max 60 seconds)
    echo "[*] Waiting for Tor to establish circuits..."
    local count=0
    while [ $count -lt 60 ]; do
        if curl --socks5-hostname 127.0.0.1:9050 -s --max-time 5 \
           https://check.torproject.org/api/ip 2>/dev/null | grep -q '"IsTor":true'; then
            echo "[✓] Tor is ready!"

            # Get exit node IP
            EXIT_IP=$(curl --socks5-hostname 127.0.0.1:9050 -s --max-time 5 \
                      https://check.torproject.org/api/ip 2>/dev/null | \
                      grep -o '"IP":"[^"]*"' | cut -d'"' -f4)
            echo "[✓] Exit node IP: ${EXIT_IP:-unknown}"
            return 0
        fi
        sleep 2
        ((count+=2))
        echo "    Waiting... (${count}s / 60s)"
    done

    echo "[✗] Tor failed to start within 60 seconds"
    return 1
}

# Function to handle signals
cleanup() {
    echo ""
    echo "[*] Shutting down gracefully..."
    if [ -n "$TOR_PID" ]; then
        echo "[*] Stopping Tor (PID: $TOR_PID)..."
        kill $TOR_PID 2>/dev/null || true
    fi
    exit 0
}

trap cleanup SIGTERM SIGINT

# Display environment info
echo "Environment Information:"
echo "  User:        $(whoami)"
echo "  Home:        $HOME"
echo "  Toolkit:     /home/c2enum/toolkit/"
echo "  Output:      /home/c2enum/output/"
echo "  SOCKS proxy: ${SOCKS:-127.0.0.1:9050}"
echo ""

# Check if running as root (should not be)
if [ "$(id -u)" -eq 0 ]; then
    echo "[!] WARNING: Running as root. This is not recommended."
    echo "[!] Container should run as user 'c2enum' (UID 1000)"
fi

# Start Tor and wait for it to be ready
if ! wait_for_tor; then
    echo "[✗] FATAL: Could not start Tor"
    exit 1
fi

echo ""
echo "╔════════════════════════════════════════════════════════════════════╗"
echo "║                    Container Ready                                 ║"
echo "╚════════════════════════════════════════════════════════════════════╝"
echo ""

# If no arguments or just the default CMD, run the toolkit
if [ $# -eq 0 ] || [ "$1" = "/home/c2enum/toolkit/c2-enum-tui.sh" ]; then
    echo "[*] Launching C2 Enumeration Toolkit..."
    echo ""
    cd /home/c2enum/output
    exec /home/c2enum/toolkit/c2-enum-tui.sh -o /home/c2enum/output
else
    # Execute custom command
    echo "[*] Executing custom command: $@"
    echo ""
    exec "$@"
fi
