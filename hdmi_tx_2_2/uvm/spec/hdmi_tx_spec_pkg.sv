// Verification package — traceable to SPEC.md v3.0 (§1–§6)
package hdmi_tx_spec_pkg;

  import hdmi_tx_pkg::*;

  // -------------------------------------------------------------------------
  // §1 Feature matrix phases
  // -------------------------------------------------------------------------
  typedef enum int {
    SPEC_PHASE1  = 1,  // TMDS 4K@60 RGB888
    SPEC_PHASE2  = 2,  // FRL 48G, VRR/ALLM, 10bpc, YUV422
    SPEC_PHASE2B = 3,  // Unified DDC + SCDC, DSC encoder
    SPEC_PHASE3  = 4   // FRL 96G, LIP, RS-FEC
  } spec_phase_e;

  // -------------------------------------------------------------------------
  // §4 Register map — offsets (SPEC.md §4)
  // -------------------------------------------------------------------------
  localparam bit [7:0] SPEC_REG_CTRL      = 8'h00;
  localparam bit [7:0] SPEC_REG_STATUS    = 8'h04;
  localparam bit [7:0] SPEC_REG_VIDEO_CFG = 8'h0C;
  localparam bit [7:0] SPEC_REG_FEAT      = 8'h10;
  localparam bit [7:0] SPEC_REG_LINK_CFG  = 8'h18;
  localparam bit [7:0] SPEC_REG_LINK_STAT = 8'h1C;
  localparam bit [7:0] SPEC_REG_ULTRA96   = 8'h20;
  localparam bit [7:0] SPEC_REG_LIP_CFG   = 8'h24;
  localparam bit [7:0] SPEC_REG_DSC_STAT  = 8'h28;
  localparam bit [7:0] SPEC_REG_LIP_STAT  = 8'h2C;

  // §4 CTRL[1:0]
  localparam int SPEC_CTRL_EN      = 0;
  localparam int SPEC_CTRL_SOFTRST = 1;

  // §4 STATUS[3:1]
  localparam int SPEC_STS_HPD         = 3;
  localparam int SPEC_STS_LINK_ACTIVE = 2;
  localparam int SPEC_STS_EDID_DONE   = 1;

  // §4 VIDEO_CFG
  localparam int SPEC_VIC_MSB  = 7;
  localparam int SPEC_VIC_LSB  = 0;
  localparam int SPEC_FMT_MSB  = 9;
  localparam int SPEC_FMT_LSB  = 8;
  localparam int SPEC_BPC_MSB  = 13;
  localparam int SPEC_BPC_LSB  = 10;

  // §4 FEAT_STATUS — {lip,fec,frl,dsc,vrr,allm,...}
  localparam int SPEC_FEAT_LIP      = 15;
  localparam int SPEC_FEAT_FEC      = 14;
  localparam int SPEC_FEAT_FRL      = 13;
  localparam int SPEC_FEAT_DSC      = 12;
  localparam int SPEC_FEAT_VRR      = 11;
  localparam int SPEC_FEAT_ALLM     = 10;
  localparam int SPEC_FEAT_CEA      = 9;
  localparam int SPEC_FEAT_HDR_OK   = 8;
  localparam int SPEC_FEAT_VIC_MSB  = 7;
  localparam int SPEC_FEAT_VIC_LSB  = 0;

  // §4 LINK_CFG[6:0]
  localparam int SPEC_LNK_FORCE_FRL = 0;
  localparam int SPEC_LNK_DSC_REQ   = 1;
  localparam int SPEC_LNK_VRR_REQ   = 2;
  localparam int SPEC_LNK_ALLM_REQ  = 3;
  localparam int SPEC_LNK_LIP_REQ   = 4;
  localparam int SPEC_LNK_FEC_REQ   = 5;
  localparam int SPEC_LNK_FORCE_96G = 6;

  // §4 LINK_STATUS
  localparam int SPEC_LINK_MODE_MSB = 7;
  localparam int SPEC_LINK_MODE_LSB = 6;
  localparam int SPEC_FRL_RATE_MSB  = 5;
  localparam int SPEC_FRL_RATE_LSB  = 3;
  localparam int SPEC_LANES_MSB     = 2;
  localparam int SPEC_LANES_LSB     = 0;

  // §4 ULTRA96_CFG
  localparam int SPEC_U96_TIER_MSB    = 1;
  localparam int SPEC_U96_TIER_LSB    = 0;
  localparam int SPEC_U96_SIM_HDMI22  = 2;

  // §4 DSC_STATUS
  localparam int SPEC_DSC_RATIO_MSB = 15;
  localparam int SPEC_DSC_RATIO_LSB = 8;
  localparam int SPEC_DSC_GBPS_MSB  = 7;
  localparam int SPEC_DSC_GBPS_LSB  = 0;

  // §1 / video constants
  localparam bit [7:0] SPEC_VIC_4K60  = 8'd97;
  localparam bit [7:0] SPEC_VIC_4K120 = 8'd119;
  localparam bit [7:0] SPEC_MAX_GBPS_48 = 8'd48;
  localparam bit [7:0] SPEC_MAX_GBPS_96 = 8'd96;

  // §5 FSM path length (bring-up order per SPEC.md §5)
  localparam int SPEC_FSM_FRL_LEN  = 7;
  localparam int SPEC_FSM_TMDS_LEN = 6;

  function automatic tx_state_e spec_fsm_state(input bit expect_frl, input int idx);
    if (expect_frl) begin
      case (idx)
        0: return TX_WAIT_HPD;
        1: return TX_READ_EDID;
        2: return TX_MODE_CALC;
        3: return TX_SCDC_CFG;
        4: return TX_FRL_LT;
        5: return TX_PROGRAM;
        6: return TX_ACTIVE;
        default: return TX_RESET;
      endcase
    end else begin
      case (idx)
        0: return TX_WAIT_HPD;
        1: return TX_READ_EDID;
        2: return TX_MODE_CALC;
        3: return TX_SCDC_CFG;
        4: return TX_PROGRAM;
        5: return TX_ACTIVE;
        default: return TX_RESET;
      endcase
    end
  endfunction

  function automatic int spec_fsm_len(input bit expect_frl);
    return expect_frl ? SPEC_FSM_FRL_LEN : SPEC_FSM_TMDS_LEN;
  endfunction

  function automatic string phase_name(input spec_phase_e p);
    case (p)
      SPEC_PHASE1:  return "SPEC-§1-Phase1-TMDS";
      SPEC_PHASE2:  return "SPEC-§1-Phase2-FRL48";
      SPEC_PHASE2B: return "SPEC-§2-Phase2b-DSC";
      SPEC_PHASE3:  return "SPEC-§3-Phase3-96G";
      default:      return "SPEC-UNKNOWN";
    endcase
  endfunction

endpackage
