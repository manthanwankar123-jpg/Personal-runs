class hdmi_tx_smoke_test extends hdmi_tx_base_test;
  `uvm_component_utils(hdmi_tx_smoke_test)
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  virtual function void configure(hdmi_tx_env_config c);
    super.configure(c);
    c.vic = 8'd97;
    c.link_cfg = 32'h0;
    c.expect_frl = 1'b0;
  endfunction
endclass
