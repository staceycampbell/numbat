`include "vchess.vh"

module trans #
  (
   parameter EVAL_WIDTH = 0
   )
   (
    input                         clk,
    input                         reset,

    (* mark_debug = "true" *) input                         entry_lookup_in,
    (* mark_debug = "true" *) input                         entry_store_in,
   
    input [`BOARD_WIDTH - 1:0]    board_in,
    (* mark_debug = "true" *) input                         white_to_move_in,
    (* mark_debug = "true" *) input [3:0]                   castle_mask_in,
    (* mark_debug = "true" *) input [3:0]                   en_passant_col_in,

    (* mark_debug = "true" *) input [1:0]                   flag_in,
    (* mark_debug = "true" *) input [EVAL_WIDTH - 1:0]      eval_in,
    (* mark_debug = "true" *) input [7:0]                   depth_in,

    (* mark_debug = "true" *) output                        trans_idle_out,

    (* mark_debug = "true" *) output reg                    entry_valid_out,
    (* mark_debug = "true" *) output reg [31:0]             hash_out,
    (* mark_debug = "true" *) output reg [EVAL_WIDTH - 1:0] eval_out,
    (* mark_debug = "true" *) output reg [7:0]              depth_out,
    (* mark_debug = "true" *) output reg [1:0]              flag_out,
   
    (* mark_debug = "true" *) input                         trans_axi_arready,
    (* mark_debug = "true" *) input                         trans_axi_awready,
    input [1:0]                   trans_axi_bresp,
    input                         trans_axi_bvalid,
    input [511:0]                 trans_axi_rdata,
    input                         trans_axi_rlast,
    input [1:0]                   trans_axi_rresp,
    (* mark_debug = "true" *) input                         trans_axi_rvalid,
    (* mark_debug = "true" *) input                         trans_axi_wready,

    (* mark_debug = "true" *) output reg [31:0]             trans_axi_araddr,
    output [1:0]                  trans_axi_arburst,
    output [3:0]                  trans_axi_arcache,
    output [7:0]                  trans_axi_arlen,
    output [0:0]                  trans_axi_arlock,
    output [2:0]                  trans_axi_arprot,
    output [3:0]                  trans_axi_arqos,
    output [2:0]                  trans_axi_arsize,
    (* mark_debug = "true" *) output reg                    trans_axi_arvalid,
    output reg [31:0]             trans_axi_awaddr,
    output [1:0]                  trans_axi_awburst,
    output [3:0]                  trans_axi_awcache,
    output [7:0]                  trans_axi_awlen,
    output [0:0]                  trans_axi_awlock,
    output [2:0]                  trans_axi_awprot,
    output [3:0]                  trans_axi_awqos,
    output [2:0]                  trans_axi_awsize,
    (* mark_debug = "true" *) output reg                    trans_axi_awvalid,
    output                        trans_axi_bready,
    (* mark_debug = "true" *) output reg                    trans_axi_rready,
    output reg [511:0]            trans_axi_wdata,
    output                        trans_axi_wlast,
    output [63:0]                 trans_axi_wstrb,
    (* mark_debug = "true" *) output reg                    trans_axi_wvalid
    );

   localparam BASE_ADDRESS = 32'h00000000; // axi4 byte address for base of memory
   localparam TABLE_SIZE_LOG2 = 25; // 2^25 * 512 bits for 2GByte DDR4
   localparam TABLE_SIZE = 1 << TABLE_SIZE_LOG2;

   localparam STATE_IDLE = 0;
   localparam STATE_HASH_0 = 1;
   localparam STATE_HASH_1 = 2;
   localparam STATE_HASH_2 = 3;
   localparam STATE_HASH_3 = 4;
   localparam STATE_STORE = 5;
   localparam STATE_STORE_WAIT_DATA = 6;
   localparam STATE_STORE_WAIT_ADDR = 7;
   localparam STATE_LOOKUP = 8;
   localparam STATE_LOOKUP_WAIT_DATA = 9;
   localparam STATE_LOOKUP_WAIT_ADDR = 10;
   localparam STATE_LOOKUP_VALIDATE = 11;
   
   (* mark_debug = "true" *) reg [3:0]                      state = STATE_IDLE;

   reg [31:0]                     hash_0[8], hash_0_8;;
   reg [31:0]                     hash_1_0, hash_1_1, hash_1_8;
   reg [31:0]                     hash_2;

   (* mark_debug = "true" *) reg                            entry_store, entry_lookup;
   reg                            entry_store_in_z, entry_lookup_in_z;

   reg [`BOARD_WIDTH - 1:0]       board;
   reg                            white_to_move;
   reg [3:0]                      castle_mask;
   reg [3:0]                      en_passant_col;
   reg [1:0]                      flag;
   reg [EVAL_WIDTH - 1:0]         eval;
   reg [7:0]                      depth;

   reg [511:0]                    lookup;

   integer                        i;

   wire [`BOARD_WIDTH - 1:0]      lookup_board;
   wire                           lookup_white_to_move;
   wire [3:0]                     lookup_castle_mask;
   wire [3:0]                     lookup_en_passant_col;
   wire [1:0]                     lookup_flag;
   wire [EVAL_WIDTH - 1:0]        lookup_eval;
   wire [7:0]                     lookup_depth;
   wire                           lookup_valid;

   wire [31:0]                    hash_address = BASE_ADDRESS + (hash_out << $clog2(512 / 8)); // axi4 byte address for 512 bit table entry
   wire [511:0]                   store = {1'b1, depth[7:0], flag[1:0], eval[EVAL_WIDTH - 1:0],
                                           white_to_move, castle_mask[3:0], en_passant_col[3:0], board[`BOARD_WIDTH - 1:0]};

   assign {lookup_valid, lookup_depth[7:0], lookup_flag[1:0], lookup_eval[EVAL_WIDTH - 1:0],
           ilookup_white_to_move, lookup_castle_mask[3:0], lookup_en_passant_col[3:0], lookup_board[`BOARD_WIDTH - 1:0]} = lookup;
   
   assign trans_idle_out = state != STATE_IDLE;

   // https://developer.arm.com/documentation/ihi0022/latest
   assign trans_axi_awlock = 1'b0; // normal access
   assign trans_axi_awprot = 3'b000; // https://support.xilinx.com/s/question/0D52E00006iHqdESAS/accessing-ddr-from-pl-on-zynq
   assign trans_axi_awqos = 4'b0; // no QOS scheme
   assign trans_axi_awburst = 2'b00; // fixed address (not incrementing burst)
   assign trans_axi_awcache = 4'b0011; // https://support.xilinx.com/s/question/0D52E00006iHqdESAS/accessing-ddr-from-pl-on-zynq
   assign trans_axi_awsize = 3'b110; // 512 bits (64 bytes) per beat
   assign trans_axi_bready = 1'b1; // can always accept a write response
   assign trans_axi_wstrb = 64'hffff_ffff_ffff_ffff; // all byte lanes valid always
   assign trans_axi_wlast = 1'b1; // only one 512 bit write per transaction
   assign trans_axi_awlen = 8'h00; // always one write per transaction

   assign trans_axi_arburst = 2'b00; // fixed address (not incrementing burst)
   assign trans_axi_arcache = 4'b0011; // https://support.xilinx.com/s/question/0D52E00006iHqdESAS/accessing-ddr-from-pl-on-zynq
   assign trans_axi_arlen = 8'h00; // always one ready per transaction
   assign trans_axi_arlock = 1'b0; // normal access
   assign trans_axi_arprot = 3'b000; // https://support.xilinx.com/s/question/0D52E00006iHqdESAS/accessing-ddr-from-pl-on-zynq
   assign trans_axi_arqos = 4'b0; // no QOS scheme
   assign trans_axi_arsize = 3'b110; // 512 bits (64 bytes) per beat

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
        entry_lookup_in_z <= entry_lookup_in;
        entry_store_in_z <= entry_store_in;
        
        trans_axi_wdata <= store;
        trans_axi_awaddr <= hash_address;
        
        trans_axi_araddr <= hash_address;
        if (trans_axi_rready && trans_axi_rvalid)
          lookup <= trans_axi_rdata;
        
        eval_out <= lookup_eval;
        depth_out <= lookup_depth;
        flag_out <= lookup_flag;
     end

   always @(posedge clk)
     if (reset)
       state <= STATE_IDLE;
     else
       case (state)
         STATE_IDLE :
           begin
              entry_lookup <= entry_lookup_in && ~entry_lookup_in_z;
              entry_store <= entry_store_in && ~entry_store_in_z;
              board <= board_in;
              white_to_move <= white_to_move_in;
              castle_mask <= castle_mask_in;
              en_passant_col <= en_passant_col_in;
              eval <= eval_in;
              flag <= flag_in;
              depth <= depth_in;

              trans_axi_wvalid <= 0;
              trans_axi_awvalid <= 0;
              
              if (entry_lookup || entry_store)
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
              if (entry_store)
                state <= STATE_STORE;
              else
                state <= STATE_LOOKUP;
           end
         STATE_STORE :
           begin
              trans_axi_awvalid <= 1;
              trans_axi_wvalid <= 1;
              if (trans_axi_awvalid && trans_axi_awready && trans_axi_wvalid && trans_axi_wready)
                begin
                   trans_axi_wvalid <= 0;
                   trans_axi_awvalid <= 0;
                   state <= STATE_IDLE;
                end
              else if (trans_axi_awvalid && trans_axi_awready)
                begin
                   trans_axi_awvalid <= 0;
                   state <= STATE_STORE_WAIT_DATA;
                end
              else if (trans_axi_wvalid && trans_axi_wready)
                begin
                   trans_axi_wvalid <= 0;
                   state <= STATE_STORE_WAIT_ADDR;
                end
           end
         STATE_STORE_WAIT_DATA :
           if (trans_axi_wready)
             begin
                trans_axi_wvalid <= 0;
                state <= STATE_IDLE;
             end
         STATE_STORE_WAIT_ADDR :
           if (trans_axi_awready)
             begin
                trans_axi_awvalid <= 0;
                state <= STATE_IDLE;
             end
         STATE_LOOKUP :
           begin
              trans_axi_arvalid <= 1;
              trans_axi_rready <= 1;
              if (trans_axi_arvalid && trans_axi_arready && trans_axi_rvalid && trans_axi_rready)
                begin
                   trans_axi_arvalid <= 0;
                   trans_axi_rready <= 0;
                   state <= STATE_LOOKUP_VALIDATE;
                end
              else if (trans_axi_arvalid && trans_axi_arready)
                begin
                   trans_axi_arvalid <= 0;
                   state <= STATE_LOOKUP_WAIT_DATA;
                end
              else if (trans_axi_rvalid && trans_axi_rready)
                begin
                   trans_axi_rready <= 0;
                   state <= STATE_LOOKUP_WAIT_ADDR;
                end
           end
         STATE_LOOKUP_WAIT_DATA :
           if (trans_axi_rvalid)
             begin
                trans_axi_rready <= 0;
                state <= STATE_LOOKUP_VALIDATE;
             end
         STATE_LOOKUP_WAIT_ADDR :
           if (trans_axi_arready)
             begin
                trans_axi_arvalid <= 0;
                state <= STATE_LOOKUP_VALIDATE;
             end
         STATE_LOOKUP_VALIDATE :
           begin
              entry_valid_out <= lookup_valid &&
                                 lookup_board == board &&
                                 lookup_en_passant_col == en_passant_col &&
                                 lookup_castle_mask == castle_mask &&
                                 lookup_white_to_move == white_to_move;
              state <= STATE_IDLE;
           end
         default :
           state <= STATE_IDLE;
       endcase
   
endmodule
