# v2 — Open-source reference architectures

We **do not** copy RTL from these projects. We study their **partitioning**, **trap model**, and **verification flow**, then implement our own SystemVerilog design in `v2/RISC-V/`.

Commercial cores (**SiFive P470**, **Ventana Veyron**) are **not** open source — ISA and toolchain only.

| Project | Language | Class | Study for v2 |
|---------|----------|-------|----------------|
| [CVA6](https://github.com/openhwgroup/cva6) (Ariane) | SV | In-order 6-stage, optional MMU | Pipeline staging, CSR/trap bring-up, AXI, Linux path |
| [VexRiscv](https://github.com/SpinalHDL/VexRiscv) | SpinalHDL | Configurable MCU→Linux | Plugin pipeline, bus wrappers, config matrix |
| [BOOM / SonicBOOM](https://github.com/riscv-boom/riscv-boom) | Chisel | OoO research | Hazard logic ideas, not our first target |
| [SoomRV](https://github.com/mathis-s/SoomRV) | **SystemVerilog** | 4-wide OoO, boots Linux | Closest style to our RTL; priv spec + mem ordering notes |
| [NEORV32](https://github.com/stnolting/neorv32) | VHDL | MCU SoC | Simple SoC map, UART, timer, onboarding |
| [PicoRV32](https://github.com/YosysHQ/picorv32) | Verilog | Tiny | Reset/IRQ minimalism (contrast only) |

## What we borrow (ideas only)

| Topic | Primary reference | Our v2 choice |
|-------|-----------------|---------------|
| Pipeline shape | CVA6, textbooks | Classic **5-stage** (IF ID EX MEM WB) |
| CSR + traps | Privileged spec + CVA6/NEORV32 | **M-mode** only first |
| SoC bus | CVA6, NEORV32 | **AXI4-Lite** (or AHB) fabric |
| Verification | riscv-tests, Spike | **riscv-tests** + optional Spike diff |
| RTOS proof | NEORV32, SoomRV | **FreeRTOS** or **Zephyr** on FPGA (phase 2c) |

## Links

- [RISC-V unprivileged spec](https://riscv.org/technical/specifications/)
- [RISC-V privileged spec](https://riscv.org/technical/specifications/)
- [riscv-tests](https://github.com/riscv-software-src/riscv-tests)
- [Spike](https://github.com/riscv-software-src/riscv-isa-sim) (golden model)
- [Awesome RISC-V list](https://github.com/suryakantamangaraj/AwesomeRISC-VResources)
