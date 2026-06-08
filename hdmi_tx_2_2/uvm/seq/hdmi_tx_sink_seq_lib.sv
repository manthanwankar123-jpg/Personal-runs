class hdmi_tx_sink_connect_seq extends uvm_sequence #(hdmi_tx_sink_item);
  `uvm_object_utils(hdmi_tx_sink_connect_seq)
  function new(string name = "hdmi_tx_sink_connect_seq"); super.new(name); endfunction
  task body();
    hdmi_tx_sink_item req;
    req = hdmi_tx_sink_item::type_id::create("req");
    start_item(req);
    assert(req.randomize() with { hpd == 1'b1; phy_ready == 1'b1; hpd_low_cycles == 0; });
    finish_item(req);
  endtask
endclass

class hdmi_tx_sink_disconnect_seq extends uvm_sequence #(hdmi_tx_sink_item);
  `uvm_object_utils(hdmi_tx_sink_disconnect_seq)
  function new(string name = "hdmi_tx_sink_disconnect_seq"); super.new(name); endfunction
  task body();
    hdmi_tx_sink_item req;
    req = hdmi_tx_sink_item::type_id::create("req");
    start_item(req);
    assert(req.randomize() with { hpd == 1'b0; phy_ready == 1'b1; hpd_low_cycles == 0; });
    finish_item(req);
  endtask
endclass

class hdmi_tx_sink_hpd_glitch_seq extends uvm_sequence #(hdmi_tx_sink_item);
  `uvm_object_utils(hdmi_tx_sink_hpd_glitch_seq)
  int unsigned glitch_cycles = 32;
  function new(string name = "hdmi_tx_sink_hpd_glitch_seq"); super.new(name); endfunction
  task body();
    hdmi_tx_sink_item req;
    req = hdmi_tx_sink_item::type_id::create("req");
    start_item(req);
    assert(req.randomize() with {
      hpd == 1'b1; phy_ready == 1'b1; hpd_low_cycles == local::glitch_cycles;
    });
    finish_item(req);
  endtask
endclass
