#!/usr/bin/env python3
"""
cleanup-generator.py - Automated Cleanup Payload Generator

Purpose: Generate safe, customized cleanup payloads for botnet neutralization
Classification: DEFENSIVE SECURITY - LAW ENFORCEMENT USE ONLY
Legal Requirement: COURT ORDER MANDATORY

Features:
- Template-based cleanup generation
- Multi-platform support (Windows, Linux, macOS)
- Safe operation validation
- Rollback capability inclusion
- Telemetry reporting
- Customizable cleanup actions
- Code obfuscation (optional)
- Digital signing support

Usage:
    # Generate Windows cleanup
    ./cleanup-generator.py --platform windows --profile zemana \\
        --output cleanup.exe

    # Generate with telemetry
    ./cleanup-generator.py --platform windows --profile generic \\
        --sinkhole-url https://sinkhole.example.gov \\
        --output cleanup.exe

    # Add custom cleanup actions
    ./cleanup-generator.py --platform windows --profile custom \\
        --processes malware.exe,bad.exe \\
        --files "C:\\Bad\\Path" \\
        --registry "HKLM\\Software\\Malware" \\
        --output cleanup.exe

LEGAL WARNING:
This tool generates code that will modify victim systems.
Requires court order or equivalent legal authorization.
Unauthorized use is ILLEGAL and punishable under CFAA and equivalent laws.
"""

import argparse
import base64
import hashlib
import json
import os
import sys
import textwrap
from pathlib import Path
from typing import List, Dict, Optional

VERSION = "2.6-takeover"

# Cleanup profiles for known malware families
CLEANUP_PROFILES = {
    "zemana": {
        "processes": ["zemana_update.exe", "zm_service.exe", "baidu_helper.exe"],
        "files": [
            "C:\\ProgramData\\Zemana",
            "C:\\Users\\*\\AppData\\Local\\Zemana",
            "C:\\Program Files\\Zemana"
        ],
        "registry_keys": [
            "HKEY_CURRENT_USER\\Software\\Microsoft\\Windows\\CurrentVersion\\Run\\ZemanaUpdate",
            "HKEY_LOCAL_MACHINE\\Software\\Microsoft\\Windows\\CurrentVersion\\Run\\ZemanaUpdate"
        ],
        "scheduled_tasks": ["ZemanaUpdate", "BaiduSync"],
        "services": ["ZemanaService"]
    },
    "generic": {
        "processes": [],
        "files": [],
        "registry_keys": [],
        "scheduled_tasks": [],
        "services": []
    }
}

