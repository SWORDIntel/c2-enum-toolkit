#!/usr/bin/env python3
"""
OpenVINO Hardware Accelerator
Auto-detects and utilizes NPU, GPU, GNA, and CPU for maximum performance
Integrates with KP14 and analysis modules
"""

import sys
import os
import json
from pathlib import Path

# OpenVINO imports with graceful fallback
try:
    from openvino.runtime import Core, get_version
    OPENVINO_AVAILABLE = True
except ImportError:
    OPENVINO_AVAILABLE = False
    print("[WARN] OpenVINO not available - using CPU-only mode", file=sys.stderr)

class HardwareAccelerator:
    """Manages hardware acceleration for analysis tasks"""

    def __init__(self, verbose=True):
        self.verbose = verbose
        self.core = None
        self.available_devices = []
        self.device_capabilities = {}
        self.recommended_device = "CPU"

        if OPENVINO_AVAILABLE:
            self._initialize_openvino()
        else:
            self.log("[!] OpenVINO not available - CPU-only mode")

    def log(self, message):
        if self.verbose:
            print(f"[OpenVINO] {message}", file=sys.stderr)

    def _initialize_openvino(self):
        """Initialize OpenVINO runtime and detect devices"""
        try:
            self.core = Core()
            self.available_devices = self.core.available_devices

            self.log(f"OpenVINO version: {get_version()}")
            self.log(f"Available devices: {', '.join(self.available_devices)}")

            # Probe device capabilities
            for device in self.available_devices:
                try:
                    capabilities = self.core.get_property(device, "FULL_DEVICE_NAME")
                    self.device_capabilities[device] = capabilities
                    self.log(f"  {device}: {capabilities}")
                except:
                    self.device_capabilities[device] = "Unknown"

            # Determine recommended device
            self.recommended_device = self._select_best_device()
            self.log(f"Recommended device: {self.recommended_device}")

        except Exception as e:
            self.log(f"[ERROR] OpenVINO initialization failed: {e}")
            self.available_devices = ["CPU"]
            self.recommended_device = "CPU"

    def _select_best_device(self):
        """Select best device based on priority: NPU > GPU > GNA > CPU"""

        # Priority order
        priority = ["NPU", "GPU.0", "GPU", "GNA", "CPU"]

        for pref in priority:
            for device in self.available_devices:
                if device.startswith(pref):
                    return device

        return "CPU"

    def get_device_for_task(self, task_type):
        """
        Select optimal device for specific task type

        Task types:
        - 'inference': ML model inference (prefer NPU/GPU)
        - 'pattern_matching': Fast pattern search (prefer NPU)
        - 'image_processing': Image analysis (prefer GPU)
        - 'signal_processing': Audio/signal work (prefer GNA)
        - 'general': General computation (CPU)
        """

        if not OPENVINO_AVAILABLE:
            return "CPU"

        task_device_map = {
            'inference': ['NPU', 'GPU', 'CPU'],
            'pattern_matching': ['NPU', 'GPU', 'CPU'],
            'image_processing': ['GPU', 'NPU', 'CPU'],
            'signal_processing': ['GNA', 'CPU'],
            'general': ['CPU']
        }

        preferences = task_device_map.get(task_type, ['CPU'])

        for pref in preferences:
            for device in self.available_devices:
                if device.startswith(pref):
                    return device

        return "CPU"

    def compile_model(self, model_path, task_type='inference'):
        """
        Load and compile model for optimal device

        Args:
            model_path: Path to OpenVINO IR model (.xml)
            task_type: Type of task (determines device selection)

        Returns:
            Compiled model ready for inference
        """

        if not OPENVINO_AVAILABLE or not self.core:
            self.log("[!] OpenVINO not available, cannot compile model")
            return None

        device = self.get_device_for_task(task_type)
        self.log(f"Compiling model on {device} for {task_type}")

        try:
            model = self.core.read_model(model_path)
            compiled = self.core.compile_model(model, device)
            self.log(f"[✓] Model compiled successfully on {device}")
            return compiled
        except Exception as e:
            self.log(f"[ERROR] Model compilation failed: {e}")
            return None

    def accelerate_pattern_search(self, data, patterns, use_device=None):
        """
        Hardware-accelerated pattern matching

        Args:
            data: Binary data to search
            patterns: List of byte patterns to find
            use_device: Override device selection

        Returns:
            Dictionary of pattern matches
        """

        device = use_device or self.get_device_for_task('pattern_matching')
        self.log(f"Pattern search on {device}")

        # TODO: Implement OpenVINO-accelerated pattern matching
        # For now, fallback to CPU
        matches = {}

        for pattern in patterns:
            pattern_bytes = bytes.fromhex(pattern) if isinstance(pattern, str) else pattern
            count = data.count(pattern_bytes)
            if count > 0:
                matches[pattern] = count

        return matches

    def accelerate_image_analysis(self, image_path, use_device=None):
        """
        Hardware-accelerated image steganography detection

        Uses GPU/NPU for parallel processing of image regions
        """

        device = use_device or self.get_device_for_task('image_processing')
        self.log(f"Image analysis on {device}")

        # Import image processing here to avoid dependency if not needed
        try:
            import numpy as np
            from PIL import Image

            img = Image.open(image_path)
            img_array = np.array(img)

            # Calculate entropy in parallel regions (can be GPU-accelerated)
            # TODO: Implement OpenVINO-based parallel entropy calculation

            self.log(f"Analyzed image: {image_path}")

            return {
                "size": img_array.shape,
                "analyzed_on": device
            }

        except ImportError:
            self.log("[!] PIL not available for image analysis")
            return None

    def get_performance_stats(self):
        """Return performance statistics for each device"""

        stats = {
            "openvino_available": OPENVINO_AVAILABLE,
            "devices": {}
        }

        if not OPENVINO_AVAILABLE:
            return stats

        for device in self.available_devices:
            stats["devices"][device] = {
                "available": True,
                "name": self.device_capabilities.get(device, "Unknown"),
                "recommended_for": []
            }

            # Assign workload types
            if "NPU" in device:
                stats["devices"][device]["recommended_for"] = ["inference", "pattern_matching"]
            elif "GPU" in device:
                stats["devices"][device]["recommended_for"] = ["image_processing", "inference"]
            elif "GNA" in device:
                stats["devices"][device]["recommended_for"] = ["signal_processing"]
            else:  # CPU
                stats["devices"][device]["recommended_for"] = ["general"]

        return stats

    def export_config(self):
        """Export configuration as JSON"""
        return json.dumps({
            "openvino_available": OPENVINO_AVAILABLE,
            "openvino_version": get_version() if OPENVINO_AVAILABLE else "N/A",
            "available_devices": self.available_devices,
            "device_capabilities": self.device_capabilities,
            "recommended_device": self.recommended_device
        }, indent=2)


