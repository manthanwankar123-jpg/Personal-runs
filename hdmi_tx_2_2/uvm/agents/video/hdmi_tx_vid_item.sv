class hdmi_tx_vid_item extends uvm_sequence_item;
  rand bit [29:0] data;
  rand bit        de;
  rand bit        hsync;
  rand bit        vsync;
  rand int unsigned burst_len;

  `uvm_object_utils_begin(hdmi_tx_vid_item)
    `uvm_field_int(data, UVM_ALL_ON | UVM_HEX)
    `uvm_field_int(de, UVM_ALL_ON)
    `uvm_field_int(hsync, UVM_ALL_ON)
    `uvm_field_int(vsync, UVM_ALL_ON)
    `uvm_field_int(burst_len, UVM_ALL_ON | UVM_DEC)
  `uvm_object_utils_end

  function new(string name = "hdmi_tx_vid_item");
    super.new(name);
  endfunction
endclass