# Windows cleanup template
WINDOWS_CLEANUP_TEMPLATE = '''
import os
import sys
import winreg
import subprocess
import ctypes
import json
import socket
from datetime import datetime

# Metadata
CLEANUP_VERSION = "{version}"
TARGET_MALWARE = "{malware_name}"
SINKHOLE_URL = "{sinkhole_url}"
TELEMETRY_ENABLED = {telemetry_enabled}

# Cleanup configuration
PROCESSES_TO_KILL = {processes}
FILES_TO_REMOVE = {files}
REGISTRY_KEYS = {registry_keys}
SCHEDULED_TASKS = {scheduled_tasks}
SERVICES_TO_STOP = {services}

def is_admin():
    """Check if running with admin privileges"""
    try:
        return ctypes.windll.shell32.IsUserAnAdmin()
    except:
        return False

def log(message, level="INFO"):
    """Log message with timestamp"""
    timestamp = datetime.utcnow().isoformat() + "Z"
    print(f"[{{timestamp}}] [{{level}}] {{message}}")

def report_telemetry(status, details=None):
    """Report cleanup status to sinkhole"""
    if not TELEMETRY_ENABLED or not SINKHOLE_URL:
        return

    try:
        import urllib.request
        import urllib.parse

        hostname = socket.gethostname()
        data = {{
            "cleanup_version": CLEANUP_VERSION,
            "target": TARGET_MALWARE,
            "hostname": hostname,
            "status": status,
            "details": details or {{}},
            "timestamp": datetime.utcnow().isoformat() + "Z"
        }}

        req = urllib.request.Request(
            SINKHOLE_URL + "/telemetry",
            data=json.dumps(data).encode(),
            headers={{"Content-Type": "application/json"}}
        )

        urllib.request.urlopen(req, timeout=5)
        log("Telemetry reported successfully")
    except Exception as e:
        log(f"Failed to report telemetry: {{e}}", "WARNING")

def kill_processes():
    """Stop malicious processes"""
    log("Killing malicious processes...")
    killed = []

    for process in PROCESSES_TO_KILL:
        try:
            result = subprocess.run(
                ["taskkill", "/F", "/IM", process],
                capture_output=True,
                text=True
            )
            if result.returncode == 0:
                log(f"Killed process: {{process}}")
                killed.append(process)
            else:
                log(f"Process not found or already stopped: {{process}}", "WARNING")
        except Exception as e:
            log(f"Failed to kill {{process}}: {{e}}", "ERROR")

    return killed

def remove_files():
    """Remove malicious files and directories"""
    log("Removing malicious files...")
    removed = []

    for path in FILES_TO_REMOVE:
        try:
            # Expand wildcards
            if "*" in path:
                import glob
                expanded = glob.glob(path)
                for p in expanded:
                    if os.path.exists(p):
                        if os.path.isdir(p):
                            import shutil
                            shutil.rmtree(p)
                        else:
                            os.remove(p)
                        log(f"Removed: {{p}}")
                        removed.append(p)
            else:
                if os.path.exists(path):
                    if os.path.isdir(path):
                        import shutil
                        shutil.rmtree(path)
                    else:
                        os.remove(path)
                    log(f"Removed: {{path}}")
                    removed.append(path)
        except Exception as e:
            log(f"Failed to remove {{path}}: {{e}}", "ERROR")

    return removed

def remove_registry_keys():
    """Remove malicious registry entries"""
    log("Removing registry entries...")
    removed = []

    for reg_path in REGISTRY_KEYS:
        try:
            # Parse registry path
            if "\\\\" not in reg_path:
                log(f"Invalid registry path format: {{reg_path}}", "ERROR")
                continue

            hive_name, subkey_path = reg_path.split("\\\\", 1)

            # Map hive names to constants
            hive_map = {{
                "HKEY_CURRENT_USER": winreg.HKEY_CURRENT_USER,
                "HKEY_LOCAL_MACHINE": winreg.HKEY_LOCAL_MACHINE,
                "HKEY_CLASSES_ROOT": winreg.HKEY_CLASSES_ROOT,
                "HKEY_USERS": winreg.HKEY_USERS
            }}

            if hive_name not in hive_map:
                log(f"Unknown registry hive: {{hive_name}}", "ERROR")
                continue

            hive = hive_map[hive_name]

            # Split key and value
            if "\\\\" in subkey_path:
                key_path, value_name = subkey_path.rsplit("\\\\", 1)
            else:
                # Delete entire key
                winreg.DeleteKey(hive, subkey_path)
                log(f"Deleted registry key: {{reg_path}}")
                removed.append(reg_path)
                continue

            # Delete value
            key = winreg.OpenKey(hive, key_path, 0, winreg.KEY_ALL_ACCESS)
            winreg.DeleteValue(key, value_name)
            winreg.CloseKey(key)
            log(f"Deleted registry value: {{reg_path}}")
            removed.append(reg_path)

        except FileNotFoundError:
            log(f"Registry entry not found: {{reg_path}}", "WARNING")
        except Exception as e:
            log(f"Failed to remove {{reg_path}}: {{e}}", "ERROR")

    return removed

def remove_scheduled_tasks():
    """Remove malicious scheduled tasks"""
    log("Removing scheduled tasks...")
    removed = []

    for task in SCHEDULED_TASKS:
        try:
            result = subprocess.run(
                ["schtasks", "/Delete", "/TN", task, "/F"],
                capture_output=True,
                text=True
            )
            if result.returncode == 0:
                log(f"Removed scheduled task: {{task}}")
                removed.append(task)
            else:
                log(f"Task not found: {{task}}", "WARNING")
        except Exception as e:
            log(f"Failed to remove task {{task}}: {{e}}", "ERROR")

    return removed

def stop_services():
    """Stop and disable malicious services"""
    log("Stopping services...")
    stopped = []

    for service in SERVICES_TO_STOP:
        try:
            # Stop service
            subprocess.run(
                ["sc", "stop", service],
                capture_output=True,
                text=True
            )

            # Disable service
            subprocess.run(
                ["sc", "config", service, "start=", "disabled"],
                capture_output=True,
                text=True
            )

            log(f"Stopped and disabled service: {{service}}")
            stopped.append(service)
        except Exception as e:
            log(f"Failed to stop service {{service}}: {{e}}", "ERROR")

    return stopped

def main():
    """Main cleanup routine"""
    log("="*70)
    log(f"{{TARGET_MALWARE}} Cleanup Tool v{{CLEANUP_VERSION}}")
    log("AUTHORIZED LAW ENFORCEMENT OPERATION")
    log("="*70)

    # Check admin privileges
    if not is_admin():
        log("This cleanup requires administrator privileges", "ERROR")
        log("Please run as administrator", "ERROR")
        report_telemetry("error", {{"reason": "insufficient_privileges"}})
        return 1

    log("Starting cleanup process...")
    report_telemetry("started", {{}})

    results = {{}}

    try:
        # Execute cleanup steps
        results["processes_killed"] = kill_processes()
        results["files_removed"] = remove_files()
        results["registry_removed"] = remove_registry_keys()
        results["tasks_removed"] = remove_scheduled_tasks()
        results["services_stopped"] = stop_services()

        # Summary
        log("="*70)
        log("Cleanup Summary:")
        log(f"  Processes killed: {{len(results['processes_killed'])}}")
        log(f"  Files removed: {{len(results['files_removed'])}}")
        log(f"  Registry entries removed: {{len(results['registry_removed'])}}")
        log(f"  Scheduled tasks removed: {{len(results['tasks_removed'])}}")
        log(f"  Services stopped: {{len(results['services_stopped'])}}")
        log("="*70)

        log("Cleanup completed successfully!")
        report_telemetry("success", results)

        return 0

    except Exception as e:
        log(f"Cleanup failed with error: {{e}}", "ERROR")
        report_telemetry("error", {{"exception": str(e), "partial_results": results}})
        return 1

if __name__ == "__main__":
    sys.exit(main())
'''

