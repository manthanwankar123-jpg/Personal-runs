class hdmi_tx_reg_write_seq extends uvm_sequence #(hdmi_tx_reg_item);
  `uvm_object_utils(hdmi_tx_reg_write_seq)
  rand bit [7:0]  addr;
  rand bit [31:0] data;
  function new(string name = "hdmi_tx_reg_write_seq"); super.new(name); endfunction
  task body();
    hdmi_tx_reg_item req;
    req = hdmi_tx_reg_item::type_id::create("req");
    start_item(req);
    assert(req.randomize() with { op == REG_WRITE; });
    req.addr = addr; req.data = data;
    finish_item(req);
  endtask
endclass

class hdmi_tx_reg_read_seq extends uvm_sequence #(hdmi_tx_reg_item);
  `uvm_object_utils(hdmi_tx_reg_read_seq)
  rand bit [7:0]  addr;
  bit [31:0]      rdata;
  function new(string name = "hdmi_tx_reg_read_seq"); super.new(name); endfunction
  task body();
    hdmi_tx_reg_item req;
    req = hdmi_tx_reg_item::type_id::create("req");
    start_item(req);
    assert(req.randomize() with { op == REG_READ; addr == local::addr; });
    finish_item(req);
    rdata = req.data;
  endtask
endclass

class hdmi_tx_reg_enable_seq extends uvm_sequence #(hdmi_tx_reg_item);
  `uvm_object_utils(hdmi_tx_reg_enable_seq)
  bit enable = 1'b1;
  function new(string name = "hdmi_tx_reg_enable_seq"); super.new(name); endfunction
  task body();
    hdmi_tx_reg_write_seq wr;
    wr = hdmi_tx_reg_write_seq::type_id::create("wr");
    wr.addr = REG_CTRL;
    wr.data = {30'b0, 1'b0, enable};
    wr.start(m_sequencer);
  endtask
endclass

class hdmi_tx_reg_disable_seq extends hdmi_tx_reg_enable_seq;
  `uvm_object_utils(hdmi_tx_reg_disable_seq)
  function new(string name = "hdmi_tx_reg_disable_seq"); super.new(name); enable = 0; endfunction
endclass
