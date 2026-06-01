# risc-v — RV32I single-cycle core (v1)

Learning project: Harvard RV32I CPU in SystemVerilog, Verilator sim, optional Artix-7 FPGA timing.

**Location:** `Personal_runs/v1/RISC-V/`  
**Repository:** [github.com/manthanwankar123-jpg/risc-v](https://github.com/manthanwankar123-jpg/risc-v) (`V1` branch) · [manthan-architect/risc-v](https://github.com/manthan-architect/risc-v)

## Docs

- [SPEC.md](SPEC.md) — architecture and memory map
- [DESIGN_DIARY.md](DESIGN_DIARY.md) — session log and decisions

## Simulate

```bash
cd sim
make core_sim      # integration: mem_sum5, mem_sort8, mem_gcd
make alu_sim       # unit tests
```

Requires **Verilator** and **riscv64-unknown-elf-gcc** (to rebuild `prog/*.S` → `sim/*.hex`).

## FPGA timing (Vivado)

```bash
export VIVADO=/path/to/vivado
./fpga/run_timing.sh xc7a35tcsg324-1
```

See SPEC §8 for measured **~54–55 MHz** on Artix-7 (-1) and caveats for `FPGA_TIMING_SYNTH`.

## Layout

| Path | Contents |
|------|----------|
| `rtl/` | Core RTL |
| `sim/` | Testbenches and program images |
| `prog/` | Assembly sources |
| `fpga/` | Vivado timing scripts |
