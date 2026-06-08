class hdmi_tx_base_test extends uvm_test;
  `uvm_component_utils(hdmi_tx_base_test)

  hdmi_tx_env        env;
  hdmi_tx_env_config cfg;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    cfg = hdmi_tx_env_config::type_id::create("cfg");
    configure(cfg);
    uvm_config_db#(hdmi_tx_env_config)::set(this, "*", "cfg", cfg);
    uvm_config_db#(hdmi_tx_env_config)::set(null, "uvm_test_top", "cfg", cfg);
    env = hdmi_tx_env::type_id::create("env", this);
  endfunction

  virtual function void end_of_elaboration_phase(uvm_phase phase);
    super.end_of_elaboration_phase(phase);
    if (cfg.hdmi22_sink)
      void'(uvm_hdl_deposit("hdmi_tx_tb.hdmi22_sink", 1'b1));
  endfunction

  virtual function void configure(hdmi_tx_env_config c);
    c.fast_edid   = 1'b1;
    c.fast_scdc   = 1'b1;
    c.fast_lt     = 1'b1;
    c.hdmi22_sink = 1'b0;
    c.vic         = 8'd97;
    c.pix_fmt     = 0;
    c.bpc         = 4'd8;
    c.link_cfg    = 32'h0;
    c.ultra96_cfg = 32'h0;
    c.lip_latency_ms = 16'd5;
    c.link_timeout_cycles = 5000;
    c.video_lines = 8;
    c.min_phy_beats = 8;
    c.min_vid_pixels = 64;
    c.fsm_trace_samples = 48;
    c.deep_check_en = 1'b1;
  endfunction

  virtual task run_phase(uvm_phase phase);
    hdmi_tx_sink_connect_seq  sink;
    hdmi_tx_link_bringup_seq  bring;
    hdmi_tx_vid_stress_seq    vid;

    phase.raise_objection(this);

    sink = hdmi_tx_sink_connect_seq::type_id::create("sink");
    sink.start(env.sink_agt.sqr);

    bring = hdmi_tx_link_bringup_seq::type_id::create("bring");
    bring.start(env.reg_agt.sqr);

    vid = hdmi_tx_vid_stress_seq::type_id::create("vid");
    vid.frames   = 2;
    vid.line_len = cfg.video_lines * 16;
    fork vid.start(env.vid_agt.sqr); join_none

    poll_link_active();
    #500;
    deep_audit_regs();

    #3000;
    phase.drop_objection(this);
  endtask

  task poll_link_active();
    hdmi_tx_reg_read_seq rd;
    int t;
    t = 0;
    rd = hdmi_tx_reg_read_seq::type_id::create("rd");
    while (t < cfg.link_timeout_cycles) begin
      rd.addr = REG_STATUS;
      rd.start(env.reg_agt.sqr);
      if (rd.rdata[2]) break;
      #100;
      t += 100;
    end
    if (t >= cfg.link_timeout_cycles)
      `uvm_error(get_type_name(), "link_active timeout")
  endtask

  task deep_audit_regs();
    hdmi_tx_reg_audit_seq audit;
    audit = hdmi_tx_reg_audit_seq::type_id::create("audit");
    audit.start(env.reg_agt.sqr);
    env.sb.note_regs(audit.status, audit.link, audit.feat, audit.dsc, audit.lip);
  endtask

  task soft_reset_link();
    hdmi_tx_reg_write_seq wr;
    hdmi_tx_reg_read_seq  rd;
    int t;

    wr = hdmi_tx_reg_write_seq::type_id::create("wr");
    wr.addr = REG_CTRL;     wr.data = 32'h0; wr.start(env.reg_agt.sqr);
    wr.addr = REG_LINK_CFG; wr.data = 32'h0; wr.start(env.reg_agt.sqr);
    wr.addr = REG_ULTRA96;  wr.data = 32'h0; wr.start(env.reg_agt.sqr);

    t = 0;
    rd = hdmi_tx_reg_read_seq::type_id::create("rd");
    while (t < cfg.link_timeout_cycles) begin
      rd.addr = REG_STATUS;
      rd.start(env.reg_agt.sqr);
      if (!rd.rdata[2]) break;
      #100;
      t += 100;
    end
    #500;
    env.sb.reset_scenario_stats();
  endtask
endclass
