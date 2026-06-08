# HDMI TX 2.2 — UVM Verification (SPEC-aligned)

UVM environment with **spec-to-spec** traceability to `SPEC.md` v3.0.

## Spec traceability

| SPEC.md | UVM artifact |
|---------|--------------|
| §1 Feature matrix | `hdmi_tx_spec_phase{1,2,2b,3}_test` |
| §2 DDC + DSC | `hdmi_tx_spec_phase2b_test`, validator `SPEC-§2-*` |
| §3 96G / LIP / FEC | `hdmi_tx_spec_phase3_test`, validator `SPEC-§3-*` |
| §4 Register map | `hdmi_tx_spec_pkg.sv`, `hdmi_tx_reg_defs.sv` |
| §5 Bring-up FSM | `hdmi_tx_spec_validator::check_fsm_path()` |
| §6 Verification order | `hdmi_tx_spec_regression_test` |

## Run spec tests

```bash
cd Personal_runs/hdmi_tx_2_2/uvm

# Single phase (pick one)
make SIM=vcs TEST=hdmi_tx_spec_phase1_test run   # §1 Phase 1
make SIM=vcs TEST=hdmi_tx_spec_phase2_test run   # §1 Phase 2
make SIM=vcs TEST=hdmi_tx_spec_phase2b_test run  # §2
make SIM=vcs TEST=hdmi_tx_spec_phase3_test run   # §3

# Full spec sequence (§6)
make SIM=vcs TEST=hdmi_tx_spec_regression_test run
make SIM=vcs regress
```

## Structure

```
uvm/spec/           # SPEC.md constants + validator
uvm/tests/          # hdmi_tx_spec_phase*_test.sv (primary)
uvm/check/          # Runtime checker (PHY, video, registers)
uvm/ref/            # Reference model
```

## What each spec test checks

**Phase 1** — `LINK_TMDS`, VIC 97, RGB888, 3 lanes, TMDS symbols, §4 STATUS bits.

**Phase 2** — `LINK_FRL`, 4 lanes, 48 Gbps cap, VRR+ALLM (FEAT[11:10]), 10bpc YUV422.

**Phase 2b** — §5 FSM through SCDC_CFG; DSC armed; `0x28[15:8]` compression ratio.

**Phase 3** — `FRL_RATE_24G`, 96 Gbps tier, LIP (FEAT[15] + `0x2C`), FEC (FEAT[14]).

**Regression** — Runs all four phases in §6 order with soft-reset between.

Legacy tests (`hdmi_tx_tmds_test`, etc.) remain for backward compatibility but are not in the primary `regress.list`.
