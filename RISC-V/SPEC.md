# RISC-V Processor — Architecture Specification

**Project:** Personal_runs / RISC-V  
**Status:** Draft — architecture phase  
**Last updated:** 2026-06-01 (D1–D7, §3.4 core, §7 integration sim, §8 FPGA timing)  

This document is the single source of truth for what we are building. RTL, testbenches, and software must match this spec. Open questions are marked **TBD**; resolve them in the [Design Diary](DESIGN_DIARY.md) and then update here.

---

## 1. Goals and non-goals

### 1.1 Goals

- Learn processor design end-to-end: architecture → RTL → simulation → simple programs.
- Implement a **correct subset** of RISC-V that can run small compiled or hand-written test programs.
- Keep the first version **simple enough to reason about** (single-cycle before pipeline).

### 1.2 Non-goals (v1)

| Item | Notes |
|------|--------|
| Virtual memory / MMU | Defer |
| Supervisor / User modes | Machine-only for v1 |
| M extension (mul/div) | Optional later |
| C extension (compressed) | Optional later |
| Full interrupt controller | Optional later |
| Linux / full OS | Out of scope |

---

## 2. ISA profile

| Parameter | Choice | Notes |
|-----------|--------|--------|
| Base ISA | **RV32I** | 32-bit integer |
| XLEN | 32 | PC, registers, addresses |
| Privilege | **Machine only** | No S-mode/U-mode in v1 |
| Endianness | **Little-endian** | Memory and instruction encoding |
| Reset vector | **`0x0000_0000`** | First instruction fetch from instr mem base |
| Illegal instructions | **Halt** | Stop PC advance; TB may flag (see §7) |

### 2.1 Instruction coverage (v1 minimum)

Check when implemented and tested.

**Arithmetic / logic (R-type, I-type)**

- [ ] ADD, SUB, AND, OR, XOR
- [ ] SLL, SRL, SRA
- [ ] SLT, SLTU
- [ ] ADDI, ANDI, ORI, XORI, SLTI, SLTIU
- [ ] SLLI, SRLI, SRAI

**Loads / stores**

- [ ] LB, LH, LW, LBU, LHU
- [ ] SB, SH, SW

**Branches**

- [ ] BEQ, BNE, BLT, BGE, BLTU, BGEU

**Jumps / upper immediates**

- [ ] JAL, JALR
- [ ] LUI, AUIPC

**System (minimal)**

- [ ] ECALL / EBREAK — **EBREAK halts** (PC holds); ECALL same as EBREAK in v1
- [ ] CSR access — **out of scope v1** unless added explicitly

### 2.2 Registers

- 32 × `x0`–`x31`, 32 bits each.
- `x0` reads as 0; writes to `x0` discarded.
- ABI names (sp, ra, etc.) are software convention only.

---

## 3. Microarchitecture

### 3.1 Implementation style

| Parameter | Choice | Notes |
|-----------|--------|--------|
| Pipeline | **Single-cycle (v1)** | One instruction per clock |
| v2 plan | **TBD** | 5-stage pipeline + hazards |
| Clocking | **Single clock, synchronous** | `posedge clk`; async reset **TBD** style |

### 3.2 Memory organization

| Parameter | Choice | Notes |
|-----------|--------|--------|
| Organization | **Harvard** | Separate `instr_mem` and `data_mem` ports; no fetch/load-store conflict in v1 |
| Instruction memory | **64 KiB** ROM/RAM | Byte-addressed; 16-bit index `pc[15:0]` |
| Data memory | **64 KiB** RAM | Byte-addressed; decode `addr[31:16]==0x8000` → local `addr[15:0]` |
| Alignment | LW/SW 4-byte aligned | **Misaligned: no trap in v1** — software must align; RTL may return bogus data |
| Technology (sim) | Behavioral arrays | FPGA: BRAM inference (see §8); comb read in v1 |

**Why Harvard (v1):** Simpler single-cycle RTL (fetch and load/store in parallel conceptually), no bus arbiter, matches two-port mental model. Von Neumann can be a v2 refactor when you pipeline and want one address space.

### 3.3 Memory map

```
Address range              Region           Physical backing (Harvard)
──────────────────────────────────────────────────────────────────────
0x0000_0000 – 0x0000_FFFF  Instruction      instr_mem[16:0] byte index
0x8000_0000 – 0x8000_FFFF  Data RAM         data_mem[16:0] byte index
(other)                    —                Ignore / read 0 (v1)
```

- **Reset PC:** `0x0000_0000` → first fetch from instr mem.
- **Linker / asm:** Place code at `0x0`, read/write data at `0x8000_0000`.
- **MMIO:** Not in v1; add e.g. `0xFFFF_0000` when you want UART.

