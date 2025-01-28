`include "numbat.vh"

module et;

   localparam EVAL_MOBILITY_DISABLE = 1;
   localparam EVAL_WIDTH = 24;
   localparam MAX_DEPTH_LOG2 = $clog2(`MAX_DEPTH);
   localparam UCI_WIDTH = 4 + 6 + 6; // promotion, to, from
   localparam HALF_MOVE_WIDTH = 10;

   reg                  reset = 1;
   reg                  clk = 0;
   reg [31:0]           pv_ctrl_in = 0;
   reg                  clear_eval = 0;
   reg [`BOARD_WIDTH-1:0] killer_board = 0;
   reg                    killer_clear = 0;
   reg [MAX_DEPTH_LOG2 - 1:0] killer_ply = 0;
   reg signed [EVAL_WIDTH - 1:0] killer_bonus0 = 0;
   reg signed [EVAL_WIDTH - 1:0] killer_bonus1 = 0;
   reg                           killer_update = 0;
   reg [3:0]                     en_passant_col = 4'h0;
   reg [HALF_MOVE_WIDTH - 1:0]   half_move;
   reg [HALF_MOVE_WIDTH - 1:0]   full_move_number;
   reg [`BOARD_WIDTH - 1:0]      board;
   reg                           board_valid = 0;
   reg [3:0]                     castle_mask = 0;
   reg [3:0]                     castle_mask_orig = 4'b1111;
   reg                           white_to_move = 0;
   reg                           clear_attack = 0;
   reg [UCI_WIDTH-1:0]           uci_in = 0;
   reg [EVAL_WIDTH - 1:0]        random_number = 0;
   reg [EVAL_WIDTH - 1:0]        random_score_mask = 0;
   reg [31:0]                    algorithm_enable = 0;

   //should be empty
   /*AUTOREGINPUT*/

   /*AUTOWIRE*/
   // Beginning of automatic wires (for undeclared instantiated-module outputs)
   wire [5:0]           attack_black_pop;       // From board_attack of board_attack.v
   wire [5:0]           attack_white_pop;       // From board_attack of board_attack.v
   wire                 black_in_check;         // From board_attack of board_attack.v
   wire [63:0]          black_is_attacking;     // From board_attack of board_attack.v
   wire signed [EVAL_WIDTH-1:0] eval;           // From evaluate of evaluate.v
   wire                 eval_pv_flag;           // From evaluate of evaluate.v
   wire                 eval_valid;             // From evaluate of evaluate.v
   wire                 insufficient_material;  // From evaluate of evaluate.v
   wire                 is_attacking_done;      // From board_attack of board_attack.v
   wire                 white_in_check;         // From board_attack of board_attack.v
   wire [63:0]          white_is_attacking;     // From board_attack of board_attack.v
   // End of automatics

   integer                       t = 0;
   integer                       i;

   initial
     begin
        $dumpfile("wave.vcd");
        $dumpvars(0, et);

        for (i = 0; i < 64; i = i + 1)
          board[i * `PIECE_WIDTH+:`PIECE_WIDTH] = `EMPTY_POSN;

`include "et_board.vh"
        
        clk = 0;
        forever
          #1 clk = ~clk;
     end

   always @(posedge clk)
     begin
        t <= t + 1;
        reset <= t < 64;
        board_valid <= t >= 128;
        if (eval_valid)
          begin
             $display("eval=%0d", eval);
             $finish;
          end
     end

   /* evaluate AUTO_TEMPLATE (
    .board_in (board[]),
    );*/
   evaluate #
     (
      .EVAL_WIDTH (EVAL_WIDTH),
      .MAX_DEPTH_LOG2 (MAX_DEPTH_LOG2),
      .EVAL_MOBILITY_DISABLE (EVAL_MOBILITY_DISABLE),
      .UCI_WIDTH (UCI_WIDTH)
      )
   evaluate
     (/*AUTOINST*/
      // Outputs
      .insufficient_material            (insufficient_material),
      .eval                             (eval[EVAL_WIDTH-1:0]),
      .eval_pv_flag                     (eval_pv_flag),
      .eval_valid                       (eval_valid),
      // Inputs
      .clk                              (clk),
      .reset                            (reset),
      .random_score_mask                (random_score_mask[EVAL_WIDTH-1:0]),
      .random_number                    (random_number[EVAL_WIDTH-1:0]),
      .algorithm_enable                 (algorithm_enable[31:0]),
      .board_valid                      (board_valid),
      .is_attacking_done                (is_attacking_done),
      .board_in                         (board[`BOARD_WIDTH-1:0]), // Templated
      .uci_in                           (uci_in[UCI_WIDTH-1:0]),
      .castle_mask                      (castle_mask[3:0]),
      .castle_mask_orig                 (castle_mask_orig[3:0]),
      .clear_eval                       (clear_eval),
      .white_to_move                    (white_to_move),
      .white_is_attacking               (white_is_attacking[63:0]),
      .black_is_attacking               (black_is_attacking[63:0]),
      .white_in_check                   (white_in_check),
      .black_in_check                   (black_in_check),
      .killer_ply                       (killer_ply[MAX_DEPTH_LOG2-1:0]),
      .killer_board                     (killer_board[`BOARD_WIDTH-1:0]),
      .killer_update                    (killer_update),
      .killer_clear                     (killer_clear),
      .killer_bonus0                    (killer_bonus0[EVAL_WIDTH-1:0]),
      .killer_bonus1                    (killer_bonus1[EVAL_WIDTH-1:0]),
      .pv_ctrl_in                       (pv_ctrl_in[31:0]));

   /* board_attack AUTO_TEMPLATE (
    );*/
   board_attack board_attack
     (/*AUTOINST*/
      // Outputs
      .is_attacking_done                (is_attacking_done),
      .white_is_attacking               (white_is_attacking[63:0]),
      .black_is_attacking               (black_is_attacking[63:0]),
      .white_in_check                   (white_in_check),
      .black_in_check                   (black_in_check),
      .attack_white_pop                 (attack_white_pop[5:0]),
      .attack_black_pop                 (attack_black_pop[5:0]),
      // Inputs
      .reset                            (reset),
      .clk                              (clk),
      .board                            (board[`BOARD_WIDTH-1:0]),
      .board_valid                      (board_valid),
      .clear_attack                     (clear_attack));

endmodule // et

// Local Variables:
// verilog-auto-inst-param-value:t
// verilog-library-directories:(
//     "."
//     ".."
//     )
// End:
