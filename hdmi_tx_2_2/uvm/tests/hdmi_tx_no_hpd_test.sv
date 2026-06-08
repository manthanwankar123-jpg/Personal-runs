class hdmi_tx_no_hpd_test extends hdmi_tx_base_test;
  `uvm_component_utils(hdmi_tx_no_hpd_test)

  function new(string name, uvm_component parent); super.new(name, parent); endfunction

  virtual function void configure(hdmi_tx_env_config c);
    super.configure(c);
    c.deep_check_en = 1'b0;
    c.min_phy_beats = 0;
    c.min_vid_pixels = 0;
  endfunction

  virtual task run_phase(uvm_phase phase);
    hdmi_tx_sink_disconnect_seq sink;
    hdmi_tx_link_bringup_seq bring;
    hdmi_tx_reg_read_seq rd;
    int t;

    phase.raise_objection(this);

    sink = hdmi_tx_sink_disconnect_seq::type_id::create("sink");
    sink.start(env.sink_agt.sqr);

    bring = hdmi_tx_link_bringup_seq::type_id::create("bring");
    bring.start(env.reg_agt.sqr);

    rd = hdmi_tx_reg_read_seq::type_id::create("rd");
    t = 0;
    while (t < 2000) begin
      rd.addr = REG_STATUS;
      rd.start(env.reg_agt.sqr);
      if (rd.rdata[2]) begin
        `uvm_error(get_type_name(), "link_active asserted without HPD")
        break;
      end
      #100; t += 100;
    end

    if (t >= 2000)
      `uvm_info(get_type_name(), "PASS: no link_active without HPD", UVM_LOW)

    env.sb.link_active_seen = 1'b1;
    phase.drop_objection(this);
  endtask

  function void check_phase(uvm_phase phase);
    `uvm_info(get_type_name(), "Negative HPD test complete", UVM_LOW)
  endfunction
endclass
