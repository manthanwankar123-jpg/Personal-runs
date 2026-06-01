module imm_gen (
  input logic [riscv_pkg::INSTR_WIDTH-1:0] inst,
  input riscv_pkg::imm_type_t imm_type,
  output logic [riscv_pkg::XLEN-1:0] imm
);

  import riscv_pkg::*;

  always_comb begin
    unique case (imm_type)
      IMM_TYPE_I: imm = {{20{inst[31]}}, inst[31:20]};
      IMM_TYPE_S: imm = {{20{inst[31]}}, inst[31:25], inst[11:7]};
      IMM_TYPE_B: imm = {{19{inst[31]}}, inst[31], inst[7], inst[30:25], inst[11:8], 1'b0};
      IMM_TYPE_U: imm = {inst[31:12], 12'b0};
      IMM_TYPE_J: imm = {{11{inst[31]}}, inst[31], inst[19:12], inst[20], inst[30:21], 1'b0};
      default: imm = '0;
    endcase
  end
endmodule