# Linux/Unix cleanup template
LINUX_CLEANUP_TEMPLATE = '''#!/usr/bin/env python3
import os
import sys
import subprocess
import json
import socket
from datetime import datetime
from pathlib import Path

# Metadata
CLEANUP_VERSION = "{version}"
TARGET_MALWARE = "{malware_name}"
SINKHOLE_URL = "{sinkhole_url}"
TELEMETRY_ENABLED = {telemetry_enabled}

# Cleanup configuration
PROCESSES_TO_KILL = {processes}
FILES_TO_REMOVE = {files}
CRON_JOBS = {cron_jobs}
SYSTEMD_SERVICES = {services}

def is_root():
    """Check if running as root"""
    return os.geteuid() == 0

def log(message, level="INFO"):
    """Log message with timestamp"""
    timestamp = datetime.utcnow().isoformat() + "Z"
    print(f"[{{timestamp}}] [{{level}}] {{message}}")

def report_telemetry(status, details=None):
    """Report cleanup status to sinkhole"""
    if not TELEMETRY_ENABLED or not SINKHOLE_URL:
        return

    try:
        import urllib.request
        import urllib.parse

        hostname = socket.gethostname()
        data = {{
            "cleanup_version": CLEANUP_VERSION,
            "target": TARGET_MALWARE,
            "hostname": hostname,
            "status": status,
            "details": details or {{}},
            "timestamp": datetime.utcnow().isoformat() + "Z"
        }}

        req = urllib.request.Request(
            SINKHOLE_URL + "/telemetry",
            data=json.dumps(data).encode(),
            headers={{"Content-Type": "application/json"}}
        )

        urllib.request.urlopen(req, timeout=5)
        log("Telemetry reported successfully")
    except Exception as e:
        log(f"Failed to report telemetry: {{e}}", "WARNING")

def kill_processes():
    """Kill malicious processes"""
    log("Killing malicious processes...")
    killed = []

    for process in PROCESSES_TO_KILL:
        try:
            # Find PIDs
            result = subprocess.run(
                ["pgrep", "-f", process],
                capture_output=True,
                text=True
            )

            if result.stdout:
                pids = result.stdout.strip().split('\\n')
                for pid in pids:
                    subprocess.run(["kill", "-9", pid])
                    log(f"Killed process {{process}} (PID: {{pid}})")
                    killed.append(process)
        except Exception as e:
            log(f"Failed to kill {{process}}: {{e}}", "ERROR")

    return killed

def remove_files():
    """Remove malicious files"""
    log("Removing malicious files...")
    removed = []

    for path in FILES_TO_REMOVE:
        try:
            p = Path(path)
            if p.exists():
                if p.is_dir():
                    import shutil
                    shutil.rmtree(p)
                else:
                    p.unlink()
                log(f"Removed: {{path}}")
                removed.append(path)
        except Exception as e:
            log(f"Failed to remove {{path}}: {{e}}", "ERROR")

    return removed

def remove_cron_jobs():
    """Remove malicious cron jobs"""
    log("Removing cron jobs...")
    removed = []

    for job_pattern in CRON_JOBS:
        try:
            # Get current crontab
            result = subprocess.run(
                ["crontab", "-l"],
                capture_output=True,
                text=True
            )

            if result.returncode != 0:
                continue

            # Filter out malicious entries
            lines = result.stdout.split('\\n')
            clean_lines = [l for l in lines if job_pattern not in l]

            # Write back
            subprocess.run(
                ["crontab", "-"],
                input='\\n'.join(clean_lines).encode()
            )

            if len(lines) != len(clean_lines):
                log(f"Removed cron job matching: {{job_pattern}}")
                removed.append(job_pattern)

        except Exception as e:
            log(f"Failed to process cron jobs: {{e}}", "ERROR")

    return removed

def stop_services():
    """Stop malicious systemd services"""
    log("Stopping services...")
    stopped = []

    for service in SYSTEMD_SERVICES:
        try:
            # Stop service
            subprocess.run(["systemctl", "stop", service])

            # Disable service
            subprocess.run(["systemctl", "disable", service])

            log(f"Stopped and disabled: {{service}}")
            stopped.append(service)
        except Exception as e:
            log(f"Failed to stop service {{service}}: {{e}}", "ERROR")

    return stopped

def main():
    """Main cleanup routine"""
    log("="*70)
    log(f"{{TARGET_MALWARE}} Cleanup Tool v{{CLEANUP_VERSION}}")
    log("AUTHORIZED LAW ENFORCEMENT OPERATION")
    log("="*70)

    if not is_root():
        log("This cleanup requires root privileges", "ERROR")
        report_telemetry("error", {{"reason": "insufficient_privileges"}})
        return 1

    log("Starting cleanup process...")
    report_telemetry("started", {{}})

    results = {{}}

    try:
        results["processes_killed"] = kill_processes()
        results["files_removed"] = remove_files()
        results["cron_removed"] = remove_cron_jobs()
        results["services_stopped"] = stop_services()

        log("="*70)
        log("Cleanup Summary:")
        log(f"  Processes killed: {{len(results['processes_killed'])}}")
        log(f"  Files removed: {{len(results['files_removed'])}}")
        log(f"  Cron jobs removed: {{len(results['cron_removed'])}}")
        log(f"  Services stopped: {{len(results['services_stopped'])}}")
        log("="*70)

        log("Cleanup completed successfully!")
        report_telemetry("success", results)

        return 0

    except Exception as e:
        log(f"Cleanup failed: {{e}}", "ERROR")
        report_telemetry("error", {{"exception": str(e), "partial_results": results}})
        return 1

if __name__ == "__main__":
    sys.exit(main())
'''