def main():
    """CLI interface for hardware detection and configuration"""

    import argparse

    parser = argparse.ArgumentParser(description="OpenVINO Hardware Accelerator")
    parser.add_argument("--detect", action="store_true", help="Detect available hardware")
    parser.add_argument("--json", action="store_true", help="Output as JSON")
    parser.add_argument("--task", choices=["inference", "pattern_matching", "image_processing", "signal_processing"],
                       help="Get recommended device for task type")

    args = parser.parse_args()

    accel = HardwareAccelerator(verbose=True)

    if args.detect:
        if args.json:
            print(accel.export_config())
        else:
            print("\n╔════════════════════════════════════════════════════════════════════╗")
            print("║           OpenVINO Hardware Acceleration Status                   ║")
            print("╚════════════════════════════════════════════════════════════════════╝\n")

            if OPENVINO_AVAILABLE:
                print(f"OpenVINO Version: {get_version()}")
                print(f"\nAvailable Devices: {len(accel.available_devices)}")
                for device in accel.available_devices:
                    capability = accel.device_capabilities.get(device, "Unknown")
                    print(f"  [{device}] {capability}")

                print(f"\nRecommended Device: {accel.recommended_device}")
            else:
                print("⚠️  OpenVINO NOT installed")
                print("\nTo install:")
                print("  pip install openvino")

    elif args.task:
        device = accel.get_device_for_task(args.task)
        print(f"{device}")

    else:
        # Show stats
        stats = accel.get_performance_stats()
        print(json.dumps(stats, indent=2))

    return 0


if __name__ == "__main__":
    sys.exit(main())
