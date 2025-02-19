`include "numbat.vh"

module tb;

   localparam EVAL_WIDTH = 24;
   localparam MAX_POSITIONS_LOG2 = $clog2(`MAX_POSITIONS);
   localparam HALF_MOVE_WIDTH = 10;
   localparam TB_REP_HISTORY = 9;
   localparam UCI_WIDTH = 4 + 6 + 6; // promotion, to, from
   localparam MAX_DEPTH_LOG2 = $clog2(`MAX_DEPTH);

   reg clk = 0;
   reg reset = 1;
   integer t = 0;
   integer i, j;

   reg     am_clear_moves = 1'b0;
   reg     board_valid = 0;
   reg [7:0] pawn_promotions [0:(1 << `PIECE_BITS) - 1];

   reg [`BOARD_WIDTH - 1:0] board;
   reg                      white_to_move;
   reg [3:0]                castle_mask;
   reg [3:0]                en_passant_col;
   reg [HALF_MOVE_WIDTH - 1:0] half_move;
   reg [HALF_MOVE_WIDTH - 1:0] full_move_number;

   reg [MAX_POSITIONS_LOG2 - 1:0] am_move_index = 0;
   reg                            display_move = 0;
   reg [EVAL_WIDTH - 1:0]         random_number = 0;
   reg [EVAL_WIDTH - 1:0]         random_score_mask = 'h0;

   reg [`BOARD_WIDTH-1:0]         killer_board = 0;
   reg signed [EVAL_WIDTH-1:0]    killer_bonus0 = 15000;
   reg signed [EVAL_WIDTH-1:0]    killer_bonus1 = 13000;
   reg                            killer_clear = 0;
   reg [MAX_DEPTH_LOG2-1:0]       killer_ply = 2;
   reg                            killer_update = 0;
   reg [31:0]                     pv_ctrl = 0;
   reg [3:0]                      castle_mask_orig = 4'b1111;
   reg [31:0]                     algorithm_enable = 0;

   // should be empty
   /*AUTOREGINPUT*/

   /*AUTOWIRE*/
   // Beginning of automatic wires (for undeclared instantiated-module outputs)
   wire [31:0]          all_moves_bram_addr;    // From all_moves of all_moves.v
   wire [511:0]         all_moves_bram_din;     // From all_moves of all_moves.v
   wire [63:0]          all_moves_bram_we;      // From all_moves of all_moves.v
   wire                 am_idle;                // From all_moves of all_moves.v
   wire [MAX_POSITIONS_LOG2-1:0] am_move_count; // From all_moves of all_moves.v
   wire                 am_move_ready;          // From all_moves of all_moves.v
   wire                 am_moves_ready;         // From all_moves of all_moves.v
   wire                 black_in_check_out;     // From all_moves of all_moves.v
   wire [63:0]          black_is_attacking_out; // From all_moves of all_moves.v
   wire [`BOARD_WIDTH-1:0] board_out;           // From all_moves of all_moves.v
   wire                 capture_out;            // From all_moves of all_moves.v
   wire [3:0]           castle_mask_out;        // From all_moves of all_moves.v
   wire                 display_done;           // From display_board of display_board.v
   wire [3:0]           en_passant_col_out;     // From all_moves of all_moves.v
   wire signed [EVAL_WIDTH-1:0] eval_out;       // From all_moves of all_moves.v
   wire                 fifty_move_out;         // From all_moves of all_moves.v
   wire [HALF_MOVE_WIDTH-1:0] half_move_out;    // From all_moves of all_moves.v
   wire                 initial_board_check;    // From all_moves of all_moves.v
   wire signed [EVAL_WIDTH-1:0] initial_eval;   // From all_moves of all_moves.v
   wire                 initial_fifty_move;     // From all_moves of all_moves.v
   wire                 initial_insufficient_material;// From all_moves of all_moves.v
   wire                 initial_mate;           // From all_moves of all_moves.v
   wire                 initial_stalemate;      // From all_moves of all_moves.v
   wire                 insufficient_material_out;// From all_moves of all_moves.v
   wire                 pv_out;                 // From all_moves of all_moves.v
   wire [UCI_WIDTH-1:0] uci_out;                // From all_moves of all_moves.v
   wire                 white_in_check_out;     // From all_moves of all_moves.v
   wire [63:0]          white_is_attacking_out; // From all_moves of all_moves.v
   wire                 white_to_move_out;      // From all_moves of all_moves.v
   // End of automatics

   wire [3:0]                     uci_promotion;
   wire [2:0]                     uci_from_row, uci_from_col;
   wire [2:0]                     uci_to_row, uci_to_col;

   wire [7:0]                     status_char = white_in_check_out ? "W" : black_in_check_out ? "B" : "D";

   assign {uci_promotion, uci_to_row, uci_to_col, uci_from_row, uci_from_col} = uci_out;

   initial
     begin
        $dumpfile("wave.vcd");
        $dumpvars(0, tb);
        for (i = 0; i < (1 << `PIECE_BITS); i = i + 1)
          pawn_promotions[i] = "?";
        pawn_promotions[`EMPTY_POSN] = " ";
        pawn_promotions[`WHITE_QUEN] = "Q";
        pawn_promotions[`WHITE_BISH] = "B";
        pawn_promotions[`WHITE_ROOK] = "R";
        pawn_promotions[`WHITE_KNIT] = "N";
        pawn_promotions[`BLACK_QUEN] = "Q";
        pawn_promotions[`BLACK_BISH] = "B";
        pawn_promotions[`BLACK_ROOK] = "R";
        pawn_promotions[`BLACK_KNIT] = "N";
        for (i = 0; i < 64; i = i + 1)
          board[i * `PIECE_WIDTH+:`PIECE_WIDTH] = `EMPTY_POSN;

        // Insert a FEN line here, feed it through the fenconv tool to convert the
        // FEN line to data that can be clocked into the move generator
	// echo 'FEN line goes here' | ../misc/fenconv
        // echo '' | ../misc/fenconv
	// echo 'rnbqkb1r/1p2pppp/p2p1n2/8/3NP3/2N5/PPP2PPP/R1BQKB1R w KQkq - 0 1' | ../misc/fenconv

        // many illegal moves
	// echo 'r1b1kb1r/ppp1qppp/8/3n4/2B5/P1N2N2/RP3PPP/2Q1K2R w Kkq - 1 12' | ../misc/fenconv

        // C80 Ruy Lopez Open, Bernstein Variation, Karpov Gambit
        // echo 'r2qkb1r/2p2ppp/p1n1b3/1pn1P1N1/3p4/1BP5/PP1N1PPP/R1BQ1RK1 b kq - 1 11' | ../misc/fenconv

        // 80 moves
        // echo '4Q3/1b4k1/1p1r3p/5R1P/1P6/P1NB1PK1/Q7/7R w - - 1 0' | ../misc/fenconv
        
        // many illegal moves
        board[7 * `SIDE_WIDTH + 0 * `PIECE_WIDTH+:`PIECE_WIDTH] = `BLACK_ROOK;
        board[7 * `SIDE_WIDTH + 2 * `PIECE_WIDTH+:`PIECE_WIDTH] = `BLACK_BISH;
        board[7 * `SIDE_WIDTH + 4 * `PIECE_WIDTH+:`PIECE_WIDTH] = `BLACK_KING;
        board[7 * `SIDE_WIDTH + 5 * `PIECE_WIDTH+:`PIECE_WIDTH] = `BLACK_BISH;
        board[7 * `SIDE_WIDTH + 7 * `PIECE_WIDTH+:`PIECE_WIDTH] = `BLACK_ROOK;
        board[6 * `SIDE_WIDTH + 0 * `PIECE_WIDTH+:`PIECE_WIDTH] = `BLACK_PAWN;
        board[6 * `SIDE_WIDTH + 1 * `PIECE_WIDTH+:`PIECE_WIDTH] = `BLACK_PAWN;
        board[6 * `SIDE_WIDTH + 2 * `PIECE_WIDTH+:`PIECE_WIDTH] = `BLACK_PAWN;
        board[6 * `SIDE_WIDTH + 4 * `PIECE_WIDTH+:`PIECE_WIDTH] = `BLACK_QUEN;
        board[6 * `SIDE_WIDTH + 5 * `PIECE_WIDTH+:`PIECE_WIDTH] = `BLACK_PAWN;
        board[6 * `SIDE_WIDTH + 6 * `PIECE_WIDTH+:`PIECE_WIDTH] = `BLACK_PAWN;
        board[6 * `SIDE_WIDTH + 7 * `PIECE_WIDTH+:`PIECE_WIDTH] = `BLACK_PAWN;
        board[4 * `SIDE_WIDTH + 3 * `PIECE_WIDTH+:`PIECE_WIDTH] = `BLACK_KNIT;
        board[3 * `SIDE_WIDTH + 2 * `PIECE_WIDTH+:`PIECE_WIDTH] = `WHITE_BISH;
        board[2 * `SIDE_WIDTH + 0 * `PIECE_WIDTH+:`PIECE_WIDTH] = `WHITE_PAWN;
        board[2 * `SIDE_WIDTH + 2 * `PIECE_WIDTH+:`PIECE_WIDTH] = `WHITE_KNIT;
        board[2 * `SIDE_WIDTH + 5 * `PIECE_WIDTH+:`PIECE_WIDTH] = `WHITE_KNIT;
        board[1 * `SIDE_WIDTH + 0 * `PIECE_WIDTH+:`PIECE_WIDTH] = `WHITE_ROOK;
        board[1 * `SIDE_WIDTH + 1 * `PIECE_WIDTH+:`PIECE_WIDTH] = `WHITE_PAWN;
        board[1 * `SIDE_WIDTH + 5 * `PIECE_WIDTH+:`PIECE_WIDTH] = `WHITE_PAWN;
        board[1 * `SIDE_WIDTH + 6 * `PIECE_WIDTH+:`PIECE_WIDTH] = `WHITE_PAWN;
        board[1 * `SIDE_WIDTH + 7 * `PIECE_WIDTH+:`PIECE_WIDTH] = `WHITE_PAWN;
        board[0 * `SIDE_WIDTH + 2 * `PIECE_WIDTH+:`PIECE_WIDTH] = `WHITE_QUEN;
        board[0 * `SIDE_WIDTH + 4 * `PIECE_WIDTH+:`PIECE_WIDTH] = `WHITE_KING;
        board[0 * `SIDE_WIDTH + 7 * `PIECE_WIDTH+:`PIECE_WIDTH] = `WHITE_ROOK;
        white_to_move = 1;
        castle_mask = 4'hD;
        en_passant_col = 4'h0;
        half_move = 1;
        full_move_number = 12;
        
        forever
          #1 clk = ~clk;
     end

   always @(posedge clk)
     begin
     end

   always @(posedge clk)
     begin
        random_number <= $random;
     end

   localparam LOADST_IDLE = 0;
   localparam LOADST_BOARD = 1;
   localparam LOADST_BOARD_WAIT = 2;

   reg [1:0] loadst = LOADST_IDLE;

   always @(posedge clk)
     if (reset)
       begin
          board_valid <= 0;
          loadst <= LOADST_IDLE;
       end
     else
       case (loadst)
         LOADST_IDLE :
           begin
              board_valid <= 0;
              loadst <= LOADST_BOARD;
           end
         LOADST_BOARD :
           begin
              board_valid <= 1;
              loadst <= LOADST_BOARD_WAIT;
           end
         LOADST_BOARD_WAIT :
           if (am_clear_moves)
             loadst <= LOADST_IDLE;
       endcase

   always @(posedge clk)
     begin
        t <= t + 1;
        reset <= t < 64;

        if (0 && t >= 100000)
          $finish;
        if (0 && tb.all_moves.state == 25 /* tb.all_moves.checkmate.state == 27 */)
          begin
             $display("stopping sim at sort init\n");
             $finish;
          end
     end

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
            am_move_index <= 0;
            display_move <= 0;
            am_clear_moves <= 0;
            if (am_clear_moves)
              $finish; // fixme hack
            if (am_moves_ready)
              begin
                 $display("inital_eval: %d, am_move_count: %d", initial_eval, am_move_count);
                 state <= STATE_DISP_INIT;
              end
         end
       STATE_DISP_INIT :
         if (am_move_count == 0)
           begin
              if (initial_mate)
                $display("checkmate");
              else if (initial_stalemate)
                $display("stalemate");
              state <= STATE_DONE_0;
           end
         else
           begin
              $display("move index: %d", am_move_index);
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
            $display("move_index=%1d %c%c%c%c%c %c", am_move_index, "a" + uci_from_col, "1" + uci_from_row,
                     "a" + uci_to_col, "1" + uci_to_row, pawn_promotions[uci_promotion], status_char);
            $display("");
            am_move_index <= am_move_index + 1;
            if (am_move_index + 1 < am_move_count)
              state <= STATE_DISP_BOARD_2;
            else
              state <= STATE_DONE_0;
         end
       STATE_DISP_BOARD_2 : // wait state for move RAM
         state <= STATE_DISP_INIT;
       STATE_DONE_0 :
         begin
            am_clear_moves <= 1;
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
      .MAX_POSITIONS_LOG2 (MAX_POSITIONS_LOG2),
      .EVAL_WIDTH (EVAL_WIDTH),
      .HALF_MOVE_WIDTH (HALF_MOVE_WIDTH),
      .UCI_WIDTH (UCI_WIDTH),
      .MAX_DEPTH_LOG2 (MAX_DEPTH_LOG2)
      )
   all_moves
     (/*AUTOINST*/
      // Outputs
      .initial_mate                     (initial_mate),
      .initial_stalemate                (initial_stalemate),
      .initial_eval                     (initial_eval[EVAL_WIDTH-1:0]),
      .initial_fifty_move               (initial_fifty_move),
      .initial_insufficient_material    (initial_insufficient_material),
      .initial_board_check              (initial_board_check),
      .am_idle                          (am_idle),
      .am_moves_ready                   (am_moves_ready),
      .am_move_ready                    (am_move_ready),
      .am_move_count                    (am_move_count[MAX_POSITIONS_LOG2-1:0]),
      .board_out                        (board_out[`BOARD_WIDTH-1:0]),
      .white_to_move_out                (white_to_move_out),
      .castle_mask_out                  (castle_mask_out[3:0]),
      .en_passant_col_out               (en_passant_col_out[3:0]),
      .capture_out                      (capture_out),
      .pv_out                           (pv_out),
      .white_in_check_out               (white_in_check_out),
      .black_in_check_out               (black_in_check_out),
      .white_is_attacking_out           (white_is_attacking_out[63:0]),
      .black_is_attacking_out           (black_is_attacking_out[63:0]),
      .eval_out                         (eval_out[EVAL_WIDTH-1:0]),
      .half_move_out                    (half_move_out[HALF_MOVE_WIDTH-1:0]),
      .fifty_move_out                   (fifty_move_out),
      .uci_out                          (uci_out[UCI_WIDTH-1:0]),
      .insufficient_material_out        (insufficient_material_out),
      .all_moves_bram_addr              (all_moves_bram_addr[31:0]),
      .all_moves_bram_din               (all_moves_bram_din[511:0]),
      .all_moves_bram_we                (all_moves_bram_we[63:0]),
      // Inputs
      .clk                              (clk),
      .reset                            (reset),
      .random_score_mask                (random_score_mask[EVAL_WIDTH-1:0]),
      .random_number                    (random_number[EVAL_WIDTH-1:0]),
      .algorithm_enable                 (algorithm_enable[31:0]),
      .board_valid_in                   (board_valid),           // Templated
      .board_in                         (board[`BOARD_WIDTH-1:0]), // Templated
      .white_to_move_in                 (white_to_move),         // Templated
      .castle_mask_in                   (castle_mask[3:0]),      // Templated
      .en_passant_col_in                (en_passant_col[3:0]),   // Templated
      .half_move_in                     (half_move[HALF_MOVE_WIDTH-1:0]), // Templated
      .castle_mask_orig_in              (castle_mask_orig[3:0]), // Templated
      .killer_ply_in                    (killer_ply[MAX_DEPTH_LOG2-1:0]), // Templated
      .killer_board_in                  (killer_board[`BOARD_WIDTH-1:0]), // Templated
      .killer_update_in                 (killer_update),         // Templated
      .killer_clear_in                  (killer_clear),          // Templated
      .killer_bonus0_in                 (killer_bonus0[EVAL_WIDTH-1:0]), // Templated
      .killer_bonus1_in                 (killer_bonus1[EVAL_WIDTH-1:0]), // Templated
      .pv_ctrl_in                       (pv_ctrl[31:0]),         // Templated
      .am_move_index                    (am_move_index[MAX_POSITIONS_LOG2-1:0]),
      .am_clear_moves                   (am_clear_moves));

   /* display_board AUTO_TEMPLATE (
    .display (display_move),
    .board (board_out[]),
    .castle_mask (castle_mask_out[]),
    .capture (capture_out[]),
    .pv (pv_out[]),
    .en_passant_col (en_passant_col_out[]),
    .white_in_check (white_in_check_out),
    .black_in_check (black_in_check_out),
    .eval (eval_out[]),
    .thrice_rep (thrice_rep_out),
    .half_move (half_move_out[]),
    .uci (uci_out[]),
    );*/
   display_board #
     (
      .EVAL_WIDTH (EVAL_WIDTH),
      .HALF_MOVE_WIDTH (HALF_MOVE_WIDTH),
      .UCI_WIDTH (UCI_WIDTH)
      )
   display_board
     (/*AUTOINST*/
      // Outputs
      .display_done                     (display_done),
      // Inputs
      .reset                            (reset),
      .clk                              (clk),
      .board                            (board_out[`BOARD_WIDTH-1:0]), // Templated
      .castle_mask                      (castle_mask_out[3:0]),  // Templated
      .en_passant_col                   (en_passant_col_out[3:0]), // Templated
      .capture                          (capture_out),           // Templated
      .pv                               (pv_out),                // Templated
      .white_in_check                   (white_in_check_out),    // Templated
      .black_in_check                   (black_in_check_out),    // Templated
      .eval                             (eval_out[EVAL_WIDTH-1:0]), // Templated
      .half_move                        (half_move_out[HALF_MOVE_WIDTH-1:0]), // Templated
      .display                          (display_move),          // Templated
      .uci                              (uci_out[UCI_WIDTH-1:0])); // Templated

   initial
     begin
        // tb.all_moves.evaluate.evaluate_killer.killer_table
        for (i = 0; i < `MAX_DEPTH; i = i + 1)
          tb.all_moves.evaluate.evaluate_killer.killer_table[i] = 0;

        // 6k1/8/1b6/2P2p2/4B3/8/8/K7 w - - 1 2
        tb.all_moves.evaluate.evaluate_killer.killer_table[killer_ply][7 * `SIDE_WIDTH + 6 * `PIECE_WIDTH+:`PIECE_WIDTH] = `BLACK_KING;
        tb.all_moves.evaluate.evaluate_killer.killer_table[killer_ply][5 * `SIDE_WIDTH + 1 * `PIECE_WIDTH+:`PIECE_WIDTH] = `BLACK_BISH;
        tb.all_moves.evaluate.evaluate_killer.killer_table[killer_ply][4 * `SIDE_WIDTH + 2 * `PIECE_WIDTH+:`PIECE_WIDTH] = `WHITE_PAWN;
        tb.all_moves.evaluate.evaluate_killer.killer_table[killer_ply][4 * `SIDE_WIDTH + 5 * `PIECE_WIDTH+:`PIECE_WIDTH] = `BLACK_PAWN;
        tb.all_moves.evaluate.evaluate_killer.killer_table[killer_ply][3 * `SIDE_WIDTH + 4 * `PIECE_WIDTH+:`PIECE_WIDTH] = `WHITE_BISH;
        tb.all_moves.evaluate.evaluate_killer.killer_table[killer_ply][0 * `SIDE_WIDTH + 0 * `PIECE_WIDTH+:`PIECE_WIDTH] = `WHITE_KING;
        
        // 8/6k1/1b6/2P2p2/4B3/8/8/K7 w - - 0 1
        tb.all_moves.evaluate.evaluate_killer.killer_table[killer_ply][`BOARD_WIDTH + 6 * `SIDE_WIDTH + 6 * `PIECE_WIDTH+:`PIECE_WIDTH] = `BLACK_KING;
        tb.all_moves.evaluate.evaluate_killer.killer_table[killer_ply][`BOARD_WIDTH + 5 * `SIDE_WIDTH + 1 * `PIECE_WIDTH+:`PIECE_WIDTH] = `BLACK_BISH;
        tb.all_moves.evaluate.evaluate_killer.killer_table[killer_ply][`BOARD_WIDTH + 4 * `SIDE_WIDTH + 2 * `PIECE_WIDTH+:`PIECE_WIDTH] = `WHITE_PAWN;
        tb.all_moves.evaluate.evaluate_killer.killer_table[killer_ply][`BOARD_WIDTH + 4 * `SIDE_WIDTH + 5 * `PIECE_WIDTH+:`PIECE_WIDTH] = `BLACK_PAWN;
        tb.all_moves.evaluate.evaluate_killer.killer_table[killer_ply][`BOARD_WIDTH + 3 * `SIDE_WIDTH + 4 * `PIECE_WIDTH+:`PIECE_WIDTH] = `WHITE_BISH;
        tb.all_moves.evaluate.evaluate_killer.killer_table[killer_ply][`BOARD_WIDTH + 0 * `SIDE_WIDTH + 0 * `PIECE_WIDTH+:`PIECE_WIDTH] = `WHITE_KING;
        tb.all_moves.evaluate.evaluate_killer.killer_valid[killer_ply * 2 + 1] = 1'b1;
     end

endmodule

// Local Variables:
// verilog-auto-inst-param-value:t
// verilog-library-directories:(
//     "."
//     ".."
//     )
// End:

