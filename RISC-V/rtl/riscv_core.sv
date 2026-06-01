// riscv_core.sv — single-cycle RV32I (see SPEC.md §3.4)
/* verilator lint_off UNOPTFLAT */  // combinational loop: control ↔ ALU ↔ branch (expected)

`ifdef FPGA_TIMING_SYNTH
(* dont_touch = "yes" *)
`endif
module riscv_core (
    input  logic clk,
    input  logic rst,
    output logic halt_0
`ifdef FPGA_TIMING_SYNTH
    ,
    output logic [riscv_pkg::XLEN-1:0] dbg_pc
`endif
);

  import riscv_pkg::*;

  // ---------------------------------------------------------------------------
  // PC
  // ---------------------------------------------------------------------------
  logic [XLEN-1:0] pc;
  logic [XLEN-1:0] pc_next;
  logic [XLEN-1:0] pc_plus4;

  assign pc_plus4 = pc + 32'd4;

  // ---------------------------------------------------------------------------
  // Fetch
  // ---------------------------------------------------------------------------
  logic [INSTR_WIDTH-1:0] instr;

  instr_mem u_instr_mem (
      .addr (pc),
      .rdata(instr)
  );

  // ---------------------------------------------------------------------------
  // Decode fields
  // ---------------------------------------------------------------------------
  logic [6:0] opcode;
  logic [4:0] rs1;
  logic [4:0] rs2;
  logic [4:0] rd;

  assign opcode = instr[OPCODE_MSB:OPCODE_LSB];
  assign rs1    = instr[RS1_MSB:RS1_LSB];
  assign rs2    = instr[RS2_MSB:RS2_LSB];
  assign rd     = instr[RD_MSB:RD_LSB];

  // ---------------------------------------------------------------------------
  // Control + immediate
  // ---------------------------------------------------------------------------
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

  logic [XLEN-1:0] imm;

  control u_control (
      .instr       (instr),
      .zero        (zero),
      .lt          (lt),
      .ltu         (ltu),
      .rf_we       (rf_we),
      .mem_we      (mem_we),
      .mem_re      (mem_re),
      .mem_size    (mem_size),
      .mem_unsigned(mem_unsigned),
      .alu_src_imm (alu_src_imm),
      .alu_op      (alu_op),
      .wb_sel      (wb_sel),
      .imm_type    (imm_type),
      .pc_sel      (pc_sel),
      .halt        (halt),
      .branch_taken(branch_taken)
  );

  imm_gen u_imm_gen (
      .inst    (instr),
      .imm_type(imm_type),
      .imm     (imm)
  );

  assign halt_0 = halt;

  // ---------------------------------------------------------------------------
  // Register file
  // ---------------------------------------------------------------------------
  logic [XLEN-1:0] rd1;
  logic [XLEN-1:0] rd2;
  logic [XLEN-1:0] rf_wdata;

  regfile u_regfile (
      .clk (clk),
      .rst (rst),
      .we  (rf_we),
      .ra1 (rs1),
      .ra2 (rs2),
      .wa  (rd),
      .wd  (rf_wdata),
      .rd1 (rd1),
      .rd2 (rd2)
  );

`ifdef FPGA_TIMING_SYNTH
  assign dbg_pc = pc;
`endif

  // ---------------------------------------------------------------------------
  // ALU
  // ---------------------------------------------------------------------------
  logic [XLEN-1:0] alu_a;
  logic [XLEN-1:0] alu_b;
  logic [XLEN-1:0] alu_result;
  logic            zero;
  logic            lt;
  logic            ltu;

  assign alu_b = alu_src_imm ? imm : rd2;

  assign alu_a = (opcode == OPCODE_LUI) ? '0 :
                  (opcode == OPCODE_AUIPC) ? pc :
                  rd1;

  alu u_alu (
      .a         (alu_a),
      .b         (alu_b),
      .alu_op    (alu_op),
      .alu_result(alu_result),
      .zero      (zero),
      .lt        (lt),
      .ltu       (ltu)
  );

  // ---------------------------------------------------------------------------
  // Write-back mux
  // ---------------------------------------------------------------------------
  logic [XLEN-1:0] load_data;

  always_comb begin
    unique case (wb_sel)
      WB_MEM: rf_wdata = load_data;
      WB_PC4: rf_wdata = pc_plus4;
      default: rf_wdata = alu_result; // WB_ALU and default
    endcase
  end

  // ---------------------------------------------------------------------------
  // Data memory
  // ---------------------------------------------------------------------------
  data_mem u_data_mem (
      .clk        (clk),
      .we         (mem_we),
      .re         (mem_re),
      .size       (mem_size),
      .unsigned_ld(mem_unsigned),
      .addr       (alu_result),
      .wdata      (rd2),
      .rdata      (load_data)
  );

  // ---------------------------------------------------------------------------
  // Next PC
  // ---------------------------------------------------------------------------
  logic [XLEN-1:0] branch_target;
  logic [XLEN-1:0] jal_target;

  assign branch_target = pc + imm;
  assign jal_target    = pc + imm;

  always_comb begin
    unique case (pc_sel)
      PC_BRANCH: pc_next = branch_target;
      PC_JAL:    pc_next = jal_target;
      PC_JALR:   pc_next = {alu_result[31:1], 1'b0};
      default:   pc_next = pc_plus4;
    endcase
  end

  always_ff @(posedge clk) begin
    if (rst)
      pc <= RESET_PC;
    else if (!halt)
      pc <= pc_next;
  end

endmodule

/* verilator lint_on UNOPTFLAT */
