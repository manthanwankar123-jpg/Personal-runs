class hdmi_tx_phy_item extends uvm_sequence_item;
  bit        valid;
  bit        tmds_valid;
  bit        is_frl;
  bit [15:0] data [4];
  bit [9:0]  tmds [4];

  `uvm_object_utils_begin(hdmi_tx_phy_item)
    `uvm_field_int(valid, UVM_ALL_ON)
    `uvm_field_int(tmds_valid, UVM_ALL_ON)
    `uvm_field_int(is_frl, UVM_ALL_ON)
  `uvm_object_utils_end

  function new(string name = "hdmi_tx_phy_item");
    super.new(name);
    foreach (data[i]) data[i] = '0;
    foreach (tmds[i]) tmds[i] = '0;
  endfunction
endclass
