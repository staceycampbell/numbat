`include "vchess.vh"

module control #
  (
   parameter EVAL_WIDTH = 0,
   parameter MAX_POSITIONS_LOG2 = $clog2(`MAX_POSITIONS),
   parameter REPDET_WIDTH = 0,
   parameter HALF_MOVE_WIDTH = 0
   )
   (
    input                                 reset,
    input                                 clk,

    output reg                            soft_reset = 0,
    output reg [`BOARD_WIDTH - 1:0]       new_board,
    output reg                            new_board_valid,
    output reg [3:0]                      castle_mask,
    output reg                            clear_moves,
    output reg [3:0]                      en_passant_col,
    output reg                            white_to_move,
    output reg [HALF_MOVE_WIDTH-1:0]      half_move,
    output reg [`BOARD_WIDTH-1:0]         repdet_board,
    output reg [3:0]                      repdet_castle_mask,
    output reg [REPDET_WIDTH-1:0]         repdet_depth,
    output reg [REPDET_WIDTH-1:0]         repdet_wr_addr,
    output reg                            repdet_wr_en,
   
    output reg [MAX_POSITIONS_LOG2 - 1:0] move_index,

    input                                 initial_moves_ready, // all moves now calculated
    input [MAX_POSITIONS_LOG2 - 1:0]      initial_move_count,
    input                                 initial_move_ready, // move index by move_index now valid
    input [`BOARD_WIDTH-1:0]              initial_board,
    input [3:0]                           initial_castle_mask,
    input [3:0]                           initial_en_passant_col,
    input                                 initial_white_to_move,
    input                                 initial_white_in_check,
    input                                 initial_black_in_check,
    input [63:0]                          initial_white_is_attacking,
    input [63:0]                          initial_black_is_attacking,
    input                                 initial_capture,
    input signed [EVAL_WIDTH - 1:0]       initial_move_eval, // user indexed move eval
    input                                 initial_move_thrice_rep, // user indexed thrice rep
    input [HALF_MOVE_WIDTH - 1:0]         initial_half_move,
   
    input                                 initial_mate,
    input                                 initial_stalemate,
    input signed [EVAL_WIDTH - 1:0]       initial_eval, // root node eval
    input                                 initial_thrice_rep, // root node thrice rep
   
    input [39:0]                          ctrl0_axi_araddr,
    input [2:0]                           ctrl0_axi_arprot,
    input                                 ctrl0_axi_arvalid,
    input [39:0]                          ctrl0_axi_awaddr,
    input [2:0]                           ctrl0_axi_awprot,
    input                                 ctrl0_axi_awvalid,
    input                                 ctrl0_axi_bready,
    input                                 ctrl0_axi_rready,
    input [31:0]                          ctrl0_axi_wdata,
    input [3:0]                           ctrl0_axi_wstrb,
    input                                 ctrl0_axi_wvalid,
   
    output [0:0]                          ctrl0_axi_arready,
    output [0:0]                          ctrl0_axi_awready,
    output [1:0]                          ctrl0_axi_bresp,
    output [0:0]                          ctrl0_axi_bvalid,
    output reg [31:0]                     ctrl0_axi_rdata,
    output [1:0]                          ctrl0_axi_rresp,
    output reg [0:0]                      ctrl0_axi_rvalid,
    output [0:0]                          ctrl0_axi_wready
    );

   reg [$clog2(`BOARD_WIDTH) - 1:0]       board_addr;

   // should be empty
   /*AUTOREGINPUT*/

   /*AUTOWIRE*/
   // Beginning of automatic wires (for undeclared instantiated-module outputs)
   wire [39:0]          ctrl0_wr_addr;          // From axi4lite_write_ctrl0 of axi4lite_write.v
   wire [31:0]          ctrl0_wr_data;          // From axi4lite_write_ctrl0 of axi4lite_write.v
   wire                 ctrl0_wr_valid;         // From axi4lite_write_ctrl0 of axi4lite_write.v
   // End of automatics

   assign ctrl0_axi_arready = 1; // always ready
   assign ctrl0_axi_rresp = 2'b0; // always ok

   wire [15:0]                            wr_reg_addr = ctrl0_wr_addr[15:2];
   wire [15:0]                            rd_reg_addr = ctrl0_axi_araddr[15:2];
   wire [5:0]                             board_address = wr_reg_addr - 1;

   always @(posedge clk)
     if (ctrl0_wr_valid)
       case (wr_reg_addr)
         5'h0 :
           begin
              new_board_valid <= ctrl0_wr_data[0];
              clear_moves <= ctrl0_wr_data[1];
              soft_reset <= ctrl0_wr_data[31];
           end
         5'h01 : move_index <= ctrl0_wr_data;
         5'h02 : {white_to_move, castle_mask, en_passant_col} <= ctrl0_wr_data;
         5'h03 : half_move <= ctrl0_wr_data;
         5'h08 : new_board[`SIDE_WIDTH * 0+:`SIDE_WIDTH] <= ctrl0_wr_data[`SIDE_WIDTH - 1:0];
         5'h09 : new_board[`SIDE_WIDTH * 1+:`SIDE_WIDTH] <= ctrl0_wr_data[`SIDE_WIDTH - 1:0];
         5'h0A : new_board[`SIDE_WIDTH * 2+:`SIDE_WIDTH] <= ctrl0_wr_data[`SIDE_WIDTH - 1:0];
         5'h0B : new_board[`SIDE_WIDTH * 3+:`SIDE_WIDTH] <= ctrl0_wr_data[`SIDE_WIDTH - 1:0];
         5'h0C : new_board[`SIDE_WIDTH * 4+:`SIDE_WIDTH] <= ctrl0_wr_data[`SIDE_WIDTH - 1:0];
         5'h0D : new_board[`SIDE_WIDTH * 5+:`SIDE_WIDTH] <= ctrl0_wr_data[`SIDE_WIDTH - 1:0];
         5'h0E : new_board[`SIDE_WIDTH * 6+:`SIDE_WIDTH] <= ctrl0_wr_data[`SIDE_WIDTH - 1:0];
         5'h0F : new_board[`SIDE_WIDTH * 7+:`SIDE_WIDTH] <= ctrl0_wr_data[`SIDE_WIDTH - 1:0];
         
         5'h10 : repdet_depth <= ctrl0_wr_data;
         5'h11 : repdet_castle_mask <= ctrl0_wr_data;
         5'h12 : {repdet_wr_en, repdet_wr_addr} <= {ctrl0_wr_data[31], ctrl0_wr_data[REPDET_WIDTH - 1:0]};
         5'h18 : repdet_board[`SIDE_WIDTH * 0+:`SIDE_WIDTH] <= ctrl0_wr_data[`SIDE_WIDTH - 1:0];
         5'h19 : repdet_board[`SIDE_WIDTH * 1+:`SIDE_WIDTH] <= ctrl0_wr_data[`SIDE_WIDTH - 1:0];
         5'h1A : repdet_board[`SIDE_WIDTH * 2+:`SIDE_WIDTH] <= ctrl0_wr_data[`SIDE_WIDTH - 1:0];
         5'h1B : repdet_board[`SIDE_WIDTH * 3+:`SIDE_WIDTH] <= ctrl0_wr_data[`SIDE_WIDTH - 1:0];
         5'h1C : repdet_board[`SIDE_WIDTH * 4+:`SIDE_WIDTH] <= ctrl0_wr_data[`SIDE_WIDTH - 1:0];
         5'h1D : repdet_board[`SIDE_WIDTH * 5+:`SIDE_WIDTH] <= ctrl0_wr_data[`SIDE_WIDTH - 1:0];
         5'h1E : repdet_board[`SIDE_WIDTH * 6+:`SIDE_WIDTH] <= ctrl0_wr_data[`SIDE_WIDTH - 1:0];
         5'h1F : repdet_board[`SIDE_WIDTH * 7+:`SIDE_WIDTH] <= ctrl0_wr_data[`SIDE_WIDTH - 1:0];
         default :
           begin
           end
       endcase

   always @(posedge clk)
     begin
        if (ctrl0_axi_rready)
          ctrl0_axi_rvalid <= 0;
        if (ctrl0_axi_arvalid)
          begin
             case (rd_reg_addr)
               4'h0 :
                 begin
                    ctrl0_axi_rdata[0] <= new_board_valid;
                    ctrl0_axi_rdata[1] <= clear_moves;
                    ctrl0_axi_rdata[2] <= initial_moves_ready;
                    ctrl0_axi_rdata[3] <= initial_move_ready;
                    ctrl0_axi_rdata[4] <= initial_stalemate;
                    ctrl0_axi_rdata[5] <= initial_mate;
                    ctrl0_axi_rdata[6] <= initial_thrice_rep;
                    ctrl0_axi_rdata[31] <= soft_reset;
                 end
               5'h01 : ctrl0_axi_rdata <= move_index;
               5'h02 : ctrl0_axi_rdata <= {white_to_move, castle_mask, en_passant_col};
               5'h03 : ctrl0_axi_rdata <= half_move;
               5'h08 : ctrl0_axi_rdata <= new_board[`SIDE_WIDTH * 0+:`SIDE_WIDTH];
               5'h09 : ctrl0_axi_rdata <= new_board[`SIDE_WIDTH * 1+:`SIDE_WIDTH];
               5'h0A : ctrl0_axi_rdata <= new_board[`SIDE_WIDTH * 2+:`SIDE_WIDTH];
               5'h0B : ctrl0_axi_rdata <= new_board[`SIDE_WIDTH * 3+:`SIDE_WIDTH];
               5'h0C : ctrl0_axi_rdata <= new_board[`SIDE_WIDTH * 4+:`SIDE_WIDTH];
               5'h0D : ctrl0_axi_rdata <= new_board[`SIDE_WIDTH * 5+:`SIDE_WIDTH];
               5'h0E : ctrl0_axi_rdata <= new_board[`SIDE_WIDTH * 6+:`SIDE_WIDTH];
               5'h0F : ctrl0_axi_rdata <= new_board[`SIDE_WIDTH * 7+:`SIDE_WIDTH];
               
               5'h10 : ctrl0_axi_rdata <= repdet_depth;
               5'h11 : ctrl0_axi_rdata <= repdet_castle_mask;
               5'h12 : ctrl0_axi_rdata <= {repdet_wr_en, repdet_wr_addr};
               5'h18 : ctrl0_axi_rdata <= repdet_board[`SIDE_WIDTH * 0+:`SIDE_WIDTH];
               5'h19 : ctrl0_axi_rdata <= repdet_board[`SIDE_WIDTH * 1+:`SIDE_WIDTH];
               5'h1A : ctrl0_axi_rdata <= repdet_board[`SIDE_WIDTH * 2+:`SIDE_WIDTH];
               5'h1B : ctrl0_axi_rdata <= repdet_board[`SIDE_WIDTH * 3+:`SIDE_WIDTH];
               5'h1C : ctrl0_axi_rdata <= repdet_board[`SIDE_WIDTH * 4+:`SIDE_WIDTH];
               5'h1D : ctrl0_axi_rdata <= repdet_board[`SIDE_WIDTH * 5+:`SIDE_WIDTH];
               5'h1E : ctrl0_axi_rdata <= repdet_board[`SIDE_WIDTH * 6+:`SIDE_WIDTH];
               5'h1F : ctrl0_axi_rdata <= repdet_board[`SIDE_WIDTH * 7+:`SIDE_WIDTH];
               
               128 : ctrl0_axi_rdata <= initial_white_is_attacking[31:0];
               129 : ctrl0_axi_rdata <= initial_white_is_attacking[63:32];
               130 : ctrl0_axi_rdata <= initial_black_is_attacking[31:0];
               131 : ctrl0_axi_rdata <= initial_black_is_attacking[63:32];
               132 : ctrl0_axi_rdata <= {initial_black_in_check, initial_white_in_check, initial_capture};
               133 : ctrl0_axi_rdata <= {initial_white_to_move, initial_castle_mask, initial_en_passant_col};
               134 : ctrl0_axi_rdata <= initial_move_eval;
               135 : ctrl0_axi_rdata <= initial_move_count;
               136 : ctrl0_axi_rdata <= initial_eval;
               138 : ctrl0_axi_rdata <= initial_half_move;
               
               172 : ctrl0_axi_rdata[`SIDE_WIDTH - 1:0] <= initial_board[`SIDE_WIDTH * 0+:`SIDE_WIDTH];
               173 : ctrl0_axi_rdata[`SIDE_WIDTH - 1:0] <= initial_board[`SIDE_WIDTH * 1+:`SIDE_WIDTH];
               174 : ctrl0_axi_rdata[`SIDE_WIDTH - 1:0] <= initial_board[`SIDE_WIDTH * 2+:`SIDE_WIDTH];
               175 : ctrl0_axi_rdata[`SIDE_WIDTH - 1:0] <= initial_board[`SIDE_WIDTH * 3+:`SIDE_WIDTH];
               176 : ctrl0_axi_rdata[`SIDE_WIDTH - 1:0] <= initial_board[`SIDE_WIDTH * 4+:`SIDE_WIDTH];
               177 : ctrl0_axi_rdata[`SIDE_WIDTH - 1:0] <= initial_board[`SIDE_WIDTH * 5+:`SIDE_WIDTH];
               178 : ctrl0_axi_rdata[`SIDE_WIDTH - 1:0] <= initial_board[`SIDE_WIDTH * 6+:`SIDE_WIDTH];
               179 : ctrl0_axi_rdata[`SIDE_WIDTH - 1:0] <= initial_board[`SIDE_WIDTH * 7+:`SIDE_WIDTH];
               default : ctrl0_axi_rdata <= 0;
             endcase
             ctrl0_axi_rvalid <= 1;
          end
     end

   /* axi4lite_write AUTO_TEMPLATE (
    .aresetb (~reset),
    .axi_\(.*\) (ctrl0_axi_\1[]),
    .addr (ctrl0_wr_addr[]),
    .data (ctrl0_wr_data[]),
    .valid (ctrl0_wr_valid),
    );*/
   axi4lite_write axi4lite_write_ctrl0
     (/*AUTOINST*/
      // Outputs
      .axi_awready                      (ctrl0_axi_awready),     // Templated
      .axi_bresp                        (ctrl0_axi_bresp[1:0]),  // Templated
      .axi_bvalid                       (ctrl0_axi_bvalid),      // Templated
      .axi_wready                       (ctrl0_axi_wready),      // Templated
      .addr                             (ctrl0_wr_addr[39:0]),   // Templated
      .data                             (ctrl0_wr_data[31:0]),   // Templated
      .valid                            (ctrl0_wr_valid),        // Templated
      // Inputs
      .aresetb                          (~reset),                // Templated
      .clk                              (clk),
      .axi_awaddr                       (ctrl0_axi_awaddr[39:0]), // Templated
      .axi_awprot                       (ctrl0_axi_awprot[2:0]), // Templated
      .axi_awvalid                      (ctrl0_axi_awvalid),     // Templated
      .axi_bready                       (ctrl0_axi_bready),      // Templated
      .axi_wdata                        (ctrl0_axi_wdata[31:0]), // Templated
      .axi_wstrb                        (ctrl0_axi_wstrb[3:0]),  // Templated
      .axi_wvalid                       (ctrl0_axi_wvalid));      // Templated
   

endmodule
