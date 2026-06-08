// SPEC.md programming helpers — included in hdmi_tx_env_pkg
function automatic void apply_spec_phase(
    input  spec_phase_e phase,
    inout  hdmi_tx_env_config cfg
);
  cfg.fast_edid  = 1'b1;
  cfg.fast_scdc  = 1'b1;
  cfg.fast_lt    = 1'b1;
  cfg.deep_check_en = 1'b1;
  cfg.min_phy_beats = 8;
  cfg.min_vid_pixels = 64;
  cfg.fsm_trace_samples = 64;
  cfg.link_timeout_cycles = 8000;

  unique case (phase)
    SPEC_PHASE1: begin
      cfg.hdmi22_sink     = 1'b0;
      cfg.vic             = SPEC_VIC_4K60;
      cfg.pix_fmt         = PIX_RGB888;
      cfg.bpc             = 4'd8;
      cfg.link_cfg        = 32'h0;
      cfg.ultra96_cfg     = 32'h0;
      cfg.lip_latency_ms  = 16'd0;
      cfg.expect_frl      = 1'b0;
      cfg.expect_tmds_valid = 1'b1;
      cfg.expect_vrr      = 1'b0;
      cfg.expect_allm     = 1'b0;
      cfg.expect_dsc      = 1'b0;
      cfg.expect_lip      = 1'b0;
      cfg.expect_fec      = 1'b0;
      cfg.expect_96g      = 1'b0;
    end

    SPEC_PHASE2: begin
      cfg.hdmi22_sink     = 1'b0;
      cfg.vic             = SPEC_VIC_4K120;
      cfg.pix_fmt         = PIX_YUV422;
      cfg.bpc             = 4'd10;
      cfg.link_cfg        = (1 << SPEC_LNK_FORCE_FRL) |
                            (1 << SPEC_LNK_VRR_REQ)   |
                            (1 << SPEC_LNK_ALLM_REQ);
      cfg.ultra96_cfg     = 32'h0;
      cfg.lip_latency_ms  = 16'd0;
      cfg.expect_frl      = 1'b1;
      cfg.expect_vrr      = 1'b1;
      cfg.expect_allm     = 1'b1;
      cfg.expect_dsc      = 1'b0;
      cfg.expect_lip      = 1'b0;
      cfg.expect_fec      = 1'b0;
      cfg.expect_96g      = 1'b0;
      cfg.expect_tmds_valid = 1'b0;
    end

    SPEC_PHASE2B: begin
      cfg.hdmi22_sink     = 1'b0;
      cfg.vic             = SPEC_VIC_4K120;
      cfg.pix_fmt         = PIX_RGB101010;
      cfg.bpc             = 4'd10;
      cfg.link_cfg        = (1 << SPEC_LNK_FORCE_FRL) |
                            (1 << SPEC_LNK_DSC_REQ)   |
                            (1 << SPEC_LNK_VRR_REQ)   |
                            (1 << SPEC_LNK_ALLM_REQ);
      cfg.ultra96_cfg     = 32'h0;
      cfg.lip_latency_ms  = 16'd0;
      cfg.expect_frl      = 1'b1;
      cfg.expect_dsc      = 1'b1;
      cfg.expect_vrr      = 1'b1;
      cfg.expect_allm     = 1'b1;
      cfg.expect_lip      = 1'b0;
      cfg.expect_fec      = 1'b0;
      cfg.expect_96g      = 1'b0;
    end

    SPEC_PHASE3: begin
      cfg.hdmi22_sink     = 1'b1;
      cfg.ultra96_cfg     = (3 << SPEC_U96_TIER_LSB) | (1 << SPEC_U96_SIM_HDMI22);
      cfg.lip_latency_ms  = 16'd10;
      cfg.vic             = SPEC_VIC_4K120;
      cfg.pix_fmt         = PIX_RGB101010;
      cfg.bpc             = 4'd10;
      cfg.link_cfg        = (1 << SPEC_LNK_FORCE_FRL) |
                            (1 << SPEC_LNK_DSC_REQ)   |
                            (1 << SPEC_LNK_VRR_REQ)   |
                            (1 << SPEC_LNK_ALLM_REQ)  |
                            (1 << SPEC_LNK_LIP_REQ)   |
                            (1 << SPEC_LNK_FEC_REQ)   |
                            (1 << SPEC_LNK_FORCE_96G);
      cfg.expect_frl      = 1'b1;
      cfg.expect_96g      = 1'b1;
      cfg.expect_vrr      = 1'b1;
      cfg.expect_allm     = 1'b1;
      cfg.expect_dsc      = 1'b1;
      cfg.expect_lip      = 1'b1;
      cfg.expect_fec      = 1'b1;
    end
  endcase
endfunction
