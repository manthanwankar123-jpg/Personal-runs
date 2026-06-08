// Exhaustive audit: all link modes, register map, FSM trace, PHY + video data path
class hdmi_tx_full_check_test extends hdmi_tx_base_test;
  `uvm_component_utils(hdmi_tx_full_check_test)

  string scenarios[$];

  function new(string name, uvm_component parent);
    super.new(name, parent);
    scenarios.push_back("tmds");
    scenarios.push_back("frl48");
    scenarios.push_back("dsc");
    scenarios.push_back("gaming");
    scenarios.push_back("lip");
    scenarios.push_back("frl96");
  endfunction

  virtual function void configure(hdmi_tx_env_config c);
    super.configure(c);
    c.min_phy_beats    = 16;
    c.min_vid_pixels   = 128;
    c.fsm_trace_samples = 64;
    c.link_timeout_cycles = 8000;
  endfunction

  virtual task run_phase(uvm_phase phase);
    int i;
    phase.raise_objection(this);
    foreach (scenarios[i]) begin
      `uvm_info(get_type_name(), $sformatf("===== FULL CHECK: %s =====", scenarios[i]), UVM_NONE)
      env.sb.reset_scenario_stats();
      apply_scenario(scenarios[i]);
      run_scenario();
      if (env.sb.err_cnt != 0)
        `uvm_error(get_type_name(), $sformatf("scenario %s failed", scenarios[i]))
      if (i != scenarios.size()-1)
        soft_reset_link();
    end
    phase.drop_objection(this);
  endtask

  task run_scenario();
    hdmi_tx_sink_connect_seq sink;
    hdmi_tx_link_bringup_seq bring;
    hdmi_tx_vid_stress_seq   vid;

    sink = hdmi_tx_sink_connect_seq::type_id::create("sink");
    sink.start(env.sink_agt.sqr);
    bring = hdmi_tx_link_bringup_seq::type_id::create("bring");
    bring.start(env.reg_agt.sqr);
    vid = hdmi_tx_vid_stress_seq::type_id::create("vid");
    vid.frames = 3;
    vid.line_len = 96;
    fork vid.start(env.vid_agt.sqr); join_none

    poll_link_active();
    env.sb.sample_fsm_trace(cfg.fsm_trace_samples);
    deep_audit_regs();
    #2000;
  endtask

  function void apply_scenario(string name);
    configure(cfg);
    case (name)
      "tmds": begin
        cfg.vic = 8'd97; cfg.link_cfg = 0;
        cfg.expect_frl = 0; cfg.expect_tmds_valid = 1;
        cfg.min_vid_pixels = 64;
      end
      "frl48": begin
        cfg.vic = 8'd119; cfg.pix_fmt = 2; cfg.bpc = 10;
        cfg.link_cfg = 32'hF; cfg.expect_frl = 1;
        cfg.expect_vrr = 1; cfg.expect_allm = 1;
      end
      "dsc": begin
        cfg.vic = 8'd119; cfg.link_cfg = 32'h1F;
        cfg.expect_frl = 1; cfg.expect_dsc = 1;
      end
      "gaming": begin
        cfg.vic = 8'd119; cfg.link_cfg = 32'hF;
        cfg.expect_frl = 1; cfg.expect_vrr = 1; cfg.expect_allm = 1;
      end
      "lip": begin
        cfg.hdmi22_sink = 1; cfg.ultra96_cfg = 32'h7;
        cfg.link_cfg = 32'h51; cfg.expect_frl = 1; cfg.expect_lip = 1;
      end
      "frl96": begin
        cfg.hdmi22_sink = 1; cfg.ultra96_cfg = 32'h7;
        cfg.lip_latency_ms = 10;
        cfg.vic = 8'd119; cfg.link_cfg = 32'h7F;
        cfg.expect_frl = 1; cfg.expect_96g = 1;
        cfg.expect_vrr = 1; cfg.expect_allm = 1;
        cfg.expect_lip = 1; cfg.expect_fec = 1;
      end
      default: `uvm_fatal("FULL", name)
    endcase
    uvm_config_db#(hdmi_tx_env_config)::set(this, "*", "cfg", cfg);
    uvm_config_db#(hdmi_tx_env_config)::set(null, "uvm_test_top", "cfg", cfg);
    if (cfg.hdmi22_sink)
      void'(uvm_hdl_deposit("hdmi_tx_tb.hdmi22_sink", 1'b1));
    else
      void'(uvm_hdl_deposit("hdmi_tx_tb.hdmi22_sink", 1'b0));
  endfunction
endclass
