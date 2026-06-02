# RISC-V v2

Pipelined **RV32IMC** MCU-class core — own SystemVerilog RTL, informed by open-source architectures (not copied).

| Doc | Purpose |
|-----|---------|
| [SPEC.md](SPEC.md) | **Architecture spec** (source of truth) |
| [REFERENCES.md](REFERENCES.md) | What to study (CVA6, VexRiscv, SoomRV, …) |
| [DESIGN_DIARY.md](DESIGN_DIARY.md) | Session log |

## Status

| Phase | Goal | Status |
|-------|------|--------|
| **2a** | 5-stage + CSRs + traps + rv32ui | **RTL sim OK** (v1 programs) |
| **2b** | M/C ext, CLINT, UART, AXI, ≥100 MHz | Planned |
| **2c** | RTOS demo, Spike diff, integration guide | Planned |

## v1 baseline

Frozen implementation: [../v1/RISC-V/](../v1/RISC-V/) (`V1` branch on GitHub).

## Quick start

```bash
cd RISC-V/sim && make core_sim
```

## Quick targets

- **ISA:** RV32I + Zicsr (2a); M/C in 2b  
- **FPGA:** ≥ 100 MHz on xc7a35t (timing TBD)  
- **RTL:** [RISC-V/rtl/](RISC-V/rtl/)
