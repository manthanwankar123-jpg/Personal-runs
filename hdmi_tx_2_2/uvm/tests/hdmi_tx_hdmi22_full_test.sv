// Authoritative HDMI 2.2 TX test — §1–§3 + §4 register map + §5 FSM in one bring-up
// Exercises: FRL 96G, Ultra96, DSC, VRR, ALLM, LIP, FEC scaffold, full video stress
class hdmi_tx_hdmi22_full_test extends hdmi_tx_spec_phase_base_test;
  `uvm_component_utils(hdmi_tx_hdmi22_full_test)

  function new(string name, uvm_component parent);
    super.new(name, parent);
    spec_phase = SPEC_PHASE3;
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    cfg.spec_mode           = 1'b1;
    cfg.min_phy_beats       = 32;
    cfg.video_lines         = 32;
    cfg.link_timeout_cycles = 12000;
  endfunction

  virtual function void end_of_elaboration_phase(uvm_phase phase);
    super.end_of_elaboration_phase(phase);
    void'(uvm_hdl_deposit("hdmi_tx_tb.hdmi22_sink", 1'b1));
  endfunction

  virtual task run_phase(uvm_phase phase);
    hdmi_tx_sink_connect_seq sink;
    hdmi_tx_link_bringup_seq bring;
    hdmi_tx_vid_stress_seq   vid;

    phase.raise_objection(this);

    sink = hdmi_tx_sink_connect_seq::type_id::create("sink");
    sink.start(env.sink_agt.sqr);

    bring = hdmi_tx_link_bringup_seq::type_id::create("bring");
    bring.start(env.reg_agt.sqr);

    vid = hdmi_tx_vid_stress_seq::type_id::create("vid");
    vid.frames   = 10;
    vid.line_len = 3840;
    fork vid.start(env.vid_agt.sqr); join_none

    poll_link_active();
    #8000;
    deep_audit_regs();

    if (env.sb.phy_beat_cnt < cfg.min_phy_beats)
      `uvm_error(get_type_name(), $sformatf("PHY beats %0d < %0d", env.sb.phy_beat_cnt, cfg.min_phy_beats))

    if (env.sb.fsm_state_seen[TX_READ_EDID] == 0 ||
        env.sb.fsm_state_seen[TX_SCDC_CFG]  == 0 ||
        env.sb.fsm_state_seen[TX_FRL_LT]    == 0 ||
        env.sb.fsm_state_seen[TX_ACTIVE]    == 0)
      `uvm_error(get_type_name(), "HDMI 2.2 FSM path incomplete (§5)")

    `uvm_info(get_type_name(), "HDMI 2.2 full feature test complete", UVM_NONE)
    phase.drop_objection(this);
  endtask

  function void check_phase(uvm_phase phase);
    `uvm_info(get_type_name(), "Spec audit done in run_phase", UVM_LOW)
  endfunction
endclass
