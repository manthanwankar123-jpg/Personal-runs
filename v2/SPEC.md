# RISC-V Processor v2 — Architecture Specification

**Project:** Personal_runs / v2 / RISC-V  
**Status:** Architecture — implementation not started  
**Baseline:** [v1/RISC-V](../v1/RISC-V/) (RV32I single-cycle, frozen on branch `V1`)  
**References:** [REFERENCES.md](REFERENCES.md) — study open cores; **our own RTL**

This document is the source of truth for v2. Update [DESIGN_DIARY.md](DESIGN_DIARY.md) for session notes; check off items here when implemented.

---

## 1. Goals and non-goals

### 1.1 Goals

- Evolve v1 into a **commercial-MCU-shaped** core: pipelined, CSRs, traps, interrupts, richer ISA.
- **Own microarchitecture** in SystemVerilog (not a fork of BOOM/CVA6 RTL).
- Run **compiled C** (picolibc/newlib) and prove with **riscv-tests** + RTOS on FPGA.
- Close timing on **Artix-7** at a documented Fmax (target **≥ 100 MHz**, stretch 150 MHz).

### 1.2 Non-goals (v2)

| Item | Notes |
|------|--------|
| SiFive P470 / Ventana Veyron class | GHz OoO datacenter — **not** our tier |
| RV64 | Stay **RV32** for v2 |
| S/U modes + MMU + Linux | **Phase 3** (optional later) |
| Full RISC-V compliance branding | Aim for tests passing; formal compliance TBD |
| JTAG debug (full) | **Phase 2c**; minimal `ebreak` debug in 2a |

### 1.3 Relationship to v1

| v1 | v2 |
|----|-----|
| Single-cycle | **5-stage pipeline** |
| Harvard, comb mem | **Unified** mem map + **sync** BRAM / bus |
| `halt` on illegal | **Traps** + `mcause` |
| RV32I | **RV32IMC** + **Zicsr** |
| `halt_0` port | **`mip` / IRQ** + optional `halt` for TB |

v1 remains frozen under `v1/RISC-V/`. v2 is a **new RTL tree** under `v2/RISC-V/` (see §10).

---

## 2. ISA profile

### 2.1 Named profile (target)

**`RV32IMC_Zicsr_M`** — machine mode only.

| Parameter | Choice |
|-----------|--------|
| XLEN | 32 |
| Base | **I** (v1 subset, verified) |
| **M** | Multiply/divide (`MUL`, `MULH*`, `DIV`, `REM*`) — phase **2b** |
| **C** | Compressed — phase **2b** (or 2c if schedule slips) |
| **Zicsr** | CSR instructions — phase **2a** |
| Privilege | **M only** |
| ABI | **ILP32** |
| Endianness | Little-endian |

### 2.2 Traps and exceptions (replace v1 halt)

| Event | v2 behavior |
|-------|-------------|
| Illegal instruction | Trap to `mtvec` |
| EBREAK | Trap (debugger / test harness) |
| ECALL | Trap (syscall ABI for RTOS) |
| Timer interrupt | IRQ via **CLINT** |
| External IRQ | **PLIC** or simple IRQ mux — phase **2b** |
| Misaligned load/store | **Trap** (phase 2a or 2b — pick one and document) |

v1 **halt** behavior is removed from the core; tests may still observe `core_halted` from TB on infinite loop.

### 2.3 CSRs (minimum M-mode set — phase 2a)

| CSR | Purpose |
|-----|---------|
| `mstatus` | Global interrupt enable (`MIE`), prior enable (`MPIE`) — minimal subset |
| `misa` | Report `I` (+ `M`, `C` when implemented) |
| `mtvec` | Trap vector (direct mode v2; vectored **TBD**) |
| `mepc` | Trap PC |
| `mcause` | Trap cause |
| `mtval` | Fault address / bad instruction |
| `mie` / `mip` | Interrupt enable / pending |
| `mtime` / `mtimecmp` | Machine timer (CLINT) — phase **2b** |

Full privileged spec is the authority; table is our **minimum bring-up set**.

---

## 3. Microarchitecture

### 3.1 Pipeline

Classic **5-stage** in-order pipeline (CVA6/NEORV32-inspired **structure**, our RTL):

```text
IF → ID → EX → MEM → WB
```

| Stage | Function |
|-------|----------|
| **IF** | PC, fetch 32-bit insn (or 16-bit if C ext later) |
| **ID** | Decode, reg read, imm gen, hazard detect |
| **EX** | ALU, branch resolve, M-extension |
| **MEM** | Load/store, address AGU |
| **WB** | Reg write, CSR write side-effects |