**Note:** Harvard means separate memories; the split at `0x8000_0000` is a **software convention** enforced by your `data_mem` address decode, not a unified bus.

### 3.4 Block diagram — `riscv_core` (single-cycle, target wiring)

This is the integration diagram for **`rtl/riscv_core.sv`**: one clock cycle from fetch through write-back and next PC. Matches implemented blocks (`control`, `imm_gen`, `regfile`, `alu`; `instr_mem` / `data_mem` TBD).

```text
                    ┌─────────────┐
  pc ──────────────►│  instr_mem  │──► instr
                    └─────────────┘
                           │
         ┌─────────────────┼─────────────────┐
         ▼                 ▼                 ▼
    ┌─────────┐      ┌──────────┐      ┌──────────┐
    │ control │      │ imm_gen  │      │ regfile  │◄── wd
    └────┬────┘      └────┬─────┘      └────▲─────┘
         │                │                 │
         │           imm ─┼──► ALU b mux      │ wb_mux
         │                │      ▲           │
         │           rs1 ─┼──► ALU a mux ────┤
         │           rs2 ─┼──► (mem / cmp)  │
         ▼                │      │           │
    branch_taken         │   ┌──┴──┐        │
         │               └──►│ ALU │────────┘
         ▼                   └─────┘
    ┌─────────┐                  │
    │ PC mux  │◄── pc+4 / branch / jump
    └────┬────┘
         ▼
        pc_reg

  alu_result ──► data_mem addr (rs1+imm) ──► load data ──► wb_mux
```

**Signal flow (same cycle):**

| Path | Flow |
|------|------|
| Fetch | `pc` → `instr_mem` → `instr` |
| Decode | `instr` → `control`, `imm_gen`; `rs1`/`rs2`/`rd` → `regfile` |
| Execute | `rd1` / `imm` / `rd2` → ALU operand muxes → `alu_result`; `zero`/`lt`/`ltu` → `control` |
| Memory | Load/store: `alu_result` = `rs1 + imm` → `data_mem`; load → `wb_mux` |
| Write-back | `wb_mux` → `regfile.wd` when `rf_we` |
| Next PC | `control` → `branch_taken` / `pc_sel` → PC mux → `pc_reg`; **`halt` freezes PC** |

**ALU A mux notes (v1):** `LUI` → `alu_a = 0`; `AUIPC` → `alu_a = pc`; default → `rd1`.

**Harvard:** `instr_mem` and `data_mem` are separate ports; data addresses use map §3.3 (`0x8000_0000` base).

**Top-level ports:** `clk`, `rst`, **`halt_0`** (asserted on EBREAK/ECALL / illegal opcode in v1).

---

## 4. Datapath specification

### 4.1 Major signals (names for RTL)

| Signal | Width | Description |
|--------|-------|-------------|
| `pc` | 32 | Current program counter |
| `pc_plus4` | 32 | `pc + 4` |
| `pc_next` | 32 | Selected next PC |
| `instr` | 32 | Current instruction |
| `rs1`, `rs2`, `rd` | 5 each | Register indices |
| `imm` | 32 | Sign-extended immediate |
| `rf_rdata1`, `rf_rdata2` | 32 | Register read data |
| `rf_wdata` | 32 | Write-back data |
| `rf_we` | 1 | Register write enable |
| `alu_a`, `alu_b` | 32 | ALU operands |
| `alu_result` | 32 | ALU output |
| `mem_addr` | 32 | Data memory address |
| `mem_wdata`, `mem_rdata` | 32 | Store / load data |
| `mem_we`, `mem_re` | 1 | Memory controls |
| `mem_size` | 2 | 00=byte, 01=half, 10=word |
| `mem_unsigned` | 1 | Load zero-extend vs sign-extend |

### 4.2 Multiplexers

| Mux | Select when | Inputs |
|-----|-------------|--------|
| ALU B | `alu_src_imm` | `rf_rdata2` vs `imm` |
| WB | `wb_sel` | ALU result vs load data vs `pc_plus4` |
| PC | `pc_sel` | `pc_plus4` vs branch target vs jump target |

### 4.3 Branch / jump next-PC

- **Branch target:** `pc + imm` (B-type immediate).
- **JAL target:** `pc + imm` (J-type); link `rd = pc + 4`.
- **JALR target:** `(rs1 + imm) & ~1`; link `rd = pc + 4`.
- **Default:** `pc + 4`.

Branch condition evaluation: **TBD** (dedicated compare vs ALU).

---

## 5. Control specification

### 5.1 Control fields

The control unit drives at least:

