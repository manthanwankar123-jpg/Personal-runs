// csr_file.sv — M-mode CSRs and trap entry (v2 phase 2a)

module csr_file (
    input  logic                       clk,
    input  logic                       rst,
    input  logic                       trap,
    input  logic [riscv_pkg::XLEN-1:0] trap_pc,
    input  logic [riscv_pkg::XLEN-1:0] trap_cause,
    input  logic [riscv_pkg::XLEN-1:0] trap_val,
    input  logic [11:0]                csr_raddr,
    output logic [riscv_pkg::XLEN-1:0] csr_rdata,
    input  logic                       csr_we,
    input  riscv_pkg::csr_op_t         csr_op,
    input  logic [riscv_pkg::XLEN-1:0] csr_wdata,
    output logic [riscv_pkg::XLEN-1:0] mtvec,
    output logic [riscv_pkg::XLEN-1:0] mepc,
    output logic [riscv_pkg::XLEN-1:0] mcause
);

  import riscv_pkg::*;

  logic [XLEN-1:0] mstatus_q;
  logic [XLEN-1:0] misa_q;
  logic [XLEN-1:0] mtvec_q;
  logic [XLEN-1:0] mepc_q;
  logic [XLEN-1:0] mcause_q;
  logic [XLEN-1:0] mtval_q;
  logic [XLEN-1:0] mie_q;
  logic [XLEN-1:0] mip_q;

  assign mtvec  = mtvec_q;
  assign mepc   = mepc_q;
  assign mcause = mcause_q;

  function automatic logic [XLEN-1:0] read_csr(input logic [11:0] addr);
    unique case (addr)
      CSR_MSTATUS:  read_csr = mstatus_q;
      CSR_MISA:     read_csr = misa_q;
      CSR_MIE:      read_csr = mie_q;
      CSR_MTVEC:    read_csr = mtvec_q;
      CSR_MEPC:     read_csr = mepc_q;
      CSR_MCAUSE:   read_csr = mcause_q;
      CSR_MTVAL:    read_csr = mtval_q;
      CSR_MIP:      read_csr = mip_q;
      default:      read_csr = '0;
    endcase
  endfunction

  assign csr_rdata = read_csr(csr_raddr);

  function automatic logic [XLEN-1:0] apply_csr_op(
      input csr_op_t op,
      input logic [XLEN-1:0] oldv,
      input logic [XLEN-1:0] wdata
  );
    unique case (op)
      CSR_OP_RW, CSR_OP_IMM: apply_csr_op = wdata;
      CSR_OP_RS: apply_csr_op = oldv | wdata;
      CSR_OP_RC: apply_csr_op = oldv & ~wdata;
      default:   apply_csr_op = oldv;
    endcase
  endfunction

  always_ff @(posedge clk) begin
    if (rst) begin
      mstatus_q <= '0;
      misa_q    <= MISA_RESET;
      mtvec_q   <= MTVEC_RESET;
      mepc_q    <= '0;
      mcause_q  <= '0;
      mtval_q   <= '0;
      mie_q     <= '0;
      mip_q     <= '0;
    end else begin
      if (trap) begin
        mepc_q   <= trap_pc;
        mcause_q <= trap_cause;
        mtval_q  <= trap_val;
      end else if (csr_we) begin
        unique case (csr_raddr)
          CSR_MSTATUS: mstatus_q <= apply_csr_op(csr_op, mstatus_q, csr_wdata);
          CSR_MTVEC:   mtvec_q   <= apply_csr_op(csr_op, mtvec_q, csr_wdata);
          CSR_MIE:     mie_q     <= apply_csr_op(csr_op, mie_q, csr_wdata);
          CSR_MEPC:    mepc_q    <= apply_csr_op(csr_op, mepc_q, csr_wdata);
          CSR_MCAUSE:  mcause_q  <= apply_csr_op(csr_op, mcause_q, csr_wdata);
          CSR_MTVAL:   mtval_q   <= apply_csr_op(csr_op, mtval_q, csr_wdata);
          default: ;
        endcase
      end
    end
  end

endmodule
