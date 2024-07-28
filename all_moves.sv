`include "vchess.vh"

module all_moves #
  (
   parameter PIECE_WIDTH = `PIECE_BITS,
   parameter SIDE_WIDTH = PIECE_WIDTH * 8,
   parameter BOARD_WIDTH = SIDE_WIDTH * 8,
   parameter MAX_POSITIONS = `MAX_POSITIONS,
   parameter MAX_POSITIONS_LOG2 = $clog2(MAX_POSITIONS)
   )
   (
    input                             clk,
    input                             reset,
    input                             board_valid,
    input [BOARD_WIDTH - 1:0]         board,
    input                             white_to_move,
    input [3:0]                       castle_mask,
    input [3:0]                       en_passant_col,

    input [MAX_POSITIONS_LOG2 - 1:0]  move_index,
    input                             clear_moves,

    output reg                        moves_ready,
    output [MAX_POSITIONS_LOG2 - 1:0] move_count,
    output [BOARD_WIDTH - 1:0]        board_out,
    output                            white_to_move_out,
    output [3:0]                      castle_mask_out,
    output [3:0]                      en_passant_col_out
    );

   localparam RAM_WIDTH = BOARD_WIDTH + 4 + 4 + 1;

   reg [RAM_WIDTH - 1:0]              move_ram [0:MAX_POSITIONS - 1];
   reg [RAM_WIDTH - 1:0]              ram_rd_data;
   reg [MAX_POSITIONS_LOG2 - 1:0]     ram_wr_addr;
   reg [2:0]                          row, col;
   reg [$clog2(BOARD_WIDTH) - 1:0]    idx [0:7][0:7];

   // should be empty
   /*AUTOREGINPUT*/

   /*AUTOWIRE*/
   // Beginning of automatic wires (for undeclared instantiated-module outputs)
   wire [63:0]                        black_is_attacking;     // From board_attack of board_attack.v
   wire                               display_attacking_done; // From board_attack of board_attack.v
   wire                               is_attacking_done;      // From board_attack of board_attack.v
   wire [63:0]                        white_is_attacking;     // From board_attack of board_attack.v
   // End of automatics

   integer                            i, x, y, ri;

   wire                               black_to_move = ~white_to_move;

   assign move_count = ram_wr_addr;
   assign {en_passant_col_out, castle_mask_out, white_to_move_out, board_out} = ram_rd_data;

   initial
     begin
        for (y = 0; y < 8; y = y + 1)
          begin
             ri = y * SIDE_WIDTH;
             for (x = 0; x < 8; x = x + 1)
               idx[y][x] = ri + x * PIECE_WIDTH;
          end
     end

   always @(posedge clk)
     ram_rd_data <= move_ram[move_index];

   localparam STATE_IDLE = 0;
   localparam STATE_GET_ATTACKS = 1;
   localparam STATE_INIT = 2;
   localparam STATE_DO_SQUARE = 3;
   localparam STATE_NEXT = 4;
   localparam STATE_DONE = 5;
   localparam STATE_ROOK_INIT = 6;

   reg [5:0]                          state = STATE_IDLE;

   always @(posedge clk)
     if (reset)
       state <= STATE_IDLE;
     else
       case (state)
         STATE_IDLE :
           begin
              moves_ready <= 0;
              ram_wr_addr <= 0;
              if (board_valid)
                state <= STATE_GET_ATTACKS;
           end
         STATE_GET_ATTACKS :
           if (is_attacking_done)
             state <= STATE_INIT;
         STATE_INIT :
           begin
              row <= 0;
              col <= 0;
              state <= STATE_DO_SQUARE;
           end
         STATE_DO_SQUARE :
           begin
              if (board[idx[row][col]+:PIECE_WIDTH] == `EMPTY_POSN) // empty square
                state <= STATE_NEXT;
              else if (board[idx[row][col] + `BLACK_BIT] != black_to_move) // not color-to-move's piece
                state <= STATE_NEXT;
              else if (board[idx[row][col]+:PIECE_WIDTH - 1] == `PIECE_ROOK)
                state <= STATE_ROOK_INIT;
              else
                state <= STATE_NEXT;
           end
         STATE_ROOK_INIT :
           state <= STATE_NEXT;
         STATE_NEXT :
           begin
              col <= col + 1;
              if (col == 7)
                row <= row + 1;
              if (col == 7 && row == 7)
                state <= STATE_DONE;
              else
                state <= STATE_DO_SQUARE;
           end
         STATE_DONE :
           begin
              moves_ready <= 1;
              if (clear_moves)
                state <= STATE_IDLE;
           end
       endcase

   /* board_attack AUTO_TEMPLATE (
    );*/
   board_attack #
     (
      .PIECE_WIDTH (PIECE_WIDTH),
      .SIDE_WIDTH (SIDE_WIDTH),
      .BOARD_WIDTH (BOARD_WIDTH),
      .DO_DISPLAY (0)
      )
   board_attack
     (/*AUTOINST*/
      // Outputs
      .white_is_attacking               (white_is_attacking[63:0]),
      .black_is_attacking               (black_is_attacking[63:0]),
      .is_attacking_done                (is_attacking_done),
      .display_attacking_done           (display_attacking_done),
      // Inputs
      .reset                            (reset),
      .clk                              (clk),
      .board                            (board[BOARD_WIDTH-1:0]),
      .board_valid                      (board_valid));

endmodule

// Local Variables:
// verilog-auto-inst-param-value:t
// verilog-library-directories:(
//     "."
//     )
// End:

