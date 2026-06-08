// Register offsets — aligned with SPEC.md §4
package hdmi_tx_reg_defs;

  parameter bit [7:0] REG_CTRL       = 8'h00;  // §4 CTRL
  parameter bit [7:0] REG_STATUS     = 8'h04;  // §4 STATUS
  parameter bit [7:0] REG_VIDEO_CFG  = 8'h0C;  // §4 VIDEO_CFG
  parameter bit [7:0] REG_FEAT       = 8'h10;  // §4 FEAT_STATUS
  parameter bit [7:0] REG_LINK_CFG   = 8'h18;  // §4 LINK_CFG
  parameter bit [7:0] REG_LINK_STAT  = 8'h1C;  // §4 LINK_STATUS
  parameter bit [7:0] REG_ULTRA96    = 8'h20;  // §4 ULTRA96_CFG
  parameter bit [7:0] REG_LIP        = 8'h24;  // §4 LIP_CFG (write)
  parameter bit [7:0] REG_DSC_STAT   = 8'h28;  // §4 DSC_STATUS
  parameter bit [7:0] REG_LIP_STAT   = 8'h2C;  // LIP latency readback

  typedef enum { REG_WRITE, REG_READ } reg_op_e;

endpackage
