import hdmi_tx_pkg::*;

`uvm_analysis_imp_decl(_reg)
`uvm_analysis_imp_decl(_phy)

class hdmi_tx_scoreboard extends uvm_scoreboard;
  `uvm_component_utils(hdmi_tx_scoreboard)

  uvm_analysis_imp_reg #(hdmi_tx_reg_item, hdmi_tx_scoreboard) reg_imp;
  uvm_analysis_imp_phy #(hdmi_tx_phy_item, hdmi_tx_scoreboard) phy_imp;

  hdmi_tx_env_config cfg;
  bit [31:0] last_status;
  bit [31:0] last_link;
  bit [31:0] last_feat;
  bit [31:0] last_dsc;
  bit        link_active_seen;
  bit        phy_frl_seen;
  bit        phy_valid_seen;
  int        err_cnt;

  function new(string name, uvm_component parent);
    super.new(name, parent);
    reg_imp = new("reg_imp", this);
    phy_imp = new("phy_imp", this);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    void'(uvm_config_db#(hdmi_tx_env_config)::get(this, "", "cfg", cfg));
  endfunction

  function void write_reg(hdmi_tx_reg_item tr);
    if (tr.op == REG_READ) begin
      case (tr.addr)
        REG_STATUS:    last_status = tr.data;
        REG_LINK_STAT: last_link    = tr.data;
        REG_FEAT:      last_feat    = tr.data;
        REG_DSC_STAT:  last_dsc     = tr.data;
        default: ;
      endcase
      if (tr.addr == REG_STATUS && tr.data[2])
        link_active_seen = 1'b1;
    end
  endfunction

  function void write_phy(hdmi_tx_phy_item tr);
    if (tr.valid) begin
      phy_valid_seen = 1'b1;
      if (tr.is_frl) phy_frl_seen = 1'b1;
    end
  endfunction

  function void note_regs(bit [31:0] status, bit [31:0] link, bit [31:0] feat, bit [31:0] dsc = 32'h0);
    last_status = status;
    last_link   = link;
    last_feat   = feat;
    last_dsc    = dsc;
    if (status[2]) link_active_seen = 1'b1;
  endfunction

  function void check_phase(uvm_phase phase);
    super.check_phase(phase);

    if (!link_active_seen) begin
      `uvm_error("SB", "link_active never asserted")
      err_cnt++;
    end

    if (!phy_valid_seen)
      `uvm_warning("SB", "no PHY valid activity observed")

    if (cfg.expect_frl && !phy_frl_seen)
      `uvm_warning("SB", "expected FRL PHY traffic not observed")

    if (cfg.expect_frl && last_link[7:6] != LINK_FRL) begin
      `uvm_error("SB", $sformatf("expected LINK_FRL got %0d", last_link[7:6]))
      err_cnt++;
    end

    if (!cfg.expect_frl && last_link[7:6] == LINK_FRL) begin
      `uvm_error("SB", "unexpected LINK_FRL")
      err_cnt++;
    end

    if (cfg.expect_vrr && !last_feat[11]) begin
      `uvm_error("SB", "VRR not enabled")
      err_cnt++;
    end

    if (cfg.expect_allm && !last_feat[10]) begin
      `uvm_error("SB", "ALLM not enabled")
      err_cnt++;
    end

    if (cfg.expect_lip && !last_feat[15]) begin
      `uvm_error("SB", "LIP not enabled")
      err_cnt++;
    end

    if (cfg.expect_dsc && last_dsc[15:8] >= 8'd100)
      `uvm_warning("SB", $sformatf("DSC ratio=%0d (no sustained video?)", last_dsc[15:8]))

    if (err_cnt == 0)
      `uvm_info("SB", "All scoreboard checks passed", UVM_LOW)
  endfunction
endclass
