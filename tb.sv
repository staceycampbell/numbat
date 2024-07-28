`include "vchess.vh"

module tb;

   localparam PIECE_WIDTH = `PIECE_BITS;
   localparam SIDE_WIDTH = PIECE_WIDTH * 8;
   localparam BOARD_WIDTH = PIECE_WIDTH * 8 * 8;

   reg clk = 0;
   reg reset = 1;
   integer t = 0;
   integer i;

   reg [BOARD_WIDTH - 1:0] board;
   reg                     board_valid = 0;
   reg                     white_to_move = 1;
   reg [3:0]               castle_mask = 4'b1111;
   reg                     clear_moves = 1'b0;
   reg [3:0]               en_passant_col = 4'b1000;
   reg [($clog2(`MAX_POSITIONS))-1:0] move_index = 0;

   // should be empty
   /*AUTOREGINPUT*/

   /*AUTOWIRE*/
   // Beginning of automatic wires (for undeclared instantiated-module outputs)
   wire                 black_in_check;         // From vchess of vchess.v
   wire [63:0]          black_is_attacking;     // From vchess of vchess.v
   wire [BOARD_WIDTH-1:0] board_out;            // From all_moves_initial of all_moves.v
   wire [3:0]           castle_mask_out;        // From all_moves_initial of all_moves.v
   wire                 display_attacking_done; // From vchess of vchess.v
   wire [3:0]           en_passant_col_out;     // From all_moves_initial of all_moves.v
   wire                 is_attacking_done;      // From vchess of vchess.v
   wire [($clog2(`MAX_POSITIONS))-1:0] move_count;// From all_moves_initial of all_moves.v
   wire                 moves_ready;            // From all_moves_initial of all_moves.v
   wire                 white_in_check;         // From vchess of vchess.v
   wire [63:0]          white_is_attacking;     // From vchess of vchess.v
   wire                 white_to_move_out;      // From all_moves_initial of all_moves.v
   // End of automatics

   initial
     begin
        $dumpfile("wave.vcd");
        $dumpvars(0, tb);
        for (i = 0; i < 64; i = i + 1)
          board[i * PIECE_WIDTH+:PIECE_WIDTH] = `EMPTY_POSN;
        // board[1 * SIDE_WIDTH + 4 * PIECE_WIDTH+:PIECE_WIDTH] = `WHITE_ROOK;
        board[1 * SIDE_WIDTH + 7 * PIECE_WIDTH+:PIECE_WIDTH] = `BLACK_ROOK;
        board[7 * SIDE_WIDTH + 7 * PIECE_WIDTH+:PIECE_WIDTH] = `BLACK_QUEN;
        // board[3 * SIDE_WIDTH + 4 * PIECE_WIDTH+:PIECE_WIDTH] = `BLACK_PAWN;
        // board[4 * SIDE_WIDTH + 5 * PIECE_WIDTH+:PIECE_WIDTH] = `BLACK_PAWN;
        // board[4 * SIDE_WIDTH + 3 * PIECE_WIDTH+:PIECE_WIDTH] = `WHITE_PAWN;
        // board[3 * SIDE_WIDTH + 5 * PIECE_WIDTH+:PIECE_WIDTH] = `WHITE_PAWN;
        board[0 * SIDE_WIDTH + 0 * PIECE_WIDTH+:PIECE_WIDTH] = `WHITE_KING;
        board[1 * SIDE_WIDTH + 1 * PIECE_WIDTH+:PIECE_WIDTH] = `WHITE_ROOK;
        board[7 * SIDE_WIDTH + 1 * PIECE_WIDTH+:PIECE_WIDTH] = `BLACK_KING;
        if (0)
          begin
             board[0 * SIDE_WIDTH + 0 * PIECE_WIDTH+:PIECE_WIDTH] = `WHITE_ROOK;
             board[0 * SIDE_WIDTH + 1 * PIECE_WIDTH+:PIECE_WIDTH] = `WHITE_KNIT;
             board[0 * SIDE_WIDTH + 2 * PIECE_WIDTH+:PIECE_WIDTH] = `WHITE_BISH;
             board[0 * SIDE_WIDTH + 3 * PIECE_WIDTH+:PIECE_WIDTH] = `WHITE_QUEN;
             board[0 * SIDE_WIDTH + 4 * PIECE_WIDTH+:PIECE_WIDTH] = `WHITE_KING;
             board[0 * SIDE_WIDTH + 5 * PIECE_WIDTH+:PIECE_WIDTH] = `WHITE_BISH;
             board[0 * SIDE_WIDTH + 6 * PIECE_WIDTH+:PIECE_WIDTH] = `WHITE_KNIT;
             board[0 * SIDE_WIDTH + 7 * PIECE_WIDTH+:PIECE_WIDTH] = `WHITE_ROOK;
             for (i = 0; i < 8; i = i + 1)
               if (i != 4)
                 board[1 * SIDE_WIDTH + i * PIECE_WIDTH+:PIECE_WIDTH] = `WHITE_PAWN;
               else
                 board[3 * SIDE_WIDTH + i * PIECE_WIDTH+:PIECE_WIDTH] = `WHITE_PAWN;

             board[7 * SIDE_WIDTH + 0 * PIECE_WIDTH+:PIECE_WIDTH] = `BLACK_ROOK;
             board[7 * SIDE_WIDTH + 1 * PIECE_WIDTH+:PIECE_WIDTH] = `BLACK_KNIT;
             board[7 * SIDE_WIDTH + 2 * PIECE_WIDTH+:PIECE_WIDTH] = `BLACK_BISH;
             board[7 * SIDE_WIDTH + 3 * PIECE_WIDTH+:PIECE_WIDTH] = `BLACK_QUEN;
             board[7 * SIDE_WIDTH + 4 * PIECE_WIDTH+:PIECE_WIDTH] = `BLACK_KING;
             board[7 * SIDE_WIDTH + 5 * PIECE_WIDTH+:PIECE_WIDTH] = `BLACK_BISH;
             board[7 * SIDE_WIDTH + 6 * PIECE_WIDTH+:PIECE_WIDTH] = `BLACK_KNIT;
             board[7 * SIDE_WIDTH + 7 * PIECE_WIDTH+:PIECE_WIDTH] = `BLACK_ROOK;
             for (i = 0; i < 8; i = i + 1)
               if (i != 4)
                 board[6 * SIDE_WIDTH + i * PIECE_WIDTH+:PIECE_WIDTH] = `BLACK_PAWN;
               else
                 board[4 * SIDE_WIDTH + i * PIECE_WIDTH+:PIECE_WIDTH] = `BLACK_PAWN;
          end
        forever
          #1 clk = ~clk;
     end

   always @(posedge clk)
     begin
        t <= t + 1;
        reset <= t < 64;

        board_valid <= t == 72;
        white_to_move <= 1;

        if (t >= 512)
          $finish;
     end
   
   /* all_moves AUTO_TEMPLATE (
    );*/
   all_moves #
     (
      .PIECE_WIDTH (PIECE_WIDTH),
      .SIDE_WIDTH (SIDE_WIDTH),
      .BOARD_WIDTH (BOARD_WIDTH),
      .MAX_POSITIONS (`MAX_POSITIONS),
      .MAX_POSITIONS_LOG2 ($clog2(`MAX_POSITIONS))
      )
   all_moves_initial
     (/*AUTOINST*/
      // Outputs
      .moves_ready                      (moves_ready),
      .move_count                       (move_count[($clog2(`MAX_POSITIONS))-1:0]),
      .board_out                        (board_out[BOARD_WIDTH-1:0]),
      .white_to_move_out                (white_to_move_out),
      .castle_mask_out                  (castle_mask_out[3:0]),
      .en_passant_col_out               (en_passant_col_out[3:0]),
      // Inputs
      .clk                              (clk),
      .reset                            (reset),
      .board_valid                      (board_valid),
      .board                            (board[BOARD_WIDTH-1:0]),
      .white_to_move                    (white_to_move),
      .castle_mask                      (castle_mask[3:0]),
      .en_passant_col                   (en_passant_col[3:0]),
      .move_index                       (move_index[($clog2(`MAX_POSITIONS))-1:0]),
      .clear_moves                      (clear_moves));

   /* vchess AUTO_TEMPLATE (
    );*/
   vchess #
     (
      .PIECE_WIDTH (PIECE_WIDTH),
      .SIDE_WIDTH (SIDE_WIDTH),
      .BOARD_WIDTH (BOARD_WIDTH)
      )
   vchess
     (/*AUTOINST*/
      // Outputs
      .white_is_attacking               (white_is_attacking[63:0]),
      .black_is_attacking               (black_is_attacking[63:0]),
      .black_in_check                   (black_in_check),
      .white_in_check                   (white_in_check),
      .is_attacking_done                (is_attacking_done),
      .display_attacking_done           (display_attacking_done),
      // Inputs
      .reset                            (reset),
      .clk                              (clk),
      .board                            (board[BOARD_WIDTH-1:0]),
      .board_valid                      (board_valid),
      .white_to_move                    (white_to_move));

   /* display_board AUTO_TEMPLATE (
    .display (display_attacking_done),
    );*/
   display_board #
     (
      .PIECE_WIDTH (PIECE_WIDTH),
      .SIDE_WIDTH (SIDE_WIDTH),
      .BOARD_WIDTH (BOARD_WIDTH)
      )
   display_board
     (/*AUTOINST*/
      // Inputs
      .reset                            (reset),
      .clk                              (clk),
      .board                            (board[BOARD_WIDTH-1:0]),
      .white_in_check                   (white_in_check),
      .black_in_check                   (black_in_check),
      .display                          (display_attacking_done)); // Templated

endmodule

// Local Variables:
// verilog-auto-inst-param-value:t
// verilog-library-directories:(
//     "."
//     )
// End:

