# HDMI TX — Phases 1–3 Complete

HDMI transmitter RTL: **TMDS**, **FRL 48G**, **FRL 96G (HDMI 2.2 class)**, DSC, VRR/ALLM, LIP, RS-FEC scaffold.

## Quick start

**RTL exhaustive smoke (Verilator, 76 checks):**

```bash
cd Personal_runs/hdmi_tx_2_2/sim
make all   # TMDS, FRL48, DSC, 96G, reg R/W, no-HPD, pixel matrix
```

**UVM verification (VCS / Xcelium / Questa):**

```bash
cd Personal_runs/hdmi_tx_2_2/uvm
make SIM=vcs TEST=hdmi_tx_hdmi22_full_test run   # complete HDMI 2.2 (default)
make SIM=vcs TEST=hdmi_tx_spec_regression_test run
make SIM=vcs regress
```

See `uvm/README.md` for the full test list and environment structure.

## Phases

| Phase | Features |
|-------|----------|
| 1 | TMDS 4K@60, EDID/DDC, scrambling |
| 2 | FRL 48G, mode calc, VRR/ALLM, 10bpc/YUV422 |
| 2b | Unified `hdmi_ddc_bus` (EDID+SCDC), DSC encoder |
| 3 | FRL 96G, Ultra96 tier, LIP, RS-FEC |

## Key modules

- `rtl/ddc/hdmi_ddc_bus.sv` — shared I²C for EDID + SCDC
- `rtl/video/hdmi_dsc_{pps,encoder,wrap}.sv` — compression path
- `rtl/packet/hdmi_lip_gen.sv` — HDMI 2.2 latency metadata
- `rtl/link/hdmi_frl_fec.sv` — FEC on FRL lane 0

## Registers

See `SPEC.md` §4. Highlights:

- `0x18` — link features (force_frl, dsc, vrr, allm, lip, fec, force_96g)
- `0x20` — Ultra96 tier + `sim_hdmi22` for TB
- `0x24` — LIP source latency (ms)
- `0x28` — DSC compression ratio + max FRL Gbps

## Licensing

Commercial HDMI products require HDMI Forum / HDMI LA adoption.
