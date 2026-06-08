# HDMI TX — Design Specification (Phase 2b / 3)

**Project:** `Personal_runs/hdmi_tx_2_2`  
**Active phase:** **Phase 2b + Phase 3 complete**  
**Status:** All phases implemented (sim verified)  
**RTL policy:** Own SystemVerilog; PHY external

---

## 1. Feature matrix

| Phase | Capability | Status |
|-------|------------|--------|
| 1 | TMDS 4K@60 RGB888 | Done |
| 2 | FRL 48G, VRR/ALLM, 10bpc, YUV422 | Done |
| 2b | Unified DDC bus + SCDC writes, DSC encoder | Done |
| 3 | FRL 96G (Ultra96), LIP, RS-FEC scaffold | Done |

---

## 2. Phase 2b — DDC + DSC

### 2.1 Unified DDC bus (`hdmi_ddc_bus`)

- Single I²C engine on `SCL`/`SDA` for **EDID** and **SCDC**
- EDID: `0xA0/0xA1` read 128 B
- SCDC: `0xA8/0xA9` writes — `SOURCE_VERSION`, `SOURCE_FRL_CONFIG`, `SOURCE_FRL_READY`
- Poll `SINK_FRL_STATUS` / timeout for `flt_ready`
- Sim shortcuts: `FAST_EDID`, `FAST_SCDC`

### 2.2 DSC encoder

| Module | Role |
|--------|------|
| `hdmi_dsc_pps` | PPS parameter block (16 B) |
| `hdmi_dsc_encoder` | Slice delta + nibble packing |
| `hdmi_dsc_wrap` | PPS on frame start + compressed stream mux |

Read `0x28[15:8]` for live compression ratio.

---

## 3. Phase 3 — HDMI 2.2 class

### 3.1 FRL 96 Gbps

- `FRL_RATE_24G` — 24 Gbps/lane × 4 = **96 Gbps**
- `ultra96_tier_e`: 48 / 64 / 80 / **96** Gbps policy cap
- `force_96g` register bit selects 24G rate when sink is HDMI 2.2

### 3.2 LIP (Latency Indication Protocol)

- `hdmi_lip_gen` — InfoFrame type 0x05, source/audio latency ms
- Enabled when `lip_req` + sink `sink_lip_capable` + HDMI 2.2 sink
- Program latency via `0x24`

### 3.3 RS-FEC

- `hdmi_frl_fec` — 240 B data + 16 B parity scaffold per FEC frame
- Enabled on 96G path via `fec_req` + HDMI 2.2 sink
- `fec_active` visible in `0x10[14]`

---

## 4. Register map

| Offset | Name | Description |
|--------|------|-------------|
| `0x00` | `CTRL` | `[0]` enable `[1]` soft_rst |
| `0x04` | `STATUS` | `[3]=hpd `[2]=link_active `[1]=edid_done |
| `0x0C` | `VIDEO_CFG` | vic, pix_fmt, bpc |
| `0x10` | `FEAT_STATUS` | `{lip,fec,frl,dsc,vrr,allm,...}` |
| `0x18` | `LINK_CFG` | force_frl, dsc/vrr/allm/lip/fec req, force_96g |
| `0x1C` | `LINK_STATUS` | link_mode, frl_rate, lanes |
| `0x20` | `ULTRA96_CFG` | `[1:0]` tier `[2]` sim_hdmi22 |
| `0x24` | `LIP_CFG` | source latency ms |
| `0x28` | `DSC_STATUS` | `[15:8]` ratio `[7:0]` max_frl_gbps |

---

## 5. Bring-up FSM

```
HPD → EDID → MODE_CALC → SCDC_CFG → FRL_LT → PROGRAM → ACTIVE
```

---

## 6. Verification

### 6.1 RTL smoke (Verilator)

```bash
cd Personal_runs/hdmi_tx_2_2/sim && make all
```

TB runs Phase 1 → 2 → 2b (DSC) → 3 (96G + LIP) with 76 spec-aligned checks.

### 6.2 UVM (spec-to-spec)

Each UVM test maps 1:1 to this document:

| Test | SPEC section | Requirements verified |
|------|--------------|----------------------|
| `hdmi_tx_hdmi22_full_test` | §1–§5 | **Primary** — single bring-up: 96G, DSC, VRR/ALLM, LIP, FEC, §4 map, §5 FSM |
| `hdmi_tx_spec_regression_test` | §6 | Full §1→§2→§2b→§3 multi-phase sequence |
| `hdmi_tx_spec_phase1_test` | §1 Phase 1 | TMDS 4K@60 RGB888, 3 lanes, §4 STATUS/FEAT/LINK |
| `hdmi_tx_spec_phase2_test` | §1 Phase 2 | FRL 48G, VRR/ALLM, 10bpc YUV422, max 48 Gbps |
| `hdmi_tx_spec_phase2b_test` | §2 | DDC+SCDC FSM (§2.1), DSC ratio (§2.2, `0x28`) |
| `hdmi_tx_spec_phase3_test` | §3 | FRL 96G/24G×4, LIP (`0x24`), FEC (`0x10[14]`), Ultra96 |

```bash
cd Personal_runs/hdmi_tx_2_2/uvm
make SIM=vcs TEST=hdmi_tx_hdmi22_full_test run      # complete HDMI 2.2 (default)
make SIM=vcs TEST=hdmi_tx_spec_regression_test run  # all phases in one test
make SIM=vcs regress
```

Spec constants and validators: `uvm/spec/hdmi_tx_spec_pkg.sv`, `hdmi_tx_spec_validator.sv`.

---

## 7. Module list

```
rtl/ddc/hdmi_ddc_bus.sv      # unified EDID + SCDC
rtl/video/hdmi_dsc_*.sv      # PPS + encoder + wrap
rtl/packet/hdmi_lip_gen.sv   # HDMI 2.2 LIP
rtl/link/hdmi_frl_fec.sv     # RS-FEC scaffold
```

---

## 8. Open items (silicon)

| Item | Notes |
|------|-------|
| Full VESA DSC entropy coding | Replace slice heuristic with licensed IP |
| GF(2^8) RS-FEC | Match HDMI exact polynomial |
| SCDC read of sink `flt_ready` | Requires sink model / retimer |

---

*Document version: 3.0 — 2026-06-08*
