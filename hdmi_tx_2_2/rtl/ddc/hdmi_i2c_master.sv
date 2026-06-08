import hdmi_tx_pkg::*;

module hdmi_i2c_master #(
    parameter int unsigned CLK_DIV = 50
) (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        req,
    input  logic [7:0]  addr_w,
    input  logic [7:0]  addr_r,
    input  logic [7:0]  reg_offset,
    input  logic [7:0]  wdata,
    input  logic        write_en,
    input  logic        read_en,
    output logic [7:0]  rdata,
    output logic        done,
    output logic        busy,
    output logic        scl_o,
    output logic        sda_o,
    output logic        scl_oe,
    output logic        sda_oe,
    input  logic        sda_i
);

  typedef enum logic [3:0] {
    ST_IDLE,
    ST_START,
    ST_WRITE_BIT,
    ST_WRITE_ACK,
    ST_REP_START,
    ST_READ_BIT,
    ST_READ_ACK,
    ST_STOP,
    ST_DONE
  } st_e;

  st_e          state;
  logic [7:0]   shifter;
  logic [3:0]   bit_idx;
  logic [7:0]   phase;
  logic [15:0]  div;
  logic         tick;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      div  <= '0;
      tick <= 1'b0;
    end else if (busy) begin
      if (div == CLK_DIV - 1) begin
        div  <= '0;
        tick <= 1'b1;
      end else begin
        div  <= div + 16'd1;
        tick <= 1'b0;
      end
    end else begin
      div  <= '0;
      tick <= 1'b0;
    end
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state   <= ST_IDLE;
      busy    <= 1'b0;
      done    <= 1'b0;
      rdata   <= '0;
      scl_o   <= 1'b1;
      sda_o   <= 1'b1;
      scl_oe  <= 1'b0;
      sda_oe  <= 1'b0;
      bit_idx <= '0;
      phase   <= '0;
    end else begin
      done <= 1'b0;

      if (state == ST_IDLE) begin
        scl_oe <= 1'b0;
        sda_oe <= 1'b0;
        if (req) begin
          busy    <= 1'b1;
          state   <= ST_START;
          phase   <= 8'd0;
          shifter <= addr_w;
          bit_idx <= 4'd7;
        end
      end else if (tick) begin
        unique case (state)
          ST_START: begin
            scl_oe <= 1'b1;
            sda_oe <= 1'b1;
            sda_o  <= 1'b0;
            scl_o  <= 1'b1;
            state  <= ST_WRITE_BIT;
          end

          ST_WRITE_BIT: begin
            sda_oe <= 1'b1;
            sda_o  <= shifter[7];
            scl_o  <= 1'b0;
            state  <= ST_WRITE_ACK;
          end

          ST_WRITE_ACK: begin
            scl_o <= 1'b1;
            if (bit_idx == 0) begin
              sda_oe <= 1'b0;
              unique case (phase)
                8'd0: begin
                  shifter <= reg_offset;
                  bit_idx <= 4'd7;
                  phase   <= 8'd1;
                  state   <= ST_WRITE_BIT;
                end
                8'd1: begin
                  if (write_en) begin
                    shifter <= wdata;
                    bit_idx <= 4'd7;
                    phase   <= 8'd2;
                    state   <= ST_WRITE_BIT;
                  end else if (read_en) begin
                    state <= ST_REP_START;
                  end else begin
                    state <= ST_STOP;
                  end
                end
                default: state <= ST_STOP;
              endcase
            end else begin
              shifter <= {shifter[6:0], 1'b0};
              bit_idx <= bit_idx - 4'd1;
              state   <= ST_WRITE_BIT;
            end
          end

          ST_REP_START: begin
            sda_oe  <= 1'b1;
            sda_o   <= 1'b0;
            scl_o   <= 1'b1;
            shifter <= addr_r;
            bit_idx <= 4'd7;
            state   <= ST_WRITE_BIT;
            phase   <= 8'd3;
          end

          ST_READ_BIT: begin
            sda_oe <= 1'b0;
            scl_o  <= 1'b0;
            state  <= ST_READ_ACK;
          end

          ST_READ_ACK: begin
            scl_o <= 1'b1;
            if (phase == 8'd3 && bit_idx == 0) begin
              shifter <= reg_offset;
              bit_idx <= 4'd7;
              phase   <= 8'd4;
              sda_oe  <= 1'b1;
              state   <= ST_WRITE_BIT;
            end else if (bit_idx == 0) begin
              rdata  <= shifter;
              sda_oe <= 1'b1;
              sda_o  <= 1'b1;
              state  <= ST_STOP;
            end else begin
              shifter <= {shifter[6:0], sda_i};
              bit_idx <= bit_idx - 4'd1;
              state   <= ST_READ_BIT;
            end
          end

          ST_STOP: begin
            scl_o  <= 1'b1;
            sda_oe <= 1'b1;
            sda_o  <= 1'b0;
            state  <= ST_DONE;
          end

          ST_DONE: begin
            sda_o <= 1'b1;
            done  <= 1'b1;
            busy  <= 1'b0;
            state <= ST_IDLE;
          end

          default: state <= ST_IDLE;
        endcase

        if (state == ST_WRITE_ACK && phase == 8'd3 && bit_idx == 0)
          state <= ST_READ_BIT;
      end
    end
  end

endmodule
