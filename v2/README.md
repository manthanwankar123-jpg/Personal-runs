# RISC-V v2 (planned)

Next-generation core: pipelined RV32IMC-class MCU profile, traps/CSRs, SoC bus, and commercial-style verification.

**Status:** Not started — planning only.

## References

- v1 implementation: [../v1/RISC-V/](../v1/RISC-V/)
- Roadmap discussion: see v1 `SPEC.md` / `DESIGN_DIARY.md`; v2 spec TBD here.

## Target profile (draft)

- RV32IMC + Zicsr, M-mode
- 5-stage pipeline, forwarding, unified memory / AXI-Lite SoC
- CLINT + IRQ, debug, riscv-tests, RTOS demo on FPGA
