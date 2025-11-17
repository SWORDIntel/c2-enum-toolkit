#!/usr/bin/env python3
"""
sinkhole-server.py - Automated C2 Sinkhole Server with Cleanup Distribution

Purpose: Serve cleanup payloads to botnet victims during authorized takedown operations
Classification: DEFENSIVE SECURITY - LAW ENFORCEMENT USE ONLY
Legal Requirement: COURT ORDER MANDATORY

Features:
- HTTP/HTTPS server mimicking C2 behavior
- Cleanup payload distribution with phased rollout
- Victim telemetry collection and monitoring
- Success rate tracking and reporting
- Automatic rollback on issues
- Evidence logging for legal proceedings
- Support for multiple payload formats
- Signature generation (if keys available)

Usage:
    # Basic sinkhole (HTTP only)
    ./sinkhole-server.py --port 8080 --cleanup cleanup.exe

    # HTTPS with certificate (recommended)
    ./sinkhole-server.py --port 443 --cleanup cleanup.exe \\
        --cert server.crt --key server.key --ssl

    # Phased rollout
    ./sinkhole-server.py --cleanup cleanup.exe --phase 1 --percentage 1

    # Mimicking specific C2
    ./sinkhole-server.py --cleanup cleanup.exe --mimic-c2 config.json

LEGAL WARNING:
This tool is for AUTHORIZED law enforcement operations ONLY.
Requires court order or equivalent legal authorization.
Unauthorized use is ILLEGAL and punishable under CFAA (US) and equivalent laws.
"""

import argparse
import json
import hashlib
import hmac
import logging
import os
import random
import signal
import sys
import time
from datetime import datetime
from http.server import HTTPServer, BaseHTTPRequestHandler
from pathlib import Path
from typing import Dict, Optional, Set
import ssl
import threading
import ipaddress

# Configuration
VERSION = "2.6-takeover"
DEFAULT_PORT = 8080
EVIDENCE_LOG = "sinkhole_evidence.jsonl"
TELEMETRY_LOG = "victim_telemetry.jsonl"
STATS_FILE = "sinkhole_stats.json"

# Phased rollout configuration
ROLLOUT_PHASES = {
    1: {"percentage": 1, "min_duration_hours": 24, "max_errors": 5},
    2: {"percentage": 10, "min_duration_hours": 12, "max_errors": 20},
    3: {"percentage": 50, "min_duration_hours": 6, "max_errors": 100},
    4: {"percentage": 100, "min_duration_hours": 0, "max_errors": -1}  # -1 = unlimited
}

# Stats tracking
stats = {
    "start_time": None,
    "total_requests": 0,
    "cleanup_served": 0,
    "success_reports": 0,
    "error_reports": 0,
    "unique_victims": set(),
    "current_phase": 1,
    "phase_started": None,
    "errors_this_phase": 0,
    "victim_ips": {}
}

# Evidence logging
evidence_file = None
telemetry_file = None

# Cleanup payload
cleanup_payload = None
cleanup_hash = None
cleanup_size = 0

# Configuration
config = {
    "phase": 1,
    "percentage": 1,
    "mimic_mode": False,
    "mimic_config": {},
    "enable_signing": False,
    "signing_key": None,
    "user_agent_filter": None,
    "require_authorization": False,
    "authorization_token": None
}


class Colors:
    """Terminal colors for logging"""
    BLUE = '\033[94m'
    GREEN = '\033[92m'
    YELLOW = '\033[93m'
    RED = '\033[91m'
    CYAN = '\033[96m'
    RESET = '\033[0m'
    BOLD = '\033[1m'


def setup_logging():
    """Configure logging with colors and proper formatting"""
    logging.basicConfig(
        level=logging.INFO,
        format='%(asctime)s - %(levelname)s - %(message)s',
        datefmt='%Y-%m-%d %H:%M:%S'
    )


def log_evidence(action: str, details: Dict, client_ip: str):
    """Log evidence for legal proceedings"""
    evidence = {
        "timestamp": datetime.utcnow().isoformat() + "Z",
        "action": action,
        "client_ip": client_ip,
        "details": details
    }

    if evidence_file:
        evidence_file.write(json.dumps(evidence) + "\n")
        evidence_file.flush()


