class hdmi_tx_soft_reset_test extends hdmi_tx_base_test;
  `uvm_component_utils(hdmi_tx_soft_reset_test)
  function new(string name, uvm_component parent); super.new(name, parent); endfunction

  virtual task run_phase(uvm_phase phase);
    hdmi_tx_sink_connect_seq  sink;
    hdmi_tx_link_bringup_seq  bring;
    hdmi_tx_vid_frame_seq     vid;
    hdmi_tx_reg_write_seq     wr;

    phase.raise_objection(this);

    sink = hdmi_tx_sink_connect_seq::type_id::create("sink");
    sink.start(env.sink_agt.sqr);
    bring = hdmi_tx_link_bringup_seq::type_id::create("bring");
    bring.start(env.reg_agt.sqr);
    vid = hdmi_tx_vid_frame_seq::type_id::create("vid");
    vid.lines = cfg.video_lines;
    fork vid.start(env.vid_agt.sqr); join_none

    poll_link_active();
    deep_audit_regs();

    soft_reset_link();

    wr = hdmi_tx_reg_write_seq::type_id::create("wr");
    wr.addr = REG_CTRL; wr.data = 32'h0000_0001;
    wr.start(env.reg_agt.sqr);

    poll_link_active();
    deep_audit_regs();

    #2000;
    phase.drop_objection(this);
  endtask
endclass
