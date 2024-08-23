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
    input [BOARD_WIDTH - 1:0]         board_in,
    input                             white_to_move_in,
    input [3:0]                       castle_mask_in,
    input [3:0]                       en_passant_col_in,

    input [MAX_POSITIONS_LOG2 - 1:0]  move_index,
    input                             clear_moves,

    output reg                        moves_ready,
    output [MAX_POSITIONS_LOG2 - 1:0] move_count,
    output [BOARD_WIDTH - 1:0]        board_out,
    output                            white_to_move_out,
    output [3:0]                      castle_mask_out,
    output [3:0]                      en_passant_col_out
    );

   // board + castle mask + en_passant_col + color_to_move
   localparam RAM_WIDTH = BOARD_WIDTH + 4 + 4 + 1;

   reg [RAM_WIDTH - 1:0]              move_ram [0:MAX_POSITIONS - 1];
   reg [RAM_WIDTH - 1:0]              ram_rd_data;
   reg [MAX_POSITIONS_LOG2 - 1:0]     ram_wr_addr;
   reg [2:0]                          row, col;
   reg [2:0]                          rook_row, rook_col;
   reg [$clog2(BOARD_WIDTH) - 1:0]    idx [0:7][0:7];
   reg                                is_queen;
   reg [PIECE_WIDTH - 1:0]            piece;
   reg [BOARD_WIDTH - 1:0]            board;
   reg                                white_to_move;
   reg [3:0]                          castle_mask;
   reg [3:0]                          en_passant_col;
   
   reg [BOARD_WIDTH - 1:0]            board_ram_wr;
   reg [3:0]                          en_passant_col_ram_wr;
   reg [3:0]                          castle_mask_ram_wr;
   reg                                white_to_move_ram_wr;
   reg                                ram_wr;

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
     begin
        ram_rd_data <= move_ram[move_index];
        if (ram_wr)
          move_ram[ram_wr_addr] <= {en_passant_col_ram_wr, castle_mask_ram_wr, white_to_move_ram_wr, board_ram_wr};
     end

   localparam STATE_IDLE = 0;
   localparam STATE_GET_ATTACKS = 1;
   localparam STATE_INIT = 2;
   localparam STATE_DO_SQUARE = 3;
   localparam STATE_NEXT = 4;
   localparam STATE_DONE = 5;
   localparam STATE_ROOK_LEFT_0 = 6;
   localparam STATE_ROOK_LEFT_1 = 7;
   localparam STATE_ROOK_RIGHT_0 = 8;
   localparam STATE_ROOK_RIGHT_1 = 9;

   reg [6:0]                          state = STATE_IDLE;

   always @(posedge clk)
     if (reset)
       state <= STATE_IDLE;
     else
       case (state)
         STATE_IDLE :
           begin
              moves_ready <= 0;
              board <= board_in;
              white_to_move <= white_to_move_in;
              castle_mask <= castle_mask_in;
              en_passant_col <= en_passant_col_in;
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
              ram_wr_addr <= 0;
              ram_wr <= 0;
              white_to_move_ram_wr <= ~white_to_move;
              state <= STATE_DO_SQUARE;
           end
         STATE_DO_SQUARE :
           begin
              board_ram_wr <= board;
              castle_mask_ram_wr <= castle_mask;
              en_passant_col_ram_wr <= en_passant_col;
              rook_row <= row;
              piece <= board[idx[row][col]+:PIECE_WIDTH];
              is_queen <= board[idx[row][col]+:PIECE_WIDTH - 1] == `PIECE_QUEN;
              if (board[idx[row][col]+:PIECE_WIDTH] == `EMPTY_POSN) // empty square, nothing to move
                state <= STATE_NEXT;
              else if (board[idx[row][col] + `BLACK_BIT] != black_to_move) // not color-to-move's piece
                state <= STATE_NEXT;
              else if (board[idx[row][col]+:PIECE_WIDTH - 1] == `PIECE_ROOK ||
                       board[idx[row][col]+:PIECE_WIDTH - 1] == `PIECE_QUEN)
                begin
                   if (col > 0)
                     begin
                        rook_col <= col - 1;
                        state <= STATE_ROOK_LEFT_0;
                     end
                   else if (col < 7)
                     begin
                        rook_col <= col + 1;
                        state <= STATE_ROOK_RIGHT_0;
                     end
                   else
                     state <= STATE_NEXT;
                end
              else
                state <= STATE_NEXT;
           end
         STATE_ROOK_LEFT_0 :
           begin
              if (board[idx[rook_row][rook_col]+:PIECE_WIDTH] == `EMPTY_POSN || // empty square
                  board[idx[rook_row][rook_col]+ `BLACK_BIT] != black_to_move) // opponent's piece
                begin
                   board_ram_wr[idx[row][col]+:PIECE_WIDTH] <= `EMPTY_POSN;
                   board_ram_wr[idx[rook_row][rook_col]+:PIECE_WIDTH] <= piece;
                   if (row == 0 && col == 7)
                     castle_mask_ram_wr[`CASTLE_WHITE_SHORT] <= 0;
                   if (row == 7 && col == 7)
                     castle_mask_ram_wr[`CASTLE_BLACK_SHORT] <= 0;
                   en_passant_col_ram_wr <= `EN_PASSANT_INVALID;
                   ram_wr <= 1;
                end
              state <= STATE_ROOK_LEFT_1;
           end
         STATE_ROOK_LEFT_1 :
           begin
              if (ram_wr)
                ram_wr_addr <= ram_wr_addr + 1;
              ram_wr <= 0;
              board_ram_wr <= board;
              castle_mask_ram_wr <= castle_mask;
              en_passant_col_ram_wr <= en_passant_col;
              if (rook_col == 0)
                if (col == 7)
                  state <= STATE_NEXT; // fixme, becomes rook up
                else
                  begin
                     rook_col <= col + 1;
                     state <= STATE_ROOK_RIGHT_0;
                  end
              else if (board[idx[rook_row][rook_col]+:PIECE_WIDTH] == `EMPTY_POSN) // keep moving left
                begin
                   rook_col <= rook_col - 1;
                   state <= STATE_ROOK_LEFT_0;
                end
              else // took a piece, or square occupied by own piece, stop moving left
                if (col == 7)
                  state <= STATE_NEXT; // fixme, becomes rook up
                else
                  begin
                     rook_col <= col + 1;
                     state <= STATE_ROOK_RIGHT_0;
                  end
           end
         STATE_ROOK_RIGHT_0 :
           begin
              state <= STATE_NEXT;
           end
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

