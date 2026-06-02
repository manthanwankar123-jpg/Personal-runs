// riscv_core.sv — 5-stage RV32I + Zicsr (clean pipeline)
//
// Stage flow: IF → ID → EX → MEM → WB
//
// Stalls:
//   load_use     — load in EX (id_ex), operand read in ID
//   mem_load     — load in MEM or pending, operand read in EX (id_ex)
//   wb_csr       — CSR result in WB, operand read in ID
//   load_issue   — (FPGA) issuing load address into memory port
//   load_queue   — (FPGA) second load blocked while prior load pending
//
// Flushes:
//   redirect     — branch/jal/jalr taken in EX → flush IF/ID
//   trap         — trap in EX or MEM → flush IF/ID/EX/MEM
//
// See ../ARCHITECTURE.md

`include "timing_cfg.vh"

`ifdef FPGA_TIMING_SYNTH
(* dont_touch = "yes" *)
`endif
module riscv_core (
    input  logic                       clk,
    input  logic                       rst,
    output logic [riscv_pkg::XLEN-1:0] dbg_pc,
    output logic                       trap_entered
);

  import riscv_pkg::*;

  // =========================================================================
  // Pipeline registers
  // =========================================================================

  // IF
  logic [XLEN-1:0] pc, pc_next;
  logic [XLEN-1:0] if_rdata;

  // IF/ID
  logic [XLEN-1:0] if_id_pc, if_id_instr;
  logic            if_id_valid;
  logic [XLEN-1:0] fetch_pc_q;  // PC that produced if_rdata (FPGA sync imem)

  // ID (combinational decode)
  logic [4:0]      id_rs1, id_rs2, id_rd;
  logic [XLEN-1:0] id_rd1, id_rd2, id_imm;
  logic            id_rf_we, id_mem_we, id_mem_re, id_mem_unsigned, id_alu_src_imm;
  logic            id_is_csr, id_csr_we, id_csr_use_imm;
  logic            id_is_jal, id_is_jalr, id_is_branch;
  logic            id_trap_req, id_check_misalign;
  mem_size_t       id_mem_size;
  alu_op_t         id_alu_op;
  wb_sel_t         id_wb_sel;
  imm_type_t       id_imm_type;
  csr_op_t         id_csr_op;
  logic [XLEN-1:0] id_trap_cause;

  // ID/EX
  logic            id_ex_valid;
  logic [XLEN-1:0] id_ex_pc, id_ex_rs1, id_ex_rs2, id_ex_imm;
  logic [XLEN-1:0] id_ex_target, id_ex_jalr_base;
  logic [4:0]      id_ex_rs1_a, id_ex_rs2_a, id_ex_rd;
  logic [2:0]      id_ex_funct3;
  logic [6:0]      id_ex_opcode;
  logic            id_ex_rf_we, id_ex_mem_we, id_ex_mem_re, id_ex_mem_unsigned;
  logic            id_ex_alu_src_imm, id_ex_is_csr, id_ex_csr_we, id_ex_csr_use_imm;
  logic            id_ex_is_jal, id_ex_is_jalr, id_ex_is_branch, id_ex_check_misalign;
  logic            id_ex_trap_req;
  logic [XLEN-1:0] id_ex_trap_cause;
  mem_size_t       id_ex_mem_size;
  alu_op_t         id_ex_alu_op;
  wb_sel_t         id_ex_wb_sel;
  csr_op_t         id_ex_csr_op;
  logic [11:0]     id_ex_csr_addr;

  // EX (combinational)
  logic [XLEN-1:0] ex_rs1_fwd, ex_rs2_fwd, ex_alu_a, ex_alu_b, ex_alu_result;
  logic            ex_branch_taken;
  logic [XLEN-1:0] ex_jalr_target, pc_plus4, pc_redirect;

  // EX/MEM
  logic            ex_mem_valid;
  logic [XLEN-1:0] ex_mem_pc, ex_mem_alu_result, ex_mem_rs2;
  logic [4:0]      ex_mem_rd;
  logic            ex_mem_rf_we, ex_mem_mem_we, ex_mem_mem_re, ex_mem_mem_unsigned;
  logic            ex_mem_is_csr, ex_mem_csr_we, ex_mem_csr_use_imm, ex_mem_check_misalign;
  mem_size_t       ex_mem_mem_size;
  wb_sel_t         ex_mem_wb_sel;
  csr_op_t         ex_mem_csr_op;
  logic [11:0]     ex_mem_csr_addr;
  logic [XLEN-1:0] ex_mem_csr_wdata;

  // MEM
  logic [XLEN-1:0] mem_rdata;
  logic            mem_re_req, mem_load_ready;
  logic            mem_trap_req;
  logic [XLEN-1:0] mem_trap_cause, mem_trap_val;

  // Load metadata retained across FPGA 2-cycle read
  logic            ld_pend;
  logic [XLEN-1:0] ld_pend_pc, ld_pend_alu;
  logic [4:0]      ld_pend_rd;
  logic            ld_pend_rf_we;
  wb_sel_t         ld_pend_wb_sel;
  logic            ld_data_rdy;

  // MEM/WB
  logic            mem_wb_valid;
  logic [XLEN-1:0] mem_wb_pc4, mem_wb_alu, mem_wb_mem;
  logic [4:0]      mem_wb_rd;
  logic            mem_wb_rf_we, mem_wb_is_csr, mem_wb_csr_we, mem_wb_csr_use_imm;
  wb_sel_t         mem_wb_wb_sel;
  csr_op_t         mem_wb_csr_op;
  logic [11:0]     mem_wb_csr_addr;
  logic [XLEN-1:0] mem_wb_csr_wdata;

  // WB
  logic [XLEN-1:0] wb_wdata, csr_rdata;
  logic [XLEN-1:0] mtvec, mepc, mcause;

  // Control
  logic stall_if, stall_id, flush_if_id, flush_id_ex, flush_ex_mem, flush_mem_wb;
  logic load_use_stall, mem_load_stall, wb_csr_stall;
  logic load_issue_stall, load_queue_stall;
  logic ex_redirect, trap_take;
  logic [XLEN-1:0] trap_pc, trap_cause, trap_val;
  logic trap_entered_q;
  logic [XLEN-1:0] dbg_pc_q;
  logic            trap_entered_out_q;

  logic            ld_active;
  logic [4:0]      ld_active_rd;
  logic            ld_active_rf_we;

  logic [XLEN-1:0] id_cap_rd1_unused;

`ifdef ASIC_DECODE_REG
  // Registered ID decode — breaks if_id_instr → control → id_ex for ASIC STA
  logic [XLEN-1:0] id_dec_pc, id_dec_imm, id_dec_target, id_dec_jalr_base;
  logic [4:0]      id_dec_rs1, id_dec_rs2, id_dec_rd;
  logic [2:0]      id_dec_funct3;
  logic [6:0]      id_dec_opcode;
  logic [11:0]     id_dec_csr_addr;
  logic            id_dec_rf_we, id_dec_mem_we, id_dec_mem_re, id_dec_mem_unsigned;
  logic            id_dec_alu_src_imm, id_dec_is_csr, id_dec_csr_we, id_dec_csr_use_imm;
  logic            id_dec_is_jal, id_dec_is_jalr, id_dec_is_branch, id_dec_check_misalign;
  logic            id_dec_trap_req;
  logic [XLEN-1:0] id_dec_trap_cause;
  mem_size_t       id_dec_mem_size;
  alu_op_t         id_dec_alu_op;
  wb_sel_t         id_dec_wb_sel;
  csr_op_t         id_dec_csr_op;
