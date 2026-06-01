// control.sv — RV32I main decoder (single-cycle)
// LUI:  core should drive ALU input a = 0 (result = imm via ALU_ADD + alu_src_imm).
// AUIPC: core should drive ALU input a = pc (result = pc + imm).

module control (
    input  logic [riscv_pkg::INSTR_WIDTH-1:0] instr,

    input  logic zero,
    input  logic lt,
    input  logic ltu,

    output logic                  rf_we,
    output logic                  mem_we,
    output logic                  mem_re,
    output riscv_pkg::mem_size_t  mem_size,
    output logic                  mem_unsigned,
    output logic                  alu_src_imm,
    output riscv_pkg::alu_op_t    alu_op,
    output riscv_pkg::wb_sel_t    wb_sel,
    output riscv_pkg::imm_type_t  imm_type,
    output riscv_pkg::pc_sel_t    pc_sel,

    output logic halt,
    output logic branch_taken
);

  import riscv_pkg::*;

  logic [6:0]  opcode;
  logic [2:0]  funct3;
  logic [6:0]  funct7;
  logic [11:0] funct12;

  assign opcode   = instr[OPCODE_MSB:OPCODE_LSB];
  assign funct3   = instr[FUNCT3_MSB:FUNCT3_LSB];
  assign funct7   = instr[FUNCT7_MSB:FUNCT7_LSB];
  assign funct12  = instr[FUNCT12_MSB:FUNCT12_LSB];

  // OP-IMM / OP shared ALU op decode
  function automatic alu_op_t alu_op_from_r_type(
    input logic [2:0] f3,
    input logic [6:0] f7
  );
    unique case (f3)
      F3_ADD_SUB: alu_op_from_r_type = (f7 == F7_SUB_SRA) ? ALU_SUB : ALU_ADD;
      F3_SLL:     alu_op_from_r_type = ALU_SLL;
      F3_SLT:     alu_op_from_r_type = ALU_SLT;
      F3_SLTU:    alu_op_from_r_type = ALU_SLTU;
      F3_XOR:     alu_op_from_r_type = ALU_XOR;
      F3_SRL_SRA: alu_op_from_r_type = (f7 == F7_SUB_SRA) ? ALU_SRA : ALU_SRL;
      F3_OR:      alu_op_from_r_type = ALU_OR;
      F3_AND:     alu_op_from_r_type = ALU_AND;
      default:    alu_op_from_r_type = ALU_ADD;
    endcase
  endfunction

  function automatic logic branch_cond(
    input logic [2:0] f3,
    input logic       z,
    input logic       lts,
    input logic       ltus
  );
    unique case (f3)
      F3_BEQ:  branch_cond = z;
      F3_BNE:  branch_cond = !z;
      F3_BLT:  branch_cond = lts;
      F3_BGE:  branch_cond = !lts;
      F3_BLTU: branch_cond = ltus;
      F3_BGEU: branch_cond = !ltus;
      default: branch_cond = 1'b0;
    endcase
  endfunction

  always_comb begin
    // Safe defaults
    rf_we         = 1'b0;
    mem_we        = 1'b0;
    mem_re        = 1'b0;
    mem_size      = MEM_WORD;
    mem_unsigned  = 1'b0;
    alu_src_imm   = 1'b0;
    alu_op        = ALU_ADD;
    wb_sel        = WB_ALU;
    imm_type      = IMM_TYPE_I;
    pc_sel        = PC_PLUS4;
    halt          = 1'b0;
    branch_taken  = 1'b0;

    unique case (opcode)
      OPCODE_LUI: begin
        rf_we       = 1'b1;
        alu_src_imm = 1'b1;
        alu_op      = ALU_ADD;
        imm_type    = IMM_TYPE_U;
      end

      OPCODE_AUIPC: begin
        rf_we       = 1'b1;
        alu_src_imm = 1'b1;
        alu_op      = ALU_ADD;
        imm_type    = IMM_TYPE_U;
      end

      OPCODE_JAL: begin
        rf_we       = 1'b1;
        wb_sel      = WB_PC4;
        imm_type    = IMM_TYPE_J;
        pc_sel      = PC_JAL;
      end

      OPCODE_JALR: begin
        rf_we       = 1'b1;
        wb_sel      = WB_PC4;
        alu_src_imm = 1'b1;
        alu_op      = ALU_ADD;
        imm_type    = IMM_TYPE_I;
        pc_sel      = PC_JALR;
      end

      OPCODE_BRANCH: begin
        imm_type     = IMM_TYPE_B;
        alu_op       = ALU_SUB;
        branch_taken = branch_cond(funct3, zero, lt, ltu);
        pc_sel       = branch_taken ? PC_BRANCH : PC_PLUS4;
      end

      OPCODE_LOAD: begin
        rf_we        = 1'b1;
        mem_re       = 1'b1;
        alu_src_imm  = 1'b1;
        alu_op       = ALU_ADD;
        wb_sel       = WB_MEM;
        unique case (funct3)
          F3_LB:  begin mem_size = MEM_BYTE; mem_unsigned = 1'b0; end
          F3_LH:  begin mem_size = MEM_HALF; mem_unsigned = 1'b0; end
          F3_LW:  begin mem_size = MEM_WORD; mem_unsigned = 1'b0; end
          F3_LBU: begin mem_size = MEM_BYTE; mem_unsigned = 1'b1; end
          F3_LHU: begin mem_size = MEM_HALF; mem_unsigned = 1'b1; end
          default: halt = 1'b1;
        endcase
      end

      OPCODE_STORE: begin
        mem_we      = 1'b1;
        alu_src_imm = 1'b1;
        alu_op      = ALU_ADD;
        imm_type    = IMM_TYPE_S;
        unique case (funct3)
          F3_SB: mem_size = MEM_BYTE;
          F3_SH: mem_size = MEM_HALF;
          F3_SW: mem_size = MEM_WORD;
          default: halt = 1'b1;
        endcase
      end

      OPCODE_OP_IMM: begin
        rf_we       = 1'b1;
        alu_src_imm = 1'b1;
        alu_op      = alu_op_from_r_type(funct3, F7_DEFAULT);
      end

      OPCODE_OP: begin
        rf_we       = 1'b1;
        alu_src_imm = 1'b0;
        alu_op      = alu_op_from_r_type(funct3, funct7);
      end

      OPCODE_SYSTEM: begin
        if (funct3 == F3_PRIV && (funct12 == EBREAK_IMM || funct12 == ECALL_IMM))
          halt = 1'b1;
        else
          halt = 1'b1;
      end

      default: halt = 1'b1;
    endcase
  end

endmodule
