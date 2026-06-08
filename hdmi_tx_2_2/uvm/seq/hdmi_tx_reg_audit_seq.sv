class hdmi_tx_reg_audit_seq extends uvm_sequence #(hdmi_tx_reg_item);
  `uvm_object_utils(hdmi_tx_reg_audit_seq)

  bit [31:0] status, link, feat, dsc, lip;

  function new(string name = "hdmi_tx_reg_audit_seq");
    super.new(name);
  endfunction

  task body();
    hdmi_tx_reg_read_seq rd;
    rd = hdmi_tx_reg_read_seq::type_id::create("rd");

    rd.addr = REG_STATUS;    rd.start(m_sequencer); status = rd.rdata;
    rd.addr = REG_LINK_STAT; rd.start(m_sequencer); link   = rd.rdata;
    rd.addr = REG_FEAT;      rd.start(m_sequencer); feat   = rd.rdata;
    rd.addr = REG_DSC_STAT;  rd.start(m_sequencer); dsc    = rd.rdata;
    rd.addr = REG_LIP_STAT;  rd.start(m_sequencer); lip    = rd.rdata;

    `uvm_info("AUDIT", $sformatf("STATUS=%08h LINK=%08h FEAT=%08h DSC=%08h LIP=%08h",
             status, link, feat, dsc, lip), UVM_LOW)
  endtask
endclass