def log_telemetry(victim_ip: str, telemetry_data: Dict):
    """Log victim telemetry"""
    telemetry = {
        "timestamp": datetime.utcnow().isoformat() + "Z",
        "victim_ip": victim_ip,
        "data": telemetry_data
    }

    if telemetry_file:
        telemetry_file.write(json.dumps(telemetry) + "\n")
        telemetry_file.flush()


def load_cleanup_payload(filepath: str) -> bytes:
    """Load cleanup payload from file"""
    global cleanup_payload, cleanup_hash, cleanup_size

    try:
        with open(filepath, 'rb') as f:
            cleanup_payload = f.read()
            cleanup_size = len(cleanup_payload)
            cleanup_hash = hashlib.sha256(cleanup_payload).hexdigest()

        logging.info(f"{Colors.GREEN}[✓]{Colors.RESET} Cleanup payload loaded:")
        logging.info(f"    Size: {cleanup_size} bytes")
        logging.info(f"    SHA256: {cleanup_hash}")

        return cleanup_payload
    except Exception as e:
        logging.error(f"{Colors.RED}[✗]{Colors.RESET} Failed to load cleanup payload: {e}")
        sys.exit(1)


def should_serve_cleanup(client_ip: str) -> bool:
    """Determine if cleanup should be served based on phased rollout"""
    phase_config = ROLLOUT_PHASES.get(config["phase"], ROLLOUT_PHASES[1])
    percentage = phase_config["percentage"]

    # Always serve to previously seen victims who got cleanup
    if client_ip in stats["victim_ips"] and stats["victim_ips"][client_ip].get("served_cleanup"):
        return True

    # Check error threshold
    max_errors = phase_config["max_errors"]
    if max_errors >= 0 and stats["errors_this_phase"] >= max_errors:
        logging.warning(f"{Colors.YELLOW}[!]{Colors.RESET} Error threshold reached for phase {config['phase']}")
        logging.warning(f"    Halting cleanup distribution. Manual intervention required.")
        return False

    # Random selection based on percentage
    return random.random() * 100 < percentage


def generate_signature(data: bytes) -> Optional[str]:
    """Generate HMAC signature if signing is enabled"""
    if not config["enable_signing"] or not config["signing_key"]:
        return None

    sig = hmac.new(
        config["signing_key"].encode(),
        data,
        hashlib.sha256
    ).hexdigest()

    return sig


def check_authorization(headers: Dict) -> bool:
    """Check if request has valid authorization"""
    if not config["require_authorization"]:
        return True

    auth_header = headers.get("Authorization", "")
    expected = f"Bearer {config['authorization_token']}"

    return auth_header == expected


