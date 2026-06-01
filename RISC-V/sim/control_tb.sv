// control_tb.sv — unit tests for rtl/control.sv

module control_tb;

  import riscv_pkg::*;

  logic [INSTR_WIDTH-1:0] instr;
  logic                  zero, lt, ltu;

  logic         rf_we;
  logic         mem_we;
  logic         mem_re;
  mem_size_t    mem_size;
  logic         mem_unsigned;
  logic         alu_src_imm;
  alu_op_t      alu_op;
  wb_sel_t      wb_sel;
  imm_type_t    imm_type;
  pc_sel_t      pc_sel;
  logic         halt;
  logic         branch_taken;

  control dut (
    .instr        (instr),
    .zero         (zero),
    .lt           (lt),
    .ltu          (ltu),
    .rf_we        (rf_we),
    .mem_we       (mem_we),
    .mem_re       (mem_re),
    .mem_size     (mem_size),
    .mem_unsigned (mem_unsigned),
    .alu_src_imm  (alu_src_imm),
    .alu_op       (alu_op),
    .wb_sel       (wb_sel),
    .imm_type     (imm_type),
    .pc_sel       (pc_sel),
    .halt         (halt),
    .branch_taken (branch_taken)
  );

  int pass_count;
  int fail_count;

  typedef struct packed {
    logic        rf_we;
    logic        mem_we;
    logic        mem_re;
    mem_size_t   mem_size;
    logic        mem_unsigned;
    logic        alu_src_imm;
    alu_op_t     alu_op;
    wb_sel_t     wb_sel;
    imm_type_t   imm_type;
    pc_sel_t     pc_sel;
    logic        halt;
    logic        branch_taken;
  } ctrl_exp_t;

  function automatic ctrl_exp_t C(
    input logic        p_rf_we,
    input logic        p_mem_we,
    input logic        p_mem_re,
    input mem_size_t   p_mem_size,
    input logic        p_mem_unsigned,
    input logic        p_alu_src_imm,
    input alu_op_t     p_alu_op,
    input wb_sel_t     p_wb_sel,
    input imm_type_t   p_imm_type,
    input pc_sel_t     p_pc_sel,
    input logic        p_halt,
    input logic        p_branch_taken
  );
    C.rf_we         = p_rf_we;
    C.mem_we        = p_mem_we;
    C.mem_re        = p_mem_re;
    C.mem_size      = p_mem_size;
    C.mem_unsigned  = p_mem_unsigned;
    C.alu_src_imm   = p_alu_src_imm;
    C.alu_op        = p_alu_op;
    C.wb_sel        = p_wb_sel;
    C.imm_type      = p_imm_type;
    C.pc_sel        = p_pc_sel;
    C.halt          = p_halt;
    C.branch_taken  = p_branch_taken;
  endfunction

  task automatic check_ctrl(
    input string       name,
    input logic [31:0] instruction,
    input logic        z,
    input logic        lts,
    input logic        ltus,
    input ctrl_exp_t   exp
  );
    instr = instruction;
    zero  = z;
    lt    = lts;
    ltu   = ltus;
    #1;

    if (rf_we !== exp.rf_we || mem_we !== exp.mem_we || mem_re !== exp.mem_re ||
        mem_size !== exp.mem_size || mem_unsigned !== exp.mem_unsigned ||
        alu_src_imm !== exp.alu_src_imm || alu_op !== exp.alu_op ||
        wb_sel !== exp.wb_sel || imm_type !== exp.imm_type ||
        pc_sel !== exp.pc_sel || halt !== exp.halt ||
        branch_taken !== exp.branch_taken) begin
      $error("[%s] mismatch", name);
      $error("  got rf_we=%0b mem_we=%0b mem_re=%0b mem_size=%0d mem_unsigned=%0b",
             rf_we, mem_we, mem_re, mem_size, mem_unsigned);
      $error("       alu_src_imm=%0b alu_op=%0d wb_sel=%0d imm_type=%0d pc_sel=%0d",
             alu_src_imm, alu_op, wb_sel, imm_type, pc_sel);
      $error("       halt=%0b branch_taken=%0b", halt, branch_taken);
      $error("  exp rf_we=%0b mem_we=%0b mem_re=%0b mem_size=%0d mem_unsigned=%0b",
             exp.rf_we, exp.mem_we, exp.mem_re, exp.mem_size, exp.mem_unsigned);
      $error("       alu_src_imm=%0b alu_op=%0d wb_sel=%0d imm_type=%0d pc_sel=%0d",
             exp.alu_src_imm, exp.alu_op, exp.wb_sel, exp.imm_type, exp.pc_sel);
      $error("       halt=%0b branch_taken=%0b", exp.halt, exp.branch_taken);
      fail_count++;
    end else begin
      $display("PASS: %s", name);
      pass_count++;
    end
  endtask

  // mem_sum5 / common defaults helper
  function automatic ctrl_exp_t exp_alu_rr(input alu_op_t op);
    exp_alu_rr = C(1, 0, 0, MEM_WORD, 0, 0, op, WB_ALU, IMM_TYPE_I, PC_PLUS4, 0, 0);
  endfunction

  function automatic ctrl_exp_t exp_alu_ri(input alu_op_t op);
    exp_alu_ri = C(1, 0, 0, MEM_WORD, 0, 1, op, WB_ALU, IMM_TYPE_I, PC_PLUS4, 0, 0);
  endfunction

  initial begin
    pass_count = 0;
    fail_count = 0;
    zero = 0;
    lt   = 0;
    ltu  = 0;

    $display("=== control_tb start ===");

    // mem_sum5 + smoke encodings
    check_ctrl("ADDI x6,x0,10", 32'h00A00313, 0, 0, 0, exp_alu_ri(ALU_ADD));

    // ADD x11, x11, x13  (example R-type; funct7=0)
  check_ctrl("ADD", 32'h00D58533, 0, 0, 0, exp_alu_rr(ALU_ADD));

    check_ctrl("LUI x4,0x80000", 32'h80000237, 0, 0, 0,
      C(1, 0, 0, MEM_WORD, 0, 1, ALU_ADD, WB_ALU, IMM_TYPE_U, PC_PLUS4, 0, 0));

    check_ctrl("LW", 32'h0082A303, 0, 0, 0,
      C(1, 0, 1, MEM_WORD, 0, 1, ALU_ADD, WB_MEM, IMM_TYPE_I, PC_PLUS4, 0, 0));

    check_ctrl("SW", 32'h0045A623, 0, 0, 0,
      C(0, 1, 0, MEM_WORD, 0, 1, ALU_ADD, WB_ALU, IMM_TYPE_S, PC_PLUS4, 0, 0));

    // BNE x5, x0 (funct3=001); taken when ALU subtract result non-zero
    check_ctrl("BNE taken", 32'h00829463, 0, 0, 0,
      C(0, 0, 0, MEM_WORD, 0, 0, ALU_SUB, WB_ALU, IMM_TYPE_B, PC_BRANCH, 0, 1));

    check_ctrl("BNE not taken", 32'h00829463, 1, 0, 0,
      C(0, 0, 0, MEM_WORD, 0, 0, ALU_SUB, WB_ALU, IMM_TYPE_B, PC_PLUS4, 0, 0));

    check_ctrl("EBREAK", 32'h00100073, 0, 0, 0,
      C(0, 0, 0, MEM_WORD, 0, 0, ALU_ADD, WB_ALU, IMM_TYPE_I, PC_PLUS4, 1, 0));

    check_ctrl("JAL", 32'h0040006F, 0, 0, 0,
      C(1, 0, 0, MEM_WORD, 0, 0, ALU_ADD, WB_PC4, IMM_TYPE_J, PC_JAL, 0, 0));

    check_ctrl("AUIPC", 32'h00000197, 0, 0, 0,
      C(1, 0, 0, MEM_WORD, 0, 1, ALU_ADD, WB_ALU, IMM_TYPE_U, PC_PLUS4, 0, 0));

    check_ctrl("SUB (R-type)", 32'h40D58533, 0, 0, 0, exp_alu_rr(ALU_SUB));

    check_ctrl("ANDI", 32'h00F37393, 0, 0, 0, exp_alu_ri(ALU_AND));

    check_ctrl("illegal opcode", 32'h00000000, 0, 0, 0,
      C(0, 0, 0, MEM_WORD, 0, 0, ALU_ADD, WB_ALU, IMM_TYPE_I, PC_PLUS4, 1, 0));

    $display("=== control_tb done: %0d passed, %0d failed ===", pass_count, fail_count);
    if (fail_count != 0)
      $fatal(1, "control tests failed");
    $finish;
  end

endmodule
