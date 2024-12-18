`include "vchess.vh"

module et;
   
   localparam EVAL_MOBILITY_DISABLE = 0;
   localparam EVAL_WIDTH = 24;
   localparam MAX_DEPTH_LOG2 = $clog2(`MAX_DEPTH);
   localparam UCI_WIDTH = 4 + 6 + 6; // promotion, to, from
   
   reg                  reset = 1;
   reg                  clk = 0;

   //should be empty
   /*AUTOREGINPUT*/
   // Beginning of automatic reg inputs (for undeclared instantiated-module inputs)
   reg [`BOARD_WIDTH-1:0] board;                // To board_attack of board_attack.v
   reg [`BOARD_WIDTH-1:0] board_in;             // To evaluate of evaluate.v
   reg                  board_valid;            // To evaluate of evaluate.v, ...
   reg [3:0]            castle_mask;            // To evaluate of evaluate.v
   reg [3:0]            castle_mask_orig;       // To evaluate of evaluate.v
   reg                  clear_attack;           // To board_attack of board_attack.v
   reg                  clear_eval;             // To evaluate of evaluate.v
   reg [`BOARD_WIDTH-1:0] killer_board;         // To evaluate of evaluate.v
   reg signed [EVAL_WIDTH-1:0] killer_bonus0;   // To evaluate of evaluate.v
   reg signed [EVAL_WIDTH-1:0] killer_bonus1;   // To evaluate of evaluate.v
   reg                  killer_clear;           // To evaluate of evaluate.v
   reg [MAX_DEPTH_LOG2-1:0] killer_ply;         // To evaluate of evaluate.v
   reg                  killer_update;          // To evaluate of evaluate.v
   reg [31:0]           pv_ctrl_in;             // To evaluate of evaluate.v
   reg                  random_bit;             // To evaluate of evaluate.v
   reg [UCI_WIDTH-1:0]  uci_in;                 // To evaluate of evaluate.v
   reg                  use_random_bit;         // To evaluate of evaluate.v
   reg                  white_to_move;          // To evaluate of evaluate.v
   // End of automatics

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
   wire [31:0]          material_black;         // From evaluate of evaluate.v
   wire [31:0]          material_white;         // From evaluate of evaluate.v
   wire                 white_in_check;         // From board_attack of board_attack.v
   wire [63:0]          white_is_attacking;     // From board_attack of board_attack.v
   // End of automatics

   integer              t = 0;

   initial
     begin
        clk = 0;
        forever
          #1 clk = ~clk;
     end

   always @(posedge clk)
     begin
        t <= t + 1;
        reset <= t < 64;
     end

   /* evaluate AUTO_TEMPLATE (
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
      .material_black                   (material_black[31:0]),
      .material_white                   (material_white[31:0]),
      // Inputs
      .clk                              (clk),
      .reset                            (reset),
      .use_random_bit                   (use_random_bit),
      .random_bit                       (random_bit),
      .board_valid                      (board_valid),
      .is_attacking_done                (is_attacking_done),
      .board_in                         (board_in[`BOARD_WIDTH-1:0]),
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
