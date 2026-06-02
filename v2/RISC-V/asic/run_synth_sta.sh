#!/usr/bin/env bash
# run_synth_sta.sh — Yosys + OpenSTA timing (ICsprout55 or ASAP7)
#
# Usage:
#   ./run_synth_sta.sh [pdk] [mhz] [mode]
#
#   pdk:  icsprout55 (default) | asap7
#   mode: all | synth | sta
#
# Examples:
#   ./run_synth_sta.sh                    # icsprout55, 200 MHz, all
#   ./run_synth_sta.sh asap7 50 all       # ASAP7 synth + STA sweep
#   ./run_synth_sta.sh icsprout55 100 sta
#
# Setup (once):
#   cd asic/icsprout55-pdk && make unzip
#   cd asic/asap7 && make unzip

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ASIC="$ROOT/asic"

PDK="icsprout55"
TARGET_MHZ="200"
MODE="all"

if [[ "${1:-}" == "icsprout55" || "${1:-}" == "asap7" ]]; then
  PDK="$1"
  shift
fi
if [[ $# -ge 1 ]]; then TARGET_MHZ="$1"; fi
if [[ $# -ge 2 ]]; then MODE="$2"; fi

OUT="$ASIC/out/$PDK"
mkdir -p "$OUT"

YOSYS="${YOSYS:-/home/manthan/yosys/yosys}"
STA="${STA:-sta}"
SV2V="${SV2V:-sv2v}"

case "$PDK" in
  icsprout55)
    PDK_DIR="$ASIC/icsprout55-pdk"
    LIB="$PDK_DIR/IP/STD_cell/ics55_LLSC_H7C_V1p10C100/ics55_LLSC_H7CR/liberty/ics55_LLSC_H7CR_typ_tt_1p2_25_nldm.lib"
    DFF_LIB="$LIB"
    ABC_LIBS=("$LIB")
    PDK_LABEL="ICsprout55 55 nm H7CR typ"
    SETUP_HINT="cd asic/icsprout55-pdk && make unzip"
    STA_SDC="$ASIC/constraints.sdc"
    STA_TIME_UNIT="ns"
    STA_PERIOD_SCALE=1
    ;;
  asap7)
    PDK_DIR="$ASIC/asap7"
    LIBDIR="$PDK_DIR/lib/NLDM"
    DFF_LIB="$LIBDIR/asap7sc7p5t_SEQ_RVT_TT_nldm_220123.lib"
    ABC_LIBS=(
      "$LIBDIR/asap7sc7p5t_AO_RVT_TT_nldm_211120.lib"
      "$LIBDIR/asap7sc7p5t_INVBUF_RVT_TT_nldm_220122.lib"
      "$LIBDIR/asap7sc7p5t_OA_RVT_TT_nldm_211120.lib"
      "$LIBDIR/asap7sc7p5t_SIMPLE_RVT_TT_nldm_211120.lib"
      "$LIBDIR/asap7sc7p5t_SEQ_RVT_TT_nldm_220123.lib"
    )
    LIB="${ABC_LIBS[0]}"
    PDK_LABEL="ASAP7 7 nm sc7p5t RVT TT"
    SETUP_HINT="cd asic/asap7 && make unzip"
    STA_SDC="$ASIC/constraints_asap7.sdc"
    STA_TIME_UNIT="ps"
    STA_PERIOD_SCALE=1000
    ;;
  *)
    echo "ERROR: Unknown PDK '$PDK' (icsprout55 | asap7)"
    exit 1
    ;;
esac

for f in "$DFF_LIB" "${ABC_LIBS[@]}"; do
  if [[ ! -f "$f" ]]; then
    echo "ERROR: Liberty not found: $f"
    echo "Run:  $SETUP_HINT"
    exit 1
  fi
done

abc_lib_args() {
  local args=""
  for f in "${ABC_LIBS[@]}"; do
    args+=" -liberty $f"
  done
  echo "$args"
}

gen_yosys_script() {
  local abc_args
  abc_args="$(abc_lib_args)"
  cat > "$OUT/synth.ys" <<EOF
read_verilog $OUT/riscv_core_flat.v
hierarchy -check -top riscv_core_asic_top
proc; opt; fsm; opt; memory; opt
synth -top riscv_core_asic_top
dfflibmap -liberty $DFF_LIB
abc$abc_args
clean
write_verilog -noattr -noexpr -nohex $OUT/riscv_core_mapped.v
stat
EOF
}

run_sv2v() {
  echo "=== sv2v (SystemVerilog → Verilog) ==="
  "$SV2V" -I"$ROOT/rtl" \
    "$ROOT/rtl/riscv_pkg.sv" \
    "$ROOT/rtl/alu.sv" \
    "$ROOT/rtl/regfile.sv" \
    "$ROOT/rtl/imm_gen.sv" \
    "$ROOT/rtl/control.sv" \
    "$ROOT/rtl/csr_file.sv" \
    "$ASIC/mem_stub.sv" \
    "$ROOT/rtl/riscv_core.sv" \
    "$ASIC/riscv_core_asic_top.sv" \
    > "$OUT/riscv_core_flat.v"
  echo "Wrote $OUT/riscv_core_flat.v"
}

run_synth() {
  echo "=== Yosys synthesis ($PDK_LABEL) ==="
  run_sv2v
  gen_yosys_script
  "$YOSYS" -s "$OUT/synth.ys" 2>&1 | tail -20
  echo "Wrote $OUT/riscv_core_mapped.v"
}

run_sta() {
  local mhz="$1"
  local period period_ns
  period_ns="$(python3 -c "print(1000.0 / float('$mhz'))")"
  period="$(python3 -c "print($period_ns * $STA_PERIOD_SCALE)")"
  echo "=== OpenSTA @ ${mhz} MHz (${period} ${STA_TIME_UNIT}) [$PDK] ==="

  export STA_NETLIST="$OUT/riscv_core_mapped.v"
  export STA_LIBERTY="$DFF_LIB"
  export STA_LIB_FILES="${ABC_LIBS[*]}"
  export STA_SDC="$STA_SDC"
  export STA_PERIOD="$period"
  export STA_TIME_UNIT="$STA_TIME_UNIT"

  "$STA" -no_splash -exit "$ASIC/sta_run.tcl" > "$OUT/sta_${mhz}mhz.rpt" 2>&1 || true

  local wns tns fmax
  wns="$(grep -m1 '^worst slack' "$OUT/sta_${mhz}mhz.rpt" | awk '{print $3}')"
  tns="$(grep -m1 '^tns' "$OUT/sta_${mhz}mhz.rpt" | awk '{print $2}')"
  if [[ -n "$wns" ]]; then
    if [[ "$STA_TIME_UNIT" == "ps" ]]; then
      fmax="$(python3 -c "p=float('$period'); w=float('$wns'); print(f'{1e6/(p-w):.1f}') if p-w>0.001 else print('N/A')")"
    else
      fmax="$(python3 -c "p=float('$period'); w=float('$wns'); print(f'{1000/(p-w):.1f}') if p-w>0.001 else print('N/A')")"
    fi
    echo "PDK:           $PDK_LABEL"
    echo "Target:        ${mhz} MHz (${period} ${STA_TIME_UNIT})"
    echo "WNS:           ${wns} ${STA_TIME_UNIT}"
    echo "TNS:           ${tns} ${STA_TIME_UNIT}"
    echo "Est. Fmax:     ${fmax} MHz"
    python3 -c "print('Timing:        MET' if float('$wns')>=0 else 'Timing:        VIOLATED')"
  else
    tail -10 "$OUT/sta_${mhz}mhz.rpt"
  fi
  echo "Report: $OUT/sta_${mhz}mhz.rpt"
}

echo "PDK: $PDK ($PDK_LABEL)"

case "$MODE" in
  synth) run_synth ;;
  sta)   run_sta "$TARGET_MHZ" ;;
  all)
    run_synth
    run_sta "$TARGET_MHZ"
    for m in 50 100 150 250 300; do
      run_sta "$m" || true
    done
    ;;
  *) echo "Unknown mode: $MODE (synth|sta|all)"; exit 1 ;;
esac

echo "Done."
