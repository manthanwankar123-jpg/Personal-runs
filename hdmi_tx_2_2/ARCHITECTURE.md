# HDMI TX — Micro-Architecture

**Active:** Phase 2 (FRL 48G + DSC + VRR/ALLM)  
**Phase 1:** TMDS 4K@60 — retained as fallback path

---

## 1. Clock domains

| Domain | Modules |
|--------|---------|
| `axi_clk` | FSM, DDC, SCDC, mode_calc, EDID parser, audio |
| `vid_clk` | `hdmi_vid_csc`, `hdmi_dsc_wrap` |
| `link_clk` | packetizer, TMDS/FRL link, InfoFrames |

---

## 2. Bring-up FSM

```
RESET → WAIT_HPD → READ_EDID → MODE_CALC → SCDC_CFG → [FRL_LT] → PROGRAM → ACTIVE
                                                      ↑ if LINK_FRL
```

TMDS path skips `FRL_LT`. `PROGRAM` enables scrambling only for TMDS.

---

## 3. Mode calculator

Inputs: EDID sink caps, `VIDEO_CFG` (vic, pix_fmt, bpc), `LINK_CFG` (force_frl, dsc/vrr/allm req).

Rules:
- `bw > 18 Gbps` or `force_frl` → **FRL** if sink supports
- Else → **TMDS**
- DSC when `dsc_req` and bandwidth exceeds ~80% of FRL capacity

---

## 4. Link layers

| Mode | Module | PHY output |
|------|--------|------------|
| TMDS | `hdmi_tmds_link` | 10-bit codes in `phy_data[*][9:0]` |
| FRL | `hdmi_frl_link` | 16-bit characters on 4 lanes |

`hdmi_link_mux` drives unified `phy_data[0:3]` + `phy_is_frl`.

---

## 5. FRL link training (`hdmi_frl_lt`)

| Step | Action |
|------|--------|
| LTS1 | Capability exchange (SCDC) |
| LTS2 | Wait `phy_ready` |
| LTS3 | Test patterns, wait `flt_ready` from SCDC |
| LTS4 | Video ready |

Sim shortcuts: `FAST_SCDC`, `FAST_LT` parameters.

---

## 6. Video path

`hdmi_vid_csc` formats:
- `PIX_RGB888` — 24-bit in `vid_data[23:0]`
- `PIX_YUV422` — packed 16-bit in upper bytes
- `PIX_RGB101010` — 30-bit in `vid_data[29:0]`

`hdmi_dsc_wrap` bypasses when `dsc_en=0`; when set, expects compressed bytes on `dsc_byte`/`dsc_valid`.

---

## 7. Gaming metadata

`hdmi_gaming_meta` + AVI InfoFrame PB2 bits signal VRR/DSC.
`LINK_CFG` bits enable VRR/ALLM when sink capable (from EDID parser).

---

## 8. Registers

See `SPEC.md` §4. Key: `VIDEO_CFG` @ `0x0C`, `LINK_CFG` @ `0x18`, `LINK_STATUS` @ `0x1C`.

---

*Architecture version: 2.0 — Phase 2*
