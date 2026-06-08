`uvm_analysis_imp_decl(_reg)
`uvm_analysis_imp_decl(_phy)
`uvm_analysis_imp_decl(_vid)

class hdmi_tx_checker extends uvm_scoreboard;
  `uvm_component_utils(hdmi_tx_checker)

  uvm_analysis_imp_reg #(hdmi_tx_reg_item, hdmi_tx_checker) reg_imp;
  uvm_analysis_imp_phy #(hdmi_tx_phy_item, hdmi_tx_checker) phy_imp;
  uvm_analysis_imp_vid #(hdmi_tx_vid_item, hdmi_tx_checker) vid_imp;

  hdmi_tx_env_config cfg;
  hdmi_tx_ref_model  refm;
  hdmi_tx_ref_model::exp_state_t exp;

  virtual hdmi_tx_fsm_if fsm_vif;

  bit [31:0] last_status, last_link, last_feat, last_dsc, last_lip;
  int unsigned phy_beat_cnt;
  int unsigned tmds_beat_cnt;
  int unsigned vid_pixel_cnt;
  int unsigned fsm_state_seen [0:8];
  int        err_cnt;
  bit        link_active_seen;
  bit        fsm_mon_en;

  function new(string name, uvm_component parent);
    super.new(name, parent);
    reg_imp = new("reg_imp", this);
    phy_imp = new("phy_imp", this);
    vid_imp = new("vid_imp", this);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    void'(uvm_config_db#(hdmi_tx_env_config)::get(this, "", "cfg", cfg));
    void'(uvm_config_db#(virtual hdmi_tx_fsm_if)::get(this, "", "fsm_vif", fsm_vif));
    refm = hdmi_tx_ref_model::type_id::create("refm");
    fsm_mon_en = (fsm_vif != null);
  endfunction

  task run_phase(uvm_phase phase);
    if (fsm_mon_en) begin
      fork
        forever begin
          @(fsm_vif.mon_cb);
          sample_fsm_state(fsm_vif.mon_cb.state);
        end
      join_none
    end
  endtask

  function void sample_fsm_state(bit [3:0] st);
    if (st <= 8)
      fsm_state_seen[st]++;
  endfunction

  task sample_fsm_trace(int unsigned samples);
    // Legacy API — FSM states sampled continuously in run_phase via fsm_vif
  endtask

  function void write_reg(hdmi_tx_reg_item tr);
    if (tr.op == REG_READ) begin
      case (tr.addr)
        REG_STATUS:    last_status = tr.data;
        REG_LINK_STAT: last_link    = tr.data;
        REG_FEAT:      last_feat    = tr.data;
        REG_DSC_STAT:  last_dsc     = tr.data;
        REG_LIP:       last_lip     = tr.data;
        default: ;
      endcase
      if (tr.addr == REG_STATUS && tr.data[2])
        link_active_seen = 1'b1;
    end
  endfunction

  function void write_phy(hdmi_tx_phy_item tr);
    if (tr.valid) begin
      phy_beat_cnt++;
      if (tr.is_frl && cfg.expect_frl && !last_feat[13] && last_feat != 0)
        `uvm_warning("CHK", "phy_is_frl during FRL beats")
    end
    if (tr.tmds_valid)
      tmds_beat_cnt++;
  endfunction

  function void write_vid(hdmi_tx_vid_item tr);
    if (tr.de)
      vid_pixel_cnt++;
  endfunction

  function void reset_scenario_stats();
    err_cnt = 0;
    link_active_seen = 0;
    phy_beat_cnt = 0;
    tmds_beat_cnt = 0;
    vid_pixel_cnt = 0;
    foreach (fsm_state_seen[i]) fsm_state_seen[i] = 0;
  endfunction

  function void note_regs(
      bit [31:0] status, link, feat, dsc, lip = 32'h0
  );
    string msg;
    last_status = status;
    last_link   = link;
    last_feat   = feat;
    last_dsc    = dsc;
    last_lip    = lip;
    if (status[2]) link_active_seen = 1'b1;

    if (!cfg.spec_mode) begin
      exp = refm.predict_active(cfg);
      if (!refm.compare_regs(exp, status, link, feat, dsc, msg))
        `uvm_warning("CHK", $sformatf("register mismatch:%s", msg))
    end
  endfunction

  function void check_phase(uvm_phase phase);
    string msg;
    super.check_phase(phase);
    if (cfg.spec_mode)
      return;

    if (!link_active_seen) begin
      `uvm_error("CHK", "link_active never asserted")
      err_cnt++;
    end

    if (phy_beat_cnt < cfg.min_phy_beats) begin
      `uvm_error("CHK", $sformatf("phy beats %0d < min %0d", phy_beat_cnt, cfg.min_phy_beats))
      err_cnt++;
    end

    if (cfg.expect_tmds_valid && tmds_beat_cnt == 0)
      `uvm_error("CHK", "no TMDS symbol activity")

    if (err_cnt == 0)
      `uvm_info("CHK", "Checker passed", UVM_LOW)
  endfunction
endclass
