// unified_mem.sv — instruction ROM @ 0x0 + data RAM @ 0x8000_0000

module unified_mem (
    input  logic                       clk,
    input  logic                       rst,
    input  logic [riscv_pkg::XLEN-1:0] if_addr,
    output logic [riscv_pkg::XLEN-1:0] if_rdata,
    input  logic [riscv_pkg::XLEN-1:0] mem_addr,
    input  logic                       mem_we,
    input  logic                       mem_re,
    input  riscv_pkg::mem_size_t       mem_size,
    input  logic                       mem_unsigned,
    input  logic [riscv_pkg::XLEN-1:0] mem_wdata,
    output logic [riscv_pkg::XLEN-1:0] mem_rdata,
    output logic                       mem_load_ready
);

  import riscv_pkg::*;

  instr_rom u_instr_rom (
      .clk  (clk),
      .rst  (rst),
      .addr (if_addr),
      .rdata(if_rdata)
  );

  logic        ram_sel;
  logic [15:0] ram_off;
  logic [11:0] ram_ix;

  assign ram_sel = (mem_addr[31:16] == RAM_BASE_HI);
  assign ram_off = mem_addr[15:0];
  assign ram_ix  = ram_off[13:2];

  function automatic logic [31:0] load_extract(
      input logic [31:0] word,
      input logic [15:0] off,
      input mem_size_t   size,
      input logic        unsigned_ld
  );
    logic [31:0] r;
    r = '0;
    unique case (size)
      MEM_BYTE: begin
        unique case (off[1:0])
          2'd0: r[7:0] = word[7:0];
          2'd1: r[7:0] = word[15:8];
          2'd2: r[7:0] = word[23:16];
          default: r[7:0] = word[31:24];
        endcase
        if (!unsigned_ld)
          r[31:8] = {24{r[7]}};
      end
      MEM_HALF: begin
        r[15:0] = off[1] ? word[31:16] : word[15:0];
        if (!unsigned_ld)
          r[31:16] = {16{r[15]}};
      end
      default: r = word;
    endcase
    load_extract = r;
  endfunction

`ifdef FPGA_TIMING_SYNTH
  localparam int unsigned FPGA_RAM_WORDS = 4096;
  (* ram_style = "distributed" *) logic [31:0] ram32 [0:FPGA_RAM_WORDS-1];

  initial begin
    int i;
    for (i = 0; i < FPGA_RAM_WORDS; i++)
      ram32[i] = 32'h0;
  end

  always_ff @(posedge clk) begin
    if (ram_sel && mem_we) begin
      unique case (mem_size)
        MEM_BYTE: begin
          unique case (ram_off[1:0])
            2'd0: ram32[ram_ix][7:0]     <= mem_wdata[7:0];
            2'd1: ram32[ram_ix][15:8]    <= mem_wdata[7:0];
            2'd2: ram32[ram_ix][23:16]   <= mem_wdata[7:0];
            default: ram32[ram_ix][31:24] <= mem_wdata[7:0];
          endcase
        end
        MEM_HALF: begin
          if (ram_off[1])
            ram32[ram_ix][31:16] <= mem_wdata[15:0];
          else
            ram32[ram_ix][15:0] <= mem_wdata[15:0];
        end
        default: ram32[ram_ix] <= mem_wdata;
      endcase
    end
  end

  logic        rd_valid;
  logic [15:0] rd_off;
  logic [11:0] rd_ix;
  mem_size_t   rd_size;
  logic        rd_unsigned;
  logic [31:0] rd_word;

  assign rd_word        = ram32[rd_ix];
  assign mem_load_ready = rd_valid;
  assign mem_rdata      = rd_valid ? load_extract(rd_word, rd_off, rd_size, rd_unsigned) : '0;

  always_ff @(posedge clk) begin
    if (rst)
      rd_valid <= 1'b0;
    else begin
      rd_valid <= ram_sel && mem_re;
      if (ram_sel && mem_re) begin
        rd_off      <= ram_off;
        rd_ix       <= ram_ix;
        rd_size     <= mem_size;
        rd_unsigned <= mem_unsigned;
      end
    end
  end
`else
  // Simulation: byte RAM, combinational load (core completes load in one MEM cycle)
  logic [7:0] ram [0:RAM_ADDR_MASK];

  initial begin
    int i;
    for (i = 0; i <= RAM_ADDR_MASK; i++)
      ram[i] = 8'h00;
  end

  always_ff @(posedge clk) begin
    if (ram_sel && mem_we) begin
      unique case (mem_size)
        MEM_BYTE: ram[ram_off] <= mem_wdata[7:0];
        MEM_HALF: begin
          ram[ram_off]     <= mem_wdata[7:0];
          ram[ram_off + 1] <= mem_wdata[15:8];
        end
        default: begin
          ram[ram_off]     <= mem_wdata[7:0];
          ram[ram_off + 1] <= mem_wdata[15:8];
          ram[ram_off + 2] <= mem_wdata[23:16];
          ram[ram_off + 3] <= mem_wdata[31:24];
        end
      endcase
    end
  end

  logic [31:0] sim_word;
  assign sim_word = {ram[ram_off + 16'd3], ram[ram_off + 16'd2],
                     ram[ram_off + 16'd1], ram[ram_off]};

  assign mem_rdata      = (ram_sel && mem_re) ?
      load_extract(sim_word, ram_off, mem_size, mem_unsigned) : '0;
  assign mem_load_ready = 1'b0;
`endif

endmodule
