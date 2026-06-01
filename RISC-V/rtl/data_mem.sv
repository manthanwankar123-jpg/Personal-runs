// data_mem.sv — 64 KiB data RAM @ 0x8000_0000 (byte-addressed)

module data_mem (
    input  logic                       clk,
    input  logic                       we,
    input  logic                       re,
    input  riscv_pkg::mem_size_t       size,
    input  logic                       unsigned_ld,
    input  logic [riscv_pkg::XLEN-1:0] addr,
    input  logic [riscv_pkg::XLEN-1:0] wdata,
    output logic [riscv_pkg::XLEN-1:0] rdata
);

  import riscv_pkg::*;

  logic [15:0] local_addr;
  logic        sel;
  logic [31:0] read_raw;

  assign sel = (addr[31:16] == DATA_MEM_BASE_HI);
  assign local_addr = addr[15:0];

`ifdef FPGA_TIMING_SYNTH
  // 16 KiB as 4K x 32 BRAM (async comb read + sync write) for Vivado Fmax characterization
  localparam int unsigned WORDS = 4096;
  (* ram_style = "block" *) logic [31:0] mem32 [0:WORDS-1];
  logic [11:0] word_ix;

  assign word_ix = local_addr[13:2];

  always_comb begin
    read_raw = '0;
    if (sel && re) begin
      unique case (size)
        MEM_BYTE: begin
          unique case (local_addr[1:0])
            2'd0: read_raw[7:0] = mem32[word_ix][7:0];
            2'd1: read_raw[7:0] = mem32[word_ix][15:8];
            2'd2: read_raw[7:0] = mem32[word_ix][23:16];
            default: read_raw[7:0] = mem32[word_ix][31:24];
          endcase
          if (!unsigned_ld)
            read_raw[31:8] = {24{read_raw[7]}};
        end
        MEM_HALF: begin
          read_raw[15:0] = local_addr[1] ? mem32[word_ix][31:16] : mem32[word_ix][15:0];
          if (!unsigned_ld)
            read_raw[31:16] = {16{read_raw[15]}};
        end
        default: read_raw = mem32[word_ix];
      endcase
    end
  end

  always_ff @(posedge clk) begin
    if (sel && we) begin
      unique case (size)
        MEM_BYTE: begin
          unique case (local_addr[1:0])
            2'd0: mem32[word_ix][7:0]   <= wdata[7:0];
            2'd1: mem32[word_ix][15:8]  <= wdata[7:0];
            2'd2: mem32[word_ix][23:16] <= wdata[7:0];
            default: mem32[word_ix][31:24] <= wdata[7:0];
          endcase
        end
        MEM_HALF: begin
          if (local_addr[1])
            mem32[word_ix][31:16] <= wdata[15:0];
          else
            mem32[word_ix][15:0] <= wdata[15:0];
        end
        default: mem32[word_ix] <= wdata;
      endcase
    end
  end

`else
  logic [7:0] mem [0:DMEM_ADDR_MASK];

  initial begin
    for (int i = 0; i <= DMEM_ADDR_MASK; i++)
      mem[i] = 8'h00;
  end

  // Combinational read (single-cycle)
  always_comb begin
    read_raw = '0;
    if (sel && re) begin
      unique case (size)
        MEM_BYTE: begin
          read_raw[7:0] = mem[local_addr];
          if (!unsigned_ld)
            read_raw[31:8] = {24{read_raw[7]}};
        end
        MEM_HALF: begin
          read_raw[15:0] = {mem[local_addr + 16'd1], mem[local_addr]};
          if (!unsigned_ld)
            read_raw[31:16] = {16{read_raw[15]}};
        end
        default: begin // MEM_WORD
          read_raw = {
            mem[local_addr + 16'd3],
            mem[local_addr + 16'd2],
            mem[local_addr + 16'd1],
            mem[local_addr]
          };
        end
      endcase
    end
  end

  // Write on clock edge
  always_ff @(posedge clk) begin
    if (sel && we) begin
      unique case (size)
        MEM_BYTE: mem[local_addr] <= wdata[7:0];
        MEM_HALF: begin
          mem[local_addr]     <= wdata[7:0];
          mem[local_addr + 1] <= wdata[15:8];
        end
        default: begin
          mem[local_addr]     <= wdata[7:0];
          mem[local_addr + 1] <= wdata[15:8];
          mem[local_addr + 2] <= wdata[23:16];
          mem[local_addr + 3] <= wdata[31:24];
        end
      endcase
    end
  end
`endif

  assign rdata = read_raw;

endmodule
