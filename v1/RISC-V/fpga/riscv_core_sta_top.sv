// Synthesis top — exposes state so Vivado cannot strip the core during timing runs
module riscv_core_sta_top (
    input  logic clk,
    input  logic rst,
    output logic        halt_0,
    output logic [31:0] dbg_pc
);

  riscv_core u_core (
      .clk    (clk),
      .rst    (rst),
      .halt_0 (halt_0),
      .dbg_pc (dbg_pc)
  );

endmodule
