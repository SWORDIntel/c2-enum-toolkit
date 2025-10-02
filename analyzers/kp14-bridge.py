#!/usr/bin/env python3
"""
KP14 Bridge Module
Integrates KP14 steganography and decryption capabilities for C2 endpoint discovery
"""

import sys
import os
import json
import re
from pathlib import Path

# Add KP14 to path
KP14_PATH = Path(__file__).parent.parent / "kp14"
sys.path.insert(0, str(KP14_PATH))
sys.path.insert(0, str(KP14_PATH / "stego-analyzer"))

try:
    from stego_analyzer.analysis.keyplug_extractor import (
        extract_jpeg_payload,
        perform_xor_decryption,
        calculate_entropy,
        KNOWN_XOR_KEYS
    )
except ImportError as e:
    print(f"Warning: Could not import KP14 modules: {e}", file=sys.stderr)
    print("Falling back to basic extraction", file=sys.stderr)
    KNOWN_XOR_KEYS = ["9e", "d3", "a5", "0a61200d"]

class C2EndpointDiscovery:
    """Main class for discovering C2 endpoints from encrypted/encoded data"""

    def __init__(self, verbose=True):
        self.verbose = verbose
        self.discovered_endpoints = []
        self.confidence_scores = {}

    def log(self, message):
        """Log message if verbose"""
        if self.verbose:
            print(f"[KP14] {message}", file=sys.stderr)

    def extract_network_indicators(self, data):
        """Extract URLs, IPs, and .onion addresses from binary data"""
        indicators = {
            "onion_addresses": [],
            "urls": [],
            "ip_addresses": [],
            "domain_names": []
        }

        try:
            # Convert bytes to string (ignore errors for binary data)
            text = data.decode('utf-8', errors='ignore')
        except:
            text = str(data)

        # .onion addresses (v2: 16 chars, v3: 56 chars)
        onion_pattern = r'\b[a-z2-7]{16,56}\.onion(?::[0-9]{1,5})?\b'
        indicators["onion_addresses"] = list(set(re.findall(onion_pattern, text, re.IGNORECASE)))

        # URLs
        url_pattern = r'https?://[^\s<>"\']+|wss?://[^\s<>"\']+'
        indicators["urls"] = list(set(re.findall(url_pattern, text, re.IGNORECASE)))

        # IP addresses
        ip_pattern = r'\b(?:[0-9]{1,3}\.){3}[0-9]{1,3}\b'
        indicators["ip_addresses"] = list(set(re.findall(ip_pattern, text)))

        # Domain names (basic)
        domain_pattern = r'\b[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?(?:\.[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?)+\b'
        potential_domains = re.findall(domain_pattern, text, re.IGNORECASE)
        # Filter out common false positives
        indicators["domain_names"] = [d for d in set(potential_domains)
                                      if not d.endswith(('.jpg', '.png', '.css', '.js', '.dll', '.exe'))]

        return indicators

    def analyze_image_steganography(self, image_path):
        """Analyze image for hidden C2 endpoints using KP14 steganography extraction"""
        self.log(f"Analyzing image for steganography: {image_path}")

        try:
            with open(image_path, 'rb') as f:
                image_data = f.read()

            # Check if it's a JPEG
            if not image_data.startswith(b'\xFF\xD8'):
                self.log(f"  Not a JPEG file, skipping: {image_path}")
                return []

            # Use KP14's extraction method
            if 'extract_jpeg_payload' in globals():
                payload = extract_jpeg_payload(image_data)
            else:
                # Fallback: extract data after EOI marker
                eoi_pos = image_data.rfind(b'\xFF\xD9')
                if eoi_pos != -1:
                    payload = image_data[eoi_pos + 2:]
                else:
                    payload = None

            if not payload or len(payload) < 10:
                self.log(f"  No payload found in: {image_path}")
                return []

            # Calculate entropy
            if 'calculate_entropy' in globals():
                entropy = calculate_entropy(payload)
            else:
                # Fallback entropy
                from collections import Counter
                import math
                counter = Counter(payload)
                entropy = -sum((c/len(payload)) * math.log2(c/len(payload))
                               for c in counter.values())

            self.log(f"  Payload found: {len(payload)} bytes, entropy: {entropy:.2f}")

            # Try XOR decryption with known keys
            decrypted_payloads = []

            for key_hex in KNOWN_XOR_KEYS:
                try:
                    if 'perform_xor_decryption' in globals():
                        decrypted = perform_xor_decryption(payload, key_hex)
                    else:
                        # Fallback XOR
                        key_bytes = bytes.fromhex(key_hex)
                        decrypted = bytes(b ^ key_bytes[i % len(key_bytes)]
                                        for i, b in enumerate(payload))

                    # Extract network indicators from decrypted data
                    indicators = self.extract_network_indicators(decrypted)

                    if any(indicators.values()):
                        self.log(f"  [✓] Key {key_hex} found indicators!")
                        decrypted_payloads.append({
                            "key": key_hex,
                            "indicators": indicators,
                            "entropy": entropy
                        })

                except Exception as e:
                    continue

            # Also try without decryption (plaintext hidden data)
            indicators = self.extract_network_indicators(payload)
            if any(indicators.values()):
                self.log(f"  [✓] Plaintext indicators found!")
                decrypted_payloads.append({
                    "key": "none",
                    "indicators": indicators,
                    "entropy": entropy
                })

            return decrypted_payloads

        except Exception as e:
            self.log(f"  Error analyzing {image_path}: {e}")
            return []

    def analyze_binary_config(self, binary_path):
        """Extract C2 configuration from binary using KP14 decryption"""
        self.log(f"Extracting C2 config from binary: {binary_path}")

        try:
            with open(binary_path, 'rb') as f:
                binary_data = f.read()

            # Extract network indicators from raw binary first
            raw_indicators = self.extract_network_indicators(binary_data)

            # Try XOR decryption on entire binary
            decrypted_configs = []

            for key_hex in KNOWN_XOR_KEYS:
                try:
                    if 'perform_xor_decryption' in globals():
                        decrypted = perform_xor_decryption(binary_data, key_hex)
                    else:
                        key_bytes = bytes.fromhex(key_hex)
                        decrypted = bytes(b ^ key_bytes[i % len(key_bytes)]
                                        for i, b in enumerate(binary_data))

                    indicators = self.extract_network_indicators(decrypted)

                    if any(indicators.values()):
                        decrypted_configs.append({
                            "key": key_hex,
                            "indicators": indicators
                        })

                except Exception:
                    continue

            # Combine raw and decrypted findings
            all_results = [{
                "key": "raw",
                "indicators": raw_indicators
            }] + decrypted_configs

            return all_results

        except Exception as e:
            self.log(f"  Error analyzing {binary_path}: {e}")
            return []

    def discover_endpoints(self, file_path, file_type="auto"):
        """Main entry point for endpoint discovery"""

        if file_type == "auto":
            # Detect file type
            with open(file_path, 'rb') as f:
                magic = f.read(4)

            if magic.startswith(b'\xFF\xD8'):
                file_type = "jpeg"
            elif magic.startswith(b'MZ') or magic.startswith(b'\x7fELF'):
                file_type = "binary"
            else:
                file_type = "unknown"

        results = []

        if file_type == "jpeg":
            results = self.analyze_image_steganography(file_path)
        elif file_type == "binary":
            results = self.analyze_binary_config(file_path)
        else:
            self.log(f"Unknown file type for: {file_path}")

        # Aggregate all discovered endpoints
        all_endpoints = []
        for result in results:
            indicators = result.get("indicators", {})
            for onion in indicators.get("onion_addresses", []):
                endpoint = {
                    "type": "onion",
                    "value": onion,
                    "source_file": str(file_path),
                    "decryption_key": result.get("key", "none"),
                    "confidence": self.calculate_confidence(result)
                }
                all_endpoints.append(endpoint)
                self.discovered_endpoints.append(endpoint)

            for url in indicators.get("urls", []):
                if ".onion" in url:
                    endpoint = {
                        "type": "url",
                        "value": url,
                        "source_file": str(file_path),
                        "decryption_key": result.get("key", "none"),
                        "confidence": self.calculate_confidence(result)
                    }
                    all_endpoints.append(endpoint)
                    self.discovered_endpoints.append(endpoint)

        return all_endpoints

    def calculate_confidence(self, result):
        """Calculate confidence score for discovered endpoint"""
        score = 50  # Base score

        # Higher entropy = more likely encrypted (good sign)
        entropy = result.get("entropy", 0)
        if entropy > 7.5:
            score += 30
        elif entropy > 6.5:
            score += 20

        # Decryption key found
        if result.get("key") not in ["none", "raw"]:
            score += 20

        # Multiple indicators
        indicators = result.get("indicators", {})
        indicator_count = sum(len(v) for v in indicators.values())
        score += min(indicator_count * 5, 30)

        return min(score, 100)

    def export_json(self):
        """Export discovered endpoints as JSON"""
        return json.dumps({
            "discovered_endpoints": self.discovered_endpoints,
            "total_discovered": len(self.discovered_endpoints),
            "unique_onions": len(set(e["value"] for e in self.discovered_endpoints))
        }, indent=2)