`endif

  assign dbg_pc       = dbg_pc_q;
  assign trap_entered = trap_entered_out_q;

  always_ff @(posedge clk) begin
    dbg_pc_q           <= pc;
    trap_entered_out_q <= trap_entered_q;
  end

  // =========================================================================
  // Memory interface
  // =========================================================================
  unified_mem u_mem (
      .clk           (clk),
      .rst           (rst),
      .if_addr       (pc),
      .if_rdata      (if_rdata),
      .mem_addr      (ex_mem_alu_result),
      .mem_we        (ex_mem_valid && ex_mem_mem_we),
      .mem_re        (mem_re_req),
      .mem_size      (ex_mem_mem_size),
      .mem_unsigned  (ex_mem_mem_unsigned),
      .mem_wdata     (ex_mem_rs2),
      .mem_rdata     (mem_rdata),
      .mem_load_ready(mem_load_ready)
  );

`ifdef PIPELINE_TIMING
  assign mem_re_req       = ex_mem_valid && ex_mem_mem_re && !ld_pend;
  assign load_issue_stall = mem_re_req;
  assign load_queue_stall = ld_pend && id_ex_valid && id_ex_mem_re;
  assign ld_active        = ld_pend || (ex_mem_valid && ex_mem_mem_re);
  assign ld_active_rd     = ld_pend ? ld_pend_rd : ex_mem_rd;
  assign ld_active_rf_we  = ld_pend ? ld_pend_rf_we : ex_mem_rf_we;
