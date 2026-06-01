// imm_gen_tb.sv — unit tests for rtl/imm_gen.sv

module imm_gen_tb;

  import riscv_pkg::*;

  logic [INSTR_WIDTH-1:0] inst;
  imm_type_t              imm_type;
  logic [XLEN-1:0]        imm;

  imm_gen dut (
    .inst     (inst),
    .imm_type (imm_type),
    .imm      (imm)
  );

  int pass_count;
  int fail_count;

  function automatic logic [XLEN-1:0] ref_imm(
    input logic [INSTR_WIDTH-1:0] i,
    input imm_type_t              t
  );
    unique case (t)
      IMM_TYPE_I: ref_imm = {{20{i[31]}}, i[31:20]};
      IMM_TYPE_S: ref_imm = {{20{i[31]}}, i[31:25], i[11:7]};
      IMM_TYPE_B: ref_imm = {{19{i[31]}}, i[31], i[7], i[30:25], i[11:8], 1'b0};
      IMM_TYPE_U: ref_imm = {i[31:12], 12'b0};
      IMM_TYPE_J: ref_imm = {{11{i[31]}}, i[31], i[19:12], i[20], i[30:21], 1'b0};
      default:    ref_imm = '0;
    endcase
  endfunction

  task automatic check_imm(
    input string       name,
    input logic [31:0] instruction,
    input imm_type_t   itype,
    input logic [31:0] expected
  );
    inst     = instruction;
    imm_type = itype;
    #1;
    if (imm !== expected) begin
      $error("[%s] imm=0x%08x (exp 0x%08x) ref=0x%08x",
             name, imm, expected, ref_imm(inst, itype));
      fail_count++;
    end else begin
      $display("PASS: %s", name);
      pass_count++;
    end
  endtask

  task automatic check_matches_ref(input string name, input logic [31:0] instruction, input imm_type_t itype);
    logic [31:0] exp;
    inst     = instruction;
    imm_type = itype;
    exp      = ref_imm(instruction, itype);
    #1;
    if (imm !== exp) begin
      $error("[%s] imm=0x%08x ref=0x%08x", name, imm, exp);
      fail_count++;
    end else begin
      $display("PASS: %s (ref match)", name);
      pass_count++;
    end
  endtask

  initial begin
    pass_count = 0;
    fail_count = 0;

    $display("=== imm_gen_tb start ===");

    // I-type: ADDI x6, x0, 10
    check_imm("I ADDI +10", 32'h00A00313, IMM_TYPE_I, 32'd10);
    // I-type: ADDI x7, x7, -1
    check_imm("I ADDI -1", 32'hFFF38393, IMM_TYPE_I, 32'hFFFF_FFFF);
    // I-type: LW offset (example encoding)
    check_imm("I LW offset 8", 32'h0082A303, IMM_TYPE_I, 32'd8);

    // U-type: LUI x4, 0x80000
    check_imm("U LUI 0x80000", 32'h80000237, IMM_TYPE_U, 32'h8000_0000);

    // S-type: SW x10, 4(x11) — imm = 4
    check_matches_ref("S SW +4", 32'h0045A623, IMM_TYPE_S);

    // B-type: BNE (forward branch); golden = ref_imm()
    check_matches_ref("B BNE forward", 32'h00828263, IMM_TYPE_B);

    // J-type: JAL x0, +4 — imm = 4
    check_matches_ref("J JAL +4", 32'h0040006F, IMM_TYPE_J);

    // Negative B-type offset (backward branch)
    check_matches_ref("B negative offset", 32'hFE0298E3, IMM_TYPE_B);

    $display("=== imm_gen_tb done: %0d passed, %0d failed ===", pass_count, fail_count);
    if (fail_count != 0)
      $fatal(1, "imm_gen tests failed");
    $finish;
  end

endmodule
