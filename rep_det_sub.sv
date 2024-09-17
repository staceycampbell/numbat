`include "vchess.vh"

module rep_det_sub #
  (
   parameter REPDET_WIDTH = 7,
   parameter RAM_WIDTH = `BOARD_WIDTH + 4
   )
   (
    input                           clk,
    input                           reset,

    input [`BOARD_WIDTH - 1:0]      board_in,
    input [3:0]                     castle_mask_in,
    input                           board_valid,
    input [REPDET_WIDTH - 1:0]      repdet_depth_in,

    input                           clear_repdet,

    input [RAM_WIDTH - 1:0]         repdet_read,
    output reg [REPDET_WIDTH - 1:0] repdet_rd_addr,

    output reg                      board_three_move_rep,
    output reg                      board_three_move_rep_valid
    );

   reg [RAM_WIDTH - 1:0]            board_castle;
   reg [REPDET_WIDTH - 1:0]         counter;
   reg [REPDET_WIDTH - 1:0]         repdet_depth_te;

   localparam STATE_IDLE = 0;
   localparam STATE_COUNT = 1;
   localparam STATE_WS = 2;
   localparam STATE_NO_REP_DET = 3;
   localparam STATE_REP_DET = 4;

   reg [2:0]                        state = STATE_IDLE;

   always @(posedge clk)
     if (reset)
       state <= STATE_IDLE;
     else
       case (state)
         STATE_IDLE :
           begin
              repdet_rd_addr <= 0;
              board_castle <= {castle_mask_in, board_in};
              counter <= 0;
              repdet_depth_te <= repdet_depth_in - 1;
              board_three_move_rep_valid <= 0;
              if (board_valid)
                if (repdet_depth_in < 3)
                  state <= STATE_NO_REP_DET;
                else
                  state <= STATE_COUNT;
           end
         STATE_COUNT :
           if (board_castle == repdet_read)
             begin
                counter <= counter + 1;
                if (counter == 2)
                  state <= STATE_REP_DET;
             end
           else
             begin
                repdet_rd_addr <= repdet_rd_addr + 1;
                if (repdet_rd_addr == repdet_depth_te)
                  state <= STATE_NO_REP_DET;
                else
                  state <= STATE_WS;
             end
         STATE_WS : // wait state for ram read
           state <= STATE_COUNT;
         STATE_NO_REP_DET :
           begin
              board_three_move_rep <= 0;
              board_three_move_rep_valid <= 1;
              if (clear_repdet)
                state <= STATE_IDLE;
           end
         STATE_REP_DET :
           begin
              board_three_move_rep <= 0;
              board_three_move_rep_valid <= 1;
              if (clear_repdet)
                state <= STATE_IDLE;
           end
         default :
           state <= STATE_IDLE;
       endcase

endmodule

// Local Variables:
// verilog-auto-inst-param-value:t
// verilog-library-directories:(
//     "."
//     )
// End:
