// regfile_tb.sv — unit tests for rtl/regfile.sv

module regfile_tb;

  import riscv_pkg::*;

  logic clk;
  logic rst;
  logic we;
  logic [REG_ADDR_WIDTH-1:0] ra1, ra2, wa;
  logic [XLEN-1:0]           wd;
  logic [XLEN-1:0]           rd1, rd2;

  regfile dut (
    .clk  (clk),
    .rst  (rst),
    .we   (we),
    .ra1  (ra1),
    .ra2  (ra2),
    .wa   (wa),
    .wd   (wd),
    .rd1  (rd1),
    .rd2  (rd2)
  );

  int pass_count;
  int fail_count;

  initial begin
    clk = 1'b0;
    rst = 1'b0;
    we  = 1'b0;
  end
  always #5 clk = ~clk;

  task automatic tick;
    @(posedge clk);
  endtask

  task automatic pulse_reset;
    rst = 1'b1;
    repeat (2) tick();
    rst = 1'b0;
    tick();
  endtask

  task automatic check_read(
    input string       name,
    input logic [4:0]  raddr1,
    input logic [4:0]  raddr2,
    input logic [31:0] exp1,
    input logic [31:0] exp2
  );
    ra1 = raddr1;
    ra2 = raddr2;
    tick();  // sample after write has latched (NBA)
    #1;
    if (rd1 !== exp1 || rd2 !== exp2) begin
      $error("[%s] rd1=%0d (exp %0d) rd2=%0d (exp %0d)",
             name, rd1, exp1, rd2, exp2);
      fail_count++;
    end else begin
      $display("PASS: %s", name);
      pass_count++;
    end
  endtask

  task automatic write_reg(
    input logic [4:0]  waddr,
    input logic [31:0] data
  );
    wa  = waddr;
    wd  = data;
    we  = 1'b1;
    @(posedge clk);
    @(negedge clk);
    we  = 1'b0;
  endtask

  initial begin
    pass_count = 0;
    fail_count = 0;
    we         = 1'b0;
    ra1        = '0;
    ra2        = '0;
    wa         = '0;
    wd         = '0;

    $display("=== regfile_tb start ===");

    pulse_reset;
    check_read("read x0 after reset", REG_ZERO, REG_ZERO, 32'd0, 32'd0);

    write_reg(5'd5, 32'd42);
    check_read("read x5 after write", 5'd5, REG_ZERO, 32'd42, 32'd0);

    write_reg(REG_ZERO, 32'd99);
    check_read("write x0 ignored", REG_ZERO, 5'd5, 32'd0, 32'd42);

    write_reg(5'd3, 32'd100);
    check_reg_dual: begin
      ra1 = 5'd3;
      ra2 = 5'd5;
      tick();
      #1;
      if (rd1 !== 32'd100 || rd2 !== 32'd42) begin
        $error("[dual read] rd1=%0d rd2=%0d", rd1, rd2);
        fail_count++;
      end else begin
        $display("PASS: dual read ports");
        pass_count++;
      end
    end

    pulse_reset;
    check_read("read x5 cleared after reset", 5'd5, 5'd3, 32'd0, 32'd0);

    $display("=== regfile_tb done: %0d passed, %0d failed ===", pass_count, fail_count);
    if (fail_count != 0)
      $fatal(1, "Register file tests failed");
    $finish;
  end

endmodule