`else
  assign mem_re_req       = ex_mem_valid && ex_mem_mem_re;
  assign load_issue_stall = 1'b0;
  assign load_queue_stall = 1'b0;
  assign ld_active        = ex_mem_valid && ex_mem_mem_re;
  assign ld_active_rd     = ex_mem_rd;
  assign ld_active_rf_we  = ex_mem_rf_we;
`endif

  // =========================================================================
  // ID — decode
  // =========================================================================
`ifdef ASIC_DECODE_REG
  // Parallel decode of incoming fetch (id_dec only — no stall feedback)
  logic [4:0]      id_cap_rs1, id_cap_rs2, id_cap_rd;
  logic [XLEN-1:0] id_cap_imm, id_cap_rd1;
  logic            id_cap_rf_we, id_cap_mem_we, id_cap_mem_re, id_cap_mem_unsigned;
  logic            id_cap_alu_src_imm, id_cap_is_csr, id_cap_csr_we, id_cap_csr_use_imm;
  logic            id_cap_is_jal, id_cap_is_jalr, id_cap_is_branch, id_cap_check_misalign;
  logic            id_cap_trap_req;
  logic [XLEN-1:0] id_cap_trap_cause;
  mem_size_t       id_cap_mem_size;
  alu_op_t         id_cap_alu_op;
  wb_sel_t         id_cap_wb_sel;
  imm_type_t       id_cap_imm_type;
  csr_op_t         id_cap_csr_op;

  control u_control_cap (
      .instr          (if_rdata),
      .rf_we          (id_cap_rf_we),
      .mem_we         (id_cap_mem_we),
      .mem_re         (id_cap_mem_re),
      .mem_size       (id_cap_mem_size),
      .mem_unsigned   (id_cap_mem_unsigned),
      .alu_src_imm    (id_cap_alu_src_imm),
      .alu_op         (id_cap_alu_op),
      .wb_sel         (id_cap_wb_sel),
      .imm_type       (id_cap_imm_type),
      .is_csr         (id_cap_is_csr),
      .csr_we         (id_cap_csr_we),
      .csr_op         (id_cap_csr_op),
      .csr_use_imm    (id_cap_csr_use_imm),
      .is_jal         (id_cap_is_jal),
      .is_jalr        (id_cap_is_jalr),
      .is_branch      (id_cap_is_branch),
      .trap_req       (id_cap_trap_req),
      .trap_cause     (id_cap_trap_cause),
      .check_misalign (id_cap_check_misalign)
  );

  imm_gen u_imm_gen_cap (
      .inst    (if_rdata),
      .imm_type(id_cap_imm_type),
      .imm     (id_cap_imm)
  );
`endif

  assign id_rs1 = if_id_instr[RS1_MSB:RS1_LSB];
  assign id_rs2 = if_id_instr[RS2_MSB:RS2_LSB];
  assign id_rd  = if_id_instr[RD_MSB:RD_LSB];

`ifndef ASIC_DECODE_REG
  control u_control (
      .instr          (if_id_instr),
      .rf_we          (id_rf_we),
      .mem_we         (id_mem_we),
      .mem_re         (id_mem_re),
      .mem_size       (id_mem_size),
      .mem_unsigned   (id_mem_unsigned),
      .alu_src_imm    (id_alu_src_imm),
      .alu_op         (id_alu_op),
      .wb_sel         (id_wb_sel),
      .imm_type       (id_imm_type),
      .is_csr         (id_is_csr),
      .csr_we         (id_csr_we),
      .csr_op         (id_csr_op),
      .csr_use_imm    (id_csr_use_imm),
      .is_jal         (id_is_jal),
      .is_jalr        (id_is_jalr),
      .is_branch      (id_is_branch),
      .trap_req       (id_trap_req),
      .trap_cause     (id_trap_cause),
      .check_misalign (id_check_misalign)
  );

  imm_gen u_imm_gen (
      .inst    (if_id_instr),
      .imm_type(id_imm_type),
      .imm     (id_imm)
  );
`endif

  regfile u_regfile (
      .clk(clk),
      .rst(rst),
      .we (mem_wb_rf_we && mem_wb_valid && !flush_mem_wb),
      .ra1(id_rs1),
      .ra2(id_rs2),
      .wa (mem_wb_rd),
      .wd (wb_wdata),
      .rd1(id_rd1),
      .rd2(id_rd2)
`ifdef ASIC_DECODE_REG
      ,
      .ra1_cap(if_rdata[RS1_MSB:RS1_LSB]),
      .rd1_cap(id_cap_rd1)
`else
      ,
      .ra1_cap(5'b0),
      .rd1_cap(id_cap_rd1_unused)
`endif
  );

  csr_file u_csr (
      .clk       (clk),
      .rst       (rst),
      .trap      (trap_take),
      .trap_pc   (trap_pc),
      .trap_cause(trap_cause),
      .trap_val  (trap_val),
      .csr_raddr (mem_wb_csr_addr),
      .csr_rdata (csr_rdata),
      .csr_we    (mem_wb_csr_we && mem_wb_valid && !flush_mem_wb),
      .csr_op    (mem_wb_csr_op),
      .csr_wdata (mem_wb_csr_wdata),
      .mtvec     (mtvec),
      .mepc      (mepc),
      .mcause    (mcause)
  );

  // =========================================================================
  // Hazard detection
  // =========================================================================
  assign load_use_stall = id_ex_valid && id_ex_mem_re && id_ex_rf_we && (id_ex_rd != REG_ZERO) &&
                          ((id_ex_rd == id_rs1 && id_rs1 != REG_ZERO) ||
                           (id_ex_rd == id_rs2 && id_rs2 != REG_ZERO));

  assign mem_load_stall = id_ex_valid && ld_active && ld_active_rf_we && (ld_active_rd != REG_ZERO) &&
                          ((ld_active_rd == id_ex_rs1_a && id_ex_rs1_a != REG_ZERO) ||
                           (ld_active_rd == id_ex_rs2_a && id_ex_rs2_a != REG_ZERO));

  assign wb_csr_stall = mem_wb_valid && mem_wb_is_csr && mem_wb_rf_we && (mem_wb_rd != REG_ZERO) &&
                        (((mem_wb_rd == id_rs1) && (id_rs1 != REG_ZERO)) ||
                         ((mem_wb_rd == id_rs2) && (id_rs2 != REG_ZERO)));

  assign stall_if = load_use_stall || mem_load_stall || wb_csr_stall ||
                    load_issue_stall || load_queue_stall;
  assign stall_id = stall_if;

  assign trap_take  = (id_ex_valid && id_ex_trap_req) || (ex_mem_valid && mem_trap_req);
  assign trap_pc    = (id_ex_valid && id_ex_trap_req) ? id_ex_pc :
                      (ex_mem_valid && mem_trap_req) ? ex_mem_pc : '0;
  assign trap_cause = (id_ex_valid && id_ex_trap_req) ? id_ex_trap_cause :
                      (ex_mem_valid && mem_trap_req) ? mem_trap_cause : MCAUSE_ILLEGAL;
  assign trap_val   = (ex_mem_valid && mem_trap_req) ? mem_trap_val :
                      (id_ex_valid && id_ex_trap_req) ? if_id_instr : '0;

  // =========================================================================
  // IF — instruction fetch (pc_next computed in EX)
  // =========================================================================

`ifdef PIPELINE_TIMING
  always_ff @(posedge clk) begin
    if (rst) begin
      fetch_pc_q  <= RESET_PC;
      if_id_valid <= 1'b0;
      if_id_pc    <= '0;
      if_id_instr <= 32'h0000_0013;
    end else if (flush_if_id) begin
      if_id_valid <= 1'b0;
    end else if (!stall_if) begin
      if_id_pc    <= fetch_pc_q;
      if_id_instr <= if_rdata;
      if_id_valid <= 1'b1;
      fetch_pc_q  <= pc;
    end
  end
`elsif ASIC_SYNC_IF
  always_ff @(posedge clk) begin
    if (rst) begin
      fetch_pc_q  <= RESET_PC;
      if_id_valid <= 1'b0;
      if_id_pc    <= '0;
      if_id_instr <= 32'h0000_0013;
    end else if (flush_if_id) begin
      if_id_valid <= 1'b0;
    end else if (!stall_if) begin
      if_id_pc    <= fetch_pc_q;
      if_id_instr <= if_rdata;
      if_id_valid <= 1'b1;
      fetch_pc_q  <= pc;
    end
  end
`else
  always_ff @(posedge clk) begin
    if (rst) begin
      if_id_valid <= 1'b0;
      if_id_pc    <= '0;
      if_id_instr <= 32'h0000_0013;
    end else if (flush_if_id) begin
      if_id_valid <= 1'b0;
    end else if (!stall_if) begin
      if_id_valid <= 1'b1;
      if_id_pc    <= pc;
      if_id_instr <= if_rdata;
    end
  end
`endif


`ifdef ASIC_DECODE_REG
  always_ff @(posedge clk) begin
    if (rst || flush_if_id) begin
      id_dec_pc <= '0;
      id_dec_imm <= '0;
      id_dec_target <= '0;
      id_dec_jalr_base <= '0;
      id_dec_trap_cause <= '0;
      id_dec_rs1 <= '0;
      id_dec_rs2 <= '0;
      id_dec_rd <= '0;
      id_dec_funct3 <= '0;
      id_dec_opcode <= '0;
      id_dec_csr_addr <= '0;
      id_dec_rf_we <= 1'b0;
      id_dec_mem_we <= 1'b0;
      id_dec_mem_re <= 1'b0;
      id_dec_mem_unsigned <= 1'b0;
      id_dec_alu_src_imm <= 1'b0;
      id_dec_is_csr <= 1'b0;
      id_dec_csr_we <= 1'b0;
      id_dec_csr_use_imm <= 1'b0;
      id_dec_is_jal <= 1'b0;
      id_dec_is_jalr <= 1'b0;
      id_dec_is_branch <= 1'b0;
      id_dec_check_misalign <= 1'b0;
      id_dec_trap_req <= 1'b0;
      id_dec_mem_size <= MEM_WORD;
      id_dec_alu_op <= ALU_ADD;
      id_dec_wb_sel <= WB_ALU;
      id_dec_csr_op <= CSR_OP_RW;
    end else if (!stall_if) begin
`ifdef PIPELINE_TIMING
      id_dec_pc <= fetch_pc_q;
      id_dec_target <= fetch_pc_q + id_cap_imm;
`elsif ASIC_SYNC_IF
      id_dec_pc <= fetch_pc_q;
      id_dec_target <= fetch_pc_q + id_cap_imm;
`else
      id_dec_pc <= pc;
      id_dec_target <= pc + id_cap_imm;
`endif
      id_dec_rs1 <= if_rdata[RS1_MSB:RS1_LSB];
      id_dec_rs2 <= if_rdata[RS2_MSB:RS2_LSB];
      id_dec_rd <= if_rdata[RD_MSB:RD_LSB];
      id_dec_imm <= id_cap_imm;
      id_dec_jalr_base <= id_cap_rd1 + id_cap_imm;
      id_dec_funct3 <= if_rdata[FUNCT3_MSB:FUNCT3_LSB];
      id_dec_opcode <= if_rdata[OPCODE_MSB:OPCODE_LSB];
      id_dec_csr_addr <= if_rdata[31:20];
      id_dec_rf_we <= id_cap_rf_we;
      id_dec_mem_we <= id_cap_mem_we;
      id_dec_mem_re <= id_cap_mem_re;
      id_dec_mem_size <= id_cap_mem_size;
      id_dec_mem_unsigned <= id_cap_mem_unsigned;
      id_dec_alu_src_imm <= id_cap_alu_src_imm;
      id_dec_alu_op <= id_cap_alu_op;
      id_dec_wb_sel <= id_cap_wb_sel;
      id_dec_is_csr <= id_cap_is_csr;
      id_dec_csr_we <= id_cap_csr_we;
      id_dec_csr_op <= id_cap_csr_op;
      id_dec_csr_use_imm <= id_cap_csr_use_imm;
      id_dec_is_jal <= id_cap_is_jal;
      id_dec_is_jalr <= id_cap_is_jalr;
      id_dec_is_branch <= id_cap_is_branch;
      id_dec_check_misalign <= id_cap_check_misalign;
      id_dec_trap_req <= id_cap_trap_req;
      id_dec_trap_cause <= id_cap_trap_cause;
    end
  end
`endif

  // =========================================================================
  // ID/EX pipeline register
  // =========================================================================
  always_ff @(posedge clk) begin
    if (rst || flush_id_ex) begin
      id_ex_valid <= 1'b0;
    end else if (load_use_stall) begin
      id_ex_valid <= 1'b0;  // bubble
    end else if (!stall_id) begin
      id_ex_valid <= if_id_valid;
      id_ex_rs1   <= id_rd1;
      id_ex_rs2   <= id_rd2;
`ifdef ASIC_DECODE_REG
      id_ex_pc <= id_dec_pc;
      id_ex_imm <= id_dec_imm;
      id_ex_target <= id_dec_target;
      id_ex_jalr_base <= id_dec_jalr_base;
      id_ex_rs1_a <= id_dec_rs1;
      id_ex_rs2_a <= id_dec_rs2;
      id_ex_rd <= id_dec_rd;
      id_ex_funct3 <= id_dec_funct3;
      id_ex_opcode <= id_dec_opcode;
      id_ex_rf_we <= id_dec_rf_we;
      id_ex_mem_we <= id_dec_mem_we;
      id_ex_mem_re <= id_dec_mem_re;
      id_ex_mem_size <= id_dec_mem_size;
      id_ex_mem_unsigned <= id_dec_mem_unsigned;
      id_ex_alu_src_imm <= id_dec_alu_src_imm;
      id_ex_alu_op <= id_dec_alu_op;
      id_ex_wb_sel <= id_dec_wb_sel;
      id_ex_is_csr <= id_dec_is_csr;
      id_ex_csr_we <= id_dec_csr_we;
      id_ex_csr_op <= id_dec_csr_op;
      id_ex_csr_use_imm <= id_dec_csr_use_imm;
      id_ex_is_jal <= id_dec_is_jal;
      id_ex_is_jalr <= id_dec_is_jalr;
      id_ex_is_branch <= id_dec_is_branch;
      id_ex_check_misalign <= id_dec_check_misalign;
      id_ex_trap_req <= id_dec_trap_req;
      id_ex_trap_cause <= id_dec_trap_cause;
      id_ex_csr_addr <= id_dec_csr_addr;
`else
      id_ex_pc            <= if_id_pc;
      id_ex_imm           <= id_imm;
      id_ex_target        <= if_id_pc + id_imm;
      id_ex_jalr_base     <= id_rd1 + id_imm;
      id_ex_rs1_a         <= id_rs1;
      id_ex_rs2_a         <= id_rs2;
      id_ex_rd            <= id_rd;
      id_ex_funct3        <= if_id_instr[FUNCT3_MSB:FUNCT3_LSB];
      id_ex_opcode        <= if_id_instr[OPCODE_MSB:OPCODE_LSB];
      id_ex_rf_we         <= id_rf_we;
      id_ex_mem_we        <= id_mem_we;
      id_ex_mem_re        <= id_mem_re;
      id_ex_mem_size      <= id_mem_size;
      id_ex_mem_unsigned  <= id_mem_unsigned;
      id_ex_alu_src_imm   <= id_alu_src_imm;
      id_ex_alu_op        <= id_alu_op;
      id_ex_wb_sel        <= id_wb_sel;
      id_ex_is_csr        <= id_is_csr;
      id_ex_csr_we        <= id_csr_we;
      id_ex_csr_op        <= id_csr_op;
      id_ex_csr_use_imm   <= id_csr_use_imm;
      id_ex_is_jal        <= id_is_jal;
      id_ex_is_jalr       <= id_is_jalr;
      id_ex_is_branch     <= id_is_branch;
      id_ex_check_misalign<= id_check_misalign;
      id_ex_trap_req      <= id_trap_req;
      id_ex_trap_cause    <= id_trap_cause;
      id_ex_csr_addr      <= if_id_instr[31:20];
`endif
    end
  end


  // =========================================================================
  // EX — forward, ALU, branch
  // =========================================================================
  logic [XLEN-1:0] wb_fwd_val;
  logic            fa_mem, fa_wb, fb_mem, fb_wb;

  assign wb_fwd_val = (mem_wb_wb_sel == WB_MEM) ? mem_wb_mem :
                      (mem_wb_wb_sel == WB_PC4) ? mem_wb_pc4 :
                      mem_wb_alu;

  assign fa_mem = ex_mem_valid && ex_mem_rf_we && !ex_mem_mem_re &&
                  (ex_mem_rd != REG_ZERO) && (ex_mem_rd == id_ex_rs1_a);
  assign fa_wb  = mem_wb_valid && mem_wb_rf_we && !mem_wb_is_csr &&
                  (mem_wb_rd != REG_ZERO) && (mem_wb_rd == id_ex_rs1_a) && !fa_mem;
  assign fb_mem = ex_mem_valid && ex_mem_rf_we && !ex_mem_mem_re &&
                  (ex_mem_rd != REG_ZERO) && (ex_mem_rd == id_ex_rs2_a);
  assign fb_wb  = mem_wb_valid && mem_wb_rf_we && !mem_wb_is_csr &&
                  (mem_wb_rd != REG_ZERO) && (mem_wb_rd == id_ex_rs2_a) && !fb_mem;

  assign ex_rs1_fwd = fa_mem ? ex_mem_alu_result :
                      fa_wb  ? wb_fwd_val :
                      id_ex_rs1;
  assign ex_rs2_fwd = fb_mem ? ex_mem_alu_result :
                      fb_wb  ? wb_fwd_val :
                      id_ex_rs2;

  function automatic logic branch_taken(input logic [2:0] f3, input logic [XLEN-1:0] a, b);
    unique case (f3)
      F3_BEQ:  branch_taken = (a == b);
      F3_BNE:  branch_taken = (a != b);
      F3_BLT:  branch_taken = ($signed(a) < $signed(b));
      F3_BGE:  branch_taken = ($signed(a) >= $signed(b));
      F3_BLTU: branch_taken = (a < b);
      F3_BGEU: branch_taken = (a >= b);
      default: branch_taken = 1'b0;
    endcase
  endfunction

  assign ex_branch_taken = id_ex_valid && (id_ex_opcode == OPCODE_BRANCH) &&
                           branch_taken(id_ex_funct3, ex_rs1_fwd, ex_rs2_fwd);

  wire ex_is_jal  = (id_ex_opcode == OPCODE_JAL);
  wire ex_is_jalr = (id_ex_opcode == OPCODE_JALR);

  assign ex_redirect = id_ex_valid && (ex_branch_taken || ex_is_jal || ex_is_jalr);

  assign flush_if_id  = ex_redirect | trap_take;
  assign flush_id_ex  = ex_redirect | trap_take;
  assign flush_ex_mem = trap_take;
  assign flush_mem_wb = trap_take;

  // JALR: skip ALU→PC when rs1 needs no EX/MEM/WB forward
  assign ex_jalr_target = (fa_mem || fa_wb) ? {ex_alu_result[31:1], 1'b0} :
                                             {id_ex_jalr_base[31:1], 1'b0};

  assign pc_plus4    = pc + 32'd4;
  assign pc_redirect = ex_is_jalr ? ex_jalr_target : id_ex_target;

  always_comb begin
    if (trap_take)
      pc_next = mtvec;
    else if (id_ex_valid && ex_redirect)
      pc_next = pc_redirect;
    else
      pc_next = pc_plus4;
  end

  always_comb begin
    unique case (id_ex_opcode)
      OPCODE_LUI:   ex_alu_a = '0;
      OPCODE_AUIPC: ex_alu_a = id_ex_pc;
      default:      ex_alu_a = ex_rs1_fwd;
    endcase
  end

  assign ex_alu_b = id_ex_alu_src_imm ? id_ex_imm : ex_rs2_fwd;

  alu u_alu (
      .a         (ex_alu_a),
      .b         (ex_alu_b),
      .alu_op    (id_ex_alu_op),
      .alu_result(ex_alu_result)
  );

  always_ff @(posedge clk) begin
    if (rst)
      pc <= RESET_PC;
    else if (!stall_if)
      pc <= pc_next;
  end

  // =========================================================================
  // EX/MEM — load pending (FPGA 2-cycle read)
  // =========================================================================
`ifdef PIPELINE_TIMING
  always_ff @(posedge clk) begin
    if (rst || flush_ex_mem)
      ld_data_rdy <= 1'b0;
    else
      ld_data_rdy <= ld_pend && mem_load_ready;
  end

  always_ff @(posedge clk) begin
    if (rst || flush_ex_mem)
      ld_pend <= 1'b0;
    else if (ld_data_rdy)
      ld_pend <= 1'b0;
    else if (mem_re_req)
      ld_pend <= 1'b1;
  end

  always_ff @(posedge clk) begin
    if (mem_re_req) begin
      ld_pend_pc     <= ex_mem_pc;
      ld_pend_alu    <= ex_mem_alu_result;
      ld_pend_rd     <= ex_mem_rd;
      ld_pend_rf_we  <= ex_mem_rf_we;
      ld_pend_wb_sel <= ex_mem_wb_sel;
    end
  end
`endif

  always_ff @(posedge clk) begin
    if (rst || flush_ex_mem) begin
      ex_mem_valid <= 1'b0;
    end else if (load_issue_stall || (mem_load_stall && ex_mem_valid && ex_mem_mem_re)) begin
      // hold load in MEM while dependent is in EX, or FPGA load address issue
    end else if (id_ex_valid && (!stall_id || load_use_stall)) begin
      ex_mem_valid          <= 1'b1;
      ex_mem_pc             <= id_ex_pc;
      ex_mem_alu_result     <= ex_alu_result;
      ex_mem_rs2            <= ex_rs2_fwd;
      ex_mem_rd             <= id_ex_rd;
      ex_mem_rf_we          <= id_ex_rf_we;
      ex_mem_mem_we         <= id_ex_mem_we;
      ex_mem_mem_re         <= id_ex_mem_re;
      ex_mem_mem_size       <= id_ex_mem_size;
      ex_mem_mem_unsigned   <= id_ex_mem_unsigned;
      ex_mem_wb_sel         <= id_ex_wb_sel;
      ex_mem_is_csr         <= id_ex_is_csr;
      ex_mem_csr_we         <= id_ex_csr_we;
      ex_mem_csr_op         <= id_ex_csr_op;
      ex_mem_csr_use_imm    <= id_ex_csr_use_imm;
      ex_mem_csr_addr       <= id_ex_csr_addr;
      ex_mem_check_misalign <= id_ex_check_misalign;
      ex_mem_csr_wdata      <= id_ex_csr_use_imm ? {27'b0, id_ex_rs1_a} : ex_rs1_fwd;
    end else begin
      ex_mem_valid <= 1'b0;
    end
  end

  always_comb begin
    mem_trap_req   = 1'b0;
    mem_trap_cause = MCAUSE_LOAD_MIS;
    mem_trap_val   = ex_mem_alu_result;
    if (ex_mem_valid && ex_mem_check_misalign && (ex_mem_alu_result[1:0] != 2'b00)) begin
`ifdef PIPELINE_TIMING
      if (!ex_mem_mem_re || mem_load_ready)
`endif
      begin
        mem_trap_req   = 1'b1;
        mem_trap_cause = ex_mem_mem_re ? MCAUSE_LOAD_MIS : MCAUSE_STORE_MIS;
      end
    end
  end

  // =========================================================================
  // MEM/WB pipeline register
  // =========================================================================
  always_ff @(posedge clk) begin
    if (rst || flush_mem_wb) begin
      mem_wb_valid <= 1'b0;
`ifdef PIPELINE_TIMING
    end else if (ld_data_rdy && !mem_trap_req) begin
      mem_wb_valid        <= 1'b1;
      mem_wb_pc4          <= ld_pend_pc + 32'd4;
      mem_wb_alu          <= ld_pend_alu;
      mem_wb_mem          <= mem_rdata;
      mem_wb_rd           <= ld_pend_rd;
      mem_wb_rf_we        <= ld_pend_rf_we;
      mem_wb_wb_sel       <= ld_pend_wb_sel;
      mem_wb_is_csr       <= 1'b0;
      mem_wb_csr_we       <= 1'b0;
      mem_wb_csr_op       <= CSR_OP_RW;
      mem_wb_csr_use_imm  <= 1'b0;
      mem_wb_csr_addr     <= '0;
      mem_wb_csr_wdata    <= '0;
    end else if (ex_mem_valid && !ex_mem_mem_re && !mem_trap_req) begin
`else
    end else if (ex_mem_valid && !mem_trap_req) begin
`endif
      mem_wb_valid        <= 1'b1;
      mem_wb_pc4          <= ex_mem_pc + 32'd4;
      mem_wb_alu          <= ex_mem_alu_result;
      mem_wb_mem          <= mem_rdata;
      mem_wb_rd           <= ex_mem_rd;
      mem_wb_rf_we        <= ex_mem_rf_we;
      mem_wb_wb_sel       <= ex_mem_wb_sel;
      mem_wb_is_csr       <= ex_mem_is_csr;
      mem_wb_csr_we       <= ex_mem_csr_we;
      mem_wb_csr_op       <= ex_mem_csr_op;
      mem_wb_csr_use_imm  <= ex_mem_csr_use_imm;
      mem_wb_csr_addr     <= ex_mem_csr_addr;
      mem_wb_csr_wdata    <= ex_mem_csr_wdata;
    end else begin
      mem_wb_valid <= 1'b0;
    end
  end

  always_comb begin
    unique case (mem_wb_wb_sel)
      WB_MEM: wb_wdata = mem_wb_mem;
      WB_PC4: wb_wdata = mem_wb_pc4;
      WB_CSR: wb_wdata = csr_rdata;
      default: wb_wdata = mem_wb_alu;
    endcase
  end

  always_ff @(posedge clk) begin
    if (rst)
      trap_entered_q <= 1'b0;
    else if (trap_take && (trap_cause == MCAUSE_EBREAK || trap_cause == MCAUSE_ECALL_M))
      trap_entered_q <= 1'b1;
  end

endmodule
