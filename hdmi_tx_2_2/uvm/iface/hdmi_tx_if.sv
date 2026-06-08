interface hdmi_tx_reg_if (input logic clk);
  logic        wr;
  logic        rd;
  logic [7:0]  addr;
  logic [31:0] wdata;
  logic [31:0] rdata;

  clocking drv_cb @(posedge clk);
    output wr, rd, addr, wdata;
    input  rdata;
  endclocking

  clocking mon_cb @(posedge clk);
    input wr, rd, addr, wdata, rdata;
  endclocking

  modport drv (clocking drv_cb, input clk);
  modport mon (clocking mon_cb, input clk);
endinterface

interface hdmi_tx_vid_if (input logic clk);
  logic [29:0] data;
  logic        de;
  logic        hsync;
  logic        vsync;

  clocking drv_cb @(posedge clk);
    output data, de, hsync, vsync;
  endclocking

  clocking mon_cb @(posedge clk);
    input data, de, hsync, vsync;
  endclocking

  modport drv (clocking drv_cb, input clk);
  modport mon (clocking mon_cb, input clk);
endinterface

interface hdmi_tx_sink_if (input logic clk);
  logic hpd;
  logic phy_ready;

  clocking drv_cb @(posedge clk);
    output hpd, phy_ready;
  endclocking

  clocking mon_cb @(posedge clk);
    input hpd, phy_ready;
  endclocking

  modport drv (clocking drv_cb, input clk);
  modport mon (clocking mon_cb, input clk);
endinterface

interface hdmi_tx_phy_if (input logic clk);
  logic [15:0] data [4];
  logic        valid;
  logic        is_frl;
  logic [9:0]  tmds [4];
  logic        tmds_valid;

  clocking mon_cb @(posedge clk);
    input data, valid, is_frl, tmds, tmds_valid;
  endclocking

  modport mon (clocking mon_cb, input clk);
endinterface

interface hdmi_tx_fsm_if (input logic clk);
  logic [3:0] state;

  clocking mon_cb @(posedge clk);
    input state;
  endclocking

  modport mon (clocking mon_cb, input clk);
endinterface

interface hdmi_tx_ddc_if (input logic clk);
  logic scl;
  logic sda;
  logic scl_oe;
  logic sda_oe;

  clocking mon_cb @(posedge clk);
    input scl, sda, scl_oe, sda_oe;
  endclocking

  modport mon (clocking mon_cb, input clk);
endinterface
