class hdmi_tx_sink_item extends uvm_sequence_item;
  rand bit hpd;
  rand bit phy_ready;
  rand int unsigned hpd_low_cycles;

  `uvm_object_utils_begin(hdmi_tx_sink_item)
    `uvm_field_int(hpd, UVM_ALL_ON)
    `uvm_field_int(phy_ready, UVM_ALL_ON)
    `uvm_field_int(hpd_low_cycles, UVM_ALL_ON | UVM_DEC)
  `uvm_object_utils_end

  function new(string name = "hdmi_tx_sink_item");
    super.new(name);
  endfunction
endclass
