import hdmi_tx_reg_defs::*;

class hdmi_tx_reg_item extends uvm_sequence_item;
  rand reg_op_e  op;
  rand bit [7:0] addr;
  rand bit [31:0] data;

  `uvm_object_utils_begin(hdmi_tx_reg_item)
    `uvm_field_enum(reg_op_e, op, UVM_ALL_ON)
    `uvm_field_int(addr, UVM_ALL_ON | UVM_HEX)
    `uvm_field_int(data, UVM_ALL_ON | UVM_HEX)
  `uvm_object_utils_end

  function new(string name = "hdmi_tx_reg_item");
    super.new(name);
  endfunction
endclass
