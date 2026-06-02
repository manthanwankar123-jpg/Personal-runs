// core_tb.sv — v2 integration (trap on EBREAK instead of halt)

module core_tb;

  import riscv_pkg::*;

  logic clk;
  logic rst;
  logic [31:0] dbg_pc;
  logic trap_entered;

  riscv_core dut (
      .clk          (clk),
      .rst          (rst),
      .dbg_pc       (dbg_pc),
      .trap_entered (trap_entered)
  );

  int pass_count;
  int fail_count;

  function automatic void load_le_word(
      input int unsigned byte_off,
      input logic [31:0] word
  );
    dut.u_mem.ram[byte_off + 0] = word[7:0];
    dut.u_mem.ram[byte_off + 1] = word[15:8];
    dut.u_mem.ram[byte_off + 2] = word[23:16];
    dut.u_mem.ram[byte_off + 3] = word[31:24];
  endfunction

  function automatic logic [31:0] read_le_word(input int unsigned byte_off);
    read_le_word = {
      dut.u_mem.ram[byte_off + 3],
      dut.u_mem.ram[byte_off + 2],
      dut.u_mem.ram[byte_off + 1],
      dut.u_mem.ram[byte_off + 0]
    };
  endfunction

  task automatic clear_memories;
    int i;
    for (i = 0; i <= ROM_ADDR_MASK; i++)
      dut.u_mem.u_instr_rom.bytes[i] = 8'h00;
    for (i = 0; i <= RAM_ADDR_MASK; i++)
      dut.u_mem.ram[i] = 8'h00;
    dut.u_mem.u_instr_rom.bytes[16'h100] = 8'h6f;
    dut.u_mem.u_instr_rom.bytes[16'h101] = 8'h00;
    dut.u_mem.u_instr_rom.bytes[16'h102] = 8'h00;
    dut.u_mem.u_instr_rom.bytes[16'h103] = 8'h00;
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
    repeat (3) tick();
    rst = 1'b0;
    repeat (2) tick();
  endtask

  task automatic run_until_trap(input int max_cycles, output logic timed_out);
    int c;
    timed_out = 1'b0;
    for (c = 0; c < max_cycles; c++) begin
      tick();
      if (dut.u_csr.mcause == MCAUSE_EBREAK)
        break;
    end
    if (dut.u_csr.mcause != MCAUSE_EBREAK)
      timed_out = 1'b1;
    else
      repeat (2) tick();
  endtask

  task automatic run_program(
      input string name,
      input string hex_file,
      input int    max_cycles
  );
    logic timed_out;

    $display("--- %s ---", name);
    clear_memories();
    $readmemh(hex_file, dut.u_mem.u_instr_rom.bytes);

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
    run_until_trap(max_cycles, timed_out);

    if (timed_out) begin
      $error("%s: timeout (pc=0x%08x trap=%0d)", name, dbg_pc, trap_entered);
      fail_count++;
      return;
    end

    case (name)
      "mem_sum5": begin
        if (dut.u_regfile.regs[11] !== 32'd15) begin
          $error("%s: x11=%0d expected 15", name, dut.u_regfile.regs[11]);
          fail_count++;
        end else begin
          $display("%s PASS: x11=%0d", name, dut.u_regfile.regs[11]);
          pass_count++;
        end
      end
      "mem_sort8": begin
        if (read_le_word(0) !== 32'd1) begin
          $error("%s: mem[0]=%0d expected 1", name, read_le_word(0));
          fail_count++;
        end else if (read_le_word(28) !== 32'd101) begin
          $error("%s: mem[7]=%0d expected 101", name, read_le_word(28));
          fail_count++;
        end else if (dut.u_regfile.regs[11] !== 32'd276) begin
          $error("%s: x11=%0d expected 276", name, dut.u_regfile.regs[11]);
          fail_count++;
        end else begin
          $display("%s PASS: sorted sum=%0d", name, dut.u_regfile.regs[11]);
          pass_count++;
        end
      end
      "mem_gcd": begin
        if (dut.u_regfile.regs[10] !== 32'd33) begin
          $error("%s: x10=%0d expected 33", name, dut.u_regfile.regs[10]);
          fail_count++;
        end else if (read_le_word(8) !== 32'd33) begin
          $error("%s: mem[8]=%0d expected 33", name, read_le_word(8));
          fail_count++;
        end else begin
          $display("%s PASS: gcd=%0d", name, dut.u_regfile.regs[10]);
          pass_count++;
        end
      end
    endcase
  endtask

  initial begin
    pass_count = 0;
    fail_count = 0;

    run_program("mem_sum5",  "program.hex",       512);
    run_program("mem_sort8", "program_sort8.hex", 16384);
    run_program("mem_gcd",   "program_gcd.hex",   8192);

    if (fail_count == 0)
      $display("core_tb: ALL PASS (%0d programs)", pass_count);
    else
      $display("core_tb: FAIL (%0d failed, %0d passed)", fail_count, pass_count);

    $finish;
  end

endmodule