def main():
    """CLI interface"""
    import argparse

    parser = argparse.ArgumentParser(description="KP14 C2 Endpoint Auto-Discovery")
    parser.add_argument("input_file", help="File to analyze (JPEG or binary)")
    parser.add_argument("-t", "--type", choices=["auto", "jpeg", "binary"],
                       default="auto", help="File type (default: auto-detect)")
    parser.add_argument("-o", "--output", help="Output JSON file (default: stdout)")
    parser.add_argument("-v", "--verbose", action="store_true", help="Verbose output")

    args = parser.parse_args()

    discovery = C2EndpointDiscovery(verbose=args.verbose)
    endpoints = discovery.discover_endpoints(args.input_file, args.type)

    if endpoints:
        print(f"\n[✓] Discovered {len(endpoints)} potential C2 endpoint(s):\n", file=sys.stderr)
        for ep in endpoints:
            conf = ep["confidence"]
            print(f"  [{conf:3d}%] {ep['value']}", file=sys.stderr)
            print(f"         Key: {ep['decryption_key']}, Source: {Path(ep['source_file']).name}",
                  file=sys.stderr)
    else:
        print("[!] No C2 endpoints discovered", file=sys.stderr)

    # Output JSON
    output_data = discovery.export_json()

    if args.output:
        with open(args.output, 'w') as f:
            f.write(output_data)
        print(f"\n[✓] Results saved to: {args.output}", file=sys.stderr)
    else:
        print("\n" + output_data)

    return 0 if endpoints else 1


if __name__ == "__main__":
    sys.exit(main())