- `rf_we`, `mem_we`, `mem_re`
- `mem_size[1:0]`, `mem_unsigned`
- `alu_src_imm`, `alu_op`
- `wb_sel[1:0]`
- `branch`, `jump`, `jalr` (or equivalent PC mux encoding)

### 5.2 Opcode table

**TBD** — fill as each instruction is designed. Example row:

| Instr | opcode | funct3 | funct7 | alu_op | alu_src_imm | mem | wb_sel | branch/jump |
|-------|--------|--------|--------|--------|-------------|-----|--------|-------------|
| ADD | 0110011 | 000 | 0000000 | ADD | 0 | — | ALU | — |

---

## 6. Module hierarchy (RTL)

| Module | Responsibility | Status |
|--------|----------------|--------|
| `riscv_core` | Top-level integration | Implemented |
| `regfile` | 32 registers, x0 handling | Implemented |
| `alu` | Datapath operations + branch compares | Implemented |
| `imm_gen` | I/S/B/U/J immediates | Implemented |
| `control` | Instruction → control signals | Implemented |
| `riscv_pkg` | Opcodes, types, constants | Implemented |
| `instr_mem` | Instruction fetch storage | Implemented |
| `data_mem` | Load/store storage | Implemented |
| `fpga/riscv_core_sta_top` | Vivado STA wrapper | Timing only |

---

## 7. Verification strategy

| Item | Plan |
|------|------|
| **Primary simulator** | **Verilator 5.x** (installed on host) — fast, strict; C++ or simple Verilog TB |
| **Secondary** | **Icarus Verilog 11** — quick sanity checks, pure `.v` |
| Unit tests | Per-module TB (start with `alu`, then `regfile`) |
| ISA tests | `riscv-tests` subset after first program passes |
| Reference | Compare register `x11` + memory word; Spike later |
| **First program** | **`mem_sum5`** — see §7.1 |
| **Integration TB** | `sim/core_tb.sv` — `make core_sim` (Verilator) |
| Pass criteria | After fixed cycle count or `ebreak`: **`x11 == 15`** (1+2+3+4+5), optional `mem[0x80000000]==15` |

**Integration programs** (same TB, sequential reset per program):

| Program | Image | Golden |
|---------|--------|--------|
| `mem_sum5` | `sim/program.hex` | `x11 == 15` |
| `mem_sort8` | `sim/program_sort8.hex` | sorted `mem[0]==1`, `mem[28]==101`, `x11(sum)==276` |
| `mem_gcd` | `sim/program_gcd.hex` | `gcd(66,99)==33` in `x10` and `mem[8]` |

Sources: `prog/*.S` → `riscv64-unknown-elf-as` + `objcopy -O verilog`.

### 7.1 First test program: `mem_sum5`

**Goal:** Sum five 32-bit words in data RAM; result in **`x11`**.

**Data image** (loaded at `0x8000_0000` before reset):  
`1, 2, 3, 4, 5` (little-endian words).

**Pseudocode:**

```text
x10 = 0x80000000          # pointer (LUI + ADDI)
x11 = 0                   # sum
x12 = 5                   # count
loop:
  x13 = mem[x10]          # LW
  x11 = x11 + x13         # ADD
  x10 = x10 + 4           # ADDI
  x12 = x12 - 1           # ADDI
  if x12 != 0: goto loop  # BNE
ebreak                    # halt for TB
```

**Minimum instructions to implement (in order of bring-up):**

| Stage | Instructions | Proves |
|-------|----------------|--------|
| 0 | ADDI, EBREAK | PC, regfile, decode slice |
| 1 | ADD | ALU |
| 2 | LUI | upper immediate |
| 3 | LW, SW | data mem, byte lanes |
| 4 | BNE | branch + PC mux |

Optional before loop: **smoke** `addi x11, x0, 42` only.

**Earlier smoke (optional):** `addi x11, x0, 42` → `ebreak` (no memory).

---

## 8. FPGA / synthesis

### 8.1 Target devices (characterized)

| Part | Board (typical) | Speed grade | Notes |
|------|-----------------|-------------|--------|
| **XC7A35T** (`xc7a35tcsg324-1`) | Digilent Arty A7-35 | -1 | Primary timing run |
| **XC7A100T** (`xc7a100tcsg324-1`) | Digilent Nexys A7 | -1 | Second run, similar Fmax |

**Toolchain:** Vivado **2024.1** at `/mnt/hw/tools/amd/2024.1/Vivado/2024.1/bin/vivado` (host install under `/mnt/hw/tools/amd`).

### 8.2 Achieved clock (single-cycle v1, STA)

Measured with post-route timing at a **50 MHz** constraint (20 ns `clk`):

| Part | WNS @ 50 MHz | **Estimated Fmax** |
|------|----------------|---------------------|
| XC7A35T | +1.62 ns | **~54 MHz** |
| XC7A100T | +1.87 ns | **~55 MHz** |

`Fmax ≈ 1 / (T_clk − WNS)` using the constrained period and worst negative slack (positive WNS → headroom below constraint).

**Recommended bring-up clock:** **40 MHz** (25 ns) first on FPGA; try **50 MHz** after timing sign-off on *your* board netlist.

**Worst setup path (representative):** `pc_reg` → fetch (`instr_mem`) → decode / `regfile` read → ALU (+ branch compare) → PC mux → **`pc_reg` D**. Data path delay ~**18.1 ns** at 50 MHz on the characterized netlist (~77% routing, ~23% logic on that path).

### 8.3 Timing / synthesis flow (repo)

| File | Role |
|------|------|
| `fpga/timing_synth.tcl` | Vivado batch: synth → place → route → `timing_summary.rpt` |
| `fpga/run_timing.sh` | Wrapper; default part `xc7a35tcsg324-1` |
| `fpga/riscv_core_sta_top.sv` | Synthesis top with `dbg_pc` probe (prevents opt deleting core) |
| `fpga/vivado_timing/` | Generated project, reports, `riscv_core_routed.dcp` |

```bash
export VIVADO=/mnt/hw/tools/amd/2024.1/Vivado/2024.1/bin/vivado
./fpga/run_timing.sh xc7a35tcsg324-1
# or: ./fpga/run_timing.sh xc7a100tcsg324-1
```

### 8.4 `FPGA_TIMING_SYNTH` (Vivado-only defines)

RTL uses `` `ifdef FPGA_TIMING_SYNTH `` (set via Vivado `verilog_define` on the fileset — **not** used by Verilator `make core_sim`):

| Change | Reason |
|--------|--------|
| **16 KiB** IMEM/DMEM (not 64 KiB) | BRAM inference; full 64 KiB byte arrays failed or inflated gate count in first runs |
| `instr_mem`: `(* ram_style = "block" *)`, `$readmemh("program.hex", mem)` | Avoid empty-IMEM constant folding; load `mem_sum5` image |
| `data_mem`: 4K×32 word BRAM + byte/half mux | Combinational byte read on 64 KiB did not infer BRAM |
| `riscv_core`: `(* dont_touch *)`, `dbg_pc` output | Keep PC path for STA |
| Skip `opt_design` in `timing_synth.tcl` | `opt_design` trimmed “unused” CPU when only `halt_0` was top-level |

**Production FPGA** (bitstream, full 64 KiB map) still **TBD**: re-run STA after true 64 KiB BRAM + board top (clock divider, reset sync, `halt_0` → LED). Expect **similar or somewhat lower** Fmax than §8.2 until characterized.

### 8.5 FPGA bring-up checklist (not done)

- [ ] Board top: MMCM/divider, synchronized reset, pin constraints (`.xdc`)
- [ ] Program load: BRAM init from `program.hex` / COE at bitgen (no `core_tb` on chip)
- [ ] Full 64 KiB memory inference or sync-read + wait-state policy
- [ ] UART MMIO (optional) for debug

---

## 9. Open decisions log

| ID | Question | Decision | Date |
|----|----------|----------|------|
| D1 | Harvard vs Von Neumann | **Harvard** | 2026-06-01 |
| D2 | Reset PC | **`0x0000_0000`** | 2026-06-01 |
| D3 | Memory sizes & map | **64 KiB instr @ 0x0, 64 KiB data @ 0x8000_0000** | 2026-06-01 |
| D4 | ECALL/EBREAK behavior | **Halt (PC stops); v1 ECALL = EBREAK** | 2026-06-01 |
| D5 | Misaligned load/store | **No trap; SW/LW must be aligned in software** | 2026-06-01 |
| D6 | Simulation toolchain | **Verilator primary, Icarus secondary** | 2026-06-01 |
| D7 | First test program | **`mem_sum5` → x11 = 15** | 2026-06-01 |
| D8 | FPGA timing (STA) | **~54–55 MHz** Artix-7 -1 @ 50 MHz constraint; **40 MHz** safe bring-up; see §8 | 2026-06-01 |

---

## 10. Revision history

| Date | Author | Summary |
|------|--------|---------|
| 2026-06-01 | Guide session | Initial spec from architecture discussion |
| 2026-06-01 | Guide session | Locked D1–D7: Harvard, memory map, Verilator, mem_sum5 |
| 2026-06-01 | Guide session | §3.4 `riscv_core` single-cycle datapath diagram |
| 2026-06-01 | Guide session | §7 integration TB; §8 Vivado STA ~54–55 MHz (Artix-7); D8 |
