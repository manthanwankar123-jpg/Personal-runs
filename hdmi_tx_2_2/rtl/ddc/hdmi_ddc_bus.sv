import hdmi_tx_pkg::*;

module hdmi_ddc_bus #(
    parameter bit FAST_EDID = 1'b0,
    parameter bit FAST_SCDC = 1'b0
) (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        edid_start,
    output logic        edid_done,
    output logic [7:0]  edid_data [0:EDID_LEN-1],
    input  logic        scdc_start,
    input  link_mode_e  link_mode,
    input  frl_rate_e   frl_rate,
    input  logic [2:0]  lane_count,
    output logic        scdc_done,
    output logic        flt_ready,
    output logic        scl_o,
    output logic        sda_o,
    output logic        scl_oe,
    output logic        sda_oe,
    input  logic        sda_i
);

  typedef enum logic [4:0] {
    BUS_IDLE, BUS_EDID_FAST, BUS_I2C_START, BUS_I2C_W_BIT, BUS_I2C_W_ACK,
    BUS_I2C_REP, BUS_I2C_R_BIT, BUS_I2C_R_ACK, BUS_I2C_STOP, BUS_I2C_DONE,
    BUS_SCDC_FAST, BUS_SCDC_WAIT, BUS_SCDC_DONE
  } bus_st_e;

  typedef enum logic [2:0] {
    JOB_NONE, JOB_EDID, JOB_SCDC_WR, JOB_SCDC_RD
  } job_e;

  bus_st_e      state;
  job_e         job;
  logic         busy;
  logic [7:0]   shifter;
  logic [3:0]   bit_idx;
  logic [7:0]   byte_idx;
  logic [7:0]   addr_byte;
  logic         reading;
  logic [15:0]  tick_cnt;
  logic         tick;
  logic [3:0]   scdc_step;
  logic [7:0]   scdc_wdata;
  logic [7:0]   scdc_reg;
  logic [15:0]  poll_cnt;
  logic         job_done_pulse;

  localparam int unsigned TICKS = 50;

  function automatic logic [7:0] frl_cfg(input frl_rate_e rate, input logic [2:0] lanes);
    logic [2:0] rc;
    begin
      unique case (rate)
        FRL_RATE_24G: rc = 3'd5;
        FRL_RATE_12G: rc = 3'd4;
        FRL_RATE_10G: rc = 3'd3;
        FRL_RATE_8G:  rc = 3'd2;
        FRL_RATE_6G:  rc = 3'd1;
        default:      rc = 3'd0;
      endcase
      frl_cfg = {1'b0, rc, lanes};
    end
  endfunction

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      tick_cnt <= '0;
      tick     <= 1'b0;
    end else if (busy) begin
      if (tick_cnt == TICKS - 1) begin
        tick_cnt <= '0;
        tick     <= 1'b1;
      end else begin
        tick_cnt <= tick_cnt + 16'd1;
        tick     <= 1'b0;
      end
    end else begin
      tick_cnt <= '0;
      tick     <= 1'b0;
    end
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state     <= BUS_IDLE;
      job       <= JOB_NONE;
      busy      <= 1'b0;
      edid_done <= 1'b0;
      scdc_done <= 1'b0;
      flt_ready <= 1'b0;
      job_done_pulse <= 1'b0;
    end else begin
      edid_done      <= 1'b0;
      scdc_done      <= 1'b0;
      job_done_pulse <= 1'b0;

      unique case (state)
        BUS_IDLE: begin
          scl_oe <= 1'b0;
          sda_oe <= 1'b0;
          flt_ready <= 1'b0;
          if (edid_start) begin
            busy <= 1'b1;
            if (FAST_EDID) begin
              edid_data[0] <= 8'h00; edid_data[1] <= 8'hFF;
              edid_data[2] <= 8'hFF; edid_data[3] <= 8'hFF;
              edid_data[4] <= 8'hFF; edid_data[5] <= 8'hFF;
              edid_data[6] <= 8'hFF; edid_data[7] <= 8'h00;
              for (int i = 8; i < EDID_LEN; i++) edid_data[i] <= 8'h00;
              edid_data[126] <= 8'h01;
              state <= BUS_EDID_FAST;
            end else begin
              job       <= JOB_EDID;
              byte_idx  <= '0;
              addr_byte <= EDID_ADDR_W;
              reading   <= 1'b0;
              state     <= BUS_I2C_START;
            end
          end else if (scdc_start) begin
            busy      <= 1'b1;
            scdc_step <= 4'd0;
            poll_cnt  <= '0;
            if (FAST_SCDC || link_mode == LINK_TMDS)
              state <= (link_mode == LINK_FRL) ? BUS_SCDC_FAST : BUS_SCDC_DONE;
            else begin
              scdc_reg   <= SCDC_SOURCE_VERSION;
              scdc_wdata <= 8'h01;
              job        <= JOB_SCDC_WR;
              addr_byte  <= SCDC_ADDR_W;
              reading    <= 1'b0;
              state      <= BUS_I2C_START;
            end
          end
        end

        BUS_EDID_FAST: begin
          edid_done <= 1'b1;
          busy      <= 1'b0;
          state     <= BUS_IDLE;
        end

        BUS_I2C_START: begin
          scl_oe <= 1'b1;
          sda_oe <= 1'b1;
          sda_o  <= 1'b0;
          scl_o  <= 1'b1;
          shifter<= addr_byte;
          bit_idx<= 4'd7;
          state  <= BUS_I2C_W_BIT;
        end

        BUS_I2C_W_BIT: begin
          sda_oe <= 1'b1;
          sda_o  <= shifter[7];
          scl_o  <= 1'b0;
          state  <= BUS_I2C_W_ACK;
        end

        BUS_I2C_W_ACK: begin
          scl_o <= 1'b1;
          if (bit_idx == 0) begin
            sda_oe <= 1'b0;
            if (job == JOB_EDID) begin
              if (!reading && addr_byte == EDID_ADDR_W) begin
                shifter <= 8'h00; bit_idx <= 4'd7; state <= BUS_I2C_W_BIT;
              end else if (!reading) begin
                addr_byte <= EDID_ADDR_R; shifter <= EDID_ADDR_R;
                bit_idx <= 4'd7; reading <= 1'b1; state <= BUS_I2C_REP;
              end else begin
                bit_idx <= 4'd7; state <= BUS_I2C_R_BIT;
              end
            end else if (job == JOB_SCDC_WR) begin
              if (addr_byte == SCDC_ADDR_W && shifter == SCDC_ADDR_W) begin
                shifter <= scdc_reg; bit_idx <= 4'd7; state <= BUS_I2C_W_BIT;
              end else begin
                shifter <= scdc_wdata; bit_idx <= 4'd7; state <= BUS_I2C_W_BIT;
                job     <= JOB_NONE;
                state   <= BUS_I2C_STOP;
              end
            end else if (job == JOB_SCDC_RD) begin
              bit_idx <= 4'd7; state <= BUS_I2C_R_BIT;
            end
          end else begin
            shifter <= {shifter[6:0], 1'b0};
            bit_idx <= bit_idx - 4'd1;
            state   <= BUS_I2C_W_BIT;
          end
        end

        BUS_I2C_REP: begin
          sda_o <= 1'b0; scl_o <= 1'b1;
          shifter <= addr_byte; bit_idx <= 4'd7;
          state   <= BUS_I2C_W_BIT;
        end

        BUS_I2C_R_BIT: begin
          sda_oe <= 1'b0; scl_o <= 1'b0; state <= BUS_I2C_R_ACK;
        end

        BUS_I2C_R_ACK: begin
          scl_o <= 1'b1;
          if (bit_idx == 0) begin
            if (job == JOB_EDID) begin
              edid_data[byte_idx[6:0]] <= shifter;
              byte_idx <= byte_idx + 8'd1;
              if (byte_idx == EDID_LEN - 1) state <= BUS_I2C_STOP;
              else begin
                sda_oe <= 1'b1; sda_o <= 1'b0;
                bit_idx <= 4'd7; state <= BUS_I2C_R_BIT;
              end
            end else if (job == JOB_SCDC_RD) begin
              if (shifter[0]) flt_ready <= 1'b1;
              job   <= JOB_NONE;
              state <= BUS_I2C_STOP;
            end
          end else begin
            shifter <= {shifter[6:0], sda_i};
            bit_idx <= bit_idx - 4'd1;
            state   <= BUS_I2C_R_BIT;
          end
        end

        BUS_I2C_STOP: begin
          scl_o <= 1'b1; sda_oe <= 1'b1; sda_o <= 1'b0;
          state <= BUS_I2C_DONE;
        end

        BUS_I2C_DONE: begin
          sda_o <= 1'b1;
          if (job == JOB_EDID) begin
            edid_done <= 1'b1; busy <= 1'b0; state <= BUS_IDLE;
          end else begin
            unique case (scdc_step)
              4'd0: begin
                scdc_step  <= 4'd1;
                scdc_reg   <= SCDC_SOURCE_FRL_CONFIG;
                scdc_wdata <= frl_cfg(frl_rate, lane_count);
                job        <= JOB_SCDC_WR;
                addr_byte  <= SCDC_ADDR_W;
                state      <= BUS_I2C_START;
              end
              4'd1: begin
                scdc_step  <= 4'd2;
                scdc_reg   <= SCDC_SOURCE_FRL_READY;
                scdc_wdata <= 8'h01;
                job        <= JOB_SCDC_WR;
                addr_byte  <= SCDC_ADDR_W;
                state      <= BUS_I2C_START;
              end
              default: begin
                poll_cnt <= '0;
                state    <= BUS_SCDC_WAIT;
              end
            endcase
          end
        end

        BUS_SCDC_FAST: begin
          poll_cnt <= 16'd8; state <= BUS_SCDC_WAIT;
        end

        BUS_SCDC_WAIT: begin
          if (poll_cnt >= 16'd16) begin
            flt_ready <= 1'b1;
            state     <= BUS_SCDC_DONE;
          end else begin
            poll_cnt <= poll_cnt + 16'd1;
            if (!FAST_SCDC) begin
              scdc_reg <= SCDC_SINK_FRL_STATUS;
              job <= JOB_SCDC_RD; addr_byte <= SCDC_ADDR_W;
              reading <= 1'b0; state <= BUS_I2C_START;
            end
          end
        end

        BUS_SCDC_DONE: begin
          scdc_done <= 1'b1; busy <= 1'b0; state <= BUS_IDLE;
        end

        default: state <= BUS_IDLE;
      endcase
    end
  end

endmodule
