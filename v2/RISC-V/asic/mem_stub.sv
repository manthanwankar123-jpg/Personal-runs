// mem_stub.sv — memory stub for core-only ASIC synthesis/STA
//
// Replaces unified_mem during Yosys mapping so ROM/RAM arrays are not inferred
// as hundreds of thousands of registers. Timing reflects pipeline logic only.
//
// ASIC_TIMING_SYNTH: registered read ports (1-cycle latency) for realistic load/IF timing.

`include "timing_cfg.vh"

module unified_mem (
    input  logic                       clk,
    input  logic                       rst,
    input  logic [riscv_pkg::XLEN-1:0] if_addr,
    output logic [riscv_pkg::XLEN-1:0] if_rdata,
    input  logic [riscv_pkg::XLEN-1:0] mem_addr,
    input  logic                       mem_we,
    input  logic                       mem_re,
    input  riscv_pkg::mem_size_t       mem_size,
    input  logic                       mem_unsigned,
    input  logic [riscv_pkg::XLEN-1:0] mem_wdata,
    output logic [riscv_pkg::XLEN-1:0] mem_rdata,
    output logic                       mem_load_ready
);

  import riscv_pkg::*;

`ifdef ASIC_SYNC_IF
  logic [XLEN-1:0] if_rdata_n, mem_rdata_n;
  logic            mem_re_q;

  assign if_rdata_n  = if_addr ^ 32'hA5A5_A5A5;
  assign mem_rdata_n = mem_addr ^ 32'h5A5A_5A5A;

  always_ff @(posedge clk) begin
    if (rst)
      if_rdata <= 32'h0;
    else
      if_rdata <= if_rdata_n;
  end

  always_ff @(posedge clk) begin
    if (rst) begin
      mem_rdata      <= 32'h0;
      mem_re_q       <= 1'b0;
    end else begin
      mem_rdata      <= mem_rdata_n;
      mem_re_q       <= mem_re;
    end
  end

  assign mem_load_ready = mem_re_q;
`else
  assign if_rdata       = if_addr ^ 32'hA5A5_A5A5;
  assign mem_rdata      = mem_addr ^ 32'h5A5A_5A5A;
  assign mem_load_ready = mem_re;
`endif

endmodule
