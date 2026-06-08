class hdmi_tx_hpd_glitch_test extends hdmi_tx_base_test;
  `uvm_component_utils(hdmi_tx_hpd_glitch_test)
  function new(string name, uvm_component parent); super.new(name, parent); endfunction

  virtual task run_phase(uvm_phase phase);
    hdmi_tx_sink_connect_seq     sink;
    hdmi_tx_sink_hpd_glitch_seq  glitch;
    hdmi_tx_link_bringup_seq     bring;
    hdmi_tx_vid_frame_seq        vid;

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

    glitch = hdmi_tx_sink_hpd_glitch_seq::type_id::create("glitch");
    glitch.glitch_cycles = 64;
    glitch.start(env.sink_agt.sqr);

    #500;
    env.sb.link_active_seen = 1'b0;
    poll_link_active();
    deep_audit_regs();

    #2000;
    phase.drop_objection(this);
  endtask
endclass
