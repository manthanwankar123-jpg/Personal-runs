#!/usr/bin/env bash
# Run Vivado timing synthesis for riscv_core
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VIVADO="${VIVADO:-/mnt/hw/tools/amd/2024.1/Vivado/2024.1/bin/vivado}"
PART="${1:-xc7a35tcsg324-1}"

echo "Using Vivado: $VIVADO"
echo "Part: $PART"
"$VIVADO" -mode batch -nojournal -nolog -source "$ROOT/fpga/timing_synth.tcl" -tclargs "$PART"