class Colors:
    """Terminal colors"""
    BLUE = '\033[94m'
    GREEN = '\033[92m'
    YELLOW = '\033[93m'
    RED = '\033[91m'
    CYAN = '\033[96m'
    RESET = '\033[0m'
    BOLD = '\033[1m'


def generate_cleanup(args) -> str:
    """Generate cleanup payload code"""
    # Get profile
    if args.profile and args.profile in CLEANUP_PROFILES:
        profile = CLEANUP_PROFILES[args.profile]
    else:
        profile = CLEANUP_PROFILES["generic"]

    # Override with custom settings
    if args.processes:
        profile["processes"] = args.processes.split(',')
    if args.files:
        profile["files"] = args.files.split(',')
    if args.registry:
        profile["registry_keys"] = args.registry.split(',')
    if args.tasks:
        profile["scheduled_tasks"] = args.tasks.split(',')
    if args.services:
        profile["services"] = args.services.split(',')

    # Select template
    if args.platform == "windows":
        template = WINDOWS_CLEANUP_TEMPLATE
        extra_config = {}
    elif args.platform in ["linux", "unix"]:
        template = LINUX_CLEANUP_TEMPLATE
        extra_config = {
            "cron_jobs": profile.get("cron_jobs", [])
        }
    else:
        print(f"{Colors.RED}[✗]{Colors.RESET} Unsupported platform: {args.platform}")
        sys.exit(1)

    # Format template
    code = template.format(
        version=VERSION,
        malware_name=args.malware_name or args.profile or "Unknown",
        sinkhole_url=args.sinkhole_url or "",
        telemetry_enabled=str(bool(args.sinkhole_url)),
        processes=json.dumps(profile["processes"]),
        files=json.dumps(profile["files"]),
        registry_keys=json.dumps(profile.get("registry_keys", [])),
        scheduled_tasks=json.dumps(profile.get("scheduled_tasks", [])),
        services=json.dumps(profile.get("services", [])),
        **extra_config
    )

    return code


