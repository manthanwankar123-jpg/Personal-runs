# RISC-V v2 RTL

5-stage pipelined **RV32I + Zicsr** core (phase 2a). Spec: [../SPEC.md](../SPEC.md).

## Build & sim

```bash
cd sim
make core_sim
```

Runs v1 integration programs (`mem_sum5`, `mem_sort8`, `mem_gcd`) with **EBREAK → trap** (no `halt_0` port).

## RTL layout

| Module | Role |
|--------|------|
| `riscv_core.sv` | 5-stage CPU + hazard/forward |
| `unified_mem.sv` | ROM + data RAM @ 0x8000_0000; **distributed RAM** (LUT) @ FPGA |
| `instr_rom.sv` | Word distributed RAM ROM; registered read under `FPGA_TIMING_SYNTH` |
| `csr_file.sv` | M-mode CSRs + trap entry |
| `control.sv` | Decode + trap/CSR |

## Timing summary (2 FPGAs + ASIC)

| Platform | Process / part | Flow | WNS @ ref | Est. Fmax | Safe clock |
|----------|----------------|------|-----------|-----------|------------|
| **FPGA** | Artix-7 **XC7A200T-3** FFG1156 | Vivado 2024.1 P&R | +9.99 ns @ 50 MHz | ~100 MHz | **~100 MHz** |
| **FPGA** | same | fast report | +0.99 ns @ 100 MHz | meets | **100 MHz** |
| **FPGA** | same | fast report | **+1.58 ns @ 200 MHz** | ~290 MHz | **200 MHz** (core; dbg I/O false-path) |
| **FPGA** | Kintex UltraScale+ **XCKU3P-3** FFVA676 | Vivado 2024.1 P&R | +18.56 ns @ 50 MHz | ~696 MHz | **≥ 200 MHz** |
| **FPGA** | same | fast report | +8.56 ns @ 100 MHz | meets | **100 MHz** |
| **FPGA** | same | fast report | **+3.56 ns @ 200 MHz** | meets setup | **200 MHz** (core) |
| **ASIC** | **ICsprout55** 55 nm H7CR typ | Yosys + OpenSTA (post-synth) | +4.75 ns @ 50 MHz | **~66 MHz** | **~65 MHz** |
| **ASIC** | **ASAP7** 7 nm sc7p5t RVT TT | Yosys + OpenSTA (post-synth) | +16.24 ns @ 50 MHz | **~266 MHz** | **~250 MHz** |
| **ASIC** | ASAP7 same | 200 MHz report | **+1.24 ns** | meets | **200 MHz** post-synth |

See [ARCHITECTURE.md](ARCHITECTURE.md) for microarchitecture. FPGA: [fpga/](fpga/). ASIC: [asic/](asic/) — [ICsprout55](asic/icsprout55-pdk), [ASAP7](https://github.com/The-OpenROAD-Project/asap7).

## FPGA timing (Vivado 2024.1)

Checkpoints are stored per part under `fpga/vivado_timing/<part>/`.

**Artix-7 (XC7A200T-3, FFG1156):**

```bash
cd fpga && ./run_timing.sh xc7a200tffg1156-3 50 full
./run_timing.sh xc7a200tffg1156-3 100
./run_timing.sh xc7a200tffg1156-3 200
```

**Kintex UltraScale+ (XCKU3P-3, FFVA676):**

```bash
cd fpga && ./run_timing.sh xcku3p-ffva676-3-e 50 full
./run_timing.sh xcku3p-ffva676-3-e 100
./run_timing.sh xcku3p-ffva676-3-e 200
```

Under `FPGA_TIMING_SYNTH`: distributed LUT RAM, 2-cycle IF + load, `id_ex_target` PC retiming, registered debug outputs + IOB pads in `riscv_core_sta_top.sv`.

## ASIC timing (2 PDKs)

**ICsprout55 (55 nm):**

```bash
cd asic/icsprout55-pdk && make unzip    # once
cd .. && ./run_synth_sta.sh icsprout55 50 all
```

**ASAP7 (7 nm):**

```bash
cd asic/asap7 && make unzip             # once
cd .. && ./run_synth_sta.sh asap7 50 all
```

Post-synthesis STA only (no P&R). Memory stubbed; reports in `asic/out/<pdk>/`.
