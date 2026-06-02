// instr_rom.sv — boot ROM @ address 0

module instr_rom (
    input  logic                       clk,
    input  logic                       rst,
    input  logic [riscv_pkg::XLEN-1:0] addr,
    output logic [riscv_pkg::XLEN-1:0] rdata
);

  import riscv_pkg::*;

  localparam logic [31:0] TRAP_HANDLER = 32'h0000_006f;

`ifdef FPGA_TIMING_SYNTH
  localparam int unsigned WORDS = 4096;
  (* ram_style = "distributed" *) logic [31:0] mem [0:WORDS-1];
  logic [11:0] word_ix;

  initial begin
    int i, b;
    logic [7:0] bytes [0:16383];
    for (i = 0; i < WORDS; i++)
      mem[i] = 32'h0000_0013;
    for (b = 0; b <= 16383; b++)
      bytes[b] = 8'h00;
    $readmemh("program.hex", bytes);
    for (i = 0; i < WORDS; i++)
      mem[i] = {bytes[4 * i + 3], bytes[4 * i + 2], bytes[4 * i + 1], bytes[4 * i]};
    mem[32'h40] = TRAP_HANDLER;
  end

  assign word_ix = addr[13:2];

  always_ff @(posedge clk) begin
    if (rst)
      rdata <= 32'h0000_0013;
    else
      rdata <= mem[word_ix];
  end
`else
  logic [7:0] bytes [0:ROM_ADDR_MASK];
  logic [15:0] off;

  initial begin
    int i;
    for (i = 0; i <= ROM_ADDR_MASK; i++)
      bytes[i] = 8'h00;
    bytes[16'h100] = TRAP_HANDLER[7:0];
    bytes[16'h101] = TRAP_HANDLER[15:8];
    bytes[16'h102] = TRAP_HANDLER[23:16];
    bytes[16'h103] = TRAP_HANDLER[31:24];
  end

  assign off   = addr[15:0];
  assign rdata = {bytes[off + 16'd3], bytes[off + 16'd2],
                  bytes[off + 16'd1], bytes[off]};
`endif

endmodule