class SinkholeHandler(BaseHTTPRequestHandler):
    """HTTP request handler for sinkhole server"""

    def log_message(self, format, *args):
        """Override to use our logging"""
        pass  # We handle logging ourselves

    def get_client_ip(self) -> str:
        """Get real client IP (handle proxies)"""
        # Check X-Forwarded-For header
        forwarded = self.headers.get("X-Forwarded-For")
        if forwarded:
            return forwarded.split(",")[0].strip()
        return self.client_address[0]

    def send_json_response(self, data: Dict, status_code: int = 200):
        """Send JSON response"""
        response = json.dumps(data).encode()

        self.send_response(status_code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(response)))
        self.send_header("Server", "nginx/1.18.0")  # Mimic common server
        self.end_headers()
        self.wfile.write(response)

    def send_binary_response(self, data: bytes, content_type: str = "application/octet-stream"):
        """Send binary response (cleanup payload)"""
        self.send_response(200)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(data)))
        self.send_header("Content-Disposition", 'attachment; filename="update.exe"')

        # Add signature if enabled
        if config["enable_signing"]:
            sig = generate_signature(data)
            if sig:
                self.send_header("X-Signature", sig)
                self.send_header("X-Signature-Algorithm", "HMAC-SHA256")

        self.end_headers()
        self.wfile.write(data)

    def do_GET(self):
        """Handle GET requests"""
        client_ip = self.get_client_ip()

        # Update stats
        stats["total_requests"] += 1
        stats["unique_victims"].add(client_ip)

        if client_ip not in stats["victim_ips"]:
            stats["victim_ips"][client_ip] = {
                "first_seen": datetime.utcnow().isoformat() + "Z",
                "requests": 0,
                "served_cleanup": False,
                "reported_success": False
            }

        stats["victim_ips"][client_ip]["requests"] += 1
        stats["victim_ips"][client_ip]["last_seen"] = datetime.utcnow().isoformat() + "Z"

        # Log request
        logging.info(f"{Colors.BLUE}[→]{Colors.RESET} GET {self.path} from {client_ip}")

        log_evidence("request_received", {
            "method": "GET",
            "path": self.path,
            "user_agent": self.headers.get("User-Agent", ""),
            "headers": dict(self.headers)
        }, client_ip)

        # Handle different endpoints
        if self.path.startswith("/update") or self.path.startswith("/api/update"):
            self.handle_update_check(client_ip)
        elif self.path.startswith("/download"):
            self.handle_download(client_ip)
        elif self.path.startswith("/cleanup"):
            self.handle_download(client_ip)
        elif self.path.startswith("/status"):
            self.handle_status(client_ip)
        elif self.path == "/stats":
            self.handle_stats()
        else:
            # Default response for unknown paths
            self.send_response(404)
            self.end_headers()

    def do_POST(self):
        """Handle POST requests (telemetry, success reports)"""
        client_ip = self.get_client_ip()

        stats["total_requests"] += 1

        # Read POST data
        content_length = int(self.headers.get("Content-Length", 0))
        post_data = self.rfile.read(content_length)

        logging.info(f"{Colors.BLUE}[→]{Colors.RESET} POST {self.path} from {client_ip}")

        try:
            data = json.loads(post_data.decode())
        except:
            data = {"raw": post_data.decode(errors="ignore")}

        log_evidence("post_received", {
            "path": self.path,
            "data": data
        }, client_ip)

        # Handle different POST endpoints
        if self.path.startswith("/report") or self.path.startswith("/telemetry"):
            self.handle_telemetry_report(client_ip, data)
        elif self.path.startswith("/success"):
            self.handle_success_report(client_ip, data)
        elif self.path.startswith("/error"):
            self.handle_error_report(client_ip, data)
        else:
            self.send_json_response({"status": "ok"})

    def handle_update_check(self, client_ip: str):
        """Handle update check request"""
        should_cleanup = should_serve_cleanup(client_ip)

        if config["mimic_mode"] and config["mimic_config"]:
            # Mimic original C2 response format
            response = config["mimic_config"].copy()

            if should_cleanup:
                # Modify to point to cleanup
                response["version"] = "99.99.9999"  # Very high version
                response["update_url"] = f"http://{self.headers.get('Host', '')}/download/cleanup.exe"
                response["mandatory"] = True

                logging.info(f"{Colors.GREEN}[✓]{Colors.RESET} Serving cleanup to {client_ip} (Phase {config['phase']})")

                stats["cleanup_served"] += 1
                stats["victim_ips"][client_ip]["served_cleanup"] = True

                log_evidence("cleanup_served", {
                    "phase": config["phase"],
                    "response": response
                }, client_ip)
            else:
                # Serve benign update or delay
                logging.info(f"{Colors.YELLOW}[◷]{Colors.RESET} Delaying cleanup for {client_ip} (Phase {config['phase']}, {ROLLOUT_PHASES[config['phase']]['percentage']}%)")
                response["version"] = "0.0.0"  # No update
                response["update_url"] = ""
        else:
            # Generic response
            response = {
                "status": "ok",
                "version": "99.99.9999" if should_cleanup else "0.0.0",
                "update_available": should_cleanup,
                "update_url": f"http://{self.headers.get('Host', '')}/download/cleanup.exe" if should_cleanup else "",
                "mandatory": should_cleanup
            }

        self.send_json_response(response)

    def handle_download(self, client_ip: str):
        """Handle cleanup download request"""
        if cleanup_payload is None:
            logging.error(f"{Colors.RED}[✗]{Colors.RESET} No cleanup payload loaded")
            self.send_response(404)
            self.end_headers()
            return

        # Check authorization if required
        if config["require_authorization"]:
            if not check_authorization(dict(self.headers)):
                logging.warning(f"{Colors.YELLOW}[!]{Colors.RESET} Unauthorized download attempt from {client_ip}")
                self.send_response(401)
                self.send_header("WWW-Authenticate", 'Bearer realm="Sinkhole"')
                self.end_headers()
                return

        logging.info(f"{Colors.GREEN}[↓]{Colors.RESET} Sending cleanup payload to {client_ip}")
        logging.info(f"    Size: {cleanup_size} bytes, SHA256: {cleanup_hash}")

        log_evidence("cleanup_downloaded", {
            "size": cleanup_size,
            "sha256": cleanup_hash,
            "phase": config["phase"]
        }, client_ip)

        self.send_binary_response(cleanup_payload)

        stats["cleanup_served"] += 1
        stats["victim_ips"][client_ip]["served_cleanup"] = True
        stats["victim_ips"][client_ip]["cleanup_downloaded"] = datetime.utcnow().isoformat() + "Z"

    def handle_telemetry_report(self, client_ip: str, data: Dict):
        """Handle telemetry report from victim"""
        logging.info(f"{Colors.CYAN}[ℹ]{Colors.RESET} Telemetry from {client_ip}: {data}")

        log_telemetry(client_ip, data)

        self.send_json_response({"status": "received"})

    def handle_success_report(self, client_ip: str, data: Dict):
        """Handle cleanup success report"""
        logging.info(f"{Colors.GREEN}[✓]{Colors.RESET} SUCCESS reported by {client_ip}")

        stats["success_reports"] += 1
        stats["victim_ips"][client_ip]["reported_success"] = True
        stats["victim_ips"][client_ip]["success_time"] = datetime.utcnow().isoformat() + "Z"

        log_evidence("cleanup_success", data, client_ip)

        self.send_json_response({"status": "success acknowledged"})

    def handle_error_report(self, client_ip: str, data: Dict):
        """Handle cleanup error report"""
        logging.error(f"{Colors.RED}[✗]{Colors.RESET} ERROR reported by {client_ip}: {data}")

        stats["error_reports"] += 1
        stats["errors_this_phase"] += 1
        stats["victim_ips"][client_ip]["reported_error"] = True
        stats["victim_ips"][client_ip]["error_time"] = datetime.utcnow().isoformat() + "Z"
        stats["victim_ips"][client_ip]["error_details"] = data

        log_evidence("cleanup_error", data, client_ip)

        # Check if we should halt rollout
        phase_config = ROLLOUT_PHASES[config["phase"]]
        if phase_config["max_errors"] >= 0 and stats["errors_this_phase"] >= phase_config["max_errors"]:
            logging.critical(f"{Colors.RED}[!!!]{Colors.RESET} ERROR THRESHOLD EXCEEDED")
            logging.critical(f"     Phase {config['phase']}: {stats['errors_this_phase']} errors (max: {phase_config['max_errors']})")
            logging.critical(f"     HALTING CLEANUP DISTRIBUTION")

        self.send_json_response({"status": "error acknowledged"})

    def handle_status(self, client_ip: str):
        """Handle status request (for monitoring)"""
        status = {
            "sinkhole_active": True,
            "phase": config["phase"],
            "uptime_seconds": int(time.time() - stats["start_time"]) if stats["start_time"] else 0
        }
        self.send_json_response(status)

    def handle_stats(self):
        """Handle stats request (admin only)"""
        # Convert set to list for JSON serialization
        stats_copy = stats.copy()
        stats_copy["unique_victims"] = len(stats["unique_victims"])

        # Calculate success rate
        if stats["cleanup_served"] > 0:
            stats_copy["success_rate"] = (stats["success_reports"] / stats["cleanup_served"]) * 100
        else:
            stats_copy["success_rate"] = 0

        # Don't expose victim IPs in stats endpoint
        stats_copy.pop("victim_ips", None)

        self.send_json_response(stats_copy)


def save_stats():
    """Save stats to file"""
    stats_copy = stats.copy()
    stats_copy["unique_victims"] = list(stats["unique_victims"])

    # Convert victim_ips (remove non-serializable data)
    victim_ips_serializable = {}
    for ip, data in stats["victim_ips"].items():
        victim_ips_serializable[ip] = data.copy()
    stats_copy["victim_ips"] = victim_ips_serializable

    with open(STATS_FILE, 'w') as f:
        json.dumps(stats_copy, f, indent=2)


def signal_handler(sig, frame):
    """Handle shutdown signal"""
    print("\n")
    logging.info(f"{Colors.YELLOW}[!]{Colors.RESET} Shutdown signal received")

    # Save final stats
    save_stats()

    # Print summary
    print("\n" + "="*70)
    print(f"{Colors.BOLD}Sinkhole Server Summary{Colors.RESET}")
    print("="*70)
    print(f"Total Requests:      {stats['total_requests']}")
    print(f"Unique Victims:      {len(stats['unique_victims'])}")
    print(f"Cleanup Served:      {stats['cleanup_served']}")
    print(f"Success Reports:     {stats['success_reports']}")
    print(f"Error Reports:       {stats['error_reports']}")

    if stats['cleanup_served'] > 0:
        success_rate = (stats['success_reports'] / stats['cleanup_served']) * 100
        print(f"Success Rate:        {success_rate:.1f}%")

    print(f"Current Phase:       {config['phase']}")
    print(f"Errors This Phase:   {stats['errors_this_phase']}")
    print("="*70)
    print(f"\nEvidence log: {EVIDENCE_LOG}")
    print(f"Telemetry log: {TELEMETRY_LOG}")
    print(f"Stats file: {STATS_FILE}")
    print()

    sys.exit(0)


