// control.sv — RV32I + Zicsr decode (no branch resolve; EX owns branches)

module control (
    input  logic [riscv_pkg::INSTR_WIDTH-1:0] instr,
    output logic                             rf_we,
    output logic                             mem_we,
    output logic                             mem_re,
    output riscv_pkg::mem_size_t             mem_size,
    output logic                             mem_unsigned,
    output logic                             alu_src_imm,
    output riscv_pkg::alu_op_t               alu_op,
    output riscv_pkg::wb_sel_t               wb_sel,
    output riscv_pkg::imm_type_t             imm_type,
    output logic                             is_csr,
    output logic                             csr_we,
    output riscv_pkg::csr_op_t               csr_op,
    output logic                             csr_use_imm,
    output logic                             is_jal,
    output logic                             is_jalr,
    output logic                             is_branch,
    output logic                             trap_req,
    output logic [riscv_pkg::XLEN-1:0]       trap_cause,
    output logic                             check_misalign
);

  import riscv_pkg::*;

  logic [6:0]  opcode;
  logic [2:0]  funct3;
  logic [6:0]  funct7;
  logic [11:0] funct12;

  assign opcode  = instr[OPCODE_MSB:OPCODE_LSB];
  assign funct3  = instr[FUNCT3_MSB:FUNCT3_LSB];
  assign funct7  = instr[FUNCT7_MSB:FUNCT7_LSB];
  assign funct12 = instr[FUNCT12_MSB:FUNCT12_LSB];

  function automatic alu_op_t alu_op_from_r_type(input logic [2:0] f3, input logic [6:0] f7);
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

  function automatic csr_op_t csr_op_from_funct3(input logic [2:0] f3);
    unique case (f3)
      F3_CSRRW, F3_CSRRWI: csr_op_from_funct3 = CSR_OP_RW;
      F3_CSRRS, F3_CSRRSI: csr_op_from_funct3 = CSR_OP_RS;
      F3_CSRRC, F3_CSRRCI: csr_op_from_funct3 = CSR_OP_RC;
      default:             csr_op_from_funct3 = CSR_OP_RW;
    endcase
  endfunction

  always_comb begin
    rf_we          = 1'b0;
    mem_we         = 1'b0;
    mem_re         = 1'b0;
    mem_size       = MEM_WORD;
    mem_unsigned   = 1'b0;
    alu_src_imm    = 1'b0;
    alu_op         = ALU_ADD;
    wb_sel         = WB_ALU;
    imm_type       = IMM_TYPE_I;
    is_csr         = 1'b0;
    csr_we         = 1'b0;
    csr_op         = CSR_OP_RW;
    csr_use_imm    = 1'b0;
    is_jal         = 1'b0;
    is_jalr        = 1'b0;
    is_branch      = 1'b0;
    trap_req       = 1'b0;
    trap_cause     = MCAUSE_ILLEGAL;
    check_misalign = 1'b0;

    unique case (opcode)
      OPCODE_LUI: begin
        rf_we       = 1'b1;
        alu_src_imm = 1'b1;
        imm_type    = IMM_TYPE_U;
      end

      OPCODE_AUIPC: begin
        rf_we       = 1'b1;
        alu_src_imm = 1'b1;
        imm_type    = IMM_TYPE_U;
      end

      OPCODE_JAL: begin
        rf_we    = 1'b1;
        wb_sel   = WB_PC4;
        imm_type = IMM_TYPE_J;
        is_jal   = 1'b1;
      end

      OPCODE_JALR: begin
        rf_we       = 1'b1;
        wb_sel      = WB_PC4;
        alu_src_imm = 1'b1;
        imm_type    = IMM_TYPE_I;
        is_jalr     = 1'b1;
      end

      OPCODE_BRANCH: begin
        imm_type  = IMM_TYPE_B;
        is_branch = 1'b1;
      end

      OPCODE_LOAD: begin
        rf_we       = 1'b1;
        mem_re      = 1'b1;
        alu_src_imm = 1'b1;
        wb_sel      = WB_MEM;
        unique case (funct3)
          F3_LB:  begin mem_size = MEM_BYTE; mem_unsigned = 1'b0; end
          F3_LH:  begin mem_size = MEM_HALF; mem_unsigned = 1'b0; end
          F3_LW:  begin mem_size = MEM_WORD; mem_unsigned = 1'b0; check_misalign = 1'b1; end
          F3_LBU: begin mem_size = MEM_BYTE; mem_unsigned = 1'b1; end
          F3_LHU: begin mem_size = MEM_HALF; mem_unsigned = 1'b1; end
          default: trap_req = 1'b1;
        endcase
      end

      OPCODE_STORE: begin
        mem_we      = 1'b1;
        alu_src_imm = 1'b1;
        imm_type    = IMM_TYPE_S;
        unique case (funct3)
          F3_SB: mem_size = MEM_BYTE;
          F3_SH: mem_size = MEM_HALF;
          F3_SW: begin mem_size = MEM_WORD; check_misalign = 1'b1; end
          default: trap_req = 1'b1;
        endcase
      end

      OPCODE_OP_IMM: begin
        rf_we       = 1'b1;
        alu_src_imm = 1'b1;
        alu_op      = alu_op_from_r_type(funct3, F7_DEFAULT);
      end

      OPCODE_OP: begin
        rf_we  = 1'b1;
        alu_op = alu_op_from_r_type(funct3, funct7);
      end

      OPCODE_SYSTEM: begin
        if (funct3 == F3_PRIV) begin
          if (funct12 == EBREAK_IMM) begin
            trap_req   = 1'b1;
            trap_cause = MCAUSE_EBREAK;
          end else if (funct12 == ECALL_IMM) begin
            trap_req   = 1'b1;
            trap_cause = MCAUSE_ECALL_M;
          end else
            trap_req = 1'b1;
        end else begin
          is_csr      = 1'b1;
          rf_we       = (instr[RD_MSB:RD_LSB] != REG_ZERO);
          wb_sel      = WB_CSR;
          csr_we      = 1'b1;
          csr_op      = csr_op_from_funct3(funct3);
          csr_use_imm = (funct3 == F3_CSRRWI || funct3 == F3_CSRRSI || funct3 == F3_CSRRCI);
        end
      end

      default: trap_req = 1'b1;
    endcase
  end

endmodule
