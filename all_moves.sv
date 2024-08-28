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
   reg [$clog2(BOARD_WIDTH) - 1:0]    idx [0:7][0:7];
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

   reg signed [4:0]                   row, col;

   reg signed [1:0]                   slider_offset_col [`PIECE_QUEN:`PIECE_BISH][0:7];
   reg signed [1:0]                   slider_offset_row [`PIECE_QUEN:`PIECE_BISH][0:7];
   reg [3:0]                          slider_offset_count [`PIECE_QUEN:`PIECE_BISH];
   reg [3:0]                          slider_index;
   reg signed [4:0]                   slider_row, slider_col;

   reg signed [2:0]                   discrete_offset_col[`PIECE_KNIT:`PIECE_KING][0:7];
   reg signed [2:0]                   discrete_offset_row[`PIECE_KNIT:`PIECE_KING][0:7];
   reg [3:0]                          discrete_index;
   reg signed [4:0]                   discrete_row, discrete_col;
   
   reg signed [1:0]                   pawn_advance [0:1];
   reg signed [4:0]                   pawn_promote_row [0:1];
   reg signed [4:0]                   pawn_init_row [0:1];
   reg signed [4:0]                   pawn_row_adv1, pawn_col_adv1;
   reg signed [4:0]                   pawn_row_adv2, pawn_col_adv2;
   reg signed [4:0]                   pawn_row_cap_left, pawn_col_cap_left;
   reg signed [4:0]                   pawn_row_cap_right, pawn_col_cap_right;
   reg [PIECE_WIDTH - 1:0]            pawn_promotions [0:3];
   reg [2:0]                          pawn_adv1_mask;
   reg [2:0]                          pawn_promote_mask;
   reg                                pawn_adv2;
   reg [1:0]                          pawn_en_passant_mask;
   reg signed [4:0]                   pawn_en_passant_row [0:1];
   reg                                pawn_en_passant_count;
   reg [1:0]                          pawn_move_count;
   reg [1:0]                          pawn_promotion_count;

   // should be empty
   /*AUTOREGINPUT*/

   /*AUTOWIRE*/
   // Beginning of automatic wires (for undeclared instantiated-module outputs)
   wire                 black_in_check;         // From board_attack of board_attack.v
   wire [63:0]          black_is_attacking;     // From board_attack of board_attack.v
   wire                 display_attacking_done; // From board_attack of board_attack.v
   wire                 is_attacking_done;      // From board_attack of board_attack.v
   wire                 white_in_check;         // From board_attack of board_attack.v
   wire [63:0]          white_is_attacking;     // From board_attack of board_attack.v
   // End of automatics
   
   wire signed [4:0]                  pawn_adv1_row [0:2];
   wire signed [4:0]                  pawn_adv1_col [0:2];
   wire signed [4:0]                  pawn_enp_row[0:1];

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

        pawn_advance[0] = -1; // black to move
        pawn_advance[1] =  1; // white to move
        pawn_promote_row[0] = 1; // black to move
        pawn_promote_row[1] = 6; // white to move
        pawn_init_row[0] = 6; // black to move
        pawn_init_row[1] = 1; // white to move
        pawn_en_passant_row[0] = 3; // black to move
        pawn_en_passant_row[1] = 4; // white to move

        pawn_promotions[0] = `PIECE_QUEN;
        pawn_promotions[1] = `PIECE_BISH;
        pawn_promotions[2] = `PIECE_ROOK;
        pawn_promotions[3] = `PIECE_KNIT;

        // avoid driver warnings in vivado
        for (ri = `PIECE_QUEN; ri <= `PIECE_BISH; ri = ri + 1)
          for (x = 0; x < 8; x = x + 1)
            begin
               slider_offset_row[ri][x] = 0;
               slider_offset_col[ri][x] = 0;
            end

        slider_offset_count[`PIECE_QUEN] = 8;
        ri = 0;
        for (y = -1; y <= +1; y = y + 1)
          for (x = -1; x <= +1; x = x + 1)
            if (! (y == 0 && x == 0))
              begin
                 slider_offset_row[`PIECE_QUEN][ri] = y;
                 slider_offset_col[`PIECE_QUEN][ri] = x;
                 ri = ri + 1;
              end

        slider_offset_count[`PIECE_ROOK] = 4;
        slider_offset_row[`PIECE_ROOK][0] = 0; slider_offset_col[`PIECE_ROOK][0] = +1;
        slider_offset_row[`PIECE_ROOK][1] = 0; slider_offset_col[`PIECE_ROOK][1] = -1;
        slider_offset_row[`PIECE_ROOK][2] = +1; slider_offset_col[`PIECE_ROOK][2] = 0;
        slider_offset_row[`PIECE_ROOK][3] = -1; slider_offset_col[`PIECE_ROOK][3] = 0;

        slider_offset_count[`PIECE_BISH] = 4;
        slider_offset_row[`PIECE_BISH][0] = +1; slider_offset_col[`PIECE_BISH][0] = +1;
        slider_offset_row[`PIECE_BISH][1] = +1; slider_offset_col[`PIECE_BISH][1] = -1;
        slider_offset_row[`PIECE_BISH][2] = -1; slider_offset_col[`PIECE_BISH][2] = +1;
        slider_offset_row[`PIECE_BISH][3] = -1; slider_offset_col[`PIECE_BISH][3] = -1;

        discrete_offset_row[`PIECE_KNIT][0] = -2; discrete_offset_col[`PIECE_KNIT][0] = -1;
        discrete_offset_row[`PIECE_KNIT][1] = -1; discrete_offset_col[`PIECE_KNIT][1] = -2;
        discrete_offset_row[`PIECE_KNIT][2] =  1; discrete_offset_col[`PIECE_KNIT][2] = -2;
        discrete_offset_row[`PIECE_KNIT][3] =  2; discrete_offset_col[`PIECE_KNIT][3] = -1;
        discrete_offset_row[`PIECE_KNIT][4] =  2; discrete_offset_col[`PIECE_KNIT][4] =  1;
        discrete_offset_row[`PIECE_KNIT][5] =  1; discrete_offset_col[`PIECE_KNIT][5] =  2;
        discrete_offset_row[`PIECE_KNIT][6] = -1; discrete_offset_col[`PIECE_KNIT][6] =  2;
        discrete_offset_row[`PIECE_KNIT][7] = -2; discrete_offset_col[`PIECE_KNIT][7] =  1;

        ri = 0;
        for (y = -1; y <= +1; y = y + 1)
          for (x = -1; x <= +1; x = x + 1)
            if (! (y == 0 && x == 0))
              begin
                 discrete_offset_row[`PIECE_KING][ri] = y;
                 discrete_offset_col[`PIECE_KING][ri] = x;
                 ri = ri + 1;
              end
     end

   always @(posedge clk)
     begin
        ram_rd_data <= move_ram[move_index];
        if (is_attacking_done)
          ram_wr_addr <= 0;
        if (ram_wr)
          begin
             move_ram[ram_wr_addr] <= {en_passant_col_ram_wr, castle_mask_ram_wr, white_to_move_ram_wr, board_ram_wr};
             ram_wr_addr <= ram_wr_addr + 1;
          end
     end // always @ (posedge clk)

   assign pawn_enp_row[0] = pawn_row_cap_left;
   assign pawn_enp_row[1] = pawn_row_cap_right;

   assign pawn_adv1_row[0] = pawn_row_cap_left;
   assign pawn_adv1_row[1] = pawn_row_adv1;
   assign pawn_adv1_row[2] = pawn_row_cap_right;
   assign pawn_adv1_col[0] = pawn_col_cap_left;
   assign pawn_adv1_col[1] = pawn_col_adv1;
   assign pawn_adv1_col[2] = pawn_col_cap_right;

   always @(posedge clk)
     begin
        piece <= board[idx[row][col]+:PIECE_WIDTH];
        
        white_to_move_ram_wr <= ~white_to_move;

        // free-run these for timing, only valid when used in states
        pawn_row_adv1 <= row + pawn_advance[white_to_move];
        pawn_col_adv1 <= col;
        pawn_row_adv2 <= row + pawn_advance[white_to_move] * 2;
        pawn_col_adv2 <= col;
        pawn_row_cap_left <= row + pawn_advance[white_to_move];
        pawn_col_cap_left <= col - 1;
        pawn_row_cap_right <= row + pawn_advance[white_to_move];
        pawn_col_cap_right <= col + 1;
        for (i = 0; i < 4; i = i + 1)
          pawn_promotions[i][`BLACK_BIT] <= black_to_move;

        pawn_adv1_mask[0] <= pawn_col_cap_left >= 0 &&
                             board[idx[pawn_row_cap_left[2:0]][pawn_col_cap_left[2:0]]+:PIECE_WIDTH] != `EMPTY_POSN && // can't be empty, and
                             board[idx[pawn_row_cap_left[2:0]][pawn_col_cap_left[2:0]] + `BLACK_BIT] != black_to_move; // contains opponent's piece
        pawn_adv1_mask[1] <= board[idx[pawn_row_adv1[2:0]][pawn_col_adv1[2:0]]+:PIECE_WIDTH] == `EMPTY_POSN;
        pawn_adv1_mask[2] <= pawn_col_cap_right <= 7 &&
                             board[idx[pawn_row_cap_right[2:0]][pawn_col_cap_right[2:0]]+:PIECE_WIDTH] != `EMPTY_POSN && // can't be empty, and
                             board[idx[pawn_row_cap_right[2:0]][pawn_col_cap_right[2:0]] + `BLACK_BIT] != black_to_move; // contains opponent's piece
        pawn_adv2 <= board[idx[pawn_row_adv1[2:0]][pawn_col_adv1[2:0]]+:PIECE_WIDTH] == `EMPTY_POSN &&
                     board[idx[pawn_row_adv2[2:0]][pawn_col_adv2[2:0]]+:PIECE_WIDTH] == `EMPTY_POSN;
        for (i = 0; i <= 2; i = i + 1)
          pawn_promote_mask[i] <= pawn_adv1_mask[i];

        pawn_en_passant_mask[0] <= en_passant_col[`EN_PASSANT_VALID_BIT] &&
                                   pawn_col_cap_left >= 0 &&
                                   en_passant_col[2:0] == pawn_col_cap_left[2:0];
        pawn_en_passant_mask[1] <= en_passant_col[`EN_PASSANT_VALID_BIT] &&
                                   pawn_col_cap_right <= 7 &&
                                   en_passant_col[2:0] == pawn_col_cap_right[2:0];
     end

   localparam STATE_IDLE = 0;
   localparam STATE_GET_ATTACKS = 1;
   localparam STATE_INIT = 2;
   localparam STATE_DO_SQUARE = 3;
   localparam STATE_SLIDER_INIT = 4;
   localparam STATE_SLIDER = 5;
   localparam STATE_DISCRETE_INIT = 6;
   localparam STATE_DISCRETE = 7;
   localparam STATE_PAWN_INIT_0 = 8;
   localparam STATE_PAWN_INIT_1 = 9;
   localparam STATE_PAWN_ROW_1 = 10;
   localparam STATE_PAWN_ROW_4 = 11;
   localparam STATE_PAWN_ROW_6 = 12;
   localparam STATE_PAWN_ADVANCE = 13;
   localparam STATE_NEXT = 127;
   localparam STATE_DONE = 255;

   reg [7:0]                          state = STATE_IDLE;

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
              ram_wr <= 0;
              state <= STATE_DO_SQUARE;
           end
         STATE_DO_SQUARE :
           begin
              board_ram_wr <= board;
              castle_mask_ram_wr <= castle_mask;
              en_passant_col_ram_wr <= 0 << `EN_PASSANT_VALID_BIT;
              slider_index <= 0;
              if (board[idx[row][col]+:PIECE_WIDTH] == `EMPTY_POSN) // empty square, nothing to move
                state <= STATE_NEXT;
              else if (board[idx[row][col] + `BLACK_BIT] != black_to_move) // not color-to-move's piece
                state <= STATE_NEXT;
              else if (board[idx[row][col]+:PIECE_WIDTH - 1] == `PIECE_QUEN ||
                       board[idx[row][col]+:PIECE_WIDTH - 1] == `PIECE_ROOK ||
                       board[idx[row][col]+:PIECE_WIDTH - 1] == `PIECE_BISH)
                state <= STATE_SLIDER_INIT;
              else if (board[idx[row][col]+:PIECE_WIDTH - 1] == `PIECE_KNIT ||
                       board[idx[row][col]+:PIECE_WIDTH - 1] == `PIECE_KING)
                state <= STATE_DISCRETE_INIT;
              else if (board[idx[row][col]+:PIECE_WIDTH - 1] == `PIECE_PAWN)
                state <= STATE_PAWN_INIT_0;
              else
                state <= STATE_NEXT;
           end
         STATE_SLIDER_INIT :
           begin
              ram_wr <= 0;
              if (slider_index < slider_offset_count[piece[`BLACK_BIT - 1:0]])
                begin
                   slider_row <= row + slider_offset_row[piece[`BLACK_BIT - 1:0]][slider_index];
                   slider_col <= col + slider_offset_col[piece[`BLACK_BIT - 1:0]][slider_index];
                   state <= STATE_SLIDER;
                end
              else
                state <= STATE_NEXT;
           end
         STATE_SLIDER :
           begin
              board_ram_wr <= board;
              if ((slider_row >= 0 && slider_row <= 7 && slider_col >= 0 && slider_col <= 7) &&
                  (board[idx[slider_row[2:0]][slider_col[2:0]]+:PIECE_WIDTH] == `EMPTY_POSN || // empty square
                   board[idx[slider_row[2:0]][slider_col[2:0]] + `BLACK_BIT] != black_to_move)) // opponent's piece
                begin
                   ram_wr <= 1;
                   board_ram_wr[idx[row][col]+:PIECE_WIDTH] <= `EMPTY_POSN;
                   board_ram_wr[idx[slider_row[2:0]][slider_col[2:0]]+:PIECE_WIDTH] <= piece;
                   slider_row <= slider_row + slider_offset_row[piece[`BLACK_BIT - 1:0]][slider_index];
                   slider_col <= slider_col + slider_offset_col[piece[`BLACK_BIT - 1:0]][slider_index];
                   if (board[idx[slider_row[2:0]][slider_col[2:0]]+:PIECE_WIDTH] != `EMPTY_POSN)
                     begin
                        slider_index <= slider_index + 1;
                        state <= STATE_SLIDER_INIT;
                     end
                end
              else
                begin
                   ram_wr <= 0;
                   slider_index <= slider_index + 1;
                   state <= STATE_SLIDER_INIT;
                end
           end
         STATE_DISCRETE_INIT :
           begin
              discrete_index <= 1;
              discrete_row <= row + discrete_offset_row[piece[`BLACK_BIT - 1:0]][0];
              discrete_col <= col + discrete_offset_col[piece[`BLACK_BIT - 1:0]][0];
              state <= STATE_DISCRETE;
           end
         STATE_DISCRETE :
           begin
              board_ram_wr <= board;
              if (discrete_row >= 0 && discrete_row <= 7 && discrete_col >= 0 && discrete_col <= 7 &&
                  (board[idx[discrete_row[2:0]][discrete_col[2:0]]+:PIECE_WIDTH] == `EMPTY_POSN || // empty square
                   board[idx[discrete_row[2:0]][discrete_col[2:0]] + `BLACK_BIT] != black_to_move)) // opponent's piece
                begin
                   ram_wr <= 1;
                   board_ram_wr[idx[row][col]+:PIECE_WIDTH] <= `EMPTY_POSN;
                   board_ram_wr[idx[discrete_row[2:0]][discrete_col[2:0]]+:PIECE_WIDTH] <= piece;
                end
              else
                ram_wr <= 0;
              discrete_index <= discrete_index + 1;
              discrete_row <= row + discrete_offset_row[piece[`BLACK_BIT - 1:0]][discrete_index];
              discrete_col <= col + discrete_offset_col[piece[`BLACK_BIT - 1:0]][discrete_index];
              if (discrete_index == 8)
                state <= STATE_NEXT;
           end
         STATE_PAWN_INIT_0 :
           state <= STATE_PAWN_INIT_1; // wait state
         STATE_PAWN_INIT_1 :
           begin
              pawn_en_passant_count <= 0;
              pawn_move_count <= 0;
              pawn_promotion_count <= 0;
              if (row == pawn_init_row[white_to_move])
                state <= STATE_PAWN_ROW_1;
              else if (row == pawn_en_passant_row[white_to_move])
                state <= STATE_PAWN_ROW_4;
              else if (row == pawn_promote_row[white_to_move])
                state <= STATE_PAWN_ROW_6;
              else
                state <= STATE_PAWN_ADVANCE;
           end
         STATE_PAWN_ROW_1 : // initial pawn
           begin
              board_ram_wr <= board;
              en_passant_col_ram_wr <= (1 << `EN_PASSANT_VALID_BIT) | pawn_col_adv2[2:0];
              if (pawn_adv2)
                begin
                   ram_wr <= 1;
                   board_ram_wr[idx[row[2:0]][col[2:0]]+:PIECE_WIDTH] <= `EMPTY_POSN;
                   board_ram_wr[idx[pawn_row_adv2[2:0]][pawn_col_adv2[2:0]]+:PIECE_WIDTH] <= piece;
                end
              state <= STATE_PAWN_ADVANCE;
           end
         STATE_PAWN_ROW_4 : // en passant pawn
           begin
              board_ram_wr <= board;
              if (pawn_en_passant_mask[pawn_en_passant_count])
                begin
                   ram_wr <= 1;
                   board_ram_wr[idx[row[2:0]][col[2:0]]+:PIECE_WIDTH] <= `EMPTY_POSN;
                   board_ram_wr[idx[row[2:0]][en_passant_col[2:0]]+:PIECE_WIDTH] <= `EMPTY_POSN;
                   board_ram_wr[idx[pawn_enp_row[pawn_en_passant_count][2:0]][en_passant_col[2:0]]+:PIECE_WIDTH] <= piece;
                   state <= STATE_PAWN_ADVANCE;
                end
              pawn_en_passant_count <= pawn_en_passant_count + 1;
              if (pawn_en_passant_count == 1)
                state <= STATE_PAWN_ADVANCE;
           end
         STATE_PAWN_ROW_6 : // promotion pawn
           begin
              ram_wr <= 0;
              board_ram_wr <= board;
              if (pawn_promote_mask[pawn_move_count])
                begin
                   ram_wr <= 1;
                   board_ram_wr[idx[row[2:0]][col[2:0]]+:PIECE_WIDTH] <= `EMPTY_POSN;
                   board_ram_wr[idx[pawn_adv1_row[pawn_move_count][2:0]][pawn_adv1_col[pawn_move_count][2:0]]+:PIECE_WIDTH]
                     <= pawn_promotions[pawn_promotion_count];
                end
              if (pawn_promotion_count == 3)
                begin
                   pawn_promotion_count <= 0;
                   pawn_move_count <= pawn_move_count + 1;
                   if (pawn_move_count == 2)
                     state <= STATE_NEXT;
                end
              else
                pawn_promotion_count <= pawn_promotion_count + 1;
           end
         STATE_PAWN_ADVANCE :
           begin
              en_passant_col_ram_wr <= 0 << `EN_PASSANT_VALID_BIT;
              ram_wr <= 0;
              board_ram_wr <= board;
              if (pawn_adv1_mask[pawn_move_count])
                begin
                   ram_wr <= 1;
                   board_ram_wr[idx[row[2:0]][col[2:0]]+:PIECE_WIDTH] <= `EMPTY_POSN;
                   board_ram_wr[idx[pawn_adv1_row[pawn_move_count][2:0]][pawn_adv1_col[pawn_move_count][2:0]]+:PIECE_WIDTH] <= piece;
                end
              pawn_move_count <= pawn_move_count + 1;
              if (pawn_move_count == 2)
                state <= STATE_NEXT;
           end
         STATE_NEXT :
           begin
              ram_wr <= 0;
              col <= col + 1;
              if (col == 7)
                begin
                   row <= row + 1;
                   col <= 0;
                end
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
      .white_in_check                   (white_in_check),
      .black_in_check                   (black_in_check),
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

