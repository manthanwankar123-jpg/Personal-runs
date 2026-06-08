class hdmi_tx_ref_model extends uvm_object;
  `uvm_object_utils(hdmi_tx_ref_model)

  typedef struct {
    bit        link_active;
    bit        hpd;
    link_mode_e link_mode;
    bit [2:0]   lane_count;
    bit         vrr_en;
    bit         allm_en;
    bit         lip_en;
    bit         phy_is_frl;
    bit [7:0]   vic;
    bit [7:0]   max_gbps;
  } exp_state_t;

  function new(string name = "hdmi_tx_ref_model");
    super.new(name);
  endfunction

  function exp_state_t predict_active(hdmi_tx_env_config cfg);
    exp_state_t e;
    bit use_frl;
    bit hdmi22;

    e.link_active = 1'b1;
    e.hpd         = 1'b1;
    e.vic         = cfg.vic;
    hdmi22        = cfg.hdmi22_sink || cfg.ultra96_cfg[2];

    use_frl = cfg.link_cfg[0] || cfg.link_cfg[6];
    if (!use_frl && (cfg.vic == 8'd119 || cfg.vic == 8'd120))
      use_frl = 1'b1;

    if (use_frl) begin
      e.link_mode  = LINK_FRL;
      e.phy_is_frl = 1'b1;
      e.lane_count = 3'd4;
      e.max_gbps   = (cfg.expect_96g || cfg.link_cfg[6]) ? 8'd96 : 8'd48;
    end else begin
      e.link_mode  = LINK_TMDS;
      e.phy_is_frl = 1'b0;
      e.lane_count = 3'd3;
      e.max_gbps   = 8'd18;
    end

    e.vrr_en  = cfg.link_cfg[2];
    e.allm_en = cfg.link_cfg[3];
    e.lip_en  = cfg.link_cfg[4] && hdmi22;
    return e;
  endfunction

  function bit compare_regs(
      input exp_state_t exp,
      input bit [31:0] status,
      input bit [31:0] link,
      input bit [31:0] feat,
      input bit [31:0] dsc,
      output string msg
  );
    bit ok;
    ok  = 1'b1;
    msg = "";

    if (status[2] != exp.link_active)
      ok = 0; msg = {msg, " link_active"};
    if (status[3] != exp.hpd)
      ok = 0; msg = {msg, " hpd"};
    if (link[7:6] != exp.link_mode)
      ok = 0; msg = {msg, $sformatf(" link_mode(exp=%0d got=%0d)", exp.link_mode, link[7:6])};
    if (link[2:0] != exp.lane_count)
      ok = 0; msg = {msg, $sformatf(" lanes(exp=%0d got=%0d)", exp.lane_count, link[2:0])};
    if (feat[7:0] != exp.vic)
      ok = 0; msg = {msg, $sformatf(" vic(exp=%0d got=%0d)", exp.vic, feat[7:0])};
    if (feat[11] != exp.vrr_en)
      ok = 0; msg = {msg, " vrr"};
    if (feat[10] != exp.allm_en)
      ok = 0; msg = {msg, " allm"};
    if (feat[15] != exp.lip_en)
      ok = 0; msg = {msg, " lip"};
    if (feat[13] != exp.phy_is_frl)
      ok = 0; msg = {msg, " phy_is_frl_feat"};
    if (dsc[7:0] != exp.max_gbps && exp.link_mode == LINK_FRL)
      ok = 0; msg = {msg, $sformatf(" max_gbps(exp=%0d got=%0d)", exp.max_gbps, dsc[7:0])};
    return ok;
  endfunction
endclass
