// SPEC.md §6 — TB runs Phase 1 → 2 → 2b (DSC) → 3 (96G + LIP)
class hdmi_tx_spec_regression_test extends hdmi_tx_base_test;
  `uvm_component_utils(hdmi_tx_spec_regression_test)

  spec_phase_e phases[$];
  hdmi_tx_spec_validator spec_v;

  function new(string name, uvm_component parent);
    super.new(name, parent);
    phases.push_back(SPEC_PHASE1);
    phases.push_back(SPEC_PHASE2);
    phases.push_back(SPEC_PHASE2B);
    phases.push_back(SPEC_PHASE3);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    spec_v = hdmi_tx_spec_validator::type_id::create("spec_v");
    cfg.deep_check_en = 1'b1;
    cfg.spec_mode     = 1'b1;
    cfg.link_timeout_cycles = 10000;
  endfunction

  virtual task run_phase(uvm_phase phase);
    int i;
    phase.raise_objection(this);

    foreach (phases[i]) begin
      `uvm_info("SPEC-§6", $sformatf("===== %s =====", phase_name(phases[i])), UVM_NONE)
      env.sb.reset_scenario_stats();
      spec_v.active_phase = phases[i];
      spec_v.reset();
      apply_spec_phase(phases[i], cfg);
      uvm_config_db#(hdmi_tx_env_config)::set(this, "*", "cfg", cfg);
      uvm_config_db#(hdmi_tx_env_config)::set(null, "uvm_test_top", "cfg", cfg);
      if (cfg.hdmi22_sink)
        void'(uvm_hdl_deposit("hdmi_tx_tb.hdmi22_sink", 1'b1));
      else
        void'(uvm_hdl_deposit("hdmi_tx_tb.hdmi22_sink", 1'b0));

      run_spec_phase();
      audit_spec_phase();

      if (spec_v.err_cnt != 0)
        `uvm_error("SPEC-§6", $sformatf("%s failed", phase_name(phases[i])))

      if (i != phases.size()-1)
        soft_reset_link();
    end

    `uvm_info("SPEC-§6", "SPEC regression sequence complete (§1→§2→§2b→§3)", UVM_NONE)
    phase.drop_objection(this);
  endtask

  task run_spec_phase();
    hdmi_tx_sink_connect_seq sink;
    hdmi_tx_link_bringup_seq bring;
    hdmi_tx_vid_stress_seq   vid;

    sink = hdmi_tx_sink_connect_seq::type_id::create("sink");
    sink.start(env.sink_agt.sqr);
    bring = hdmi_tx_link_bringup_seq::type_id::create("bring");
    bring.start(env.reg_agt.sqr);
    vid = hdmi_tx_vid_stress_seq::type_id::create("vid");
    vid.frames   = (cfg.expect_dsc) ? 8 : 3;
    vid.line_len = (cfg.expect_dsc) ? 3840 : 128;
    fork vid.start(env.vid_agt.sqr); join_none

    poll_link_active();
    #((cfg.expect_dsc) ? 5000 : 2000);
  endtask

  task audit_spec_phase();
    hdmi_tx_reg_audit_seq audit;
    hdmi_tx_reg_read_seq  rd;
    bit [31:0] lip_stat;

    audit = hdmi_tx_reg_audit_seq::type_id::create("audit");
    audit.start(env.reg_agt.sqr);
    rd = hdmi_tx_reg_read_seq::type_id::create("rd");
    rd.addr = SPEC_REG_LIP_STAT;
    rd.start(env.reg_agt.sqr);
    lip_stat = rd.rdata;

    env.sb.note_regs(audit.status, audit.link, audit.feat, audit.dsc, lip_stat);
    spec_v.check_reg_map(audit.status, audit.feat, audit.link, audit.dsc, lip_stat, cfg);
    spec_v.check_phase_caps(audit.link, audit.feat, audit.dsc,
                            env.sb.phy_beat_cnt, env.sb.tmds_beat_cnt, cfg);
    spec_v.check_fsm_path(env.sb.fsm_state_seen, cfg.expect_frl);
  endtask

  function void check_phase(uvm_phase phase);
    `uvm_info("SPEC-§6", "Per-phase spec audit done in run_phase", UVM_LOW)
  endfunction
endclass
