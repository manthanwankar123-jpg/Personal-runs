// Spec-to-spec checker — each function maps to SPEC.md section
class hdmi_tx_spec_validator extends uvm_object;
  `uvm_object_utils(hdmi_tx_spec_validator)

  spec_phase_e active_phase;
  int err_cnt;

  function new(string name = "hdmi_tx_spec_validator");
    super.new(name);
  endfunction

  function void reset();
    err_cnt = 0;
  endfunction

  // SPEC §4 — register map bit-accurate audit
  function void check_reg_map(
      input bit [31:0] status,
      input bit [31:0] feat,
      input bit [31:0] link,
      input bit [31:0] dsc,
      input bit [31:0] lip_stat,
      input hdmi_tx_env_config cfg
  );
    if (!status[SPEC_STS_HPD])
      report_err("SPEC-§4-STATUS", "STATUS[3] hpd deasserted");
    if (!status[SPEC_STS_LINK_ACTIVE])
      report_err("SPEC-§4-STATUS", "STATUS[2] link_active deasserted");
    if (!status[SPEC_STS_EDID_DONE] && !feat[SPEC_FEAT_HDR_OK])
      report_warn("SPEC-§4-STATUS", "STATUS[1] edid_done / header_ok");

    if (feat[SPEC_FEAT_VIC_MSB:SPEC_FEAT_VIC_LSB] != cfg.vic)
      report_err("SPEC-§4-FEAT", $sformatf("FEAT vic exp=%0d got=%0d",
               cfg.vic, feat[SPEC_FEAT_VIC_MSB:SPEC_FEAT_VIC_LSB]));

    if (link[SPEC_LINK_MODE_MSB:SPEC_LINK_MODE_LSB] == LINK_TMDS) begin
      if (feat[SPEC_FEAT_FRL])
        report_err("SPEC-§4-FEAT", "FEAT[13] frl set in TMDS mode");
      if (link[SPEC_LANES_MSB:SPEC_LANES_LSB] != 3'd3)
        report_err("SPEC-§4-LINK", "TMDS requires 3 lanes per §1 Phase1");
    end else if (link[SPEC_LINK_MODE_MSB:SPEC_LINK_MODE_LSB] == LINK_FRL) begin
      if (!feat[SPEC_FEAT_FRL])
        report_err("SPEC-§4-FEAT", "FEAT[13] frl clear in FRL mode");
      if (link[SPEC_LANES_MSB:SPEC_LANES_LSB] != 3'd4)
        report_err("SPEC-§4-LINK", "FRL requires 4 lanes");
    end

    if (cfg.expect_vrr && !feat[SPEC_FEAT_VRR])
      report_err("SPEC-§1-Phase2", "VRR not enabled (FEAT[11])");
    if (cfg.expect_allm && !feat[SPEC_FEAT_ALLM])
      report_err("SPEC-§1-Phase2", "ALLM not enabled (FEAT[10])");
    if (cfg.expect_dsc && !feat[SPEC_FEAT_DSC])
      report_warn("SPEC-§2.2-DSC", "DSC not enabled (FEAT[12]) — check bandwidth");
    if (cfg.expect_lip && !feat[SPEC_FEAT_LIP])
      report_err("SPEC-§3.2-LIP", "LIP not enabled (FEAT[15])");
    if (cfg.expect_fec && !feat[SPEC_FEAT_FEC])
      report_warn("SPEC-§3.3-FEC", "FEC scaffold idle (FEAT[14]) — OK for Phase 3 scaffold");

    if (cfg.expect_96g) begin
      if (link[SPEC_FRL_RATE_MSB:SPEC_FRL_RATE_LSB] != FRL_RATE_24G)
        report_err("SPEC-§3.1-96G", $sformatf("FRL rate exp 24G got %0d",
                 link[SPEC_FRL_RATE_MSB:SPEC_FRL_RATE_LSB]));
      if (dsc[SPEC_DSC_GBPS_MSB:SPEC_DSC_GBPS_LSB] != SPEC_MAX_GBPS_96)
        report_err("SPEC-§3.1-Ultra96", $sformatf("max_frl_gbps exp 96 got %0d",
                 dsc[SPEC_DSC_GBPS_MSB:SPEC_DSC_GBPS_LSB]));
    end else if (cfg.expect_frl) begin
      if (dsc[SPEC_DSC_GBPS_MSB:SPEC_DSC_GBPS_LSB] != SPEC_MAX_GBPS_48)
        report_err("SPEC-§1-Phase2", $sformatf("max_frl_gbps exp 48 got %0d",
                 dsc[SPEC_DSC_GBPS_MSB:SPEC_DSC_GBPS_LSB]));
    end

    if (cfg.expect_lip && lip_stat[15:0] != cfg.lip_latency_ms)
      report_err("SPEC-§3.2-LIP", $sformatf("LIP_CFG readback exp=%0d got=%0d",
               cfg.lip_latency_ms, lip_stat[15:0]));

    if (cfg.expect_dsc && dsc[SPEC_DSC_RATIO_MSB:SPEC_DSC_RATIO_LSB] >= 8'd100)
      report_warn("SPEC-§2.2-DSC", $sformatf("DSC ratio=%0d (§2.2: drive video DE)",
               dsc[SPEC_DSC_RATIO_MSB:SPEC_DSC_RATIO_LSB]));
  endfunction

  // SPEC §5 — bring-up FSM path
  function void check_fsm_path(
      input int unsigned fsm_seen[0:8],
      input bit expect_frl
  );
    int i, len;
    tx_state_e st;
    len = spec_fsm_len(expect_frl);

    if (fsm_seen[TX_READ_EDID] == 0)
      report_err("SPEC-§5-FSM", "missing TX_READ_EDID (EDID §2.1)");
    if (fsm_seen[TX_SCDC_CFG] == 0)
      report_err("SPEC-§5-FSM", "missing TX_SCDC_CFG (§2.1 SCDC)");
    if (expect_frl && fsm_seen[TX_FRL_LT] == 0)
      report_err("SPEC-§5-FSM", "missing TX_FRL_LT (§2.1 FRL LT)");
    if (!expect_frl && fsm_seen[TX_FRL_LT] > 0)
      report_warn("SPEC-§5-FSM", "unexpected TX_FRL_LT in TMDS path");
    if (fsm_seen[TX_ACTIVE] == 0)
      report_err("SPEC-§5-FSM", "missing TX_ACTIVE");
  endfunction

  // SPEC §1 feature matrix — phase-specific mandatory checks
  function void check_phase_caps(
      input bit [31:0] link,
      input bit [31:0] feat,
      input bit [31:0] dsc,
      input int phy_beats,
      input int tmds_beats,
      input hdmi_tx_env_config cfg
  );
    unique case (active_phase)
      SPEC_PHASE1: begin
        if (link[SPEC_LINK_MODE_MSB:SPEC_LINK_MODE_LSB] != LINK_TMDS)
          report_err("SPEC-§1-P1", "Phase1 requires LINK_TMDS");
        if (cfg.vic != SPEC_VIC_4K60)
          report_err("SPEC-§1-P1", "Phase1 requires VIC 97 (4K@60)");
        if (cfg.pix_fmt != PIX_RGB888)
          report_err("SPEC-§1-P1", "Phase1 requires RGB888");
        if (tmds_beats == 0)
          report_err("SPEC-§1-P1", "Phase1 requires TMDS symbol activity");
      end

      SPEC_PHASE2: begin
        if (link[SPEC_LINK_MODE_MSB:SPEC_LINK_MODE_LSB] != LINK_FRL)
          report_err("SPEC-§1-P2", "Phase2 requires LINK_FRL");
        if (!feat[SPEC_FEAT_VRR] || !feat[SPEC_FEAT_ALLM])
          report_err("SPEC-§1-P2", "Phase2 requires VRR+ALLM");
        if (cfg.bpc != 4'd10)
          report_err("SPEC-§1-P2", "Phase2 requires 10bpc");
        if (dsc[SPEC_DSC_GBPS_MSB:SPEC_DSC_GBPS_LSB] != SPEC_MAX_GBPS_48)
          report_err("SPEC-§1-P2", "Phase2 requires 48 Gbps cap");
      end

      SPEC_PHASE2B: begin
        if (!cfg.link_cfg[SPEC_LNK_DSC_REQ])
          report_err("SPEC-§2-P2b", "Phase2b requires LINK_CFG[dsc]");
        if (phy_beats < 8)
          report_err("SPEC-§2-P2b", "Phase2b requires PHY activity");
      end

      SPEC_PHASE3: begin
        if (link[SPEC_FRL_RATE_MSB:SPEC_FRL_RATE_LSB] != FRL_RATE_24G)
          report_err("SPEC-§3-P3", "Phase3 requires FRL_RATE_24G (96G)");
        if (!feat[SPEC_FEAT_LIP])
          report_err("SPEC-§3-P3", "Phase3 requires LIP (§3.2)");
        if (dsc[SPEC_DSC_GBPS_MSB:SPEC_DSC_GBPS_LSB] != SPEC_MAX_GBPS_96)
          report_err("SPEC-§3-P3", "Phase3 requires Ultra96-96 tier");
      end
    endcase
  endfunction

  function void report_err(string id, string msg);
    err_cnt++;
    `uvm_error(id, msg)
  endfunction

  function void report_warn(string id, string msg);
    `uvm_warning(id, msg)
  endfunction

endclass
