# ASIC timing — ICsprout55 + ASAP7

Post-synthesis STA on two open PDKs:

| PDK | Process | Corner | Liberty time unit |
|-----|---------|--------|-------------------|
| [ICsprout55](icsprout55-pdk/) | 55 nm CMOS | H7CR RVT typ | ns |
| [ASAP7](asap7/) | 7 nm FinFET (predictive) | sc7p5t RVT TT | ps |

## Setup (once)

**ICsprout55:**

```bash
cd asic/icsprout55-pdk && make unzip
```

**ASAP7** ([The-OpenROAD-Project/asap7](https://github.com/The-OpenROAD-Project/asap7)):

```bash
cd asic/asap7 && make unzip    # extracts RVT TT NLDM from asap7sc7p5t_28
```

Requires: **sv2v**, **Yosys**, **OpenSTA** (`sta`), **7z**.

## Run

```bash
cd asic
./run_synth_sta.sh icsprout55 50 all     # default PDK
./run_synth_sta.sh asap7 50 all
./run_synth_sta.sh asap7 250 sta         # STA only (reuse netlist)
./run_synth_sta.sh icsprout55 100 sta
```

Reports: `asic/out/<pdk>/sta_*mhz.rpt`, netlist: `asic/out/<pdk>/riscv_core_mapped.v`.

## Methodology

| Item | Detail |
|------|--------|
| Top | `riscv_core_asic_top` |
| Memory | `mem_stub.sv` (core-only; no ROM/RAM inference) |
| Flow | sv2v → Yosys `synth` → `dfflibmap` → `abc` → OpenSTA |
| Scope | **Post-synthesis, zero wire load** (no place/route) |

ASAP7 maps against five NLDM libraries (AO, INVBUF, OA, SIMPLE, SEQ) and uses picosecond SDC (`constraints_asap7.sdc`).

## Results (core logic, post-synth STA)

### ICsprout55 55 nm H7CR typ

| Target | WNS | Est. Fmax | Notes |
|--------|-----|-----------|-------|
| 50 MHz | **+4.75 ns** | **~66 MHz** | meets |
| 100 MHz | −5.25 ns | ~66 MHz | |

Critical path: IF/ID decode → pipeline enable (~15 ns).

### ASAP7 7 nm sc7p5t RVT TT

| Target | WNS | Est. Fmax | Notes |
|--------|-----|-----------|-------|
| 50 MHz | **+16.24 ns** | **~266 MHz** | meets |
| 200 MHz | **+1.24 ns** | meets | core-closed post-synth |
| 250 MHz | **+0.24 ns** | meets | |
| 300 MHz | −0.42 ns | ~266 MHz | |

Critical path: IF/ID decode cone (similar to ICsprout55).

**Safe clocks (post-synth):** ICsprout55 **~65 MHz**; ASAP7 **~250 MHz**. Expect further gain after OpenROAD P&R on ASAP7.
