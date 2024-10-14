`include "vchess.vh"

module trans #
  (
   parameter EVAL_WIDTH = 0
   )
   (
    input                      clk,
    input                      reset,

    input                      entry_lookup_in,
    input                      entry_store_in,
   
    input [`BOARD_WIDTH - 1:0] board_in,
    input                      white_to_move_in,
    input [3:0]                castle_mask_in,
    input [3:0]                en_passant_col_in,

    input [1:0]                flag_in,
    input [EVAL_WIDTH - 1:0]   eval_in,
    input [7:0]                depth_in,

    output                     trans_idle_out,

    output                     entry_valid_out,
    output reg [31:0]          hash_out,
    output [EVAL_WIDTH - 1:0]  eval_out,
    output [7:0]               depth_out,
    output [1:0]               flag_out,
   
    input                      trans_axi_arready,
    input                      trans_axi_awready,
    input [1:0]                trans_axi_bresp,
    input                      trans_axi_bvalid,
    input [511:0]              trans_axi_rdata,
    input                      trans_axi_rlast,
    input [1:0]                trans_axi_rresp,
    input                      trans_axi_rvalid,
    input                      trans_axi_wready,

    output [31:0]              trans_axi_araddr,
    output [1:0]               trans_axi_arburst,
    output [3:0]               trans_axi_arcache,
    output [7:0]               trans_axi_arlen,
    output [0:0]               trans_axi_arlock,
    output [2:0]               trans_axi_arprot,
    output [3:0]               trans_axi_arqos,
    output [2:0]               trans_axi_arsize,
    output                     trans_axi_arvalid,
    output [31:0]              trans_axi_awaddr,
    output [1:0]               trans_axi_awburst,
    output [3:0]               trans_axi_awcache,
    output [7:0]               trans_axi_awlen,
    output [0:0]               trans_axi_awlock,
    output [2:0]               trans_axi_awprot,
    output [3:0]               trans_axi_awqos,
    output [2:0]               trans_axi_awsize,
    output                     trans_axi_awvalid,
    output                     trans_axi_bready,
    output                     trans_axi_rready,
    output [511:0]             trans_axi_wdata,
    output                     trans_axi_wlast,
    output [63:0]              trans_axi_wstrb,
    output                     trans_axi_wvalid
    );

   localparam TABLE_SIZE_LOG2 = 25; // 2^25 * 512 bits for 2GByte DDR4
   localparam TABLE_SIZE = 1 << TABLE_SIZE_LOG2;
   
   localparam STATE_IDLE = 0;
   localparam STATE_HASH_0 = 1;
   localparam STATE_HASH_1 = 2;
   localparam STATE_HASH_2 = 3;
   localparam STATE_HASH_3 = 4;

   reg [4:0]                   state = STATE_IDLE;

   reg [31:0]                  hash_0[8], hash_0_8;;
   reg [31:0]                  hash_1_0, hash_1_1, hash_1_8;
   reg [31:0]                  hash_2;

   reg [`BOARD_WIDTH - 1:0]    board;
   reg                         white_to_move;
   reg [3:0]                   castle_mask;
   reg [3:0]                   en_passant_col;

   integer                     i;
   
   assign trans_idle_out = state != STATE_IDLE;
   
   function [31:0] xorshift32 (input [31:0] x);
      begin
         reg [31:0] x0, x1, x2, x3;
         // x = x == 0 ? 1 : x; // no need to avoid 0 in this use case
         x0 = ((x & 32'h0007ffff) << 13) ^ x;
         x1 = (x0 >> 17) ^ x0;
         x2 = ((x1 & 32'h07ffffff) << 5) ^ x1;
         x3 = x2 & 32'hffffffff;
         xorshift32 = x3;
      end
   endfunction
   
   always @(posedge clk)
     begin
        if (entry_lookup_in || entry_store_in)
          begin
             board <= board_in;
             white_to_move <= white_to_move_in;
             castle_mask <= castle_mask_in;
             en_passant_col <= en_passant_col_in;
          end
     end

   always @(posedge clk)
     if (reset)
       state <= STATE_IDLE;
     else
       case (state)
         STATE_IDLE :
           begin
              if (entry_lookup_in || entry_store_in)
                state <= STATE_HASH_0;
           end
         STATE_HASH_0 :
           begin
              for (i = 0; i < 8; i = i + 1)
                hash_0[i] <= xorshift32(board[i * `SIDE_WIDTH+:`SIDE_WIDTH]);
              hash_0_8 <= castle_mask ^ en_passant_col;
              state <= STATE_HASH_1;
           end
         STATE_HASH_1 :
           begin
              hash_1_0 <= hash_0[0] - hash_0[1] + hash_0[2] - hash_0[3];
              hash_1_1 <= hash_0[4] - hash_0[5] + hash_0[6] - hash_0[7];
              hash_1_8 <= hash_0_8;
              state <= STATE_HASH_2;
           end
         STATE_HASH_2 :
           begin
              hash_2 <= hash_1_0 + hash_1_1 + hash_1_8;
              state <= STATE_HASH_3;
           end
         STATE_HASH_3 :
           begin
              if (white_to_move)
                hash_out <= xorshift32(hash_2) & (TABLE_SIZE - 1);
              else
                hash_out <= hash_2 & (TABLE_SIZE - 1);
           end
         default :
           state <= STATE_IDLE;
       endcase
   
endmodule
