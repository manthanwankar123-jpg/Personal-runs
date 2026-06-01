module regfile (
  input logic clk,
  input logic rst,
  input logic we,
  input logic [riscv_pkg::REG_ADDR_WIDTH-1:0] ra1,
  input logic [riscv_pkg::REG_ADDR_WIDTH-1:0] ra2,
  input logic [riscv_pkg::REG_ADDR_WIDTH-1:0] wa,
  input logic [riscv_pkg::XLEN-1:0] wd,
  output logic [riscv_pkg::XLEN-1:0] rd1,
  output logic [riscv_pkg::XLEN-1:0] rd2
);
  
  import riscv_pkg::*;
  logic [XLEN-1:0] regs [NUM_REGS];

  always_ff @(posedge clk) begin
    if (rst) begin
      for (int i = 0; i < NUM_REGS; i++)
        regs[i] <= '0;
    end
  end

  always_ff @(posedge clk) begin
    if (!rst && we && (wa != REG_ZERO))
      regs[wa] <= wd;
  end

  assign rd1 = (ra1 != REG_ZERO) ? regs[ra1] : '0;
  assign rd2 = (ra2 != REG_ZERO) ? regs[ra2] : '0;

endmodule
