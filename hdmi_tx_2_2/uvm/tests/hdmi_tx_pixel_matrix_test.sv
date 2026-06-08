class hdmi_tx_pixel_matrix_test extends hdmi_tx_base_test;
  `uvm_component_utils(hdmi_tx_pixel_matrix_test)

  function new(string name, uvm_component parent); super.new(name, parent); endfunction

  virtual task run_phase(uvm_phase phase);
    bit [1:0] fmts[$];
    bit [3:0] bpcs[$];
    int i, j;

    fmts.push_back(0); fmts.push_back(1); fmts.push_back(2);
    bpcs.push_back(8); bpcs.push_back(10);

    phase.raise_objection(this);

    for (i = 0; i < fmts.size(); i++) begin
      for (j = 0; j < bpcs.size(); j++) begin
        `uvm_info(get_type_name(), $sformatf("pix_fmt=%0d bpc=%0d", fmts[i], bpcs[j]), UVM_LOW)
        cfg.vic = 8'd119;
        cfg.pix_fmt = fmts[i];
        cfg.bpc = bpcs[j];
        cfg.link_cfg = 32'h01;
        cfg.expect_frl = 1;
        uvm_config_db#(hdmi_tx_env_config)::set(this, "*", "cfg", cfg);

        if (i > 0 || j > 0)
          soft_reset_link();

        run_one_matrix();
      end
    end

    phase.drop_objection(this);
  endtask

  task run_one_matrix();
    hdmi_tx_sink_connect_seq sink;
    hdmi_tx_link_bringup_seq bring;
    hdmi_tx_vid_stress_seq   vid;

    sink = hdmi_tx_sink_connect_seq::type_id::create("sink");
    sink.start(env.sink_agt.sqr);
    bring = hdmi_tx_link_bringup_seq::type_id::create("bring");
    bring.start(env.reg_agt.sqr);
    vid = hdmi_tx_vid_stress_seq::type_id::create("vid");
    vid.frames = 1; vid.line_len = 48;
    fork vid.start(env.vid_agt.sqr); join_none

    poll_link_active();
    deep_audit_regs();
    #1000;
  endtask
endclass
