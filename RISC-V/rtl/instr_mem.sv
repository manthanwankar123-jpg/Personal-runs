// instr_mem.sv — 64 KiB instruction memory @ 0x0000_0000 (byte-addressed)

module instr_mem (
    input  logic [riscv_pkg::XLEN-1:0] addr,
    output logic [riscv_pkg::XLEN-1:0] rdata
);

  import riscv_pkg::*;

`ifdef FPGA_TIMING_SYNTH
  // Smaller depth + BRAM hint so Vivado can infer (timing characterization only)
  localparam int unsigned MEM_LAST = 16'h3FFF;  // 16 KiB
  (* ram_style = "block" *) logic [7:0] mem [0:MEM_LAST];
`else
  logic [7:0] mem [0:IMEM_ADDR_MASK];
`endif

  initial begin
`ifdef FPGA_TIMING_SYNTH
    for (int i = 0; i <= MEM_LAST; i++)
      mem[i] = 8'h00;
    // Load mem_sum5 image so synthesis cannot constant-fold the fetch path
    $readmemh("program.hex", mem);
`else
    for (int i = 0; i <= IMEM_ADDR_MASK; i++)
      mem[i] = 8'h00;
`endif
  end

  assign rdata = {
    mem[addr[15:0] + 16'd3],
    mem[addr[15:0] + 16'd2],
    mem[addr[15:0] + 16'd1],
    mem[addr[15:0]]
  };

  // Optional program image: sim/core_tb can call $readmemh("program.hex", mem);

endmodule
