// riscv_pkg.sv — RV32I constants and types for Personal_runs/RISC-V
// See SPEC.md for memory map and microarchitecture choices.
//
// Port lists: use package scope (riscv_pkg::alu_op_t). Import riscv_pkg::* inside
// the module body for constants. Compile riscv_pkg.sv before other RTL files.

/* verilator lint_off UNUSEDPARAM */
package riscv_pkg;

  // ---------------------------------------------------------------------------
  // Width parameters
  // ---------------------------------------------------------------------------
  localparam int unsigned XLEN            = 32;
  localparam int unsigned REG_ADDR_WIDTH  = 5;
  localparam int unsigned OPCODE_WIDTH    = 7;
  localparam int unsigned FUNCT7_WIDTH    = 7;
  localparam int unsigned FUNCT3_WIDTH    = 3;
  localparam int unsigned RD_WIDTH        = REG_ADDR_WIDTH;
  localparam int unsigned RS1_WIDTH       = REG_ADDR_WIDTH;
  localparam int unsigned RS2_WIDTH       = REG_ADDR_WIDTH;
  localparam int unsigned IMM_I_WIDTH     = 12;
  localparam int unsigned IMM_S_WIDTH     = 12;
  localparam int unsigned IMM_B_WIDTH     = 13;
  localparam int unsigned IMM_U_WIDTH     = 20;
  localparam int unsigned IMM_J_WIDTH     = 21;
  localparam int unsigned SHAMT_WIDTH     = 5;
  localparam int unsigned PC_WIDTH        = XLEN;
  localparam int unsigned INSTR_WIDTH     = 32;
  localparam int unsigned NUM_REGS        = 32;
  localparam int unsigned INSTR_ALIGN_BYTES = 4;

  localparam int unsigned ALU_OP_WIDTH   = 4;
  localparam int unsigned WB_SEL_WIDTH    = 2;
  localparam int unsigned MEM_SIZE_WIDTH  = 2;
  localparam int unsigned PC_SEL_WIDTH    = 2;
  localparam int unsigned IMM_TYPE_WIDTH  = 3;

  // ---------------------------------------------------------------------------
  // Memory map (Harvard; see SPEC §3.3)
  // ---------------------------------------------------------------------------
  localparam logic [XLEN-1:0] RESET_PC         = 32'h0000_0000;
  localparam logic [XLEN-1:0] DATA_MEM_BASE     = 32'h8000_0000;
  localparam logic [15:0] DATA_MEM_BASE_HI  = 16'h8000;  // match addr[31:16]
  localparam logic [XLEN-1:0] IMEM_ADDR_MASK    = 32'h0000_FFFF;  // 64 KiB byte index
  localparam logic [XLEN-1:0] DMEM_ADDR_MASK    = 32'h0000_FFFF;  // local offset mask

  // ---------------------------------------------------------------------------
  // Instruction field bit ranges (instr[31:0])
  // ---------------------------------------------------------------------------
  localparam int unsigned OPCODE_LSB  = 0;
  localparam int unsigned OPCODE_MSB  = 6;
  localparam int unsigned RD_LSB      = 7;
  localparam int unsigned RD_MSB      = 11;
  localparam int unsigned FUNCT3_LSB  = 12;
  localparam int unsigned FUNCT3_MSB  = 14;
  localparam int unsigned RS1_LSB     = 15;
  localparam int unsigned RS1_MSB     = 19;
  localparam int unsigned RS2_LSB     = 20;
  localparam int unsigned RS2_MSB     = 24;
  localparam int unsigned FUNCT7_LSB  = 25;
  localparam int unsigned FUNCT7_MSB  = 31;

  // SYSTEM ECALL/EBREAK: imm[11:0] in instr[31:20]
  localparam int unsigned FUNCT12_LSB   = 20;
  localparam int unsigned FUNCT12_MSB   = 31;

  // ---------------------------------------------------------------------------
  // RV32I major opcodes [6:0]
  // ---------------------------------------------------------------------------
  localparam logic [OPCODE_WIDTH-1:0] OPCODE_LOAD    = 7'b0000011;
  localparam logic [OPCODE_WIDTH-1:0] OPCODE_STORE   = 7'b0100011;
  localparam logic [OPCODE_WIDTH-1:0] OPCODE_OP_IMM   = 7'b0010011;
  localparam logic [OPCODE_WIDTH-1:0] OPCODE_OP        = 7'b0110011;
  localparam logic [OPCODE_WIDTH-1:0] OPCODE_BRANCH   = 7'b1100011;
  localparam logic [OPCODE_WIDTH-1:0] OPCODE_JALR     = 7'b1100111;
  localparam logic [OPCODE_WIDTH-1:0] OPCODE_JAL       = 7'b1101111;
  localparam logic [OPCODE_WIDTH-1:0] OPCODE_LUI       = 7'b0110111;
  localparam logic [OPCODE_WIDTH-1:0] OPCODE_AUIPC     = 7'b0010111;
  localparam logic [OPCODE_WIDTH-1:0] OPCODE_SYSTEM    = 7'b1110011;

  // ---------------------------------------------------------------------------
  // funct3 — OP / OP-IMM
  // ---------------------------------------------------------------------------
  localparam logic [FUNCT3_WIDTH-1:0] F3_ADD_SUB  = 3'b000;
  localparam logic [FUNCT3_WIDTH-1:0] F3_SLL      = 3'b001;
  localparam logic [FUNCT3_WIDTH-1:0] F3_SLT      = 3'b010;
  localparam logic [FUNCT3_WIDTH-1:0] F3_SLTU     = 3'b011;
  localparam logic [FUNCT3_WIDTH-1:0] F3_XOR      = 3'b100;
  localparam logic [FUNCT3_WIDTH-1:0] F3_SRL_SRA  = 3'b101;
  localparam logic [FUNCT3_WIDTH-1:0] F3_OR       = 3'b110;
  localparam logic [FUNCT3_WIDTH-1:0] F3_AND      = 3'b111;

  // funct3 — LOAD
  localparam logic [FUNCT3_WIDTH-1:0] F3_LB       = 3'b000;
  localparam logic [FUNCT3_WIDTH-1:0] F3_LH       = 3'b001;
  localparam logic [FUNCT3_WIDTH-1:0] F3_LW       = 3'b010;
  localparam logic [FUNCT3_WIDTH-1:0] F3_LBU      = 3'b100;
  localparam logic [FUNCT3_WIDTH-1:0] F3_LHU      = 3'b101;

  // funct3 — STORE
  localparam logic [FUNCT3_WIDTH-1:0] F3_SB       = 3'b000;
  localparam logic [FUNCT3_WIDTH-1:0] F3_SH       = 3'b001;
  localparam logic [FUNCT3_WIDTH-1:0] F3_SW       = 3'b010;

  // funct3 — BRANCH
  localparam logic [FUNCT3_WIDTH-1:0] F3_BEQ      = 3'b000;
  localparam logic [FUNCT3_WIDTH-1:0] F3_BNE      = 3'b001;
  localparam logic [FUNCT3_WIDTH-1:0] F3_BLT      = 3'b100;
  localparam logic [FUNCT3_WIDTH-1:0] F3_BGE      = 3'b101;
  localparam logic [FUNCT3_WIDTH-1:0] F3_BLTU     = 3'b110;
  localparam logic [FUNCT3_WIDTH-1:0] F3_BGEU     = 3'b111;

  // funct3 — JALR / SYSTEM
  localparam logic [FUNCT3_WIDTH-1:0] F3_JALR     = 3'b000;
  localparam logic [FUNCT3_WIDTH-1:0] F3_PRIV     = 3'b000;

  // ---------------------------------------------------------------------------
  // funct7
  // ---------------------------------------------------------------------------
  localparam logic [FUNCT7_WIDTH-1:0] F7_DEFAULT  = 7'b0000000;
  localparam logic [FUNCT7_WIDTH-1:0] F7_SUB_SRA  = 7'b0100000;  // SUB, SRA, SRAI

  // ---------------------------------------------------------------------------
  // SYSTEM immediates (instr[31:20])
  // ---------------------------------------------------------------------------
  localparam logic [IMM_I_WIDTH-1:0] ECALL_IMM   = 12'h000;
  localparam logic [IMM_I_WIDTH-1:0] EBREAK_IMM  = 12'h001;

  // ---------------------------------------------------------------------------
  // Register indices (optional readability)
  // ---------------------------------------------------------------------------
  localparam logic [REG_ADDR_WIDTH-1:0] REG_ZERO  = 5'd0;

  // ---------------------------------------------------------------------------
  // Microarchitecture types (control → datapath)
  // ---------------------------------------------------------------------------
  typedef enum logic [ALU_OP_WIDTH-1:0] {
    ALU_ADD  = 4'd0,
    ALU_SUB  = 4'd1,
    ALU_AND  = 4'd2,
    ALU_OR   = 4'd3,
    ALU_XOR  = 4'd4,
    ALU_SLL  = 4'd5,
    ALU_SRL  = 4'd6,
    ALU_SRA  = 4'd7,
    ALU_SLT  = 4'd8,
    ALU_SLTU = 4'd9
  } alu_op_t;

  typedef enum logic [WB_SEL_WIDTH-1:0] {
    WB_ALU = 2'd0,
    WB_MEM = 2'd1,
    WB_PC4 = 2'd2
  } wb_sel_t;

  typedef enum logic [MEM_SIZE_WIDTH-1:0] {
    MEM_BYTE = 2'd0,
    MEM_HALF = 2'd1,
    MEM_WORD = 2'd2
  } mem_size_t;

  typedef enum logic [PC_SEL_WIDTH-1:0] {
    PC_PLUS4  = 2'd0,
    PC_BRANCH = 2'd1,
    PC_JAL    = 2'd2,
    PC_JALR   = 2'd3
  } pc_sel_t;

  typedef enum logic [IMM_TYPE_WIDTH-1:0] {
    IMM_TYPE_I = 3'd0,
    IMM_TYPE_S = 3'd1,
    IMM_TYPE_B = 3'd2,
    IMM_TYPE_U = 3'd3,
    IMM_TYPE_J = 3'd4
  } imm_type_t;

endpackage : riscv_pkg
/* verilator lint_on UNUSEDPARAM */
