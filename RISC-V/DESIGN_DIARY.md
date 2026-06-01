# RISC-V Processor — Design Diary

A chronological log of design sessions, decisions, and open questions.  
**Spec:** [SPEC.md](SPEC.md) — when a decision is final, update the spec and check items off there.

---

## How to use this diary

1. **Each session** gets a dated entry below (newest at top after the template).
2. Record what we discussed, what you decided, and what’s next.
3. Move settled **TBD** items from the spec’s [§9 Open decisions](SPEC.md#9-open-decisions-log) into both places.
4. I (your guide) will append/update entries as we work together.

---

## Session template (copy for new entries)

```markdown
### YYYY-MM-DD — <short title>

**Participants:** you / guide  
**Phase:** architecture | RTL | verification | FPGA  

#### What we did
-

#### Decisions
-

#### Open questions
-

#### Next steps
- [ ]
```

---

## 2026-06-01 — FPGA timing (Vivado STA, Artix-7)

**Participants:** you / guide  
**Phase:** FPGA / verification  

#### What we did

- Ran **Vivado 2024.1** (`/mnt/hw/tools/amd/2024.1/...`) post-route STA on single-cycle `riscv_core` for Artix-7.
- Added `fpga/timing_synth.tcl`, `fpga/run_timing.sh`, `fpga/riscv_core_sta_top.sv`.
- Documented results in [SPEC.md §8](SPEC.md#8-fpga--synthesis).

#### Decisions

| Topic | Result |
|-------|--------|
| **D8 Fmax (STA)** | **~54 MHz** (XC7A35T), **~55 MHz** (XC7A100T) at 50 MHz constraint; WNS +1.6–1.9 ns |
| **Safe FPGA clock** | **40 MHz** first; **50 MHz** if board timing matches STA netlist |
| **Critical path** | `pc_reg` → fetch/decode/ALU/branch → `pc_reg` (~18.1 ns data path in report) |
| **STA netlist** | `FPGA_TIMING_SYNTH`: 16 KiB BRAM, `program.hex` in IMEM, `dbg_pc`, no `opt_design` trim |

#### Notes / pitfalls

- Synthesizing **`riscv_core` alone** with empty IMEM → Vivado **deleted the whole CPU** (0 LUTs). Fix: load `program.hex` + probe port / `dont_touch`.
- Full **64 KiB** byte comb-read memories did not infer cleanly in first synthesis; production FPGA needs BRAM-focused memory RTL and a fresh STA run.
- **`FPGA_TIMING_SYNTH`** is Vivado-only; Verilator sim uses full 64 KiB behavioral memories unchanged.

#### Next steps

- [ ] Board top + `.xdc` (Arty/Nexys), `halt_0` → LED
- [ ] 64 KiB BRAM init for bitstream; re-run `./fpga/run_timing.sh`
- [ ] Decide sync BRAM + stall vs keep comb-read for v1 FPGA

---

## 2026-06-01 — Integration sim (`core_tb`, mem_sum5 / sort8 / gcd)

**Participants:** you / guide  
**Phase:** verification  

#### What we did

- `sim/core_tb.sv`: `$readmemh` for instr, data preload, `run_program()` for three tests.
- `make core_sim` — all pass: **mem_sum5**, **mem_sort8** (bubble sort 8 words), **mem_gcd** (JAL/JALR).
- Renamed core port **`halt_o` → `halt_0`**.

#### Next steps

- [x] `core_tb` run until `halt_0` on EBREAK
- [ ] Waveforms / ILA on FPGA when board top exists

---

## 2026-06-01 — `riscv_core` datapath diagram (SPEC §3.4)

**Participants:** you / guide  
**Phase:** architecture / RTL integration  

#### What we did

- Captured the single-cycle **`riscv_core`** wiring diagram in [SPEC.md §3.4](SPEC.md#34-block-diagram--riscv_core-single-cycle-target-wiring) and this diary.
- Diagram shows: `instr_mem` fetch → `control` / `imm_gen` / `regfile` → ALU muxes → `data_mem` / write-back → PC mux → `pc_reg`.
- Documented signal-flow table (fetch, decode, execute, mem, WB, next PC) and LUI/AUIPC `alu_a` rules.

#### Decisions

- **Integration target:** build `riscv_core.sv` to match §3.4; add `instr_mem.sv` and `data_mem.sv` next.
- **Bring-up order:** PC + fetch → ADDI/EBREAK → ADD → LUI → LW/SW → BNE → `mem_sum5`.

#### Next steps

- [x] Implement `instr_mem.sv` + `data_mem.sv`
- [x] Write `riscv_core.sv` shell (PC, instances, WB mux, PC mux)
- [x] `core_tb` run until `halt_0` on EBREAK (see integration entry above)

#### Reference diagram

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

---

## 2026-06-01 — `riscv_pkg` completed

**Participants:** you / guide  
**Phase:** RTL  

#### What we did

- Filled `rtl/riscv_pkg.sv`: widths, memory map, opcodes, funct3/7, SYSTEM imm, enums (`alu_op_t`, `wb_sel_t`, `mem_size_t`, `pc_sel_t`, `imm_type_t`).

#### Next steps

- [ ] Lint/sim import smoke test
- [ ] Write `alu.sv` using `alu_op_t`
- [ ] Write `control.sv` decode using `OPCODE_*` / `F3_*`

---

## 2026-06-01 — Architecture decisions (memory, sim, test)

**Participants:** you / guide  
**Phase:** architecture  

#### What we did

- Compared **Harvard vs Von Neumann** for single-cycle v1.
- Chose **reset PC**, **64 KiB** instr/data regions, and **Verilator** as primary sim (Icarus as backup).
- Defined first program **`mem_sum5`** and staged instruction bring-up.

#### Decisions

| Topic | Decision | Rationale |
|-------|----------|-----------|
| **D1 Memory** | **Harvard** | Separate fetch vs load/store; simplest single-cycle RTL; no arbiter |
| **D2 Reset PC** | **`0x0000_0000`** | Code at bottom of map; industry-default mental model |
| **D3 Sizes / map** | **64 KiB instr @ 0x0**, **64 KiB data @ 0x8000_0000** | Room for tests; clear split in dumps; decode in `data_mem` |
| **D6 Simulator** | **Verilator** (+ Icarus optional) | Both on host (Verilator 5.044, Icarus 11.0); Verilator fast/strict |
| **D7 Test program** | **`mem_sum5`** | Exercises ALU, LUI, LW, ADDI, BNE, EBREAK; golden **x11 = 15** |
| **D4 EBREAK** | **Halt PC** | Easy for TB to stop |
| **D5 Misalign** | **No hardware trap** | Defer exception unit |

**Von Neumann note:** Revisit when pipelining or when you want one `.hex` for unified memory; can mux PC and LSU on one RAM with stall on conflict.

#### Open questions

- Async vs sync reset style in RTL
- Branch compare inside ALU vs separate comparator (document when ALU is written)

#### Next steps

- [ ] Start `riscv_pkg` + **`alu`** module and Verilator smoke TB
- [ ] Sketch datapath with Harvard ports labeled
- [ ] Write `mem_sum5` asm (or ask guide to review your draft)
- [ ] Fill SPEC §5.2 control rows for: ADDI, ADD, LUI, LW, BNE, EBREAK

---

## 2026-06-01 — Project kickoff & architecture framing

**Participants:** you / guide  
**Phase:** architecture  

#### Context

- Project lives under `Personal_runs/RISC-V/`.
- You asked for guide-mode help (not auto-generated RTL); processor sources will be written by you with review.
- Created living **SPEC.md** and this **DESIGN_DIARY.md** for ongoing updates.

#### What we did

- Framed a typical learning path: **RV32I**, machine-only, **single-cycle** first, pipeline later.
- Introduced canonical blocks: PC, instr mem, decode, regfile, ALU, data mem, control, WB/PC muxes.
- Listed control signals and a minimum instruction checklist for v1.
- Outlined verification approach (small asm program → expand to riscv-tests).

#### Proposed defaults (not locked — confirm when ready)

| Topic | Proposal |
|-------|----------|
| ISA | RV32I |
| Microarchitecture | Single-cycle v1 |
| Privilege | Machine only |
| Endianness | Little-endian |
| Pipeline later | 5-stage with forwarding/hazards |

#### Decisions

- Superseded by **2026-06-01 — Architecture decisions** entry above.

#### Open questions

- Resolved in follow-up session (see decision index).

#### Next steps

- [x] Confirm defaults → see architecture decisions entry.
- [ ] Sketch datapath on paper (label PC_MUX, WB_MUX, ALU_B_MUX).
- [ ] Fill SPEC §5.2 control rows for mem_sum5 insn set.

---

## Decision index (quick reference)

| ID | Summary | Status | Spec section |
|----|---------|--------|--------------|
| D1 | Memory organization | **Harvard** | §3.2, §9 |
| D2 | Reset vector | **0x0000_0000** | §2, §9 |
| D3 | Memory map | **64K @ 0x0 + 64K @ 0x8000_0000** | §3.3, §9 |
| D4 | System insn behavior | **EBREAK/ECALL halt** | §2.1, §9 |
| D5 | Misaligned access | **No trap (SW/LW aligned)** | §3.2, §9 |
| D6 | Simulator | **Verilator (+ Icarus)** | §7, §9 |
| D7 | First program | **mem_sum5 (x11=15)** | §7.1, §9 |
| D8 | FPGA STA Fmax | **~54–55 MHz** (Artix-7 -1); **40 MHz** safe | §8, §9 |

---

## Backlog (ideas for later versions)

- 5-stage pipeline (IF/ID/EX/MEM/WB)
- Hazard detection + forwarding
- M extension
- CSR + simple exceptions / interrupts
- UART MMIO for printf-style bring-up
- FPGA board top + bitstream (see SPEC §8.5)
- Full 64 KiB BRAM + production STA re-characterization

---

## Revision history

| Date | Change |
|------|--------|
| 2026-06-01 | Created diary; Session 1 kickoff entry |
| 2026-06-01 | Session 2: locked D1–D7 in SPEC |
| 2026-06-01 | `riscv_core` datapath diagram → SPEC §3.4 + diary entry |
| 2026-06-01 | `core_tb` + mem_sum5/sort8/gcd; FPGA Vivado STA → SPEC §8, D8 |