| Parameter | Choice |
|-----------|--------|
| Branch | Resolve in **EX**; flush IF/ID on taken branch |
| Load-use | **1-cycle stall** (minimum) + **forwarding** from MEM/WB |
| CPI | Target **~1.2–1.5** on typical code (not 1.0 like v1) |

**Not in v2:** out-of-order (BOOM/SoomRV are references only for later study).

### 3.2 Hazard / forwarding

| Path | Action |
|------|--------|
| EX → EX (ALU-ALU) | Forward EX/MEM or MEM/WB |
| Load → use | Stall ID/EX or forward after load in MEM |
| CSR read | Document hazard on `csrr` — may stall 1 |

### 3.3 Reset

- Synchronous reset, active-high `rst` (match v1 unless board needs inverted).
- PC ← `RESET_PC` after reset deassert.
- All pipeline regs cleared; `mstatus.MIE` ← 0.

---

## 4. Memory system

### 4.1 Organization (change from v1)

| v1 | v2 |
|----|-----|
| Harvard (separate arrays) | **Unified** physical address space |
| Comb read | **Synchronous** RAM (1-cycle read latency) |

Software sees **one** map; fetch and load/store arbitrate on the bus (Harvard **ports** allowed internally if bus has separate IF/D channels — **TBD**: von Neumann vs split AXI).

### 4.2 Memory map (draft)

```text
0x0000_0000 – 0x0007_FFFF   ROM / IMEM (512 KiB)     boot, .text
0x8000_0000 – 0x8007_FFFF   RAM (512 KiB)            .data, .bss, stack
0x0200_0000 – 0x0200_FFFF   CLINT                    timer, software IRQ
0x1000_0000 – 0x1000_FFFF   UART0 (MMIO)             console
0x1000_1000 – 0x1000_1FFF   PLIC (optional)          external IRQ
```

Exact sizes are **parameters** (`ROM_SIZE`, `RAM_SIZE`). v1’s 64 KiB + 64 KiB is too small for libc — **512 KiB** each as default for v2 sim/FPGA unless BRAM limited.

### 4.3 Alignment

- LW/SW: **aligned**; misaligned → **trap** with `mcause` store/load fault.
- LB/LH/SB/SH: supported with defined byte lanes.

---

## 5. SoC and buses

### 5.1 Top level

`riscv_soc` wraps:

- `riscv_core` (pipeline CPU)
- `clint` (timer + msip)
- `uart_mmio` (minimal 16550 or custom FIFO UART)
- Bus interconnect

### 5.2 Bus (phase 2b)

| Choice | Notes |
|--------|--------|
| **AXI4-Lite** | Default target; matches industry SoC IP |
| Alternative | AHB-Lite if AXI is heavy for first FPGA |

Core exposes:

- Instruction fetch port (read-only)
- Data port (read/write)

Or single unified port if simpler for 2a bring-up.

---

## 6. Performance targets

| Metric | v1 (measured) | v2 FPGA Artix-7 (XC7A200T-3) | v2 FPGA Kintex US+ (XCKU3P-3) | v2 ASIC ICsprout55 | v2 ASIC ASAP7 |
|--------|---------------|------------------------------|-------------------------------|--------------------|---------------|
| Fmax | ~54 MHz (single-cycle) | **~100 MHz** P&R; **200 MHz** core-closed | **200 MHz** core-closed | **~66 MHz** post-synth STA | **~250 MHz** post-synth STA |
| IPC | 1.0 | ~1.2+ typical | same RTL | same RTL | same RTL |
| Commercial compare | — | MCU-class MHz on FPGA | faster US+ fabric | 55 nm MCU-class | 7 nm predictive PDK |

**FPGA:** Vivado 2024.1 — Artix-7 `fpga/run_timing.sh xc7a200tffg1156-3`; Kintex US+ `fpga/run_timing.sh xcku3p-ffva676-3-e`.  
**ASIC:** Yosys + OpenSTA — `asic/run_synth_sta.sh icsprout55` or `asic/run_synth_sta.sh asap7` ([ICsprout55](https://github.com/openecos-projects/icsprout55-pdk), [ASAP7](https://github.com/The-OpenROAD-Project/asap7)).

Re-run timing each milestone.

---

## 7. Verification

| Layer | Tool / method |
|-------|----------------|
| Unit | Per-module TB (carry forward v1 style) |
| ISA | [riscv-tests](https://github.com/riscv-software-src/riscv-tests) — `rv32ui`, then `rv32um`, `rv32uc` |
| Compare | **Spike** lockstep (optional, phase 2b) |
| Integration | C programs via GCC; `crt0`, linker script |
| RTOS | **FreeRTOS** or **Zephyr** smoke on FPGA (phase 2c) |
| CI | Verilator sim mandatory on push |

Pass criteria per phase in §9.

---

## 8. Block diagram (target)

```text
                    ┌──────────────┐
             clk ──►│  riscv_soc   │
             rst ──►│              │
                    │  ┌────────┐  │     AXI-Lite / SRAM
                    │  │ riscv  │◄─┼──► ROM, RAM, MMIO
                    │  │ _core  │  │
                    │  └───┬────┘  │
                    │      │ IRQ   │
                    │  ┌───▼────┐  │
                    │  │ CLINT  │  │
                    │  │ UART   │  │
                    │  └────────┘  │
                    └──────────────┘
```

Pipeline inside `riscv_core` matches §3.1 (IF/ID/EX/MEM/WB).

---

## 9. Implementation phases

### Phase 2a — “Real CPU” (MVP)

**Goal:** Pipelined RV32I + Zicsr + traps; no C ext yet.

- [ ] 5-stage pipeline, forwarding, branch flush
- [ ] Unified mem, sync BRAM, boot from ROM image
- [ ] CSR minimum table (§2.3)
- [ ] Illegal / ebreak / ecall → trap handler
- [ ] `mtvec` + simple trap handler in ROM (asm)
- [ ] riscv-tests **rv32ui** subset passing
- [ ] Verilator `core_sim`; Fmax report ≥ 80 MHz

**Does not include:** UART, timer IRQ, M/C ext.

### Phase 2b — “MCU SoC”

**Goal:** Commercial-MCU feature set on FPGA.

- [ ] **M** and **C** extensions
- [ ] CLINT (`mtime` / `mtimecmp`)
- [ ] UART MMIO + printf
- [ ] Simple PLIC or 16-line IRQ mux
- [ ] AXI4-Lite (or finish bus fabric)
- [ ] riscv-tests rv32ui + um + uc
- [ ] Fmax ≥ 100 MHz on Artix-7
- [ ] GCC + picolibc “hello world”

### Phase 2c — “Product shape”

**Goal:** Demonstrate integratability.

- [ ] FreeRTOS or Zephyr tick + UART console
- [ ] Spike diff on test suite
- [ ] Integration guide + memory map doc
- [ ] Optional: minimal RISC-V debug module (JTAG TBD)

### Phase 3 (out of v2 scope)

RV64, S/U, MMU, Linux — only after v2 frozen.

---

## 10. RTL layout (planned)

```text
v2/RISC-V/
├── SPEC.md              → symlink or copy of ../SPEC.md (optional)
├── DESIGN_DIARY.md
├── rtl/
│   ├── riscv_pkg.sv
│   ├── riscv_core.sv    # pipeline CPU
│   ├── regfile.sv
│   ├── alu.sv
│   ├── mul_div.sv       # phase 2b
│   ├── control.sv
│   ├── imm_gen.sv
│   ├── csr_file.sv      # new
│   ├── clint.sv
│   ├── uart.sv
│   └── riscv_soc.sv
├── sim/
├── software/
│   ├── linker/
│   ├── crt0/
│   └── tests/
└── fpga/
```

Reuse v1 blocks **only** by copy-and-adapt (alu, regfile concepts) — do not `#include` v1 files in sim.

---

## 11. Open decisions (TBD)

| ID | Question | Options | Decide by |
|----|----------|---------|-----------|
| O1 | Split IF/D bus vs single AXI | Split (CVA6-like) vs unified | Start of 2b |
| O2 | Vectored `mtvec` | Direct only vs vectored | 2a trap bring-up |
| O3 | ROM/RAM size default | 512 KiB vs 64 KiB | First synthesis |
| O4 | Misalign policy | Trap vs software fixup | 2a |
| O5 | C extension timing | 2b vs 2c | After 2a stable |

---

## 12. Decision log

| ID | Decision | Date |
|----|----------|------|
| V2-1 | Profile **RV32IMC_Zicsr_M** (not Linux/RV64) | 2026-06-01 |
| V2-2 | **5-stage in-order** pipeline (not OoO) | 2026-06-01 |
| V2-3 | Study **CVA6 / NEORV32 / VexRiscv / SoomRV**; **own SV RTL** | 2026-06-01 |
| V2-4 | FPGA Fmax target **≥ 100 MHz** (Artix-7 -1) | 2026-06-01 |
| V2-5 | Replace v1 **halt** with **traps** | 2026-06-01 |

---

## 13. Revision history

| Date | Summary |
|------|---------|
| 2026-06-01 | Initial v2 SPEC: MCU profile, 5-stage, phases 2a–2c |
