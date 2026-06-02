// regfile.sv — v2

module regfile (
    input  logic                            clk,
    input  logic                            rst,
    input  logic                            we,
    input  logic [riscv_pkg::REG_ADDR_WIDTH-1:0] ra1,
    input  logic [riscv_pkg::REG_ADDR_WIDTH-1:0] ra2,
    input  logic [riscv_pkg::REG_ADDR_WIDTH-1:0] wa,
    input  logic [riscv_pkg::XLEN-1:0]      wd,
    output logic [riscv_pkg::XLEN-1:0]      rd1,
    output logic [riscv_pkg::XLEN-1:0]      rd2,
    input  logic [riscv_pkg::REG_ADDR_WIDTH-1:0] ra1_cap,
    output logic [riscv_pkg::XLEN-1:0]      rd1_cap
);

  import riscv_pkg::*;

  logic [XLEN-1:0] regs [NUM_REGS];

  always_ff @(posedge clk) begin
    if (rst) begin
      for (int i = 0; i < NUM_REGS; i++)
        regs[i] <= '0;
    end else if (we && (wa != REG_ZERO))
      regs[wa] <= wd;
  end

  // Bypass: same-cycle write/read (WB stage vs ID read)
  assign rd1 = (we && (wa == ra1) && (wa != REG_ZERO)) ? wd :
               ((ra1 != REG_ZERO) ? regs[ra1] : '0);
  assign rd2 = (we && (wa == ra2) && (wa != REG_ZERO)) ? wd :
               ((ra2 != REG_ZERO) ? regs[ra2] : '0);
  assign rd1_cap = (we && (wa == ra1_cap) && (wa != REG_ZERO)) ? wd :
                   ((ra1_cap != REG_ZERO) ? regs[ra1_cap] : '0);

endmodule