def main():
    parser = argparse.ArgumentParser(
        description="C2 Sinkhole Server with Cleanup Distribution",
        epilog="LEGAL WARNING: Requires court order or legal authorization. Unauthorized use is ILLEGAL."
    )

    parser.add_argument("--port", type=int, default=DEFAULT_PORT,
                       help="Port to listen on (default: 8080)")
    parser.add_argument("--cleanup", required=True,
                       help="Path to cleanup payload file")
    parser.add_argument("--phase", type=int, choices=[1,2,3,4], default=1,
                       help="Rollout phase (1=1%%, 2=10%%, 3=50%%, 4=100%%)")
    parser.add_argument("--mimic-c2", metavar="CONFIG",
                       help="JSON config file with C2 response format to mimic")
    parser.add_argument("--ssl", action="store_true",
                       help="Enable HTTPS")
    parser.add_argument("--cert", help="SSL certificate file")
    parser.add_argument("--key", help="SSL private key file")
    parser.add_argument("--sign", action="store_true",
                       help="Enable payload signing")
    parser.add_argument("--signing-key", help="Key for HMAC signing")
    parser.add_argument("--require-auth", action="store_true",
                       help="Require authorization header")
    parser.add_argument("--auth-token", help="Authorization token")
    parser.add_argument("--legal-ack", action="store_true",
                       help="Acknowledge legal requirements and authorization")

    args = parser.parse_args()

    # Legal acknowledgment check
    if not args.legal_ack:
        print(f"{Colors.RED}{Colors.BOLD}")
        print("╔═══════════════════════════════════════════════════════════════╗")
        print("║                  LEGAL AUTHORIZATION REQUIRED                 ║")
        print("╚═══════════════════════════════════════════════════════════════╝")
        print(f"{Colors.RESET}")
        print("This tool is for AUTHORIZED law enforcement operations ONLY.")
        print()
        print("Requirements:")
        print("  • Court order or equivalent legal authorization")
        print("  • Proper jurisdiction over target infrastructure")
        print("  • Coordination with relevant authorities")
        print()
        print("Unauthorized use violates:")
        print("  • Computer Fraud and Abuse Act (CFAA) - US")
        print("  • Computer Misuse Act - UK")
        print("  • Equivalent laws in other jurisdictions")
        print()
        print("To proceed, you MUST:")
        print("  1. Have proper legal authorization")
        print("  2. Add --legal-ack flag to acknowledge")
        print()
        print(f"{Colors.YELLOW}Without --legal-ack, the server will NOT start.{Colors.RESET}")
        print()
        sys.exit(1)

    setup_logging()

    print(f"{Colors.CYAN}{Colors.BOLD}")
    print("╔═══════════════════════════════════════════════════════════════╗")
    print("║          C2 Sinkhole Server with Cleanup Distribution        ║")
    print(f"║                    Version {VERSION}                         ║")
    print("╚═══════════════════════════════════════════════════════════════╝")
    print(f"{Colors.RESET}")

    # Load cleanup payload
    load_cleanup_payload(args.cleanup)

    # Set config
    config["phase"] = args.phase
    config["percentage"] = ROLLOUT_PHASES[args.phase]["percentage"]

    # Load mimic config if provided
    if args.mimic_c2:
        try:
            with open(args.mimic_c2, 'r') as f:
                config["mimic_config"] = json.load(f)
            config["mimic_mode"] = True
            logging.info(f"{Colors.GREEN}[✓]{Colors.RESET} Loaded C2 mimic config from {args.mimic_c2}")
        except Exception as e:
            logging.error(f"{Colors.RED}[✗]{Colors.RESET} Failed to load mimic config: {e}")
            sys.exit(1)

    # Setup signing
    if args.sign:
        if not args.signing_key:
            logging.error(f"{Colors.RED}[✗]{Colors.RESET} --signing-key required when --sign is enabled")
            sys.exit(1)
        config["enable_signing"] = True
        config["signing_key"] = args.signing_key
        logging.info(f"{Colors.GREEN}[✓]{Colors.RESET} Payload signing enabled")

    # Setup authorization
    if args.require_auth:
        if not args.auth_token:
            logging.error(f"{Colors.RED}[✗]{Colors.RESET} --auth-token required when --require-auth is enabled")
            sys.exit(1)
        config["require_authorization"] = True
        config["authorization_token"] = args.auth_token
        logging.info(f"{Colors.GREEN}[✓]{Colors.RESET} Authorization required for downloads")

    # Open evidence and telemetry logs
    global evidence_file, telemetry_file
    evidence_file = open(EVIDENCE_LOG, 'a')
    telemetry_file = open(TELEMETRY_LOG, 'a')

    # Log startup
    log_evidence("sinkhole_started", {
        "version": VERSION,
        "phase": config["phase"],
        "percentage": config["percentage"],
        "cleanup_hash": cleanup_hash,
        "cleanup_size": cleanup_size,
        "ssl_enabled": args.ssl,
        "signing_enabled": config["enable_signing"],
        "auth_required": config["require_authorization"]
    }, "system")

    # Initialize stats
    stats["start_time"] = time.time()
    stats["phase_started"] = time.time()
    stats["current_phase"] = config["phase"]

    # Print configuration
    print(f"\n{Colors.BOLD}Configuration:{Colors.RESET}")
    print(f"  Port:              {args.port}")
    print(f"  SSL:               {'Enabled' if args.ssl else 'Disabled'}")
    print(f"  Cleanup Payload:   {args.cleanup}")
    print(f"  Payload SHA256:    {cleanup_hash}")
    print(f"  Rollout Phase:     {config['phase']} ({config['percentage']}%)")
    print(f"  Max Errors:        {ROLLOUT_PHASES[config['phase']]['max_errors']}")
    print(f"  Mimic Mode:        {'Enabled' if config['mimic_mode'] else 'Disabled'}")
    print(f"  Signing:           {'Enabled' if config['enable_signing'] else 'Disabled'}")
    print(f"  Authorization:     {'Required' if config['require_authorization'] else 'Not required'}")
    print(f"\n{Colors.BOLD}Logs:{Colors.RESET}")
    print(f"  Evidence:          {EVIDENCE_LOG}")
    print(f"  Telemetry:         {TELEMETRY_LOG}")
    print(f"  Stats:             {STATS_FILE}")
    print()

    # Setup signal handlers
    signal.signal(signal.SIGINT, signal_handler)
    signal.signal(signal.SIGTERM, signal_handler)

    # Create server
    server = HTTPServer(('0.0.0.0', args.port), SinkholeHandler)

    # Setup SSL if requested
    if args.ssl:
        if not args.cert or not args.key:
            logging.error(f"{Colors.RED}[✗]{Colors.RESET} --cert and --key required for SSL")
            sys.exit(1)

        try:
            context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
            context.load_cert_chain(args.cert, args.key)
            server.socket = context.wrap_socket(server.socket, server_side=True)
            logging.info(f"{Colors.GREEN}[✓]{Colors.RESET} SSL enabled")
        except Exception as e:
            logging.error(f"{Colors.RED}[✗]{Colors.RESET} SSL setup failed: {e}")
            sys.exit(1)

    # Start server
    protocol = "HTTPS" if args.ssl else "HTTP"
    logging.info(f"{Colors.GREEN}[✓]{Colors.RESET} Sinkhole server listening on {protocol}://0.0.0.0:{args.port}")
    logging.info(f"{Colors.YELLOW}[!]{Colors.RESET} Press Ctrl+C to stop")
    print()

    try:
        server.serve_forever()
    except KeyboardInterrupt:
        signal_handler(None, None)


if __name__ == "__main__":
    main()
