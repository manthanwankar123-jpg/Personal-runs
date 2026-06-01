// alu_tb.sv — directed tests for rtl/alu.sv (run via sim/Makefile)

module alu_tb;

  import riscv_pkg::*;

  logic [XLEN-1:0] a, b;
  logic [XLEN-1:0] alu_result;
  alu_op_t         alu_op;
  logic            zero, lt, ltu;

  alu dut (
    .a          (a),
    .b          (b),
    .alu_op     (alu_op),
    .alu_result (alu_result),
    .zero       (zero),
    .lt         (lt),
    .ltu        (ltu)
  );

  int pass_count;
  int fail_count;

  task automatic check_alu(
    input string       name,
    input logic [31:0] ta,
    input logic [31:0] tb,
    input alu_op_t     top,
    input logic [31:0] expected_result,
    input logic        expected_zero
  );
    a      = ta;
    b      = tb;
    alu_op = top;
    #1;
    if (alu_result !== expected_result) begin
      $error("[%s] alu_result: got %0d (0x%08x), expected %0d (0x%08x)",
             name, alu_result, alu_result, expected_result, expected_result);
      fail_count++;
    end else if (zero !== expected_zero) begin
      $error("[%s] zero: got %0b, expected %0b", name, zero, expected_zero);
      fail_count++;
    end else begin
      $display("PASS: %s", name);
      pass_count++;
    end
  endtask

  task automatic check_branch_flags(
    input string       name,
    input logic [31:0] ta,
    input logic [31:0] tb,
    input logic        expected_lt,
    input logic        expected_ltu
  );
    a      = ta;
    b      = tb;
    alu_op = ALU_ADD;  // op does not affect lt/ltu
    #1;
    if (lt !== expected_lt || ltu !== expected_ltu) begin
      $error("[%s] lt=%0b (exp %0b) ltu=%0b (exp %0b)", name, lt, expected_lt, ltu, expected_ltu);
      fail_count++;
    end else begin
      $display("PASS: %s", name);
      pass_count++;
    end
  endtask

  initial begin
    pass_count = 0;
    fail_count = 0;

    $display("=== alu_tb start ===");

    check_alu("ADD", 32'd10, 32'd5, ALU_ADD, 32'd15, 1'b0);
    check_alu("SUB equal", 32'd7, 32'd7, ALU_SUB, 32'd0, 1'b1);
    check_alu("SUB", 32'd8, 32'd3, ALU_SUB, 32'd5, 1'b0);
    check_alu("AND", 32'hF0, 32'h0F, ALU_AND, 32'h00, 1'b1);
    check_alu("OR", 32'hF0, 32'h0F, ALU_OR, 32'hFF, 1'b0);
    check_alu("XOR", 32'd8, 32'd3, ALU_XOR, 32'd11, 1'b0);
    check_alu("SLL", 32'd1, 32'd4, ALU_SLL, 32'd16, 1'b0);
    check_alu("SLL shamt mod 32", 32'd1, 32'd36, ALU_SLL, 32'd16, 1'b0);  // 36[4:0]==4
    check_alu("SRL", 32'd16, 32'd2, ALU_SRL, 32'd4, 1'b0);
    check_alu("SRA", 32'h8000_0000, 32'd1, ALU_SRA, 32'hC000_0000, 1'b0);
    check_alu("SLT signed -1 < 1", 32'hFFFF_FFFF, 32'd1, ALU_SLT, 32'd1, 1'b0);
    check_alu("SLT signed 1 < -1", 32'd1, 32'hFFFF_FFFF, ALU_SLT, 32'd0, 1'b1);
    check_alu("SLTU 1 < 0xFFFFFFFF", 32'd1, 32'hFFFF_FFFF, ALU_SLTU, 32'd1, 1'b0);

    check_branch_flags("lt signed -1 vs 1", 32'hFFFF_FFFF, 32'd1, 1'b1, 1'b0);
    check_branch_flags("lt unsigned 1 vs 0xFFFFFFFF", 32'd1, 32'hFFFF_FFFF, 1'b0, 1'b1);

    $display("=== alu_tb done: %0d passed, %0d failed ===", pass_count, fail_count);
    if (fail_count != 0) begin
      $fatal(1, "ALU tests failed");
    end
    $finish;
  end

endmodule
