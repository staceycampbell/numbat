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
   reg                                display_move = 0;

   // should be empty
   /*AUTOREGINPUT*/

   /*AUTOWIRE*/
   // Beginning of automatic wires (for undeclared instantiated-module outputs)
   wire                               black_in_check;         // From vchess of vchess.v
   wire [63:0]                        black_is_attacking;     // From vchess of vchess.v
   wire [BOARD_WIDTH-1:0]             board_out;            // From all_moves_initial of all_moves.v
   wire [3:0]                         castle_mask_out;        // From all_moves_initial of all_moves.v
   wire                               display_attacking_done; // From vchess of vchess.v
   wire                               display_done;           // From display_board of display_board.v
   wire [3:0]                         en_passant_col_out;     // From all_moves_initial of all_moves.v
   wire                               is_attacking_done;      // From vchess of vchess.v
   wire [($clog2(`MAX_POSITIONS))-1:0] move_count;// From all_moves_initial of all_moves.v
   wire                                moves_ready;            // From all_moves_initial of all_moves.v
   wire                                white_in_check;         // From vchess of vchess.v
   wire [63:0]                         white_is_attacking;     // From vchess of vchess.v
   wire                                white_to_move_out;      // From all_moves_initial of all_moves.v
   // End of automatics

   initial
     begin
        $dumpfile("wave.vcd");
        $dumpvars(0, tb);
        for (i = 0; i < 64; i = i + 1)
          board[i * PIECE_WIDTH+:PIECE_WIDTH] = `EMPTY_POSN;
        if (1)
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
               board[1 * SIDE_WIDTH + i * PIECE_WIDTH+:PIECE_WIDTH] = `WHITE_PAWN;

             board[7 * SIDE_WIDTH + 0 * PIECE_WIDTH+:PIECE_WIDTH] = `BLACK_ROOK;
             board[7 * SIDE_WIDTH + 1 * PIECE_WIDTH+:PIECE_WIDTH] = `BLACK_KNIT;
             board[7 * SIDE_WIDTH + 2 * PIECE_WIDTH+:PIECE_WIDTH] = `BLACK_BISH;
             board[7 * SIDE_WIDTH + 3 * PIECE_WIDTH+:PIECE_WIDTH] = `BLACK_QUEN;
             board[7 * SIDE_WIDTH + 4 * PIECE_WIDTH+:PIECE_WIDTH] = `BLACK_KING;
             board[7 * SIDE_WIDTH + 5 * PIECE_WIDTH+:PIECE_WIDTH] = `BLACK_BISH;
             board[7 * SIDE_WIDTH + 6 * PIECE_WIDTH+:PIECE_WIDTH] = `BLACK_KNIT;
             board[7 * SIDE_WIDTH + 7 * PIECE_WIDTH+:PIECE_WIDTH] = `BLACK_ROOK;
             for (i = 0; i < 8; i = i + 1)
               board[6 * SIDE_WIDTH + i * PIECE_WIDTH+:PIECE_WIDTH] = `BLACK_PAWN;
          end
        forever
          #1 clk = ~clk;
     end

   always @(posedge clk)
     begin
        t <= t + 1;
        reset <= t < 64;

        board_valid <= t == 72;

        if (t >= 5000)
          $finish;
     end // always @ (posedge clk)

   localparam STATE_IDLE = 0;
   localparam STATE_DISP_INIT = 1;
   localparam STATE_DISP_BOARD_0 = 2;
   localparam STATE_DISP_BOARD_1 = 3;
   localparam STATE_DISP_BOARD_2 = 4;
   localparam STATE_DONE_0 = 5;
   localparam STATE_DONE_1 = 6;
   
   reg [4:0] state = STATE_IDLE;

   always @(posedge clk)
     case (state)
       STATE_IDLE :
         begin
            move_index <= 0;
            display_move <= 0;
            clear_moves <= 0;
            if (clear_moves)
              $finish; // fixme hack
            if (moves_ready)
              begin
                 $display("move_count: %d", move_count);
                 state <= STATE_DISP_INIT;
              end
         end
       STATE_DISP_INIT :
         begin
            display_move <= 1;
            state <= STATE_DISP_BOARD_0;
         end
       STATE_DISP_BOARD_0 :
         begin
            display_move <= 0;
            if (display_done)
              state <= STATE_DISP_BOARD_1;
         end
       STATE_DISP_BOARD_1 :
         begin
            move_index <= move_index + 1;
            if (move_index + 1 < move_count)
              state <= STATE_DISP_BOARD_2;
            else
              state <= STATE_DONE_0;
         end
       STATE_DISP_BOARD_2 : // wait state for move RAM
         state <= STATE_DISP_INIT;
       STATE_DONE_0 :
         begin
            clear_moves <= 1;
            state <= STATE_DONE_1;
         end
       STATE_DONE_1 : // wait state for moves state machine to reset
         state <= STATE_IDLE;
     endcase
   
   /* all_moves AUTO_TEMPLATE (
    .\(.*\)_in (\1[]),
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
      .board_in                         (board[BOARD_WIDTH-1:0]), // Templated
      .white_to_move_in                 (white_to_move),         // Templated
      .castle_mask_in                   (castle_mask[3:0]),      // Templated
      .en_passant_col_in                (en_passant_col[3:0]),   // Templated
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
    .display (display_move),
    .board (board_out[]),
    .white_in_check (1'b0),
    .black_in_check (1'b0),
    );*/
   display_board #
     (
      .PIECE_WIDTH (PIECE_WIDTH),
      .SIDE_WIDTH (SIDE_WIDTH),
      .BOARD_WIDTH (BOARD_WIDTH)
      )
   display_board
     (/*AUTOINST*/
      // Outputs
      .display_done                     (display_done),
      // Inputs
      .reset                            (reset),
      .clk                              (clk),
      .board                            (board_out[BOARD_WIDTH-1:0]), // Templated
      .white_in_check                   (1'b0),                  // Templated
      .black_in_check                   (1'b0),                  // Templated
      .display                          (display_move));          // Templated

endmodule

// Local Variables:
// verilog-auto-inst-param-value:t
// verilog-library-directories:(
//     "."
//     )
// End:

