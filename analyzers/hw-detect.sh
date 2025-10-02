#!/usr/bin/env bash
# Hardware Detection for OpenVINO Acceleration
# Detects NPU, GPU (Intel Arc), GNA, and CPU capabilities
set -euo pipefail

OUTPUT_FORMAT="${1:-text}"  # text, json, or export

# ========== Detection Functions ==========

detect_cpu() {
    local cpu_model=""
    local cpu_count=0
    local arch=""

    if [[ -f /proc/cpuinfo ]]; then
        cpu_model=$(grep "model name" /proc/cpuinfo | head -1 | cut -d: -f2 | xargs)
        cpu_count=$(grep -c "^processor" /proc/cpuinfo)
        arch=$(uname -m)
    fi

    echo "CPU:$cpu_model:$cpu_count:$arch"
}

detect_igpu() {
    local gpu_model=""
    local gpu_device=""

    # Check for Intel integrated GPU
    if command -v lspci >/dev/null 2>&1; then
        gpu_model=$(lspci | grep -i "VGA.*Intel" | sed 's/.*: //')

        # Check for DRI device
        if [[ -e /dev/dri/renderD128 ]]; then
            gpu_device="/dev/dri/renderD128"
        elif [[ -e /dev/dri/card0 ]]; then
            gpu_device="/dev/dri/card0"
        fi
    fi

    if [[ -n "$gpu_model" ]]; then
        echo "GPU:$gpu_model:$gpu_device:available"
    else
        echo "GPU:::not_found"
    fi
}

detect_npu() {
    local npu_status="not_found"
    local npu_device=""

    # Intel NPU detection (Meteor Lake and newer)
    # Check for NPU in lspci
    if command -v lspci >/dev/null 2>&1; then
        if lspci | grep -qi "neural\|NPU\|AI Boost"; then
            npu_status="available"
            npu_device=$(lspci | grep -i "neural\|NPU" | head -1)
        fi
    fi

    # Check for Intel VPU device files (used by NPU)
    if [[ -e /dev/accel/accel0 ]]; then
        npu_status="available"
        npu_device="/dev/accel/accel0"
    fi

    # Check CPU model for NPU support
    local cpu_model=$(grep "model name" /proc/cpuinfo | head -1 | cut -d: -f2)
    if echo "$cpu_model" | grep -qi "Ultra.*1[0-9][0-9]H\|Core.*AI"; then
        npu_status="likely_available"
    fi

    echo "NPU:$npu_device:$npu_status"
}

detect_gna() {
    local gna_status="not_found"

    # Gaussian & Neural Accelerator (older Intel chips)
    # Check for GNA device
    if [[ -e /dev/gna0 ]]; then
        gna_status="available"
    fi

    # Tiger Lake and newer may have GNA
    local cpu_model=$(grep "model name" /proc/cpuinfo | head -1 | cut -d: -f2)
    if echo "$cpu_model" | grep -qi "11th Gen\|12th Gen\|13th Gen"; then
        gna_status="possibly_available"
    fi

    echo "GNA::$gna_status"
}

detect_openvino() {
    local ov_status="not_installed"
    local ov_version=""
    local ov_devices=""

    # Check if OpenVINO Python package is installed
    if python3 -c "from openvino.runtime import Core; print(Core().get_versions())" 2>/dev/null; then
        ov_status="installed"
        ov_version=$(python3 -c "from openvino.runtime import Core; import openvino; print(openvino.__version__)" 2>/dev/null || echo "unknown")

        # Get available devices
        ov_devices=$(python3 -c "
from openvino.runtime import Core
core = Core()
devices = core.available_devices
print(','.join(devices))
" 2>/dev/null || echo "")
    fi

    echo "OPENVINO:$ov_version:$ov_status:$ov_devices"
}

# ========== Main Detection ==========

detect_all() {
    local cpu_info=$(detect_cpu)
    local gpu_info=$(detect_igpu)
    local npu_info=$(detect_npu)
    local gna_info=$(detect_gna)
    local ov_info=$(detect_openvino)

    case "$OUTPUT_FORMAT" in
        json)
            # Parse detection strings
            IFS=':' read -r _ cpu_model cpu_count cpu_arch <<< "$cpu_info"
            IFS=':' read -r _ gpu_model gpu_device gpu_status <<< "$gpu_info"
            IFS=':' read -r _ npu_device npu_status <<< "$npu_info"
            IFS=':' read -r _ _ gna_status <<< "$gna_info"
            IFS=':' read -r _ ov_version ov_status ov_devices <<< "$ov_info"

            cat <<EOF
{
  "cpu": {
    "model": "$cpu_model",
    "cores": $cpu_count,
    "architecture": "$cpu_arch",
    "available": true
  },
  "gpu": {
    "model": "$gpu_model",
    "device": "$gpu_device",
    "available": $([ "$gpu_status" = "available" ] && echo "true" || echo "false")
  },
  "npu": {
    "device": "$npu_device",
    "status": "$npu_status",
    "available": $([ "$npu_status" = "available" ] && echo "true" || echo "false")
  },
  "gna": {
    "status": "$gna_status",
    "available": $([ "$gna_status" = "available" ] && echo "true" || echo "false")
  },
  "openvino": {
    "version": "$ov_version",
    "installed": $([ "$ov_status" = "installed" ] && echo "true" || echo "false"),
    "devices": "$ov_devices"
  },
  "recommended_device": "$(get_recommended_device)"
}
EOF
            ;;

        export)
            # Export as environment variables
            IFS=':' read -r _ cpu_model cpu_count cpu_arch <<< "$cpu_info"
            IFS=':' read -r _ gpu_model gpu_device gpu_status <<< "$gpu_info"
            IFS=':' read -r _ npu_device npu_status <<< "$npu_info"
            IFS=':' read -r _ ov_version ov_status ov_devices <<< "$ov_info"

            cat <<EOF
export HW_CPU_CORES=$cpu_count
export HW_CPU_MODEL="$cpu_model"
export HW_GPU_AVAILABLE=$([ "$gpu_status" = "available" ] && echo "1" || echo "0")
export HW_GPU_DEVICE="$gpu_device"
export HW_NPU_AVAILABLE=$([ "$npu_status" = "available" ] && echo "1" || echo "0")
export HW_OPENVINO_AVAILABLE=$([ "$ov_status" = "installed" ] && echo "1" || echo "0")
export HW_OPENVINO_DEVICES="$ov_devices"
export HW_RECOMMENDED_DEVICE="$(get_recommended_device)"
EOF
            ;;

        text|*)
            cat <<EOF
╔════════════════════════════════════════════════════════════════════╗
║               Hardware Acceleration Detection                      ║
╚════════════════════════════════════════════════════════════════════╝

$cpu_info
$gpu_info
$npu_info
$gna_info
$ov_info

Recommended Device: $(get_recommended_device)
Device Priority: NPU > GPU > GNA > CPU

EOF
            ;;
    esac
}

get_recommended_device() {
    local npu_info=$(detect_npu)
    local gpu_info=$(detect_igpu)
    local ov_info=$(detect_openvino)

    IFS=':' read -r _ _ npu_status <<< "$npu_info"
    IFS=':' read -r _ _ _ gpu_status <<< "$gpu_info"
    IFS=':' read -r _ _ ov_status ov_devices <<< "$ov_info"

    # Priority: NPU > GPU > CPU
    if [[ "$npu_status" == "available" ]] && [[ "$ov_status" == "installed" ]] && [[ "$ov_devices" == *"NPU"* ]]; then
        echo "NPU"
    elif [[ "$gpu_status" == "available" ]] && [[ "$ov_status" == "installed" ]]; then
        echo "GPU"
    else
        echo "CPU"
    fi
}

# ========== Main ==========
detect_all
