import hdmi_tx_pkg::*;

class hdmi_tx_coverage extends uvm_subscriber #(hdmi_tx_reg_item);
  `uvm_component_utils(hdmi_tx_coverage)

  hdmi_tx_env_config cfg;

  covergroup cg_link;
    option.per_instance = 1;
    cp_vic: coverpoint cfg.vic {
      bins vic60  = {8'd97, 8'd95};
      bins vic120 = {8'd119, 8'd118};
      bins vic240 = {8'd120, 8'd121};
      bins other  = default;
    }
    cp_link_cfg: coverpoint cfg.link_cfg[6:0] {
      bins force_frl = {7'h01};
      bins dsc       = {7'h02};
      bins vrr       = {7'h04};
      bins allm      = {7'h08};
      bins lip       = {7'h10};
      bins fec       = {7'h20};
      bins force_96g = {7'h40};
      bins combo     = default;
    }
    cp_pix_fmt: coverpoint cfg.pix_fmt {
      bins rgb888    = {0};
      bins yuv422    = {1};
      bins rgb101010 = {2};
    }
    cp_ultra96: coverpoint cfg.ultra96_cfg[1:0] {
      bins tier48 = {0}; bins tier64 = {1}; bins tier80 = {2}; bins tier96 = {3};
    }
  endgroup

  covergroup cg_regs;
    option.per_instance = 1;
    cp_reg_addr: coverpoint last_addr {
      bins ctrl = {REG_CTRL}; bins status = {REG_STATUS};
      bins video = {REG_VIDEO_CFG}; bins link = {REG_LINK_CFG};
      bins ultra = {REG_ULTRA96}; bins lip = {REG_LIP};
    }
    cp_reg_op: coverpoint last_op { bins wr = {REG_WRITE}; bins rd = {REG_READ}; }
  endgroup

  reg_op_e last_op;
  bit [7:0] last_addr;

  function new(string name, uvm_component parent);
    super.new(name, parent);
    cg_link = new();
    cg_regs = new();
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    void'(uvm_config_db#(hdmi_tx_env_config)::get(this, "", "cfg", cfg));
  endfunction

  function void write(hdmi_tx_reg_item t);
    last_op   = t.op;
    last_addr = t.addr;
    cg_regs.sample();
    cg_link.sample();
  endfunction
endclass
