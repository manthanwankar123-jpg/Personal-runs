// alu.sv — compute only (branch compare is separate in riscv_core)

module alu (
    input  logic [riscv_pkg::XLEN-1:0] a,
    input  logic [riscv_pkg::XLEN-1:0] b,
    input  riscv_pkg::alu_op_t         alu_op,
    output logic [riscv_pkg::XLEN-1:0] alu_result
);

  import riscv_pkg::*;

  always_comb begin
    unique case (alu_op)
      ALU_ADD:  alu_result = a + b;
      ALU_SUB:  alu_result = a - b;
      ALU_AND:  alu_result = a & b;
      ALU_OR:   alu_result = a | b;
      ALU_XOR:  alu_result = a ^ b;
      ALU_SLL:  alu_result = a << b[4:0];
      ALU_SRL:  alu_result = a >> b[4:0];
      ALU_SRA:  alu_result = $signed(a) >>> b[4:0];
      ALU_SLT:  alu_result = ($signed(a) < $signed(b)) ? 32'd1 : 32'd0;
      ALU_SLTU: alu_result = (a < b) ? 32'd1 : 32'd0;
      default:  alu_result = '0;
    endcase
  end

endmodule
