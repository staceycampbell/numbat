// Copyright (c) 2025 Stacey Campbell
// SPDX-License-Identifier: MIT

`include "numbat.vh"

module evaluate_pv #
  (
   parameter UCI_WIDTH = 0,
   parameter MAX_DEPTH_LOG2 = 0
   )
   (
    input                        clk,
    input                        reset,

    input                        board_valid,
    input [UCI_WIDTH - 1:0]      uci_in,
    input [MAX_DEPTH_LOG2 - 1:0] pv_ply,
    input [31:0]                 pv_ctrl_in,

    output reg                   eval_pv_flag_t1 = 0,
    output reg                   eval_valid_t1
    );

   reg [UCI_WIDTH - 1:0]         pv_table [0:`MAX_DEPTH - 1];
   reg [`MAX_DEPTH - 1:0]        pv_table_valid = 0;

   wire                          pv_ctrl_in_table_write = pv_ctrl_in[31];
   wire                          pv_ctrl_in_table_clear = pv_ctrl_in[30];
   wire [UCI_WIDTH - 1:0]        pv_ctrl_in_table_entry = pv_ctrl_in[UCI_WIDTH - 1:0];
   wire [MAX_DEPTH_LOG2 - 1:0]   pv_ctrl_in_ply = pv_ctrl_in[UCI_WIDTH+:MAX_DEPTH_LOG2];
   wire                          pv_ctrl_in_entry_valid = pv_ctrl_in[UCI_WIDTH + MAX_DEPTH_LOG2];

   wire [UCI_WIDTH - 1:0]        uci_t0 = uci_in;
   wire                          board_valid_t0 = board_valid;

   always @(posedge clk)
     begin
        if (pv_ctrl_in_table_clear)
          pv_table_valid <= 0;
        if (pv_ctrl_in_table_write)
          begin
             pv_table[pv_ctrl_in_ply] <= pv_ctrl_in_table_entry;
             pv_table_valid[pv_ctrl_in_ply] <= pv_ctrl_in_entry_valid;
          end

        if (board_valid_t0)
          if (pv_table_valid[pv_ply] && pv_table[pv_ply] == uci_t0)
            begin
               eval_pv_flag_t1 <= 1;
               pv_table_valid[pv_ply] <= 1'b0; // auto-clear, at most only one pv move per ply
            end
          else
            eval_pv_flag_t1 <= 0;

        eval_valid_t1 <= board_valid_t0;
     end

endmodule
