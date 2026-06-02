#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VIVADO="${VIVADO:-/mnt/hw/tools/amd/2024.1/Vivado/2024.1/bin/vivado}"
PART="${1:-xc7a35tcsg324-1}"
MHZ="${2:-50}"
MODE="${3:-}"
PART_LC="${PART,,}"
OUT_DIR="$ROOT/fpga/vivado_timing/$PART_LC"
DCP="$OUT_DIR/riscv_core_routed.dcp"

echo "Using Vivado: $VIVADO"

# Fast: reuse routed DCP, only change clock constraint and report (seconds).
# Full synth/P&R at 200 MHz can take 30+ minutes and rarely helps vs this.
if [[ "$MODE" == "fast" || "$MODE" == "report" ]] || [[ "$MHZ" != "50" && "$MODE" != "full" ]]; then
  if [[ ! -f "$DCP" ]]; then
    echo "No checkpoint at $DCP — running full 50 MHz build first..."
    "$VIVADO" -mode batch -nojournal -nolog -source "$ROOT/fpga/timing_synth.tcl" -tclargs "$PART" 50
  fi
  echo "Fast timing report @ ${MHZ} MHz on $PART_LC (existing placement)"
  "$VIVADO" -mode batch -nojournal -nolog -source "$ROOT/fpga/report_timing_mhz.tcl" -tclargs "$MHZ" "$PART_LC"
  exit 0
fi

echo "Part: $PART"
echo "Target clock: ${MHZ} MHz (full synth + place + route)"
"$VIVADO" -mode batch -nojournal -nolog -source "$ROOT/fpga/timing_synth.tcl" -tclargs "$PART" "$MHZ"
