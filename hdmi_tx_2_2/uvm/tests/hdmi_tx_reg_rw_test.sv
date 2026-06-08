class hdmi_tx_reg_rw_test extends hdmi_tx_base_test;
  `uvm_component_utils(hdmi_tx_reg_rw_test)

  function new(string name, uvm_component parent); super.new(name, parent); endfunction

  virtual task run_phase(uvm_phase phase);
    hdmi_tx_reg_write_seq wr;
    hdmi_tx_reg_read_seq  rd;
    bit [31:0] rdata;

    phase.raise_objection(this);

    wr = hdmi_tx_reg_write_seq::type_id::create("wr");
    rd = hdmi_tx_reg_read_seq::type_id::create("rd");

    wr.addr = REG_VIDEO_CFG;
    wr.data = {18'b0, 4'd10, 2'd1, 8'd119};
    wr.start(env.reg_agt.sqr);

    wr.addr = REG_LINK_CFG; wr.data = 32'h0000_001F; wr.start(env.reg_agt.sqr);
    wr.addr = REG_ULTRA96;  wr.data = 32'h0000_0003; wr.start(env.reg_agt.sqr);
    wr.addr = REG_LIP;      wr.data = 32'h0000_0007; wr.start(env.reg_agt.sqr);

    rd.addr = REG_VIDEO_CFG; rd.start(env.reg_agt.sqr);
    if (rd.rdata[7:0] != 8'd119 || rd.rdata[9:8] != 2'd1 || rd.rdata[13:10] != 4'd10)
      `uvm_error("REG_RW", $sformatf("VIDEO_CFG readback %08h", rd.rdata))

    rd.addr = REG_LIP; rd.start(env.reg_agt.sqr);
    if (rd.rdata[15:0] != 16'd7)
      `uvm_error("REG_RW", "LIP readback failed")

    cfg.vic = 8'd119; cfg.pix_fmt = 1; cfg.bpc = 10;
    cfg.link_cfg = 32'h1F; cfg.ultra96_cfg = 32'h3;
    cfg.lip_latency_ms = 7; cfg.expect_frl = 1; cfg.expect_dsc = 1;
    cfg.hdmi22_sink = 1;

    void'(uvm_hdl_deposit("hdmi_tx_tb.hdmi22_sink", 1'b1));

    begin
      hdmi_tx_sink_connect_seq  s;
      hdmi_tx_link_bringup_seq  b;
      hdmi_tx_vid_stress_seq    v;
      s = hdmi_tx_sink_connect_seq::type_id::create("s");
      s.start(env.sink_agt.sqr);
      b = hdmi_tx_link_bringup_seq::type_id::create("b");
      b.start(env.reg_agt.sqr);
      v = hdmi_tx_vid_stress_seq::type_id::create("v");
      v.frames = 2; v.line_len = 64;
      fork v.start(env.vid_agt.sqr); join_none
      poll_link_active();
      env.sb.sample_fsm_trace(cfg.fsm_trace_samples);
      deep_audit_regs();
      #2000;
    end

    phase.drop_objection(this);
  endtask
endclass
