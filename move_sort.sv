// Copyright (c) 2025 Stacey Campbell
// SPDX-License-Identifier: MIT

// Very large O(n) sort

`include "numbat.vh"

module move_sort #
  (
   parameter RAM_WIDTH = 0,
   parameter EVAL_WIDTH = 0,
   parameter MAX_POSITIONS_LOG2 = $clog2(`MAX_POSITIONS)
   )
   (
    input                                 clk,
    input                                 reset,

    input                                 evaluate_go,
    input                                 sort_start,
    input                                 sort_clear,
    input                                 white_to_move,

    input                                 ram_wr_addr_init,
    input [RAM_WIDTH - 1:0]               ram_wr_data,
    input                                 ram_wr,
    input [MAX_POSITIONS_LOG2 - 1:0]      ram_rd_addr,

    output reg [RAM_WIDTH - 1:0]          ram_rd_data,
    output reg [MAX_POSITIONS_LOG2 - 1:0] ram_wr_addr,

    output reg [31:0]                     all_moves_bram_addr = 0,
    output reg [511:0]                    all_moves_bram_din = 0,
    output reg [63:0]                     all_moves_bram_we,

    output reg                            sort_complete = 0
    );

   localparam BAD_EVAL = -(`GLOBAL_VALUE_KING + 500);

   reg [RAM_WIDTH - 1:0]                  move_ram [0:`MAX_POSITIONS - 1];

   reg signed [EVAL_WIDTH - 1:0]          sort_eval_table [0:`MAX_POSITIONS - 1];
   reg [`MAX_POSITIONS - 1:0]             sort_pv_table;
   reg [MAX_POSITIONS_LOG2 - 1:0]         sort_addr_table [0:`MAX_POSITIONS - 1];
   reg [MAX_POSITIONS_LOG2 - 1:0]         table_count = 0;
   reg                                    sorted_0, sorted_1;
   reg [MAX_POSITIONS_LOG2 - 1:0]         index = 0;
   reg                                    next_index = 0;
   reg [31:0]                             all_moves_bram_addr_pre;
   reg [511:0]                            all_moves_bram_din_pre;
   reg [63:0]                             all_moves_bram_we_pre;

   integer                                i;
   
   wire [63:0]                            all_bytes_wren_clr = 64'h0000000000000000;
   wire [63:0]                            all_bytes_wren_set = 64'hFFFFFFFFFFFFFFFF;

   wire signed [EVAL_WIDTH - 1:0]         eval_test = $signed(all_moves_bram_din[EVAL_WIDTH - 1:0]);
   wire signed [EVAL_WIDTH - 1:0]         input_eval = $signed(ram_wr_data[EVAL_WIDTH - 1:0]);
   wire                                   input_pv = ram_wr_data[EVAL_WIDTH + 3];

   always @(posedge clk)
     begin
        all_moves_bram_addr <= all_moves_bram_addr_pre;
        all_moves_bram_din <= all_moves_bram_din_pre;
        all_moves_bram_we <= all_moves_bram_we_pre;
     end

   localparam STATE_IDLE = 0;
   localparam STATE_TABLE_FILL = 1;
   localparam STATE_TABLE_SORT0 = 2;
   localparam STATE_TABLE_SORT1 = 3;
   localparam STATE_REORDER = 4;
   localparam STATE_DONE = 5;

   reg [2:0]                              state = STATE_IDLE;

   always @(posedge clk)
     if (reset)
       begin
          state <= STATE_IDLE;
          all_moves_bram_we_pre <= all_bytes_wren_clr;
       end
     else
       case (state)
         STATE_IDLE :
           begin
              all_moves_bram_addr_pre <= 0;
              index <= 0;
              next_index <= 0;
              all_moves_bram_we_pre <= all_bytes_wren_clr;
              sort_complete <= 0;
              sorted_0 <= 0;
              sorted_1 <= 0;
              for (i = 0; i < `MAX_POSITIONS; i = i + 1)
                begin
                   sort_eval_table[i] <= BAD_EVAL;
                   sort_pv_table[i] <= 1'b0;
                   sort_addr_table[i] <= i;
                end
              if (evaluate_go)
                state <= STATE_TABLE_FILL; // one or more legal moves to sort
           end
         STATE_TABLE_FILL :
           begin
              if (ram_wr)
                begin
                   if (white_to_move)
                     sort_eval_table[ram_wr_addr] <= $signed(ram_wr_data[EVAL_WIDTH - 1:0]);
                   else
                     sort_eval_table[ram_wr_addr] <= -$signed(ram_wr_data[EVAL_WIDTH - 1:0]);
                   sort_pv_table[ram_wr_addr] <= ram_wr_data[EVAL_WIDTH + 3];
                end
              if (sort_start)
                state <= STATE_TABLE_SORT0;
           end
         
         STATE_TABLE_SORT0 :
           begin
              table_count <= ram_wr_addr;
              sorted_0 <= 1;
              for (i = 0; i < `MAX_POSITIONS - 1; i = i + 2)
                if (! sort_pv_table[i] && sort_pv_table[i + 1] ? 1'b1 : sort_pv_table[i] && ! sort_pv_table[i + 1] ? 1'b0 : // principal variation 1st
                    sort_eval_table[i] < sort_eval_table[i + 1]) // evaluation 2nd
                  begin // swap
                     sorted_0 <= 0; // not yet sorted
                     sort_eval_table[i + 1] <= sort_eval_table[i];
                     sort_eval_table[i] <= sort_eval_table[i + 1];
                     sort_pv_table[i + 1] <= sort_pv_table[i];
                     sort_pv_table[i] <= sort_pv_table[i + 1];
                     sort_addr_table[i + 1] <= sort_addr_table[i];
                     sort_addr_table[i] <= sort_addr_table[i + 1];
                  end
              if (sorted_0 && sorted_1)
                state <= STATE_REORDER;
              else
                state <= STATE_TABLE_SORT1;
           end

         STATE_TABLE_SORT1 :
           begin
              sorted_1 <= 1;
              for (i = 1; i < `MAX_POSITIONS - 1; i = i + 2)
                if (! sort_pv_table[i] && sort_pv_table[i + 1] ? 1'b1 : sort_pv_table[i] && ! sort_pv_table[i + 1] ? 1'b0 : // principal variation 1st
                    sort_eval_table[i] < sort_eval_table[i + 1]) // evaluation 2nd
                  begin // swap
                     sorted_1 <= 0; // not yet sorted
                     sort_eval_table[i + 1] <= sort_eval_table[i];
                     sort_eval_table[i] <= sort_eval_table[i + 1];
                     sort_pv_table[i + 1] <= sort_pv_table[i];
                     sort_pv_table[i] <= sort_pv_table[i + 1];
                     sort_addr_table[i + 1] <= sort_addr_table[i];
                     sort_addr_table[i] <= sort_addr_table[i + 1];
                  end
              if (sorted_1 && sorted_0)
                state <= STATE_REORDER;
              else
                state <= STATE_TABLE_SORT0;
           end
         STATE_REORDER :
           begin
              all_moves_bram_din_pre <= move_ram[sort_addr_table[index]];
              index <= index + 1;
              all_moves_bram_we_pre <= all_bytes_wren_set;
              next_index <= 1;
              if (next_index)
                all_moves_bram_addr_pre <= all_moves_bram_addr_pre + (1 << 6); // AXI byte address
              if (index == table_count - 1)
                state <= STATE_DONE;
           end
         STATE_DONE :
           begin
              all_moves_bram_we_pre <= all_bytes_wren_clr;
              sort_complete <= 1;
              if (sort_clear)
                state <= STATE_IDLE;
           end
         default :
           state <= STATE_IDLE;
       endcase

   always @(posedge clk)
     begin
        if (ram_wr_addr_init)
          ram_wr_addr <= 0;
        if (ram_wr)
          ram_wr_addr <= ram_wr_addr + 1;

        if (ram_wr)
          move_ram[ram_wr_addr] <= ram_wr_data;
        ram_rd_data <= move_ram[ram_rd_addr];
     end

endmodule

// Local Variables:
// verilog-auto-inst-param-value:t
// verilog-library-directories:(
//     "."
//     )
// End:
