// Copyright (c) 2025 Stacey Campbell
// SPDX-License-Identifier: MIT

`include "numbat.vh"

module checkmate #
  (
   parameter MAX_POSITIONS_LOG2 = $clog2(`MAX_POSITIONS)
   )
   (
    input                      clk,
    input                      reset,

    input                      board_valid_in,
    input [`BOARD_WIDTH - 1:0] board_in,
    input                      white_to_move_in,
    input [3:0]                en_passant_col_in,

    input                      clear,

    output reg                 checkmate_out,
    output reg                 checkmate_valid_out
    );

   always @(posedge clk)
     begin
        checkmate_out <= 0;
        checkmate_valid_out <= 1;
     end

//   localparam INITIAL_WIDTH = `BOARD_WIDTH + 4 + 4 + 1;
//   localparam RAM_WIDTH = 6 + 6 + INITIAL_WIDTH + 1 + 1;
//
//   reg [RAM_WIDTH - 1:0]       move_ram [0:`MAX_POSITIONS - 1];
//   reg [RAM_WIDTH - 1:0]       ram_rd_data;
//   reg 			       ram_wr_addr_init;
//   reg [MAX_POSITIONS_LOG2 - 1:0] ram_wr_addr, ram_rd_addr;
//   reg [MAX_POSITIONS_LOG2 - 1:0] attack_test_move_count;
//   reg [$clog2(`BOARD_WIDTH) - 1:0] idx [0:7][0:7];
//   reg [`PIECE_WIDTH - 1:0]         piece;
//   reg [`BOARD_WIDTH - 1:0]         board;
//   reg 				    white_to_move;
//   reg [3:0]                        en_passant_col;
//   reg 				    board_valid_in_z;
//
//   reg [`BOARD_WIDTH - 1:0]         board_ram_wr;
//   reg [3:0]                        en_passant_col_ram_wr;
//   reg 				    white_to_move_ram_wr;
//   reg 				    ram_wr;
//
//   reg [`BOARD_WIDTH - 1:0]         attack_test_board;
//   reg [3:0]                        attack_test_en_passant_col;
//   reg 				    attack_test_white_to_move;
//
//   reg 				    clear_attack = 0;
//
//   reg signed [3:0]                 row, col;
//   reg signed [3:0]                 col_r, row_r; // one clock delayed, for timing/fanout, be careful using this
//
//   reg signed [1:0]                 slider_offset_col [`PIECE_QUEN:`PIECE_BISH][0:7];
//   reg signed [1:0]                 slider_offset_row [`PIECE_QUEN:`PIECE_BISH][0:7];
//   reg [3:0]                        slider_offset_count [`PIECE_QUEN:`PIECE_BISH];
//   reg [3:0]                        slider_index;
//   reg signed [4:0]                 slider_row, slider_col;
//
//   reg signed [2:0]                 discrete_offset_col[`PIECE_KNIT:`PIECE_KING][0:7];
//   reg signed [2:0]                 discrete_offset_row[`PIECE_KNIT:`PIECE_KING][0:7];
//   reg [3:0]                        discrete_index;
//   reg signed [4:0]                 discrete_row, discrete_col;
//
//   reg signed [1:0]                 pawn_advance [0:1];
//   reg signed [4:0]                 pawn_promote_row [0:1];
//   reg signed [4:0]                 pawn_init_row [0:1];
//   reg signed [4:0]                 pawn_row_adv1, pawn_col_adv1;
//   reg signed [4:0]                 pawn_row_adv2, pawn_col_adv2;
//   reg signed [4:0]                 pawn_row_cap_left, pawn_col_cap_left;
//   reg signed [4:0]                 pawn_row_cap_right, pawn_col_cap_right;
//   reg [`PIECE_WIDTH - 1:0]         pawn_promotions [0:3];
//   reg [2:0]                        pawn_adv1_mask;
//   reg 				    pawn_adv2;
//   reg [1:0]                        pawn_en_passant_mask;
//   reg signed [4:0]                 pawn_en_passant_row [0:1];
//   reg 				    pawn_en_passant_count;
//   reg [1:0]                        pawn_move_count;
//   reg [1:0]                        pawn_promotion_count;
//   reg 				    pawn_do_init;
//   reg 				    pawn_do_en_passant;
//   reg 				    pawn_do_promote;
//
//   reg [63:0]                       square_active;
//
//   reg 				    checkmate_provisional = 0;
//   
//   reg [`BOARD_WIDTH - 1:0]         evaluate_board, evaluate_board_r; // registered for timing and fanout
//   reg 				    evaluate_go, evaluate_go_r;
//
//   // should be empty
//   /*AUTOREGINPUT*/
//
//   /*AUTOWIRE*/
//   // Beginning of automatic wires (for undeclared instantiated-module outputs)
//   wire                 black_in_check;         // From board_attack of board_attack.v
//   wire                 is_attacking_done;      // From board_attack of board_attack.v
//   wire                 white_in_check;         // From board_attack of board_attack.v
//   // End of automatics
//
//   wire signed [4:0]                pawn_adv1_row [0:2];
//   wire signed [4:0]                pawn_adv1_col [0:2];
//   wire signed [4:0]                pawn_enp_row[0:1];
//
//   integer 			    i, x, y, ri, s;
//
//   wire 			    black_to_move = ~white_to_move;
//
//   initial
//     begin
//        for (y = 0; y < 8; y = y + 1)
//          begin
//             ri = y * `SIDE_WIDTH;
//             for (x = 0; x < 8; x = x + 1)
//               idx[y][x] = ri + x * `PIECE_WIDTH;
//          end
//
//        pawn_advance[0] = -1; // black to move
//        pawn_advance[1] =  1; // white to move
//        pawn_promote_row[0] = 1; // black to move
//        pawn_promote_row[1] = 6; // white to move
//        pawn_init_row[0] = 6; // black to move
//        pawn_init_row[1] = 1; // white to move
//        pawn_en_passant_row[0] = 3; // black to move
//        pawn_en_passant_row[1] = 4; // white to move
//
//        pawn_promotions[0] = `PIECE_QUEN;
//        pawn_promotions[1] = `PIECE_BISH;
//        pawn_promotions[2] = `PIECE_ROOK;
//        pawn_promotions[3] = `PIECE_KNIT;
//
//        // avoid driver warnings in vivado
//        for (ri = `PIECE_QUEN; ri <= `PIECE_BISH; ri = ri + 1)
//          for (x = 0; x < 8; x = x + 1)
//            begin
//               slider_offset_row[ri][x] = 0;
//               slider_offset_col[ri][x] = 0;
//            end
//
//        slider_offset_count[`PIECE_QUEN] = 8;
//        ri = 0;
//        for (y = -1; y <= +1; y = y + 1)
//          for (x = -1; x <= +1; x = x + 1)
//            if (! (y == 0 && x == 0))
//              begin
//                 slider_offset_row[`PIECE_QUEN][ri] = y;
//                 slider_offset_col[`PIECE_QUEN][ri] = x;
//                 ri = ri + 1;
//              end
//
//        slider_offset_count[`PIECE_ROOK] = 4;
//        slider_offset_row[`PIECE_ROOK][0] = 0; slider_offset_col[`PIECE_ROOK][0] = +1;
//        slider_offset_row[`PIECE_ROOK][1] = 0; slider_offset_col[`PIECE_ROOK][1] = -1;
//        slider_offset_row[`PIECE_ROOK][2] = +1; slider_offset_col[`PIECE_ROOK][2] = 0;
//        slider_offset_row[`PIECE_ROOK][3] = -1; slider_offset_col[`PIECE_ROOK][3] = 0;
//
//        slider_offset_count[`PIECE_BISH] = 4;
//        slider_offset_row[`PIECE_BISH][0] = +1; slider_offset_col[`PIECE_BISH][0] = +1;
//        slider_offset_row[`PIECE_BISH][1] = +1; slider_offset_col[`PIECE_BISH][1] = -1;
//        slider_offset_row[`PIECE_BISH][2] = -1; slider_offset_col[`PIECE_BISH][2] = +1;
//        slider_offset_row[`PIECE_BISH][3] = -1; slider_offset_col[`PIECE_BISH][3] = -1;
//
//        discrete_offset_row[`PIECE_KNIT][0] = -2; discrete_offset_col[`PIECE_KNIT][0] = -1;
//        discrete_offset_row[`PIECE_KNIT][1] = -1; discrete_offset_col[`PIECE_KNIT][1] = -2;
//        discrete_offset_row[`PIECE_KNIT][2] =  1; discrete_offset_col[`PIECE_KNIT][2] = -2;
//        discrete_offset_row[`PIECE_KNIT][3] =  2; discrete_offset_col[`PIECE_KNIT][3] = -1;
//        discrete_offset_row[`PIECE_KNIT][4] =  2; discrete_offset_col[`PIECE_KNIT][4] =  1;
//        discrete_offset_row[`PIECE_KNIT][5] =  1; discrete_offset_col[`PIECE_KNIT][5] =  2;
//        discrete_offset_row[`PIECE_KNIT][6] = -1; discrete_offset_col[`PIECE_KNIT][6] =  2;
//        discrete_offset_row[`PIECE_KNIT][7] = -2; discrete_offset_col[`PIECE_KNIT][7] =  1;
//
//        ri = 0;
//        for (y = -1; y <= +1; y = y + 1)
//          for (x = -1; x <= +1; x = x + 1)
//            if (! (y == 0 && x == 0))
//              begin
//                 discrete_offset_row[`PIECE_KING][ri] = y;
//                 discrete_offset_col[`PIECE_KING][ri] = x;
//                 ri = ri + 1;
//              end
//     end
//
//   always @(posedge clk)
//     begin
//        ram_rd_data <= move_ram[ram_rd_addr];
//        if (ram_wr_addr_init)
//          ram_wr_addr <= 0;
//        if (ram_wr)
//          begin
//             move_ram[ram_wr_addr] <= {en_passant_col_ram_wr, white_to_move_ram_wr, board_ram_wr};
//             ram_wr_addr <= ram_wr_addr + 1;
//          end
//     end
//
//   assign pawn_enp_row[0] = pawn_row_cap_left;
//   assign pawn_enp_row[1] = pawn_row_cap_right;
//
//   assign pawn_adv1_row[0] = pawn_row_cap_left;
//   assign pawn_adv1_row[1] = pawn_row_adv1;
//   assign pawn_adv1_row[2] = pawn_row_cap_right;
//   assign pawn_adv1_col[0] = pawn_col_cap_left;
//   assign pawn_adv1_col[1] = pawn_col_adv1;
//   assign pawn_adv1_col[2] = pawn_col_cap_right;
//
//   always @(posedge clk)
//     begin
//	board_valid_in_z <= board_valid_in;
//	
//        piece <= board[idx[row][col]+:`PIECE_WIDTH];
//
//        col_r <= col;
//        row_r <= row;
//
//        evaluate_board_r <= evaluate_board;
//        evaluate_go_r <= evaluate_go;
//
//        white_to_move_ram_wr <= ~white_to_move;
//
//        // free-run these for timing, only valid when used in states
//        pawn_row_adv1 <= row + pawn_advance[white_to_move];
//        pawn_col_adv1 <= col_r;
//        pawn_row_adv2 <= row + pawn_advance[white_to_move] * 2;
//        pawn_col_adv2 <= col_r;
//        pawn_row_cap_left <= row + pawn_advance[white_to_move];
//        pawn_col_cap_left <= col_r - 1;
//        pawn_row_cap_right <= row + pawn_advance[white_to_move];
//        pawn_col_cap_right <= col_r + 1;
//        for (i = 0; i < 4; i = i + 1)
//          pawn_promotions[i][`BLACK_BIT] <= black_to_move;
//
//        pawn_adv1_mask[0] <= pawn_col_cap_left >= 0 &&
//                             board[idx[pawn_row_cap_left[2:0]][pawn_col_cap_left[2:0]]+:`PIECE_WIDTH] != `EMPTY_POSN && // can't be empty, and
//                             board[idx[pawn_row_cap_left[2:0]][pawn_col_cap_left[2:0]] + `BLACK_BIT] != black_to_move; // contains opponent's piece
//        pawn_adv1_mask[1] <= board[idx[pawn_row_adv1[2:0]][pawn_col_adv1[2:0]]+:`PIECE_WIDTH] == `EMPTY_POSN;
//        pawn_adv1_mask[2] <= pawn_col_cap_right <= 7 &&
//                             board[idx[pawn_row_cap_right[2:0]][pawn_col_cap_right[2:0]]+:`PIECE_WIDTH] != `EMPTY_POSN && // can't be empty, and
//                             board[idx[pawn_row_cap_right[2:0]][pawn_col_cap_right[2:0]] + `BLACK_BIT] != black_to_move; // contains opponent's piece
//        pawn_adv2 <= board[idx[pawn_row_adv1[2:0]][pawn_col_adv1[2:0]]+:`PIECE_WIDTH] == `EMPTY_POSN &&
//                     board[idx[pawn_row_adv2[2:0]][pawn_col_adv2[2:0]]+:`PIECE_WIDTH] == `EMPTY_POSN;
//
//        pawn_en_passant_mask[0] <= en_passant_col[`EN_PASSANT_VALID_BIT] &&
//                                   pawn_col_cap_left >= 0 &&
//                                   en_passant_col[2:0] == pawn_col_cap_left[2:0];
//        pawn_en_passant_mask[1] <= en_passant_col[`EN_PASSANT_VALID_BIT] &&
//                                   pawn_col_cap_right <= 7 &&
//                                   en_passant_col[2:0] == pawn_col_cap_right[2:0];
//        pawn_do_init <= row == pawn_init_row[white_to_move];
//        pawn_do_en_passant <= row == pawn_en_passant_row[white_to_move];
//        pawn_do_promote <= row == pawn_promote_row[white_to_move];
//     end
//
//   localparam STATE_IDLE = 0;
//   localparam STATE_INIT = 1;
//   localparam STATE_FIND_PIECE = 2;
//   localparam STATE_DO_SQUARE = 3;
//   localparam STATE_SLIDER_INIT = 4;
//   localparam STATE_SLIDER = 5;
//   localparam STATE_DISCRETE_INIT = 6;
//   localparam STATE_DISCRETE = 7;
//   localparam STATE_PAWN_INIT_0 = 8;
//   localparam STATE_PAWN_INIT_1 = 9;
//   localparam STATE_PAWN_ROW_1 = 10;
//   localparam STATE_PAWN_ROW_4 = 11;
//   localparam STATE_PAWN_ROW_6 = 12;
//   localparam STATE_PAWN_ADVANCE = 13;
//   localparam STATE_NEXT = 14;
//   localparam STATE_ALL_MOVES_DONE = 15;
//   localparam STATE_LEGAL_INIT = 16;
//   localparam STATE_LEGAL_LOAD = 17;
//   localparam STATE_LEGAL_KING_POS = 18;
//   localparam STATE_ATTACK_WAIT = 19;
//   localparam STATE_LEGAL_MOVE = 20;
//   localparam STATE_LEGAL_NEXT = 21;
//   localparam STATE_DONE = 22;
//
//   reg [4:0] state = STATE_IDLE;
//
//   always @(posedge clk)
//     if (reset)
//       state <= STATE_IDLE;
//     else
//       case (state)
//         STATE_IDLE :
//           begin
//	      checkmate_out <= 0;
//	      checkmate_valid_out <= 0;
//	      
//              board <= board_in;
//              white_to_move <= white_to_move_in;
//              en_passant_col <= en_passant_col_in;
//
//              evaluate_go <= 0;
//              clear_attack <= 0;
//	      checkmate_provisional <= 1; // will be cleared if a legal move found
//	      
//              ram_wr_addr_init <= 1;
//
//              if (board_valid_in && ~board_valid_in_z)
//                state <= STATE_INIT;
//           end
//         STATE_INIT :
//           begin
//              // bitmask of all potentially moveable pieces
//              for (s = 0; s < 64; s = s + 1)
//                square_active[s] <= board[s * `PIECE_WIDTH+:`PIECE_WIDTH] != `EMPTY_POSN && // square not empty
//                       board[s * `PIECE_WIDTH + `BLACK_BIT] == black_to_move; // my piece
//              clear_attack <= 1;
//              evaluate_go <= 0;
//              ram_wr_addr_init <= 0;
//              ram_wr <= 0;
//              state <= STATE_FIND_PIECE;
//           end
//         STATE_FIND_PIECE :
//           begin
//              for (s = 63; s >= 0; s = s - 1)
//                if (square_active[s])
//                  begin
//                     row <= s >> 3;
//                     col <= s & 7;
//                  end
//              if (square_active == 64'b0)
//                state <= STATE_ALL_MOVES_DONE;
//              else
//                state <= STATE_DO_SQUARE;
//           end
//         STATE_DO_SQUARE :
//           begin
//              clear_attack <= 0;
//              en_passant_col_ram_wr <= 4'b0;
//              slider_index <= 0;
//              if (board[idx[row][col]+:`PIECE_WIDTH - 1] == `PIECE_QUEN ||
//                  board[idx[row][col]+:`PIECE_WIDTH - 1] == `PIECE_ROOK ||
//                  board[idx[row][col]+:`PIECE_WIDTH - 1] == `PIECE_BISH)
//                state <= STATE_SLIDER_INIT;
//              else if (board[idx[row][col]+:`PIECE_WIDTH - 1] == `PIECE_KNIT ||
//                       board[idx[row][col]+:`PIECE_WIDTH - 1] == `PIECE_KING)
//                state <= STATE_DISCRETE_INIT;
//              else
//                state <= STATE_PAWN_INIT_0; // must be a pawn
//           end
//         STATE_SLIDER_INIT :
//           begin
//              ram_wr <= 0;
//              if (slider_index < slider_offset_count[piece[`BLACK_BIT - 1:0]])
//                begin
//                   slider_row <= row_r + slider_offset_row[piece[`BLACK_BIT - 1:0]][slider_index];
//                   slider_col <= col_r + slider_offset_col[piece[`BLACK_BIT - 1:0]][slider_index];
//                   state <= STATE_SLIDER;
//                end
//              else
//                state <= STATE_NEXT;
//           end
//         STATE_SLIDER :
//           begin
//              board_ram_wr <= board;
//              board_ram_wr[idx[row_r][col_r]+:`PIECE_WIDTH] <= `EMPTY_POSN;
//              board_ram_wr[idx[slider_row[2:0]][slider_col[2:0]]+:`PIECE_WIDTH] <= piece;
//              if ((slider_row >= 0 && slider_row <= 7 && slider_col >= 0 && slider_col <= 7) &&
//                  (board[idx[slider_row[2:0]][slider_col[2:0]]+:`PIECE_WIDTH] == `EMPTY_POSN || // empty square
//                   board[idx[slider_row[2:0]][slider_col[2:0]] + `BLACK_BIT] != black_to_move)) // opponent's piece
//                begin
//                   ram_wr <= 1;
//                   slider_row <= slider_row + slider_offset_row[piece[`BLACK_BIT - 1:0]][slider_index];
//                   slider_col <= slider_col + slider_offset_col[piece[`BLACK_BIT - 1:0]][slider_index];
//                   if (board[idx[slider_row[2:0]][slider_col[2:0]]+:`PIECE_WIDTH] != `EMPTY_POSN)
//                     begin
//                        slider_index <= slider_index + 1;
//                        state <= STATE_SLIDER_INIT;
//                     end
//                end
//              else
//                begin
//                   ram_wr <= 0;
//                   slider_index <= slider_index + 1;
//                   state <= STATE_SLIDER_INIT;
//                end
//           end
//         STATE_DISCRETE_INIT :
//           begin
//              discrete_index <= 1;
//              discrete_row <= row_r + discrete_offset_row[piece[`BLACK_BIT - 1:0]][0];
//              discrete_col <= col_r + discrete_offset_col[piece[`BLACK_BIT - 1:0]][0];
//              state <= STATE_DISCRETE;
//           end
//         STATE_DISCRETE :
//           begin
//              board_ram_wr <= board;
//              board_ram_wr[idx[row_r][col_r]+:`PIECE_WIDTH] <= `EMPTY_POSN;
//              board_ram_wr[idx[discrete_row[2:0]][discrete_col[2:0]]+:`PIECE_WIDTH] <= piece;
//              if (discrete_row >= 0 && discrete_row <= 7 && discrete_col >= 0 && discrete_col <= 7 &&
//                  (board[idx[discrete_row[2:0]][discrete_col[2:0]]+:`PIECE_WIDTH] == `EMPTY_POSN || // empty square
//                   board[idx[discrete_row[2:0]][discrete_col[2:0]] + `BLACK_BIT] != black_to_move)) // opponent's piece
//                ram_wr <= 1;
//              else
//                ram_wr <= 0;
//              discrete_index <= discrete_index + 1;
//              discrete_row <= row_r + discrete_offset_row[piece[`BLACK_BIT - 1:0]][discrete_index];
//              discrete_col <= col_r + discrete_offset_col[piece[`BLACK_BIT - 1:0]][discrete_index];
//              if (discrete_index == 8)
//                state <= STATE_NEXT;
//           end
//         STATE_PAWN_INIT_0 : // wait state
//           state <= STATE_PAWN_INIT_1;
//         STATE_PAWN_INIT_1 :
//           begin
//              pawn_en_passant_count <= 0;
//              pawn_move_count <= 0;
//              pawn_promotion_count <= 0;
//              if (pawn_do_init)
//                state <= STATE_PAWN_ROW_1;
//              else if (pawn_do_en_passant)
//                state <= STATE_PAWN_ROW_4;
//              else if (pawn_do_promote)
//                state <= STATE_PAWN_ROW_6;
//              else
//                state <= STATE_PAWN_ADVANCE;
//           end
//         STATE_PAWN_ROW_1 : // initial pawn
//           begin
//              board_ram_wr <= board;
//              en_passant_col_ram_wr <= (1 << `EN_PASSANT_VALID_BIT) | pawn_col_adv2[2:0];
//              board_ram_wr[idx[row_r[2:0]][col_r[2:0]]+:`PIECE_WIDTH] <= `EMPTY_POSN;
//              board_ram_wr[idx[pawn_row_adv2[2:0]][pawn_col_adv2[2:0]]+:`PIECE_WIDTH] <= piece;
//              if (pawn_adv2)
//                ram_wr <= 1;
//              state <= STATE_PAWN_ADVANCE;
//           end
//         STATE_PAWN_ROW_4 : // en passant pawn
//           begin
//              board_ram_wr <= board;
//              board_ram_wr[idx[row_r[2:0]][col_r[2:0]]+:`PIECE_WIDTH] <= `EMPTY_POSN;
//              board_ram_wr[idx[row_r[2:0]][en_passant_col[2:0]]+:`PIECE_WIDTH] <= `EMPTY_POSN;
//              board_ram_wr[idx[pawn_enp_row[pawn_en_passant_count][2:0]][en_passant_col[2:0]]+:`PIECE_WIDTH] <= piece;
//              if (pawn_en_passant_mask[pawn_en_passant_count])
//                begin
//                   ram_wr <= 1;
//                   state <= STATE_PAWN_ADVANCE;
//                end
//              pawn_en_passant_count <= pawn_en_passant_count + 1;
//              if (pawn_en_passant_count == 1)
//                state <= STATE_PAWN_ADVANCE;
//           end
//         STATE_PAWN_ROW_6 : // promotion pawn
//           begin
//              board_ram_wr <= board;
//              board_ram_wr[idx[row_r[2:0]][col_r[2:0]]+:`PIECE_WIDTH] <= `EMPTY_POSN;
//              board_ram_wr[idx[pawn_adv1_row[pawn_move_count][2:0]][pawn_adv1_col[pawn_move_count][2:0]]+:`PIECE_WIDTH]
//                <= pawn_promotions[pawn_promotion_count];
//              if (pawn_adv1_mask[pawn_move_count])
//                ram_wr <= 1;
//              else
//                ram_wr <= 0;
//              if (pawn_promotion_count == 3)
//                begin
//                   pawn_promotion_count <= 0;
//                   pawn_move_count <= pawn_move_count + 1;
//                   if (pawn_move_count == 2)
//                     state <= STATE_NEXT;
//                end
//              else
//                pawn_promotion_count <= pawn_promotion_count + 1;
//           end
//         STATE_PAWN_ADVANCE : // default pawn moves
//           begin
//              en_passant_col_ram_wr <= 0 << `EN_PASSANT_VALID_BIT;
//              board_ram_wr <= board;
//              board_ram_wr[idx[row_r[2:0]][col_r[2:0]]+:`PIECE_WIDTH] <= `EMPTY_POSN;
//              board_ram_wr[idx[pawn_adv1_row[pawn_move_count][2:0]][pawn_adv1_col[pawn_move_count][2:0]]+:`PIECE_WIDTH] <= piece;
//              if (pawn_adv1_mask[pawn_move_count])
//                ram_wr <= 1;
//              else
//                ram_wr <= 0;
//              pawn_move_count <= pawn_move_count + 1;
//              if (pawn_move_count == 2)
//                state <= STATE_NEXT;
//           end
//         STATE_NEXT :
//           begin
//              ram_wr <= 0;
//              square_active[{row[2:0], col[2:0]}] <= 1'b0;
//              state <= STATE_FIND_PIECE;
//           end
//         STATE_ALL_MOVES_DONE :
//           begin
//              ram_wr <= 0;
//              ram_rd_addr <= 0;
//              if (ram_wr_addr == 0)
//                state <= STATE_DONE; // no moves, mate
//	      else
//		state <= STATE_LEGAL_INIT;
//           end
//         STATE_LEGAL_INIT :
//           begin
//              attack_test_move_count <= ram_wr_addr;
//              state <= STATE_LEGAL_LOAD;
//           end
//         STATE_LEGAL_LOAD :
//           begin
//              {attack_test_en_passant_col, attack_test_white_to_move, attack_test_board} <= ram_rd_data;
//              evaluate_go <= 0;
//              clear_attack <= 0;
//              state <= STATE_LEGAL_KING_POS;
//           end
//         STATE_LEGAL_KING_POS :
//           begin
//              evaluate_board <= attack_test_board;
//              evaluate_go <= 1;
//
//              ram_rd_addr <= ram_rd_addr + 1;
//              state <= STATE_ATTACK_WAIT;
//           end
//         STATE_ATTACK_WAIT :
//           begin
//              evaluate_go <= 0;
//              if (is_attacking_done)
//                if ((white_to_move && white_in_check) || (black_to_move && black_in_check))
//                  state <= STATE_LEGAL_NEXT;
//                else
//		  begin
//		     checkmate_provisional <= 0;
//                     state <= STATE_DONE; // at least one legal move, no checkmate
//		  end
//           end
//         STATE_LEGAL_NEXT :
//           begin
//              clear_attack <= 1;
//              if (ram_rd_addr == attack_test_move_count)
//                state <= STATE_DONE;
//              else
//                state <= STATE_LEGAL_LOAD;
//           end
//         STATE_DONE :
//           begin
//              clear_attack <= 0;
//	      checkmate_out <= checkmate_provisional;
//              checkmate_valid_out <= 1;
//              if (clear)
//                state <= STATE_IDLE;
//           end
//         default :
//           state <= STATE_IDLE;
//       endcase
//
//   /* board_attack AUTO_TEMPLATE (
//    .board (evaluate_board_r[]),
//    .board_valid (evaluate_go_r),
//    .attack_white_pop (),
//    .attack_black_pop (),
//    .white_is_attacking (),
//    .black_is_attacking (),
//    );*/
//   board_attack board_attack
//     (/*AUTOINST*/
//      // Outputs
//      .is_attacking_done                (is_attacking_done),
//      .white_is_attacking               (),                      // Templated
//      .black_is_attacking               (),                      // Templated
//      .white_in_check                   (white_in_check),
//      .black_in_check                   (black_in_check),
//      .attack_white_pop                 (),                      // Templated
//      .attack_black_pop                 (),                      // Templated
//      // Inputs
//      .reset                            (reset),
//      .clk                              (clk),
//      .board                            (evaluate_board_r[`BOARD_WIDTH-1:0]), // Templated
//      .board_valid                      (evaluate_go_r),         // Templated
//      .clear_attack                     (clear_attack));

endmodule

// Local Variables:
// verilog-auto-inst-param-value:t
// verilog-library-directories:(
//     "."
//     )
// End:

