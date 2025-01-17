// Copyright (c) 2025 Stacey Campbell
// SPDX-License-Identifier: MIT

`include "numbat.vh"

// Donald Shell's shellsort, algorithm from K&R, 2nd edition, page 62
// all writes are mirrored to block diagram BRAM for AXI4 burst DMA readout to Zynq

module move_sort #
  (
   parameter RAM_WIDTH = 0,
   parameter EVAL_WIDTH = 0,
   parameter MAX_POSITIONS_LOG2 = $clog2(`MAX_POSITIONS)
   )
   (
    input                                 clk,
    input                                 reset,

    input                                 sort_start,
    input                                 sort_clear,
    input                                 white_to_move,

    input                                 ram_wr_addr_init,
    input [RAM_WIDTH - 1:0]               ram_wr_data,
    input                                 ram_wr,
    input [MAX_POSITIONS_LOG2 - 1:0]      ram_rd_addr,

    output [RAM_WIDTH - 1:0]              ram_rd_data,
    output reg [MAX_POSITIONS_LOG2 - 1:0] ram_wr_addr,

    output reg [31:0]                     all_moves_bram_addr,
    output reg [511:0]                    all_moves_bram_din,
    output reg [63:0]                     all_moves_bram_we,

    output reg                            sort_complete
    );

   reg                                    external_io = 0;
   reg                                    sort_start_z = 0;

   reg [MAX_POSITIONS_LOG2 - 1:0]         port_a_addr;
   reg                                    port_a_wr_en = 0;
   reg [RAM_WIDTH - 1:0]                  port_a_wr_data;

   reg [MAX_POSITIONS_LOG2 - 1:0]         port_b_addr;
   reg                                    port_b_wr_en = 0;
   reg [RAM_WIDTH - 1:0]                  port_b_wr_data;

   reg [31:0]                             all_moves_bram_addr_next;
   reg [511:0]                            all_moves_bram_din_next;

   // should be empty
   /*AUTOREGINPUT*/

   /*AUTOWIRE*/
   // Beginning of automatic wires (for undeclared instantiated-module outputs)
   wire [RAM_WIDTH-1:0] port_a_rd_data;         // From mram of mram.v
   wire [RAM_WIDTH-1:0] port_b_rd_data;         // From mram of mram.v
   // End of automatics

   wire [MAX_POSITIONS_LOG2 - 1:0]        active_port_a_addr = external_io ? ram_wr_addr : port_a_addr; // external write to "a" port
   wire [MAX_POSITIONS_LOG2 - 1:0]        active_port_b_addr = external_io ? ram_rd_addr : port_b_addr; // external read from "b" port

   wire [RAM_WIDTH - 1:0]                 active_port_a_wr_data = external_io ? ram_wr_data : port_a_wr_data;

   wire                                   active_port_a_wr_en = external_io ? ram_wr : port_a_wr_en;
   wire                                   active_port_b_wr_en = external_io ? 1'b0 : port_b_wr_en;

   wire signed [EVAL_WIDTH - 1:0]         eval_a = $signed(port_a_rd_data[EVAL_WIDTH - 1:0]);
   wire signed [EVAL_WIDTH - 1:0]         eval_b = $signed(port_b_rd_data[EVAL_WIDTH - 1:0]);
   wire                                   pv_a = port_a_rd_data[EVAL_WIDTH + 3];
   wire                                   pv_b = port_b_rd_data[EVAL_WIDTH + 3];

   wire [63:0]                            all_bytes_wren_clr = 64'h0000000000000000;
   wire [63:0]                            all_bytes_wren_set = 64'hFFFFFFFFFFFFFFFF;

   assign ram_rd_data = port_b_rd_data;

   always @(posedge clk)
     begin
        sort_start_z <= sort_start;

        if (ram_wr_addr_init)
          ram_wr_addr <= 0;
        if (ram_wr)
          ram_wr_addr <= ram_wr_addr + 1;
     end

   localparam STATE_IDLE = 0;
   localparam STATE_LOOP_OUTER_0 = 1;
   localparam STATE_LOOP_OUTER_1 = 2;
   localparam STATE_LOOP_MIDDLE_0 = 3;
   localparam STATE_LOOP_MIDDLE_1 = 4;
   localparam STATE_LOOP_INNER_0 = 5;
   localparam STATE_LOOP_INNER_1 = 6;
   localparam STATE_LOOP_INNER_2 = 7;
   localparam STATE_LOOP_INNER_3 = 8;
   localparam STATE_LOOP_INNER_4 = 9;
   localparam STATE_LOOP_INNER_5 = 10;
   localparam STATE_DONE = 11;

   reg [3:0]                              state = STATE_IDLE;

   reg signed [MAX_POSITIONS_LOG2 + 2 + 1 - 1:0] gap, i, j, n;

   always @(posedge clk)
     if (reset)
       state <= STATE_IDLE;
     else
       case (state)
         STATE_IDLE :
           begin
              port_a_wr_en <= 0;
              port_b_wr_en <= 0;
              external_io <= 1;
              sort_complete <= 0;
              gap <= ram_wr_addr / 2;
              n <= ram_wr_addr;
              if (sort_start && ~sort_start_z)
                if (ram_wr_addr <= 1)
                  state <= STATE_DONE;
                else
                  state <= STATE_LOOP_OUTER_0;
           end

         STATE_LOOP_OUTER_0 :
           begin
              external_io <= 0;
              i <= gap;
              if (gap <= 0)
                state <= STATE_DONE;
              else
                state <= STATE_LOOP_MIDDLE_0;
           end
         STATE_LOOP_OUTER_1 :
           begin
              gap <= gap / 2;
              state <= STATE_LOOP_OUTER_0;
           end

         STATE_LOOP_MIDDLE_0 :
           begin
              j <= i - gap;
              if (i < n)
                state <= STATE_LOOP_INNER_0;
              else
                state <= STATE_LOOP_OUTER_1;
           end
         STATE_LOOP_MIDDLE_1 :
           begin
              i <= i + 1;
              state <= STATE_LOOP_MIDDLE_0;
           end

         STATE_LOOP_INNER_0 :
           if (j < 0)
             state <= STATE_LOOP_MIDDLE_1;
           else
             begin
                port_a_addr <= j;
                port_b_addr <= j + gap;
                state <= STATE_LOOP_INNER_1;
             end
         STATE_LOOP_INNER_1 :
           state <= STATE_LOOP_INNER_2;
         STATE_LOOP_INNER_2 :
           state <= STATE_LOOP_INNER_3;
         STATE_LOOP_INNER_3 :
           // compare
           if (! pv_a && pv_b ? 1'b1 : pv_a && ! pv_b ? 1'b0 : // principal variation 1st
               white_to_move ? eval_a < eval_b : eval_a > eval_b) // evaluation 2nd
             state <= STATE_LOOP_INNER_4;
           else
             state <= STATE_LOOP_MIDDLE_1;
         STATE_LOOP_INNER_4 :
           begin
              // swap
              port_a_wr_en <= 1;
              port_b_wr_en <= 1;
              port_a_wr_data <= port_b_rd_data;
              port_b_wr_data <= port_a_rd_data;
              state <= STATE_LOOP_INNER_5;
           end
         STATE_LOOP_INNER_5 :
           begin
              port_a_wr_en <= 0;
              port_b_wr_en <= 0;
              j <= j - gap;
              state <= STATE_LOOP_INNER_0;
           end

         STATE_DONE :
           begin
              sort_complete <= 1;
              if (sort_clear)
                state <= STATE_IDLE;
           end

         default :
           state <= STATE_IDLE;
       endcase

   localparam AM_PORT_A = 0;
   localparam AM_PORT_B = 1;

   reg [0:0] am_state = AM_PORT_A;

   always @(posedge clk)
     case (am_state)
       AM_PORT_A :
         begin
            all_moves_bram_din <= active_port_a_wr_data;
            all_moves_bram_addr <= active_port_a_addr << 6;

            all_moves_bram_din_next <= port_b_wr_data;
            all_moves_bram_addr_next <= port_b_addr << 6;

            all_moves_bram_we <= all_bytes_wren_clr;
            if (active_port_a_wr_en)
              begin
                 all_moves_bram_we <= all_bytes_wren_set;
                 if (port_b_wr_en)
                   am_state <= AM_PORT_B;
              end
         end
       AM_PORT_B :
         begin
            all_moves_bram_din <= all_moves_bram_din_next;
            all_moves_bram_addr <= all_moves_bram_addr_next;
            all_moves_bram_we <= all_bytes_wren_set;
            am_state <= AM_PORT_A;
         end
     endcase

   /* mram AUTO_TEMPLATE (
    );*/
   mram #
     (
      .RAM_WIDTH (RAM_WIDTH),
      .MAX_POSITIONS_LOG2 (MAX_POSITIONS_LOG2)
      )
   mram
     (/*AUTOINST*/
      // Outputs
      .port_a_rd_data                   (port_a_rd_data[RAM_WIDTH-1:0]),
      .port_b_rd_data                   (port_b_rd_data[RAM_WIDTH-1:0]),
      // Inputs
      .clk                              (clk),
      .active_port_a_wr_en              (active_port_a_wr_en),
      .active_port_a_addr               (active_port_a_addr[MAX_POSITIONS_LOG2-1:0]),
      .active_port_b_wr_en              (active_port_b_wr_en),
      .active_port_b_addr               (active_port_b_addr[MAX_POSITIONS_LOG2-1:0]),
      .active_port_a_wr_data            (active_port_a_wr_data[RAM_WIDTH-1:0]),
      .port_b_wr_data                   (port_b_wr_data[RAM_WIDTH-1:0]));

endmodule

// Local Variables:
// verilog-auto-inst-param-value:t
// verilog-library-directories:(
//     "."
//     )
// End:
