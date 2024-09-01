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

    input                                     initial_moves_ready,
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

   wire [15:0]                                wr_reg_addr = ctrl0_wr_addr[15:2];
   wire [15:0]                                rd_reg_addr = ctrl0_axi_araddr[15:2];
   wire [5:0]                                 board_address = wr_reg_addr - 1;

   always @(posedge clk)
     if (ctrl0_wr_valid)
       if (ctrl0_wr_addr == 0)
         new_board_valid <= ctrl0_wr_data[0];
       else if (ctrl0_wr_addr >= 1 && ctrl0_wr_addr <= 65)
         new_board[board_address+:PIECE_WIDTH] <= ctrl0_wr_data[PIECE_WIDTH - 1:0];
       else if (ctrl0_wr_addr == 66)
         move_index <= ctrl0_wr_data;
       else if (ctrl0_wr_addr == 67)
         clear_moves <= ctrl0_wr_data;
       else if (ctrl0_wr_addr == 68)
         {white_to_move, castle_mask, en_passant_col} <= ctrl0_wr_data;
       else if (ctrl0_wr_addr == 69)
         clear_eval <= ctrl0_wr_data;

   always @(posedge clk)
     begin
        if (ctrl0_axi_rready)
          ctrl0_axi_rvalid <= 0;
        if (ctrl0_axi_arvalid)
          begin
             case (rd_reg_addr)
               0 : ctrl0_axi_rdata <= initial_white_is_attacking[31:0];
               1 : ctrl0_axi_rdata <= initial_white_is_attacking[63:32];
               2 : ctrl0_axi_rdata <= initial_black_is_attacking[31:0];
               3 : ctrl0_axi_rdata <= initial_black_is_attacking[63:32];
               4 : ctrl0_axi_rdata <= {initial_black_in_check, initial_white_in_check, initial_capture};
               5 : ctrl0_axi_rdata <= initial_moves_ready;
               6 : ctrl0_axi_rdata <= {initial_white_to_move, initial_castle_mask, initial_en_passant_col};
               7 : ctrl0_axi_rdata <= eval_valid;
               8 : ctrl0_axi_rdata <= eval;
               default :
                 begin
                    if (rd_reg_addr >= 16)
                      ctrl0_axi_rdata <= initial_board[(rd_reg_addr - 16) << PIECE_WIDTH+:PIECE_WIDTH];
                 end
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