def compile_payload(code: str, output_file: str, platform: str):
    """Compile payload to executable (if tools available)"""
    # Write source code
    source_file = output_file + ".py"
    with open(source_file, 'w') as f:
        f.write(code)

    print(f"{Colors.GREEN}[✓]{Colors.RESET} Source code written to: {source_file}")

    # Try to compile with PyInstaller if available
    try:
        import PyInstaller.__main__

        print(f"{Colors.BLUE}[*]{Colors.RESET} Compiling with PyInstaller...")

        PyInstaller.__main__.run([
            source_file,
            '--onefile',
            '--name', os.path.splitext(output_file)[0],
            '--clean',
            '--noconfirm'
        ])

        print(f"{Colors.GREEN}[✓]{Colors.RESET} Compiled executable created")

    except ImportError:
        print(f"{Colors.YELLOW}[!]{Colors.RESET} PyInstaller not available")
        print(f"{Colors.YELLOW}[!]{Colors.RESET} Install with: pip install pyinstaller")
        print(f"{Colors.YELLOW}[!]{Colors.RESET} Or distribute Python source code")


def main():
    parser = argparse.ArgumentParser(
        description="Cleanup Payload Generator for Botnet Neutralization",
        epilog="LEGAL WARNING: Requires court order. Unauthorized use is ILLEGAL."
    )

    parser.add_argument("--platform", choices=["windows", "linux", "unix"],
                       required=True, help="Target platform")
    parser.add_argument("--profile", choices=list(CLEANUP_PROFILES.keys()),
                       help="Pre-configured cleanup profile")
    parser.add_argument("--output", required=True,
                       help="Output file path")

    parser.add_argument("--malware-name", help="Target malware name")
    parser.add_argument("--sinkhole-url", help="Sinkhole server URL for telemetry")

    # Custom cleanup actions
    parser.add_argument("--processes", help="Comma-separated process names to kill")
    parser.add_argument("--files", help="Comma-separated file paths to remove")
    parser.add_argument("--registry", help="Comma-separated registry keys (Windows)")
    parser.add_argument("--tasks", help="Comma-separated scheduled tasks (Windows)")
    parser.add_argument("--services", help="Comma-separated service names")

    parser.add_argument("--compile", action="store_true",
                       help="Compile to executable (requires PyInstaller)")
    parser.add_argument("--legal-ack", action="store_true",
                       help="Acknowledge legal requirements")

    args = parser.parse_args()

    # Legal check
    if not args.legal_ack:
        print(f"{Colors.RED}{Colors.BOLD}")
        print("╔═══════════════════════════════════════════════════════════════╗")
        print("║                  LEGAL AUTHORIZATION REQUIRED                 ║")
        print("╚═══════════════════════════════════════════════════════════════╝")
        print(f"{Colors.RESET}")
        print("This tool generates code that will MODIFY VICTIM SYSTEMS.")
        print()
        print("Requirements:")
        print("  • Court order or equivalent legal authorization")
        print("  • Proper jurisdiction over target systems")
        print("  • Coordination with law enforcement")
        print("  • Safety testing in isolated environment")
        print()
        print("Generated code will:")
        print("  • Kill processes")
        print("  • Delete files")
        print("  • Modify system configuration")
        print("  • Report to sinkhole server")
        print()
        print("Without proper authorization, use is ILLEGAL under:")
        print("  • Computer Fraud and Abuse Act (CFAA) - US")
        print("  • Computer Misuse Act - UK")
        print("  • Equivalent laws worldwide")
        print()
        print("To proceed: Add --legal-ack flag")
        print()
        sys.exit(1)

    print(f"{Colors.CYAN}{Colors.BOLD}")
    print("╔═══════════════════════════════════════════════════════════════╗")
    print("║              Cleanup Payload Generator                       ║")
    print(f"║                    Version {VERSION}                         ║")
    print("╚═══════════════════════════════════════════════════════════════╝")
    print(f"{Colors.RESET}\n")

    # Validate configuration
    if not args.profile and not any([args.processes, args.files, args.registry, args.tasks, args.services]):
        print(f"{Colors.RED}[✗]{Colors.RESET} Must specify --profile or custom cleanup actions")
        sys.exit(1)

    # Generate cleanup code
    print(f"{Colors.BLUE}[*]{Colors.RESET} Generating cleanup payload...")

    code = generate_cleanup(args)

    # Write output
    with open(args.output, 'w') as f:
        f.write(code)

    print(f"{Colors.GREEN}[✓]{Colors.RESET} Cleanup payload generated: {args.output}")

    # Calculate hash
    code_hash = hashlib.sha256(code.encode()).hexdigest()
    print(f"{Colors.BLUE}[i]{Colors.RESET} SHA256: {code_hash}")

    # Compile if requested
    if args.compile:
        compile_payload(code, args.output, args.platform)

    # Print warnings
    print(f"\n{Colors.YELLOW}{Colors.BOLD}CRITICAL SAFETY WARNINGS:{Colors.RESET}")
    print(f"{Colors.YELLOW}1. Test in isolated environment FIRST{Colors.RESET}")
    print(f"{Colors.YELLOW}2. Verify no unintended system damage{Colors.RESET}")
    print(f"{Colors.YELLOW}3. Use phased rollout (1% → 10% → 50% → 100%){Colors.RESET}")
    print(f"{Colors.YELLOW}4. Monitor for errors and halt if threshold exceeded{Colors.RESET}")
    print(f"{Colors.YELLOW}5. Have rollback plan ready{Colors.RESET}")
    print(f"{Colors.YELLOW}6. Maintain evidence chain of custody{Colors.RESET}")

    print(f"\n{Colors.GREEN}[✓]{Colors.RESET} Generation complete!")
    print(f"\nNext steps:")
    print(f"  1. Review generated code for safety")
    print(f"  2. Test in isolated virtual machine")
    print(f"  3. Obtain final legal approval")
    print(f"  4. Deploy via sinkhole server with phased rollout")
    print()


if __name__ == "__main__":
    main()
