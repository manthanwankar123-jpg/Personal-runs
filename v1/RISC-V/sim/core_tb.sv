// core_tb.sv — integration sim: mem_sum5, mem_sort8, mem_gcd

module core_tb;

  import riscv_pkg::*;

  logic clk;
  logic rst;
  logic halt_0;

  riscv_core dut (
      .clk    (clk),
      .rst    (rst),
      .halt_0 (halt_0)
  );

  int pass_count;
  int fail_count;

  function automatic void load_le_word(
      input int unsigned byte_off,
      input logic [31:0] word
  );
    dut.u_data_mem.mem[byte_off + 0] = word[7:0];
    dut.u_data_mem.mem[byte_off + 1] = word[15:8];
    dut.u_data_mem.mem[byte_off + 2] = word[23:16];
    dut.u_data_mem.mem[byte_off + 3] = word[31:24];
  endfunction

  function automatic logic [31:0] read_le_word(input int unsigned byte_off);
    read_le_word = {
      dut.u_data_mem.mem[byte_off + 3],
      dut.u_data_mem.mem[byte_off + 2],
      dut.u_data_mem.mem[byte_off + 1],
      dut.u_data_mem.mem[byte_off + 0]
    };
  endfunction

  task automatic clear_memories;
    int i;
    for (i = 0; i <= IMEM_ADDR_MASK; i++)
      dut.u_instr_mem.mem[i] = 8'h00;
    for (i = 0; i <= DMEM_ADDR_MASK; i++)
      dut.u_data_mem.mem[i] = 8'h00;
  endtask

  initial begin
    clk = 1'b0;
    rst = 1'b0;
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

  task automatic run_until_halt(input int max_cycles, output logic timed_out);
    int c;
    timed_out = 1'b0;
    for (c = 0; c < max_cycles; c++) begin
      tick();
      if (halt_0)
        break;
    end
    if (!halt_0)
      timed_out = 1'b1;
    else
      tick();  // settle regfile after EBREAK
  endtask

  task automatic run_program(
      input string       name,
      input string       hex_file,
      input int          max_cycles
  );
    logic timed_out;

    $display("--- %s ---", name);
    clear_memories();
    $readmemh(hex_file, dut.u_instr_mem.mem);

    case (name)
      "mem_sum5": begin
        load_le_word(0, 32'd1);
        load_le_word(4, 32'd2);
        load_le_word(8, 32'd3);
        load_le_word(12, 32'd4);
        load_le_word(16, 32'd5);
      end
      "mem_sort8": begin
        load_le_word(0, 32'd42);
        load_le_word(4, 32'd7);
        load_le_word(8, 32'd101);
        load_le_word(12, 32'd3);
        load_le_word(16, 32'd15);
        load_le_word(20, 32'd8);
        load_le_word(24, 32'd99);
        load_le_word(28, 32'd1);
      end
      "mem_gcd": begin
        load_le_word(0, 32'd66);
        load_le_word(4, 32'd99);
      end
      default: $fatal(1, "unknown program %s", name);
    endcase

    pulse_reset();
    run_until_halt(max_cycles, timed_out);

    if (timed_out) begin
      $error("%s: timeout after %0d cycles", name, max_cycles);
      fail_count++;
      return;
    end

    case (name)
      "mem_sum5": begin
        if (dut.u_regfile.regs[11] !== 32'd15) begin
          $error("%s: x11=%0d expected 15", name, dut.u_regfile.regs[11]);
          fail_count++;
        end
        else begin
          $display("%s PASS: x11=%0d", name, dut.u_regfile.regs[11]);
          pass_count++;
        end
      end
      "mem_sort8": begin
        if (read_le_word(0) !== 32'd1) begin
          $error("%s: mem[0]=%0d expected 1", name, read_le_word(0));
          fail_count++;
        end
        else if (read_le_word(28) !== 32'd101) begin
          $error("%s: mem[7]=%0d expected 101", name, read_le_word(28));
          fail_count++;
        end
        else if (dut.u_regfile.regs[11] !== 32'd276) begin
          $error("%s: x11(sum)=%0d expected 276", name, dut.u_regfile.regs[11]);
          fail_count++;
        end
        else begin
          $display("%s PASS: sorted [1..101] sum=%0d", name, dut.u_regfile.regs[11]);
          pass_count++;
        end
      end
      "mem_gcd": begin
        if (dut.u_regfile.regs[10] !== 32'd33) begin
          $error("%s: x10(gcd)=%0d expected 33", name, dut.u_regfile.regs[10]);
          fail_count++;
        end
        else if (read_le_word(8) !== 32'd33) begin
          $error("%s: mem[8]=%0d expected 33", name, read_le_word(8));
          fail_count++;
        end
        else begin
          $display("%s PASS: gcd=%0d (x10 and mem[8])", name, dut.u_regfile.regs[10]);
          pass_count++;
        end
      end
    endcase
  endtask

  initial begin
    pass_count = 0;
    fail_count = 0;

    run_program("mem_sum5",  "program.hex",       256);
    run_program("mem_sort8", "program_sort8.hex", 8192);
    run_program("mem_gcd",   "program_gcd.hex",   4096);

    if (fail_count == 0)
      $display("core_tb: ALL PASS (%0d programs)", pass_count);
    else
      $display("core_tb: FAIL (%0d failed, %0d passed)", fail_count, pass_count);

    $finish;
  end

endmodule
