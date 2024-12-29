// Copyright (c) 2025 Stacey Campbell
// SPDX-License-Identifier: MIT

`include "vchess.vh"

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
    input                        clear_eval,
    input [31:0]                 pv_ctrl_in,

    output reg                   eval_pv_flag = 0,
    output                       eval_valid
    );

   localparam LATENCY_COUNT = 2;

   reg [UCI_WIDTH - 1:0]         pv_table [0:`MAX_DEPTH - 1];
   reg [`MAX_DEPTH - 1:0]        pv_table_valid = 0;

   reg                           board_valid_r;
   reg                           clear_eval_r;

   // should be empty
   /*AUTOREGINPUT*/

   /*AUTOWIRE*/

   wire                          pv_ctrl_in_table_write = pv_ctrl_in[31];
   wire                          pv_ctrl_in_table_clear = pv_ctrl_in[30];
   wire [UCI_WIDTH - 1:0]        pv_ctrl_in_table_entry = pv_ctrl_in[UCI_WIDTH - 1:0];
   wire [MAX_DEPTH_LOG2 - 1:0]   pv_ctrl_in_ply = pv_ctrl_in[UCI_WIDTH+:MAX_DEPTH_LOG2];
   wire                          pv_ctrl_in_entry_valid = pv_ctrl_in[UCI_WIDTH + MAX_DEPTH_LOG2];

   always @(posedge clk)
     begin
        board_valid_r <= board_valid;
        clear_eval_r <= clear_eval;

        if (pv_ctrl_in_table_clear)
          pv_table_valid <= 0;
        if (pv_ctrl_in_table_write)
          begin
             pv_table[pv_ctrl_in_ply] <= pv_ctrl_in_table_entry;
             pv_table_valid[pv_ctrl_in_ply] <= pv_ctrl_in_entry_valid;
          end

        // auto-clear, at most only one pv move per ply
        if (clear_eval && ~clear_eval_r && eval_pv_flag)
          pv_table_valid[pv_ply] <= 1'b0;

        if (board_valid && ~board_valid_r)
          if (pv_table_valid[pv_ply] && pv_table[pv_ply] == uci_in)
            eval_pv_flag <= 1;
          else
            eval_pv_flag <= 0;
     end

   /* latency_sm AUTO_TEMPLATE (
    );*/
   latency_sm #
     (
      .LATENCY_COUNT (LATENCY_COUNT)
      )
   latency_sm
     (/*AUTOINST*/
      // Outputs
      .eval_valid                       (eval_valid),
      // Inputs
      .clk                              (clk),
      .reset                            (reset),
      .board_valid                      (board_valid),
      .clear_eval                       (clear_eval));

endmodule
