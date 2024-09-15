`include "vchess.vh"

module all_moves #
  (
   parameter MAX_POSITIONS_LOG2 = $clog2(`MAX_POSITIONS),
   parameter EVAL_WIDTH = 0
   )
   (
    input                                clk,
    input                                reset,

    input                                board_valid,
    input [`BOARD_WIDTH - 1:0]           board_in,
    input                                white_to_move_in,
    input [3:0]                          castle_mask_in,
    input [3:0]                          en_passant_col_in,

    input [MAX_POSITIONS_LOG2 - 1:0]     move_index,
    input                                clear_moves,

    output reg                           initial_mate = 0,
    output reg                           initial_stalemate = 0,
    output reg signed [EVAL_WIDTH - 1:0] initial_eval,

    output reg                           moves_ready,
    output reg                           move_ready,
    output [MAX_POSITIONS_LOG2 - 1:0]    move_count,

    output [`BOARD_WIDTH - 1:0]          board_out,
    output                               white_to_move_out,
    output [3:0]                         castle_mask_out,
    output [3:0]                         en_passant_col_out,
    output                               capture_out,
    output                               white_in_check_out,
    output                               black_in_check_out,
    output [63:0]                        white_is_attacking_out,
    output [63:0]                        black_is_attacking_out,
    output signed [EVAL_WIDTH - 1:0]     eval_out
    );

   // board + castle mask + en_passant_col + color_to_move + capture
   localparam RAM_WIDTH = `BOARD_WIDTH + 4 + 4 + 1 + 1;
   localparam LEGAL_RAM_WIDTH = EVAL_WIDTH + 64 + 64 + RAM_WIDTH + 1 + 1; // eval, is-attacking, board, white, black in check

   reg                                   initial_board_check;

   reg [RAM_WIDTH - 1:0]                 move_ram [0:`MAX_POSITIONS - 1];
   reg [RAM_WIDTH - 1:0]                 ram_rd_data;
   reg                                   ram_wr_addr_init;
   reg [MAX_POSITIONS_LOG2 - 1:0]        ram_wr_addr, ram_rd_addr;
   reg [MAX_POSITIONS_LOG2 - 1:0]        attack_test_move_count;
   reg [$clog2(`BOARD_WIDTH) - 1:0]      idx [0:7][0:7];
   reg [`PIECE_WIDTH - 1:0]              piece;
   reg [`BOARD_WIDTH - 1:0]              board;
   reg                                   white_to_move;
   reg [3:0]                             castle_mask;
   reg [3:0]                             en_passant_col;

   reg [LEGAL_RAM_WIDTH - 1:0]           legal_move_ram [0:`MAX_POSITIONS - 1];
   reg [LEGAL_RAM_WIDTH - 1:0]           legal_ram_rd_data;
   reg [MAX_POSITIONS_LOG2 - 1:0]        legal_ram_wr_addr;
   reg                                   legal_ram_wr_addr_init;

   reg [`BOARD_WIDTH - 1:0]              board_ram_wr;
   reg [3:0]                             en_passant_col_ram_wr;
   reg [3:0]                             castle_mask_ram_wr;
   reg                                   white_to_move_ram_wr;
   reg                                   capture_ram_wr;
   reg                                   ram_wr;

   reg [`BOARD_WIDTH - 1:0]              legal_board_ram_wr;
   reg [3:0]                             legal_en_passant_col_ram_wr;
   reg [3:0]                             legal_castle_mask_ram_wr;
   reg                                   legal_white_to_move_ram_wr;
   reg                                   legal_capture_ram_wr;
   reg                                   legal_white_in_check_ram_wr;
   reg                                   legal_black_in_check_ram_wr;
   reg [63:0]                            legal_white_is_attacking_ram_wr;
   reg [63:0]                            legal_black_is_attacking_ram_wr;
   reg signed [EVAL_WIDTH - 1:0]         legal_eval_ram_wr;
   reg                                   legal_ram_wr;

   reg [MAX_POSITIONS_LOG2 - 1:0]        move_index_r;

   reg [`BOARD_WIDTH - 1:0]              attack_test_board;
   reg [3:0]                             attack_test_en_passant_col;
   reg [3:0]                             attack_test_castle_mask;
   reg                                   attack_test_white_to_move;
   reg                                   attack_test_capture;
   reg                                   attack_test_white_in_check;
   reg                                   attack_test_black_in_check;
   reg [63:0]                            attack_test_white_is_attacking;
   reg [63:0]                            attack_test_black_is_attacking;

   reg [`BOARD_WIDTH - 1:0]              attack_test;
   reg                                   attack_test_valid;

   reg                                   clear_eval = 0;
   reg                                   clear_attack = 0;

   reg signed [4:0]                      row, col;

   reg signed [1:0]                      slider_offset_col [`PIECE_QUEN:`PIECE_BISH][0:7];
   reg signed [1:0]                      slider_offset_row [`PIECE_QUEN:`PIECE_BISH][0:7];
   reg [3:0]                             slider_offset_count [`PIECE_QUEN:`PIECE_BISH];
   reg [3:0]                             slider_index;
   reg signed [4:0]                      slider_row, slider_col;

   reg signed [2:0]                      discrete_offset_col[`PIECE_KNIT:`PIECE_KING][0:7];
   reg signed [2:0]                      discrete_offset_row[`PIECE_KNIT:`PIECE_KING][0:7];
   reg [3:0]                             discrete_index;
   reg signed [4:0]                      discrete_row, discrete_col;

   reg signed [1:0]                      pawn_advance [0:1];
   reg signed [4:0]                      pawn_promote_row [0:1];
   reg signed [4:0]                      pawn_init_row [0:1];
   reg signed [4:0]                      pawn_row_adv1, pawn_col_adv1;
   reg signed [4:0]                      pawn_row_adv2, pawn_col_adv2;
   reg signed [4:0]                      pawn_row_cap_left, pawn_col_cap_left;
   reg signed [4:0]                      pawn_row_cap_right, pawn_col_cap_right;
   reg [`PIECE_WIDTH - 1:0]              pawn_promotions [0:3];
   reg [2:0]                             pawn_adv1_mask;
   reg [2:0]                             pawn_promote_mask;
   reg                                   pawn_adv2;
   reg [1:0]                             pawn_en_passant_mask;
   reg signed [4:0]                      pawn_en_passant_row [0:1];
   reg                                   pawn_en_passant_count;
   reg [1:0]                             pawn_move_count;
   reg [1:0]                             pawn_promotion_count;
   reg                                   pawn_do_init;
   reg                                   pawn_do_en_passant;
   reg                                   pawn_do_promote;

   reg [1:0]                             castle_short_legal;
   reg [1:0]                             castle_long_legal;
   reg [2:0]                             castle_row [0:1];

   // should be empty
   /*AUTOREGINPUT*/

   /*AUTOWIRE*/
   // Beginning of automatic wires (for undeclared instantiated-module outputs)
   wire                                  black_in_check;         // From board_attack of board_attack.v
   wire [63:0]                           black_is_attacking;     // From board_attack of board_attack.v
   wire                                  display_attacking_done; // From board_attack of board_attack.v
   wire signed [EVAL_WIDTH-1:0]          eval;           // From evaluate of evaluate.v
   wire                                  eval_valid;             // From evaluate of evaluate.v
   wire                                  is_attacking_done;      // From board_attack of board_attack.v
   wire                                  white_in_check;         // From board_attack of board_attack.v
   wire [63:0]                           white_is_attacking;     // From board_attack of board_attack.v
   // End of automatics

   wire signed [4:0]                     pawn_adv1_row [0:2];
   wire signed [4:0]                     pawn_adv1_col [0:2];
   wire signed [4:0]                     pawn_enp_row[0:1];

   integer                               i, x, y, ri;

   wire                                  black_to_move = ~white_to_move;

   assign move_count = legal_ram_wr_addr;
   assign {eval_out, white_is_attacking_out, black_is_attacking_out,
           white_in_check_out, black_in_check_out,
           capture_out, en_passant_col_out, castle_mask_out, white_to_move_out,
           board_out} = legal_ram_rd_data;

   initial
     begin
        for (y = 0; y < 8; y = y + 1)
          begin
             ri = y * `SIDE_WIDTH;
             for (x = 0; x < 8; x = x + 1)
               idx[y][x] = ri + x * `PIECE_WIDTH;
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

        castle_row[0] = 7; // black to move
        castle_row[1] = 0; // white to move
     end

   always @(posedge clk)
     begin
        ram_rd_data <= move_ram[ram_rd_addr];
        if (ram_wr_addr_init)
          ram_wr_addr <= 0;
        if (ram_wr)
          begin
             move_ram[ram_wr_addr] <= {capture_ram_wr, en_passant_col_ram_wr, castle_mask_ram_wr, white_to_move_ram_wr, board_ram_wr};
             ram_wr_addr <= ram_wr_addr + 1;
          end
     end

   always @(posedge clk)
     begin
        move_index_r <= move_index;
        move_ready <= move_index == move_index_r;

        legal_ram_rd_data <= legal_move_ram[move_index];
        if (legal_ram_wr_addr_init)
          legal_ram_wr_addr <= 0;
        if (legal_ram_wr)
          begin
             legal_move_ram[legal_ram_wr_addr] <= {legal_eval_ram_wr,
                                                   legal_white_is_attacking_ram_wr, legal_black_is_attacking_ram_wr,
                                                   legal_white_in_check_ram_wr, legal_black_in_check_ram_wr,
                                                   legal_capture_ram_wr, legal_en_passant_col_ram_wr, legal_castle_mask_ram_wr,
                                                   legal_white_to_move_ram_wr, legal_board_ram_wr};
             legal_ram_wr_addr <= legal_ram_wr_addr + 1;
          end
     end

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
        piece <= board[idx[row][col]+:`PIECE_WIDTH];

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
                             board[idx[pawn_row_cap_left[2:0]][pawn_col_cap_left[2:0]]+:`PIECE_WIDTH] != `EMPTY_POSN && // can't be empty, and
                             board[idx[pawn_row_cap_left[2:0]][pawn_col_cap_left[2:0]] + `BLACK_BIT] != black_to_move; // contains opponent's piece
        pawn_adv1_mask[1] <= board[idx[pawn_row_adv1[2:0]][pawn_col_adv1[2:0]]+:`PIECE_WIDTH] == `EMPTY_POSN;
        pawn_adv1_mask[2] <= pawn_col_cap_right <= 7 &&
                             board[idx[pawn_row_cap_right[2:0]][pawn_col_cap_right[2:0]]+:`PIECE_WIDTH] != `EMPTY_POSN && // can't be empty, and
                             board[idx[pawn_row_cap_right[2:0]][pawn_col_cap_right[2:0]] + `BLACK_BIT] != black_to_move; // contains opponent's piece
        pawn_adv2 <= board[idx[pawn_row_adv1[2:0]][pawn_col_adv1[2:0]]+:`PIECE_WIDTH] == `EMPTY_POSN &&
                     board[idx[pawn_row_adv2[2:0]][pawn_col_adv2[2:0]]+:`PIECE_WIDTH] == `EMPTY_POSN;
        for (i = 0; i <= 2; i = i + 1)
          pawn_promote_mask[i] <= pawn_adv1_mask[i];

        pawn_en_passant_mask[0] <= en_passant_col[`EN_PASSANT_VALID_BIT] &&
                                   pawn_col_cap_left >= 0 &&
                                   en_passant_col[2:0] == pawn_col_cap_left[2:0];
        pawn_en_passant_mask[1] <= en_passant_col[`EN_PASSANT_VALID_BIT] &&
                                   pawn_col_cap_right <= 7 &&
                                   en_passant_col[2:0] == pawn_col_cap_right[2:0];
        pawn_do_init <= row == pawn_init_row[white_to_move];
        pawn_do_en_passant <= row == pawn_en_passant_row[white_to_move];
        pawn_do_promote <= row == pawn_promote_row[white_to_move];

        // black to move
        castle_short_legal[0] <= castle_mask[`CASTLE_BLACK_SHORT] &&
                                 board[idx[7][5]+:`PIECE_WIDTH] == `EMPTY_POSN &&
                                 board[idx[7][6]+:`PIECE_WIDTH] == `EMPTY_POSN &&
                                 white_is_attacking[7 << 3 | 4] == 1'b0 &&
                                 white_is_attacking[7 << 3 | 5] == 1'b0 &&
                                 white_is_attacking[7 << 3 | 6] == 1'b0;
        castle_long_legal[0] <= castle_mask[`CASTLE_BLACK_LONG] &&
                                board[idx[7][1]+:`PIECE_WIDTH] == `EMPTY_POSN &&
                                board[idx[7][2]+:`PIECE_WIDTH] == `EMPTY_POSN &&
                                board[idx[7][3]+:`PIECE_WIDTH] == `EMPTY_POSN &&
                                white_is_attacking[7 << 3 | 2] == 1'b0 &&
                                white_is_attacking[7 << 3 | 3] == 1'b0 &&
                                white_is_attacking[7 << 3 | 4] == 1'b0;
        // white to move
        castle_short_legal[1] <= castle_mask[`CASTLE_WHITE_SHORT] &&
                                 board[idx[0][5]+:`PIECE_WIDTH] == `EMPTY_POSN &&
                                 board[idx[0][6]+:`PIECE_WIDTH] == `EMPTY_POSN &&
                                 black_is_attacking[0 << 3 | 4] == 1'b0 &&
                                 black_is_attacking[0 << 3 | 5] == 1'b0 &&
                                 black_is_attacking[0 << 3 | 6] == 1'b0;
        castle_long_legal[1] <= castle_mask[`CASTLE_WHITE_LONG] &&
                                board[idx[0][1]+:`PIECE_WIDTH] == `EMPTY_POSN &&
                                board[idx[0][2]+:`PIECE_WIDTH] == `EMPTY_POSN &&
                                board[idx[0][3]+:`PIECE_WIDTH] == `EMPTY_POSN &&
                                black_is_attacking[0 << 3 | 2] == 1'b0 &&
                                black_is_attacking[0 << 3 | 3] == 1'b0 &&
                                black_is_attacking[0 << 3 | 4] == 1'b0;
     end

   localparam STATE_IDLE = 0;
   localparam STATE_INIT = 1;
   localparam STATE_DO_SQUARE = 2;
   localparam STATE_SLIDER_INIT = 3;
   localparam STATE_SLIDER = 4;
   localparam STATE_DISCRETE_INIT = 5;
   localparam STATE_DISCRETE = 6;
   localparam STATE_PAWN_INIT_0 = 7;
   localparam STATE_PAWN_INIT_1 = 8;
   localparam STATE_PAWN_ROW_1 = 9;
   localparam STATE_PAWN_ROW_4 = 10;
   localparam STATE_PAWN_ROW_6 = 11;
   localparam STATE_PAWN_ADVANCE = 12;
   localparam STATE_NEXT = 13;
   localparam STATE_CASTLE_SHORT = 14;
   localparam STATE_CASTLE_LONG = 15;
   localparam STATE_ALL_MOVES_DONE = 16;
   localparam STATE_LEGAL_INIT = 17;
   localparam STATE_LEGAL_LOAD = 18;
   localparam STATE_LEGAL_KING_POS = 19;
   localparam STATE_ATTACK_WAIT = 20;
   localparam STATE_LEGAL_MOVE = 21;
   localparam STATE_LEGAL_NEXT = 22;
   localparam STATE_DONE = 23;

   reg [4:0] state = STATE_IDLE;

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

              attack_test <= board_in;
              attack_test_valid <= board_valid;
              ram_wr_addr_init <= 1;
              clear_eval <= 0;
              clear_attack <= 0;
              if (is_attacking_done && eval_valid)
                state <= STATE_INIT;
           end
         STATE_INIT :
           begin
              initial_eval <= eval;
              clear_eval <= 1;
              clear_attack <= 1;
              attack_test_valid <= 0;
              initial_board_check <= (white_to_move && white_in_check) || (black_to_move && black_in_check);
              legal_ram_wr_addr_init <= 1;
              ram_wr_addr_init <= 0;
              row <= 0;
              col <= 0;
              ram_wr <= 0;
              state <= STATE_DO_SQUARE;
           end
         STATE_DO_SQUARE :
           begin
              clear_eval <= 0;
              clear_attack <= 0;
              castle_mask_ram_wr <= castle_mask;
              en_passant_col_ram_wr <= 4'b0;
              slider_index <= 0;
              if (board[idx[row][col]+:`PIECE_WIDTH] == `EMPTY_POSN || // empty square or
                  board[idx[row][col] + `BLACK_BIT] != black_to_move) // opponent's piece, nothing to move
                begin
                   ram_wr <= 0;
                   col <= col + 1;
                   if (col == 7)
                     begin
                        row <= row + 1;
                        col <= 0;
                     end
                   if (col == 7 && row == 7)
                     state <= STATE_CASTLE_SHORT;
                   else
                     state <= STATE_DO_SQUARE;
                end
              else if (board[idx[row][col]+:`PIECE_WIDTH - 1] == `PIECE_QUEN ||
                       board[idx[row][col]+:`PIECE_WIDTH - 1] == `PIECE_ROOK ||
                       board[idx[row][col]+:`PIECE_WIDTH - 1] == `PIECE_BISH)
                state <= STATE_SLIDER_INIT;
              else if (board[idx[row][col]+:`PIECE_WIDTH - 1] == `PIECE_KNIT ||
                       board[idx[row][col]+:`PIECE_WIDTH - 1] == `PIECE_KING)
                state <= STATE_DISCRETE_INIT;
              else
                state <= STATE_PAWN_INIT_0; // must be a pawn
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
              board_ram_wr[idx[row][col]+:`PIECE_WIDTH] <= `EMPTY_POSN;
              board_ram_wr[idx[slider_row[2:0]][slider_col[2:0]]+:`PIECE_WIDTH] <= piece;
              capture_ram_wr <= board[idx[slider_row[2:0]][slider_col[2:0]] + `BLACK_BIT] != black_to_move &&
                                ! board[idx[slider_row[2:0]][slider_col[2:0]]+:`PIECE_WIDTH] == `EMPTY_POSN;
              if ((slider_row >= 0 && slider_row <= 7 && slider_col >= 0 && slider_col <= 7) &&
                  (board[idx[slider_row[2:0]][slider_col[2:0]]+:`PIECE_WIDTH] == `EMPTY_POSN || // empty square
                   board[idx[slider_row[2:0]][slider_col[2:0]] + `BLACK_BIT] != black_to_move)) // opponent's piece
                begin
                   ram_wr <= 1;
                   slider_row <= slider_row + slider_offset_row[piece[`BLACK_BIT - 1:0]][slider_index];
                   slider_col <= slider_col + slider_offset_col[piece[`BLACK_BIT - 1:0]][slider_index];
                   if (board[idx[slider_row[2:0]][slider_col[2:0]]+:`PIECE_WIDTH] != `EMPTY_POSN)
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
              board_ram_wr[idx[row][col]+:`PIECE_WIDTH] <= `EMPTY_POSN;
              board_ram_wr[idx[discrete_row[2:0]][discrete_col[2:0]]+:`PIECE_WIDTH] <= piece;
              capture_ram_wr <= board[idx[discrete_row[2:0]][discrete_col[2:0]] + `BLACK_BIT] != black_to_move &&
                                ! board[idx[discrete_row[2:0]][discrete_col[2:0]]+:`PIECE_WIDTH] == `EMPTY_POSN;
              if (discrete_row >= 0 && discrete_row <= 7 && discrete_col >= 0 && discrete_col <= 7 &&
                  (board[idx[discrete_row[2:0]][discrete_col[2:0]]+:`PIECE_WIDTH] == `EMPTY_POSN || // empty square
                   board[idx[discrete_row[2:0]][discrete_col[2:0]] + `BLACK_BIT] != black_to_move)) // opponent's piece
                ram_wr <= 1;
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
              if (pawn_do_init)
                state <= STATE_PAWN_ROW_1;
              else if (pawn_do_en_passant)
                state <= STATE_PAWN_ROW_4;
              else if (pawn_do_promote)
                state <= STATE_PAWN_ROW_6;
              else
                state <= STATE_PAWN_ADVANCE;
           end
         STATE_PAWN_ROW_1 : // initial pawn
           begin
              board_ram_wr <= board;
              en_passant_col_ram_wr <= (1 << `EN_PASSANT_VALID_BIT) | pawn_col_adv2[2:0];
              board_ram_wr[idx[row[2:0]][col[2:0]]+:`PIECE_WIDTH] <= `EMPTY_POSN;
              board_ram_wr[idx[pawn_row_adv2[2:0]][pawn_col_adv2[2:0]]+:`PIECE_WIDTH] <= piece;
              capture_ram_wr <= 0;
              if (pawn_adv2)
                ram_wr <= 1;
              state <= STATE_PAWN_ADVANCE;
           end
         STATE_PAWN_ROW_4 : // en passant pawn
           begin
              board_ram_wr <= board;
              board_ram_wr[idx[row[2:0]][col[2:0]]+:`PIECE_WIDTH] <= `EMPTY_POSN;
              board_ram_wr[idx[row[2:0]][en_passant_col[2:0]]+:`PIECE_WIDTH] <= `EMPTY_POSN;
              board_ram_wr[idx[pawn_enp_row[pawn_en_passant_count][2:0]][en_passant_col[2:0]]+:`PIECE_WIDTH] <= piece;
              if (pawn_en_passant_mask[pawn_en_passant_count])
                begin
                   capture_ram_wr <= 1;
                   ram_wr <= 1;
                   state <= STATE_PAWN_ADVANCE;
                end
              else
                capture_ram_wr <= 0;
              pawn_en_passant_count <= pawn_en_passant_count + 1;
              if (pawn_en_passant_count == 1)
                state <= STATE_PAWN_ADVANCE;
           end
         STATE_PAWN_ROW_6 : // promotion pawn
           begin
              board_ram_wr <= board;
              board_ram_wr[idx[row[2:0]][col[2:0]]+:`PIECE_WIDTH] <= `EMPTY_POSN;
              board_ram_wr[idx[pawn_adv1_row[pawn_move_count][2:0]][pawn_adv1_col[pawn_move_count][2:0]]+:`PIECE_WIDTH]
                <= pawn_promotions[pawn_promotion_count];
              capture_ram_wr <= pawn_move_count != 1;
              if (pawn_promote_mask[pawn_move_count])
                ram_wr <= 1;
              else
                ram_wr <= 0;
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
         STATE_PAWN_ADVANCE : // default pawn moves
           begin
              en_passant_col_ram_wr <= 0 << `EN_PASSANT_VALID_BIT;
              board_ram_wr <= board;
              board_ram_wr[idx[row[2:0]][col[2:0]]+:`PIECE_WIDTH] <= `EMPTY_POSN;
              board_ram_wr[idx[pawn_adv1_row[pawn_move_count][2:0]][pawn_adv1_col[pawn_move_count][2:0]]+:`PIECE_WIDTH] <= piece;
              capture_ram_wr <= pawn_move_count != 1;
              if (pawn_adv1_mask[pawn_move_count])
                ram_wr <= 1;
              else
                ram_wr <= 0;
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
                state <= STATE_CASTLE_SHORT;
              else
                state <= STATE_DO_SQUARE;
           end
         STATE_CASTLE_SHORT :
           begin
              board_ram_wr <= board;
              board_ram_wr[idx[castle_row[white_to_move]][4]+:`PIECE_WIDTH] <= `EMPTY_POSN;
              board_ram_wr[idx[castle_row[white_to_move]][7]+:`PIECE_WIDTH] <= `EMPTY_POSN;
              board_ram_wr[idx[castle_row[white_to_move]][5]+:`PIECE_WIDTH] <= (black_to_move << `BLACK_BIT) | `PIECE_ROOK;
              board_ram_wr[idx[castle_row[white_to_move]][6]+:`PIECE_WIDTH] <= (black_to_move << `BLACK_BIT) | `PIECE_KING;
              capture_ram_wr <= 0;
              if (castle_short_legal[white_to_move])
                ram_wr <= 1;
              state <= STATE_CASTLE_LONG;
           end
         STATE_CASTLE_LONG :
           begin
              board_ram_wr <= board;
              board_ram_wr[idx[castle_row[white_to_move]][0]+:`PIECE_WIDTH] <= `EMPTY_POSN;
              board_ram_wr[idx[castle_row[white_to_move]][1]+:`PIECE_WIDTH] <= `EMPTY_POSN;
              board_ram_wr[idx[castle_row[white_to_move]][4]+:`PIECE_WIDTH] <= `EMPTY_POSN;
              board_ram_wr[idx[castle_row[white_to_move]][3]+:`PIECE_WIDTH] <= (black_to_move << `BLACK_BIT) | `PIECE_ROOK;
              board_ram_wr[idx[castle_row[white_to_move]][2]+:`PIECE_WIDTH] <= (black_to_move << `BLACK_BIT) | `PIECE_KING;
              capture_ram_wr <= 0;
              if (castle_long_legal[white_to_move])
                ram_wr <= 1;
              else
                ram_wr <= 0;
              state <= STATE_ALL_MOVES_DONE;
           end
         STATE_ALL_MOVES_DONE :
           begin
              ram_wr <= 0;
              capture_ram_wr <= 0;
              if (ram_wr_addr == 0)
                state <= STATE_DONE; // no moves
              legal_ram_wr_addr_init <= 1;
              ram_rd_addr <= 0;
              state <= STATE_LEGAL_INIT;
           end
         STATE_LEGAL_INIT :
           begin
              legal_ram_wr_addr_init <= 0;
              attack_test_move_count <= ram_wr_addr;
              state <= STATE_LEGAL_LOAD;
           end
         STATE_LEGAL_LOAD :
           begin
              {attack_test_capture, attack_test_en_passant_col, attack_test_castle_mask, attack_test_white_to_move, attack_test_board} <= ram_rd_data;
              attack_test_valid <= 0;
              clear_eval <= 0;
              clear_attack <= 0;
              state <= STATE_LEGAL_KING_POS;
           end
         STATE_LEGAL_KING_POS :
           begin
              if (attack_test_board[idx[0][0]+:`PIECE_WIDTH] != `WHITE_ROOK || attack_test_board[idx[0][4]+:`PIECE_WIDTH] != `WHITE_KING)
                attack_test_castle_mask[`CASTLE_WHITE_LONG] <= 1'b0;
              if (attack_test_board[idx[0][7]+:`PIECE_WIDTH] != `WHITE_ROOK || attack_test_board[idx[0][4]+:`PIECE_WIDTH] != `WHITE_KING)
                attack_test_castle_mask[`CASTLE_WHITE_SHORT] <= 1'b0;
              if (attack_test_board[idx[7][0]+:`PIECE_WIDTH] != `BLACK_ROOK || attack_test_board[idx[7][4]+:`PIECE_WIDTH] != `BLACK_KING)
                attack_test_castle_mask[`CASTLE_BLACK_LONG] <= 1'b0;
              if (attack_test_board[idx[7][7]+:`PIECE_WIDTH] != `BLACK_ROOK || attack_test_board[idx[7][4]+:`PIECE_WIDTH] != `BLACK_KING)
                attack_test_castle_mask[`CASTLE_BLACK_SHORT] <= 1'b0;
              attack_test <= attack_test_board;
              attack_test_valid <= 1;
              ram_rd_addr <= ram_rd_addr + 1;
              state <= STATE_ATTACK_WAIT;
           end
         STATE_ATTACK_WAIT :
           begin
              attack_test_valid <= 0;
              attack_test_white_in_check <= white_in_check;
              attack_test_black_in_check <= black_in_check;
              attack_test_white_is_attacking <= white_is_attacking;
              attack_test_black_is_attacking <= black_is_attacking;
              if (is_attacking_done && eval_valid)
                if ((white_to_move && white_in_check) || (black_to_move && black_in_check))
                  state <= STATE_LEGAL_NEXT;
                else
                  state <= STATE_LEGAL_MOVE;
           end
         STATE_LEGAL_MOVE :
           begin
              legal_board_ram_wr <= attack_test_board;
              legal_en_passant_col_ram_wr <= attack_test_en_passant_col;
              legal_castle_mask_ram_wr <= attack_test_castle_mask;
              legal_white_to_move_ram_wr <= attack_test_white_to_move;
              legal_capture_ram_wr <= attack_test_capture;
              legal_white_in_check_ram_wr <= attack_test_white_in_check;
              legal_black_in_check_ram_wr <= attack_test_black_in_check;
              legal_white_is_attacking_ram_wr <= attack_test_white_is_attacking;
              legal_black_is_attacking_ram_wr <= attack_test_black_is_attacking;
              legal_eval_ram_wr <= eval;
              legal_ram_wr <= 1;
              clear_eval <= 1;
              clear_attack <= 1;
              state <= STATE_LEGAL_NEXT;
           end
         STATE_LEGAL_NEXT :
           begin
              legal_ram_wr <= 0;
              clear_eval <= 1;
              clear_attack <= 1;
              if (ram_rd_addr == attack_test_move_count)
                state <= STATE_DONE;
              else
                state <= STATE_LEGAL_LOAD;
           end
         STATE_DONE :
           begin
              clear_eval <= 0;
              clear_attack <= 0;
              if (move_count == 0)
                begin
                   if (initial_board_check)
                     if (white_to_move)
                       initial_eval <= -(`GLOBAL_VALUE_KING); // white mated
                     else
                       initial_eval <= `GLOBAL_VALUE_KING; // black mated
                   else
                     initial_eval <= 0; // stalemate
                   initial_mate <= initial_board_check;
                   initial_stalemate <= ~initial_board_check;
                end
              else
                begin
                   initial_mate <= 0;
                   initial_stalemate <= 0;
                end
              moves_ready <= 1;
              if (clear_moves)
                state <= STATE_IDLE;
           end
         default :
           state <= STATE_IDLE;
       endcase

   /* board_attack AUTO_TEMPLATE (
    .board (attack_test[]),
    .board_valid (attack_test_valid),
    );*/
   board_attack #
     (
      .DO_DISPLAY (0)
      )
   board_attack
     (/*AUTOINST*/
      // Outputs
      .is_attacking_done                (is_attacking_done),
      .white_is_attacking               (white_is_attacking[63:0]),
      .black_is_attacking               (black_is_attacking[63:0]),
      .white_in_check                   (white_in_check),
      .black_in_check                   (black_in_check),
      .display_attacking_done           (display_attacking_done),
      // Inputs
      .reset                            (reset),
      .clk                              (clk),
      .board                            (attack_test[`BOARD_WIDTH-1:0]), // Templated
      .board_valid                      (attack_test_valid),     // Templated
      .clear_attack                     (clear_attack));

   /* evaluate AUTO_TEMPLATE (
    .board_in (attack_test[]),
    .board_valid (attack_test_valid),
    );*/
   evaluate #
     (
      .EVAL_WIDTH (EVAL_WIDTH)
      )
   evaluate
     (/*AUTOINST*/
      // Outputs
      .eval                             (eval[EVAL_WIDTH-1:0]),
      .eval_valid                       (eval_valid),
      // Inputs
      .clk                              (clk),
      .reset                            (reset),
      .board_valid                      (attack_test_valid),     // Templated
      .board_in                         (attack_test[`BOARD_WIDTH-1:0]), // Templated
      .clear_eval                       (clear_eval));

endmodule

// Local Variables:
// verilog-auto-inst-param-value:t
// verilog-library-directories:(
//     "."
//     )
// End:

