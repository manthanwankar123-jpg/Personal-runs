// Synthesis top for Vivado STA (prevents opt_design from stripping the core)
module riscv_core_sta_top (
    input  logic        clk,
    input  logic        rst,
    output logic [31:0] dbg_pc,
    output logic        trap_entered
);

  logic [31:0] dbg_pc_core;
  logic        trap_entered_core;

  riscv_core u_core (
      .clk          (clk),
      .rst          (rst),
      .dbg_pc       (dbg_pc_core),
      .trap_entered (trap_entered_core)
  );

  // IOB output registers — break FF→OBUF long route for high Fmax
  (* IOB = "TRUE" *) logic [31:0] dbg_pc_iob;
  (* IOB = "TRUE" *) logic        trap_entered_iob;

  always_ff @(posedge clk) begin
    dbg_pc_iob       <= dbg_pc_core;
    trap_entered_iob <= trap_entered_core;
  end

  assign dbg_pc       = dbg_pc_iob;
  assign trap_entered = trap_entered_iob;

endmodule
