// ASIC synthesis / STA top (no debug pad pipeline — core outputs registered internally)

module riscv_core_asic_top (
    input  logic        clk,
    input  logic        rst,
    output logic [31:0] dbg_pc,
    output logic        trap_entered
);

  riscv_core u_core (
      .clk          (clk),
      .rst          (rst),
      .dbg_pc       (dbg_pc),
      .trap_entered (trap_entered)
  );

endmodule
