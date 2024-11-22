`include "vchess.vh"

module evaluate_killer #
  (
   parameter EVAL_WIDTH = 0,
   parameter MAX_DEPTH_LOG2 = 0
   )
   (
    input                                clk,
    input                                reset,

    input                                board_valid,
    input [`BOARD_WIDTH - 1:0]           board,
    input                                clear_eval,
    input                                white_to_move,

    input [MAX_DEPTH_LOG2 - 1:0]         killer_ply,
    input [`BOARD_WIDTH - 1:0]           killer_board,
    input                                killer_update,
    input                                killer_clear,
    input signed [EVAL_WIDTH - 1:0]      killer_bonus0,
    input signed [EVAL_WIDTH - 1:0]      killer_bonus1,

    output reg signed [EVAL_WIDTH - 1:0] eval_mg,
    output reg signed [EVAL_WIDTH - 1:0] eval_eg,
    output reg                           eval_valid
    );

   localparam LATENCY_COUNT = 3;

   reg [$clog2(LATENCY_COUNT) + 1 - 1:0] latency;
   reg                                   killer_clear_r;
   reg                                   killer_update_r;
   reg                                   board_valid_r;
   (* ram_style = "distributed" *) reg [`BOARD_WIDTH * 2 - 1:0] killer_table [0:`MAX_DEPTH - 1]; // two killer moves per ply
   reg [`MAX_DEPTH * 2 - 1:0]            killer_valid = 0;

   reg [EVAL_WIDTH - 1:0]                bonus0, bonus1;

   always @(posedge clk)
     begin
        killer_clear_r <= killer_clear;
        killer_update_r <= killer_update;
        board_valid_r <= board_valid;

        if (white_to_move)
          begin
             bonus0 <= -killer_bonus0;
             bonus1 <= -killer_bonus1;
          end
        else
          begin
             bonus0 <= killer_bonus0;
             bonus1 <= killer_bonus1;
          end

        if (killer_clear && ~killer_clear_r)
          killer_valid <= 0;

        if (killer_update && ~killer_update_r)
          begin
             killer_table[killer_ply][`BOARD_WIDTH - 1:0] <= killer_board;
             killer_table[killer_ply][`BOARD_WIDTH * 2 - 1:`BOARD_WIDTH] <= killer_table[killer_ply][`BOARD_WIDTH - 1:0];
             killer_valid[killer_ply * 2] <= 1;
             killer_valid[killer_ply * 2 + 1] <= killer_valid[killer_ply * 2];
          end

        if (board_valid && ~board_valid_r)
          if (killer_valid[killer_ply * 2] && board == killer_table[killer_ply][`BOARD_WIDTH - 1:0])
            begin
               eval_mg <= bonus0;
               eval_eg <= bonus0;
            end
          else if (killer_valid[killer_ply * 2 + 1] && board == killer_table[killer_ply][`BOARD_WIDTH * 2 - 1:`BOARD_WIDTH])
            begin
               eval_mg <= bonus1;
               eval_eg <= bonus1;
            end
          else
            begin
               eval_mg <= 0;
               eval_eg <= 0;
            end
     end

   localparam STATE_IDLE = 0;
   localparam STATE_LATENCY = 1;
   localparam STATE_WAIT_CLEAR = 2;

   reg [1:0]                                 state = STATE_IDLE;

   always @(posedge clk)
     if (reset)
       begin
          state <= STATE_IDLE;
          eval_valid <= 0;
       end
     else
       case (state)
         STATE_IDLE :
           begin
              latency <= 1;
              eval_valid <= 0;
              if (board_valid && ~board_valid_r)
                state <= STATE_LATENCY;
           end
         STATE_LATENCY :
           begin
              latency <= latency + 1;
              if (latency == LATENCY_COUNT - 1)
                begin
                   eval_valid <= 1;
                   state <= STATE_WAIT_CLEAR;
                end
           end
         STATE_WAIT_CLEAR :
           if (clear_eval)
             state <= STATE_IDLE;
         default :
           state <= STATE_IDLE;
       endcase

endmodule
