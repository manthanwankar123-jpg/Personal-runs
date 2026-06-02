# v2 RISC-V — timing-first microarchitecture

**Targets:** **200 MHz** core on Artix-7 and Kintex UltraScale+; **~65 MHz** post-synth on [ICsprout55 55 nm](../asic/icsprout55-pdk); **~250 MHz** post-synth on [ASAP7 7 nm](https://github.com/The-OpenROAD-Project/asap7).

## Design rules (timing-first)

1. **No combinational memory read into pipeline registers.** Loads are **2 cycles minimum** (addr latch → registered read/extract → WB) under `FPGA_TIMING_SYNTH`.
2. **Instruction fetch is 2 cycles** (PC → distributed ROM addr → registered `if_rdata`). Core holds IF/ID with `fetch_pc_hold`.
3. **No MEM→EX load forwarding.** Stall EX when a load is active in MEM or pending.
4. **Forward only registered pipeline values:** EX/MEM ALU (non-load), MEM/WB (non-CSR). No comb CSR forward.
5. **Branch/jal in EX** using dedicated **compare**. Target = **`id_ex_target`** latched in ID/EX. JALR uses **`id_ex_jalr_base`** when rs1 needs no forward.
6. **Traps in EX** (illegal/ecall/ebreak); misalign check in MEM before load issue.
7. **Memory:** distributed RAM (FPGA); byte arrays (sim). ASIC flow uses [mem_stub](../asic/mem_stub.sv) for synthesis.
8. **PC mux:** trap > redirect (`pc_redirect` / `pc_plus4`) > sequential. **`dbg_pc` / `trap_entered` output-registered.**

## Pipeline

```text
IF (pc, sync imem) → IF/ID → ID (decode, reg read, hazard)
  → ID/EX → EX (forward, ALU, branch, trap)
  → EX/MEM → MEM (load FSM, store) → MEM/WB → WB (reg + CSR)
```

## Timing results

| Platform | Condition | WNS | Est. Fmax |
|----------|-----------|-----|-----------|
| FPGA XC7A200T-3 | 50 MHz P&R | +9.99 ns | ~100 MHz |
| FPGA XC7A200T-3 | 100 MHz report | +0.99 ns | meets |
| FPGA XC7A200T-3 | 200 MHz report (core) | +1.58 ns | ~290 MHz |
| FPGA XCKU3P-3 | 50 MHz P&R | +18.56 ns | ~696 MHz |
| FPGA XCKU3P-3 | 100 MHz report | +8.56 ns | meets |
| FPGA XCKU3P-3 | 200 MHz report (core) | +3.56 ns | meets |
| ASIC ICsprout55 typ | 50 MHz post-synth STA | +4.75 ns | **~66 MHz** |
| ASIC ICsprout55 typ | 100 MHz post-synth STA | −5.25 ns | ~66 MHz |
| ASIC ASAP7 RVT TT | 50 MHz post-synth STA | +16.24 ns | **~266 MHz** |
| ASIC ASAP7 RVT TT | 200 MHz post-synth STA | +1.24 ns | meets |
| ASIC ASAP7 RVT TT | 250 MHz post-synth STA | +0.24 ns | meets |

FPGA critical path @ 200 MHz: `pc_reg` → `pc_plus4` → `pc_next` (both parts).  
ASIC critical path (both PDKs, post-synth): IF/ID decode → pipeline enable.

## Load FSM (MEM, FPGA)

| Cycle | Action |
|-------|--------|
| 0 | Load in `ex_mem`; assert `mem_re`; latch addr; snapshot metadata; `load_issue_stall` |
| 1 | `mem_load_ready`; capture data to `mem_wb` |

## Hazards

| Hazard | Action |
|--------|--------|
| Load-use (load in EX, use in ID) | Stall IF/ID, bubble ID/EX |
| Load in MEM/pending, use in EX | `mem_load_stall` |
| CSR in WB, use in ID | `wb_csr_stall` |
| Branch/jal/jalr taken | Flush IF/ID, redirect PC |
| Trap | Flush IF/ID/EX/MEM |

Sim: comb byte RAM (1-cycle load). FPGA: Vivado STA. ASIC: Yosys + OpenSTA — see [asic/README.md](../asic/README.md).
