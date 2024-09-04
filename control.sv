module control #
  (
   parameter PIECE_WIDTH = 0,
   parameter SIDE_WIDTH = 0,
   parameter BOARD_WIDTH = 0,
   parameter EVAL_WIDTH = 0
   )
   (
    input                                     reset,
    input                                     clk,

    output reg                                soft_reset = 0,
    output reg [BOARD_WIDTH - 1:0]            new_board,
    output reg                                new_board_valid,
    output reg [3:0]                          castle_mask,
    output reg                                clear_moves,
    output reg [3:0]                          en_passant_col,
    output reg                                white_to_move,
    output reg [($clog2(`MAX_POSITIONS))-1:0] move_index,
    output reg                                clear_eval,

    input                                     eval_valid,
    input signed [EVAL_WIDTH - 1:0]           eval,

    input                                     initial_moves_ready, // all moves now calculated
    input                                     initial_move_ready, // move index by move_index now valid
    input [BOARD_WIDTH-1:0]                   initial_board,
    input [3:0]                               initial_castle_mask,
    input [3:0]                               initial_en_passant_col,
    input                                     initial_white_to_move,
    input                                     initial_white_in_check,
    input                                     initial_black_in_check,
    input [63:0]                              initial_white_is_attacking,
    input [63:0]                              initial_black_is_attacking,
    input                                     initial_capture,
   
    input [39:0]                              ctrl0_axi_araddr,
    input [2:0]                               ctrl0_axi_arprot,
    input                                     ctrl0_axi_arvalid,
    input [39:0]                              ctrl0_axi_awaddr,
    input [2:0]                               ctrl0_axi_awprot,
    input                                     ctrl0_axi_awvalid,
    input                                     ctrl0_axi_bready,
    input                                     ctrl0_axi_rready,
    input [31:0]                              ctrl0_axi_wdata,
    input [3:0]                               ctrl0_axi_wstrb,
    input                                     ctrl0_axi_wvalid,
   
    output [0:0]                              ctrl0_axi_arready,
    output [0:0]                              ctrl0_axi_awready,
    output [1:0]                              ctrl0_axi_bresp,
    output [0:0]                              ctrl0_axi_bvalid,
    output reg [31:0]                         ctrl0_axi_rdata,
    output [1:0]                              ctrl0_axi_rresp,
    output reg [0:0]                          ctrl0_axi_rvalid,
    output [0:0]                              ctrl0_axi_wready,
   
    input [39:0]                              ctrl1_axi_araddr,
    input [2:0]                               ctrl1_axi_arprot,
    input                                     ctrl1_axi_arvalid,
    input [39:0]                              ctrl1_axi_awaddr,
    input [2:0]                               ctrl1_axi_awprot,
    input                                     ctrl1_axi_awvalid,
    input                                     ctrl1_axi_bready,
    input                                     ctrl1_axi_rready,
    input reg [31:0]                          ctrl1_axi_wdata,
    input [3:0]                               ctrl1_axi_wstrb,
    input                                     ctrl1_axi_wvalid,
   
    output [0:0]                              ctrl1_axi_arready,
    output [0:0]                              ctrl1_axi_awready,
    output [1:0]                              ctrl1_axi_bresp,
    output [0:0]                              ctrl1_axi_bvalid,
    output [31:0]                             ctrl1_axi_rdata,
    output [1:0]                              ctrl1_axi_rresp,
    output [0:0]                              ctrl1_axi_rvalid,
    output [0:0]                              ctrl1_axi_wready
    );

   reg [$clog2(BOARD_WIDTH) - 1:0]            board_addr;

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

   wire [15:0]                                wr_reg_addr = ctrl0_wr_addr[15:2];
   wire [15:0]                                rd_reg_addr = ctrl0_axi_araddr[15:2];
   wire [5:0]                                 board_address = wr_reg_addr - 1;

   always @(posedge clk)
     if (ctrl0_wr_valid)
       case (ctrl0_wr_addr)
         4'h0 :
           begin
              new_board_valid <= ctrl0_wr_data[0];
              clear_moves <= ctrl0_wr_data[1];
              clear_eval <= ctrl0_wr_data[2];
              soft_reset <= ctrl0_wr_data[31];
           end
         4'h1 : move_index <= ctrl0_wr_data;
         4'h2 : {white_to_move, castle_mask, en_passant_col} <= ctrl0_wr_data;
         4'h8 : new_board[SIDE_WIDTH * 0+:SIDE_WIDTH] <= ctrl0_wr_data[SIDE_WIDTH - 1:0];
         4'h9 : new_board[SIDE_WIDTH * 1+:SIDE_WIDTH] <= ctrl0_wr_data[SIDE_WIDTH - 1:0];
         4'hA : new_board[SIDE_WIDTH * 2+:SIDE_WIDTH] <= ctrl0_wr_data[SIDE_WIDTH - 1:0];
         4'hB : new_board[SIDE_WIDTH * 3+:SIDE_WIDTH] <= ctrl0_wr_data[SIDE_WIDTH - 1:0];
         4'hC : new_board[SIDE_WIDTH * 4+:SIDE_WIDTH] <= ctrl0_wr_data[SIDE_WIDTH - 1:0];
         4'hD : new_board[SIDE_WIDTH * 5+:SIDE_WIDTH] <= ctrl0_wr_data[SIDE_WIDTH - 1:0];
         4'hE : new_board[SIDE_WIDTH * 6+:SIDE_WIDTH] <= ctrl0_wr_data[SIDE_WIDTH - 1:0];
         4'hF : new_board[SIDE_WIDTH * 7+:SIDE_WIDTH] <= ctrl0_wr_data[SIDE_WIDTH - 1:0];
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
                    ctrl0_axi_rdata[2] <= clear_eval;
                    ctrl0_axi_rdata[5:3] <= {eval_valid, initial_move_ready, initial_moves_ready};
                 end
               4'h1 : ctrl0_axi_rdata <= move_index;
               4'h2 : ctrl0_axi_rdata <= {white_to_move, castle_mask, en_passant_col};
               4'h8 : ctrl0_axi_rdata[SIDE_WIDTH - 1:0] <= new_board[SIDE_WIDTH * 0+:SIDE_WIDTH];
               4'h9 : ctrl0_axi_rdata[SIDE_WIDTH - 1:0] <= new_board[SIDE_WIDTH * 1+:SIDE_WIDTH];
               4'hA : ctrl0_axi_rdata[SIDE_WIDTH - 1:0] <= new_board[SIDE_WIDTH * 2+:SIDE_WIDTH];
               4'hB : ctrl0_axi_rdata[SIDE_WIDTH - 1:0] <= new_board[SIDE_WIDTH * 3+:SIDE_WIDTH];
               4'hC : ctrl0_axi_rdata[SIDE_WIDTH - 1:0] <= new_board[SIDE_WIDTH * 4+:SIDE_WIDTH];
               4'hD : ctrl0_axi_rdata[SIDE_WIDTH - 1:0] <= new_board[SIDE_WIDTH * 5+:SIDE_WIDTH];
               4'hE : ctrl0_axi_rdata[SIDE_WIDTH - 1:0] <= new_board[SIDE_WIDTH * 6+:SIDE_WIDTH];
               4'hF : ctrl0_axi_rdata[SIDE_WIDTH - 1:0] <= new_board[SIDE_WIDTH * 7+:SIDE_WIDTH];
               
               128 : ctrl0_axi_rdata <= initial_white_is_attacking[31:0];
               129 : ctrl0_axi_rdata <= initial_white_is_attacking[63:32];
               130 : ctrl0_axi_rdata <= initial_black_is_attacking[31:0];
               131 : ctrl0_axi_rdata <= initial_black_is_attacking[63:32];
               132 : ctrl0_axi_rdata <= {initial_black_in_check, initial_white_in_check, initial_capture};
               133 : ctrl0_axi_rdata <= {initial_white_to_move, initial_castle_mask, initial_en_passant_col};
               134 : ctrl0_axi_rdata <= eval;
               
               172 : ctrl0_axi_rdata[SIDE_WIDTH - 1:0] <= initial_board[SIDE_WIDTH * 0+:SIDE_WIDTH];
               173 : ctrl0_axi_rdata[SIDE_WIDTH - 1:0] <= initial_board[SIDE_WIDTH * 1+:SIDE_WIDTH];
               174 : ctrl0_axi_rdata[SIDE_WIDTH - 1:0] <= initial_board[SIDE_WIDTH * 2+:SIDE_WIDTH];
               175 : ctrl0_axi_rdata[SIDE_WIDTH - 1:0] <= initial_board[SIDE_WIDTH * 3+:SIDE_WIDTH];
               176 : ctrl0_axi_rdata[SIDE_WIDTH - 1:0] <= initial_board[SIDE_WIDTH * 4+:SIDE_WIDTH];
               177 : ctrl0_axi_rdata[SIDE_WIDTH - 1:0] <= initial_board[SIDE_WIDTH * 5+:SIDE_WIDTH];
               178 : ctrl0_axi_rdata[SIDE_WIDTH - 1:0] <= initial_board[SIDE_WIDTH * 6+:SIDE_WIDTH];
               179 : ctrl0_axi_rdata[SIDE_WIDTH - 1:0] <= initial_board[SIDE_WIDTH * 7+:SIDE_WIDTH];
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
