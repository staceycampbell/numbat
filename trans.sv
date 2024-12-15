`include "vchess.vh"

module trans #
  (
   parameter EVAL_WIDTH = 0
   )
   (
    input                                 clk,
    input                                 reset,

    input                                 entry_lookup_in,
    input                                 entry_store_in,
    input                                 hash_only_in,
    input                                 clear_trans_in,
   
    input [`BOARD_WIDTH - 1:0]            board_in,
    input                                 white_to_move_in,
    input [3:0]                           castle_mask_in,
    input [3:0]                           en_passant_col_in,

    input [1:0]                           flag_in,
    input signed [EVAL_WIDTH - 1:0]       eval_in,
    input [7:0]                           depth_in,
    input [`TRANS_NODES_WIDTH - 1:0]      nodes_in,
    input                                 capture_in,

    output                                trans_idle_out,

    output reg                            entry_valid_out,
    output reg signed [EVAL_WIDTH - 1:0]  eval_out,
    output reg [7:0]                      depth_out,
    output reg [1:0]                      flag_out,
    output reg [`TRANS_NODES_WIDTH - 1:0] nodes_out,
    output reg                            capture_out,
    output reg                            collision_out,

    output reg [79:0]                     hash_out,
   
    input                                 trans_axi_arready,
    input                                 trans_axi_awready,
    input [1:0]                           trans_axi_bresp,
    input                                 trans_axi_bvalid,
    input [127:0]                         trans_axi_rdata,
    input                                 trans_axi_rlast,
    input [1:0]                           trans_axi_rresp,
    input                                 trans_axi_rvalid,
    input                                 trans_axi_wready,
   
    output reg [31:0]                     trans_axi_araddr,
    output [1:0]                          trans_axi_arburst,
    output [3:0]                          trans_axi_arcache,
    output [7:0]                          trans_axi_arlen,
    output [0:0]                          trans_axi_arlock,
    output [2:0]                          trans_axi_arprot,
    output [3:0]                          trans_axi_arqos,
    output [2:0]                          trans_axi_arsize,
    output reg                            trans_axi_arvalid,
    output reg [31:0]                     trans_axi_awaddr,
    output [1:0]                          trans_axi_awburst,
    output [3:0]                          trans_axi_awcache,
    output [7:0]                          trans_axi_awlen,
    output [0:0]                          trans_axi_awlock,
    output [2:0]                          trans_axi_awprot,
    output [3:0]                          trans_axi_awqos,
    output [2:0]                          trans_axi_awsize,
    output reg                            trans_axi_awvalid,
    output                                trans_axi_bready,
    output reg                            trans_axi_rready,
    output reg [127:0]                    trans_axi_wdata,
    output                                trans_axi_wlast,
    output [15:0]                         trans_axi_wstrb,
    output                                trans_axi_wvalid,
    output [3:0]                          trans_axi_arregion,
    output [3:0]                          trans_axi_awregion,

    output reg [31:0]                     trans_trans = 0
    );

   localparam HASH_USED = 64;

   localparam BASE_ADDRESS = 32'h00000000; // AXI4 byte address for base of memory
   localparam MEM_SIZE_BYTES = 2 * 1024 * 1024 * 1024; // 2GByte DDR4
   localparam MEM_ADDR_WIDTH = $clog2(MEM_SIZE_BYTES);
   localparam TABLE_SIZE_LOG2 = $clog2(MEM_SIZE_BYTES) + $clog2(8) - $clog2(128); // 2^27 * 128 bits for 2GByte
   localparam TABLE_SIZE = 1 << TABLE_SIZE_LOG2;
   localparam BURST_TICK_TOTAL = TABLE_SIZE;
   localparam BURST_COUNTER_WIDTH = $clog2(BURST_TICK_TOTAL) + 1;

   localparam STATE_IDLE = 0;
   localparam STATE_CLEAR_TRANS_INIT = 1;
   localparam STATE_CLEAR_TRANS = 2;
   localparam STATE_TRANS_WAIT_DATA = 3;
   localparam STATE_CLEAR_TRANS_DONE = 4;
   localparam STATE_HASH_0 = 5;
   localparam STATE_HASH_1 = 6;
   localparam STATE_HASH_2 = 7;
   localparam STATE_HASH_3 = 8;
   localparam STATE_HASH_4 = 9;
   localparam STATE_STORE = 10;
   localparam STATE_STORE_WAIT_DATA = 11;
   localparam STATE_STORE_WAIT_ADDR = 12;
   localparam STATE_LOOKUP = 13;
   localparam STATE_LOOKUP_WAIT_DATA = 14;
   localparam STATE_LOOKUP_WAIT_ADDR = 15;
   localparam STATE_LOOKUP_VALIDATE = 16;
   
   reg [4:0]                              state = STATE_IDLE;

   reg [79:0]                             hash_0 [63:0];
   reg [79:0]                             hash_1 [15:0];
   reg [79:0]                             hash_2 [ 3:0];
   reg [79:0]                             hash_side;
   reg [79:0]                             hash;

   reg                                    entry_store, entry_lookup, hash_only, clear_trans;
   reg                                    clear_trans_r;
   reg                                    entry_store_in_z, entry_lookup_in_z, hash_only_in_z, clear_trans_in_z;
   
   (* ram_style = "distributed" *) reg [79:0] zob_rand_board [0:767];
   (* ram_style = "distributed" *) reg [79:0] zob_rand_en_passant_col [0:31];
   (* ram_style = "distributed" *) reg [3:0] zob_piece_lookup [1:14];
   (* ram_style = "distributed" *) reg [79:0] zob_rand_castle_mask [0:15];
   reg [79:0]                             zob_rand_btm;

   reg [`BOARD_WIDTH - 1:0]               board;
   reg                                    white_to_move;
   reg [3:0]                              castle_mask;
   reg [3:0]                              en_passant_col;
   reg [1:0]                              flag;
   reg signed [EVAL_WIDTH - 1:0]          eval;
   reg [7:0]                              depth;
   reg [`TRANS_NODES_WIDTH - 1:0]         nodes;
   reg                                    capture;
   reg                                    valid_wr;
   reg                                    local_wvalid;
   reg [BURST_COUNTER_WIDTH - 1:0]        burst_counter;
   reg                                    start_data;

   reg [127:0]                            lookup;

   integer                                i;

   wire [HASH_USED - 1:0]                 lookup_hash;
   wire [1:0]                             lookup_flag;
   wire signed [EVAL_WIDTH - 1:0]         lookup_eval;
   wire [7:0]                             lookup_depth;
   wire [`TRANS_NODES_WIDTH - 1:0]        lookup_nodes;
   wire                                   lookup_capture;
   wire                                   lookup_valid;

   wire [MEM_ADDR_WIDTH - 1:0]            hash_address = BASE_ADDRESS + (hash << $clog2(128 / 8)); // axi4 byte address for 128 bit table entry
   wire [127:0]                           store = {valid_wr, capture, nodes[`TRANS_NODES_WIDTH - 1:0], depth[7:0],
                                                   flag[1:0], eval[EVAL_WIDTH - 1:0], hash[HASH_USED - 1:0]};

   wire                                   clear_wlast = burst_counter[7:0] == 8'hFF;

   assign {lookup_valid, lookup_capture, lookup_nodes[`TRANS_NODES_WIDTH - 1:0], lookup_depth[7:0], lookup_flag[1:0],
           lookup_eval[EVAL_WIDTH - 1:0], lookup_hash[HASH_USED - 1:0]} = lookup;
   
   assign trans_idle_out = state == STATE_IDLE;

   // https://developer.arm.com/documentation/ihi0022/latest
   assign trans_axi_awlock = 1'b0; // normal access
   assign trans_axi_awprot = 3'b000; // https://support.xilinx.com/s/question/0D52E00006iHqdESAS/accessing-ddr-from-pl-on-zynq
   assign trans_axi_awqos = 4'b0; // no QOS scheme
   assign trans_axi_awburst = 2'b01; // incrementing address
   assign trans_axi_awcache = 4'b0011; // https://support.xilinx.com/s/question/0D52E00006iHqdESAS/accessing-ddr-from-pl-on-zynq
   assign trans_axi_awsize = 3'b100; // 128 bits (16 bytes) per beat
   assign trans_axi_bready = 1'b1; // can always accept a write response
   assign trans_axi_wstrb = 16'hffff; // all byte lanes valid always
   assign trans_axi_wlast = clear_trans ? clear_wlast : 1'b1; // full 256 ticks per burst on clear, otherwise one 128 bit write per transaction
   assign trans_axi_awlen = clear_trans ? 8'hFF : 8'h00; // full bursts on clear, otherwise one write per transaction
   assign trans_axi_wvalid = clear_trans ? start_data && burst_counter < BURST_TICK_TOTAL : local_wvalid;

   assign trans_axi_arburst = 2'b00; // fixed address (not incrementing burst)
   assign trans_axi_arcache = 4'b0011; // https://support.xilinx.com/s/question/0D52E00006iHqdESAS/accessing-ddr-from-pl-on-zynq
   assign trans_axi_arlen = 8'h00; // one ready per transaction
   assign trans_axi_arlock = 1'b0; // normal access
   assign trans_axi_arprot = 3'b000; // https://support.xilinx.com/s/question/0D52E00006iHqdESAS/accessing-ddr-from-pl-on-zynq
   assign trans_axi_arqos = 4'b0; // no QOS scheme
   assign trans_axi_arsize = 3'b100; // 128 bits (16 bytes) per beat
   
   assign trans_axi_arregion = 4'b0; // unused
   assign trans_axi_awregion = 4'b0; // unused

   always @(posedge clk)
     begin
        entry_lookup_in_z <= entry_lookup_in;
        entry_store_in_z <= entry_store_in;
        hash_only_in_z <= hash_only_in;
        clear_trans_in_z <= clear_trans_in;

        clear_trans_r <= clear_trans;

        trans_axi_wdata <= store;
        trans_axi_awaddr <= hash_address;

        if (clear_trans && ~clear_trans_r)
          burst_counter <= 0;
        else if (trans_axi_wready && start_data)
          burst_counter <= burst_counter + 1;

        valid_wr <= ~clear_trans;
        
        trans_axi_araddr <= hash_address;
        if (trans_axi_rready && trans_axi_rvalid)
          lookup <= trans_axi_rdata;
        
        eval_out <= lookup_eval;
        depth_out <= lookup_depth;
        nodes_out <= lookup_nodes;
        capture_out <= lookup_capture;
        flag_out <= lookup_flag;
        hash_out <= hash;
     end

   always @(posedge clk)
     if (reset)
       begin
          state <= STATE_IDLE;
          trans_trans <= 0;
       end
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
              nodes <= nodes_in;
              capture <= capture_in;

              local_wvalid <= 0;
              trans_axi_awvalid <= 0;

              entry_store <= 0;
              entry_lookup <= 0;
              hash_only <= 0;
              clear_trans <= 0;
              start_data <= 0;
              if (entry_store_in && ~entry_store_in_z)
                begin
                   entry_store <= 1;
                   state <= STATE_HASH_0;
                end
              else if (entry_lookup_in && ~entry_lookup_in_z)
                begin
                   entry_lookup <= 1;
                   state <= STATE_HASH_0;
                end
              else if (hash_only_in && ~hash_only_in_z)
                begin
                   hash_only <= 1;
                   state <= STATE_HASH_0;
                end
              else if (clear_trans_in && ~clear_trans_in_z)
                begin
                   clear_trans <= 1;
                   state <= STATE_CLEAR_TRANS_INIT;
                end
           end
         STATE_CLEAR_TRANS_INIT :
           begin
              trans_trans <= trans_trans + 1;
              hash <= 0;
              trans_axi_awvalid <= 0;
              state <= STATE_CLEAR_TRANS;
           end
         STATE_CLEAR_TRANS :
           begin
              start_data <= 1;
              trans_axi_awvalid <= 1;
              if (trans_axi_awvalid && trans_axi_awready)
                if (hash >= TABLE_SIZE - 256)
                  begin
                     trans_axi_awvalid <= 0;
                     state <= STATE_TRANS_WAIT_DATA;
                  end
                else
                  hash <= hash + 256;
           end
         STATE_TRANS_WAIT_DATA :
           if (burst_counter >= BURST_TICK_TOTAL)
             state <= STATE_CLEAR_TRANS_DONE;
         STATE_CLEAR_TRANS_DONE :
           state <= STATE_IDLE;
         STATE_HASH_0 :
           begin
              for (i = 0; i < 64; i = i + 1)
                if (board[i * `PIECE_BITS+:`PIECE_BITS] != `EMPTY_POSN)
                  hash_0[i] <= zob_rand_board[zob_piece_lookup[board[i * `PIECE_BITS+:`PIECE_BITS]] << 6 | i];
                else
                  hash_0[i] <= 0;
              state <= STATE_HASH_1;
           end
         STATE_HASH_1 :
           begin
              for (i = 0; i < 16; i = i + 1)
                hash_1[i] <= hash_0[i * 4 + 0] ^ hash_0[i * 4 + 1] ^ hash_0[i * 4 + 2] ^ hash_0[i * 4 + 3];
              state <= STATE_HASH_2;
           end
         STATE_HASH_2 :
           begin
              for (i = 0; i < 4; i = i + 1)
                hash_2[i] <= hash_1[i * 4 + 0] ^ hash_1[i * 4 + 1] ^ hash_1[i * 4 + 2] ^ hash_1[i * 4 + 3];
              state <= STATE_HASH_3;
           end
         STATE_HASH_3 :
           begin
              if (white_to_move)
                hash_side <= hash_2[0] ^ hash_2[1] ^ hash_2[2] ^ hash_2[3];
              else
                hash_side <= hash_2[0] ^ hash_2[1] ^ hash_2[2] ^ hash_2[3] ^ zob_rand_btm;
              state <= STATE_HASH_4;
           end
         STATE_HASH_4 :
           begin
              trans_trans <= trans_trans + 1;
              hash <= hash_side ^ zob_rand_en_passant_col[en_passant_col] ^ zob_rand_castle_mask[castle_mask];
              if (entry_store)
                state <= STATE_STORE;
              else if (entry_lookup)
                state <= STATE_LOOKUP;
              else
                state <= STATE_IDLE; // hash_only
           end
         STATE_STORE :
           begin
              trans_axi_awvalid <= 1;
              local_wvalid <= 1;
              if (trans_axi_awvalid && trans_axi_awready && local_wvalid && trans_axi_wready)
                begin
                   local_wvalid <= 0;
                   trans_axi_awvalid <= 0;
                   state <= STATE_IDLE;
                end
              else if (trans_axi_awvalid && trans_axi_awready)
                begin
                   trans_axi_awvalid <= 0;
                   state <= STATE_STORE_WAIT_DATA;
                end
              else if (local_wvalid && trans_axi_wready)
                begin
                   local_wvalid <= 0;
                   state <= STATE_STORE_WAIT_ADDR;
                end
           end
         STATE_STORE_WAIT_DATA :
           if (trans_axi_wready)
             begin
                local_wvalid <= 0;
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
              entry_valid_out <= lookup_valid && lookup_hash[HASH_USED - 1:0] == hash[HASH_USED - 1:0];
              collision_out <= lookup_valid && lookup_hash[HASH_USED - 1:0] != hash[HASH_USED - 1:0];
              state <= STATE_IDLE;
           end
         default :
           state <= STATE_IDLE;
       endcase

   initial
     begin
        zob_piece_lookup[`WHITE_QUEN] =  0;
        zob_piece_lookup[`WHITE_ROOK] =  1;
        zob_piece_lookup[`WHITE_BISH] =  2;
        zob_piece_lookup[`WHITE_PAWN] =  3;
        zob_piece_lookup[`WHITE_KNIT] =  4;
        zob_piece_lookup[`WHITE_KING] =  5;
        zob_piece_lookup[`BLACK_QUEN] =  6;
        zob_piece_lookup[`BLACK_ROOK] =  7;
        zob_piece_lookup[`BLACK_BISH] =  8;
        zob_piece_lookup[`BLACK_PAWN] =  9;
        zob_piece_lookup[`BLACK_KNIT] = 10;
        zob_piece_lookup[`BLACK_KING] = 11;

        zob_rand_board[  0] = 'hc3a8fbbf9e7102cb133b;
        zob_rand_board[  1] = 'h64cbfd810893ba926f23;
        zob_rand_board[  2] = 'h342cf76e326740020c70;
        zob_rand_board[  3] = 'h86b109994d2d3fba5c7e;
        zob_rand_board[  4] = 'h667d7a88e824914c5090;
        zob_rand_board[  5] = 'h23954d8b605f750360f3;
        zob_rand_board[  6] = 'h4a8d25820097af68c447;
        zob_rand_board[  7] = 'h284563e754782b0d3457;
        zob_rand_board[  8] = 'hab14041d704fd46efd80;
        zob_rand_board[  9] = 'hc12e57c5ac2503b01b71;
        zob_rand_board[ 10] = 'he743f52647779c8f27f3;
        zob_rand_board[ 11] = 'h899ec0da638f1f96e17e;
        zob_rand_board[ 12] = 'h0a15a74180e4900d5f40;
        zob_rand_board[ 13] = 'hf4f7e3bab5a1d0ac2727;
        zob_rand_board[ 14] = 'h2bb92bff078aeb28a904;
        zob_rand_board[ 15] = 'h8f797c8021f51fe2a872;
        zob_rand_board[ 16] = 'he041cdcf930e0a854d87;
        zob_rand_board[ 17] = 'h2bae2daa85e3df8c3309;
        zob_rand_board[ 18] = 'hcbe7b18ef127b69ce710;
        zob_rand_board[ 19] = 'hcd63570b1588bc45c904;
        zob_rand_board[ 20] = 'hbca4c9856b115b0e198c;
        zob_rand_board[ 21] = 'h4f636e24d8468ce91724;
        zob_rand_board[ 22] = 'hb678df3ec8cea0925692;
        zob_rand_board[ 23] = 'hba78f341b4c8d64b3152;
        zob_rand_board[ 24] = 'h849624bb57ade9ecd2f0;
        zob_rand_board[ 25] = 'h4c13df75cf9bac625281;
        zob_rand_board[ 26] = 'hd179bdf0b4ec9a28bbbb;
        zob_rand_board[ 27] = 'h5bf1fbfcb7d56dff2edd;
        zob_rand_board[ 28] = 'h3ee94d492657b992751d;
        zob_rand_board[ 29] = 'hdf1eb261cdb6c3685fc7;
        zob_rand_board[ 30] = 'hd171fd43b5ed4e3c14fe;
        zob_rand_board[ 31] = 'h0f97d930e445f71d510d;
        zob_rand_board[ 32] = 'he034c132f944a15cb5ad;
        zob_rand_board[ 33] = 'h0644890729c15de28425;
        zob_rand_board[ 34] = 'h59e087e2a5c53192641d;
        zob_rand_board[ 35] = 'hddfc641e757f4b4662c1;
        zob_rand_board[ 36] = 'h71d43deb5ceb58208ea6;
        zob_rand_board[ 37] = 'h3ef91bc5d73f5bed01d6;
        zob_rand_board[ 38] = 'h36b1682ed60de5873a88;
        zob_rand_board[ 39] = 'h37783d27b947d49023f4;
        zob_rand_board[ 40] = 'h4e084eb44dde6b7cec6d;
        zob_rand_board[ 41] = 'h1e8dd7dcab4be7c31027;
        zob_rand_board[ 42] = 'h4ece78599ec9fe730d35;
        zob_rand_board[ 43] = 'h599f0267f01c16b249bd;
        zob_rand_board[ 44] = 'h2c34f258348363457112;
        zob_rand_board[ 45] = 'h87813823fa0b48cd2c0e;
        zob_rand_board[ 46] = 'h2542cbed865299bc95f2;
        zob_rand_board[ 47] = 'h281692406dd88c2ded8b;
        zob_rand_board[ 48] = 'h3f7f470048b9023ac99e;
        zob_rand_board[ 49] = 'hb61750432ea3ff0055ad;
        zob_rand_board[ 50] = 'h4101db2d96a131f345d8;
        zob_rand_board[ 51] = 'he28986596f08021cd0e8;
        zob_rand_board[ 52] = 'h4e92b92a48d4399987bb;
        zob_rand_board[ 53] = 'h89f0c9de94642aad84ec;
        zob_rand_board[ 54] = 'he88c8a7c3d31118351a0;
        zob_rand_board[ 55] = 'hcba16d367ef7b0d86fa5;
        zob_rand_board[ 56] = 'h0f3248154ba4c91bac08;
        zob_rand_board[ 57] = 'h9faabbb8079c20ccfc5b;
        zob_rand_board[ 58] = 'h66fdc7f7e5c65e0df83f;
        zob_rand_board[ 59] = 'h4704a6464ab3a23afb53;
        zob_rand_board[ 60] = 'h397c09cae35d65af838a;
        zob_rand_board[ 61] = 'hab22ca45022c69ced706;
        zob_rand_board[ 62] = 'hc03ca25674109111473b;
        zob_rand_board[ 63] = 'ha7cf75af4c973831b5fe;
        zob_rand_board[ 64] = 'hce4a662cc96ed2e07566;
        zob_rand_board[ 65] = 'h488b907a28435fac76e2;
        zob_rand_board[ 66] = 'haa056fea55bc7a9d091b;
        zob_rand_board[ 67] = 'h17a854b565ce47c4c8d9;
        zob_rand_board[ 68] = 'hd9e69153c7d5bdef52d2;
        zob_rand_board[ 69] = 'hae2058da7b381b40aac0;
        zob_rand_board[ 70] = 'hf377b103993c292f6a52;
        zob_rand_board[ 71] = 'h5dc96a2dbfdbd8650725;
        zob_rand_board[ 72] = 'h8dd7f0c8c84e55506a8d;
        zob_rand_board[ 73] = 'h943fb087a6b657098df0;
        zob_rand_board[ 74] = 'hc9fb2b3123da73da0a05;
        zob_rand_board[ 75] = 'h8967fb5f4a74b02362bd;
        zob_rand_board[ 76] = 'hfb41da0c01a5633a77f0;
        zob_rand_board[ 77] = 'h2d5be896a71107f13f60;
        zob_rand_board[ 78] = 'ha4f88c909dc976f89b05;
        zob_rand_board[ 79] = 'hfaecebc39c5c860201ed;
        zob_rand_board[ 80] = 'h890350cd316c6eeb9210;
        zob_rand_board[ 81] = 'h91177c17b540b056097c;
        zob_rand_board[ 82] = 'hc0972406965b792206f6;
        zob_rand_board[ 83] = 'hb18b276108e4f45dbce4;
        zob_rand_board[ 84] = 'hefadc6988aaf4bb2c262;
        zob_rand_board[ 85] = 'hcb7c34d782b4a72d8ed1;
        zob_rand_board[ 86] = 'h6e8fa12a00f012cbfcb1;
        zob_rand_board[ 87] = 'h48edc92748242b784bcc;
        zob_rand_board[ 88] = 'h27b7f9a1030355531c17;
        zob_rand_board[ 89] = 'hed02898ed4c95b3c8365;
        zob_rand_board[ 90] = 'h02e7a4da71c0afad3139;
        zob_rand_board[ 91] = 'h89a5da05993da3b3c0b7;
        zob_rand_board[ 92] = 'ha47141579753bbd8a575;
        zob_rand_board[ 93] = 'had66e295fa0b9d2f734a;
        zob_rand_board[ 94] = 'hea9fd7484f9e201b28e5;
        zob_rand_board[ 95] = 'ha0e9a67d817fd50d04f9;
        zob_rand_board[ 96] = 'hb195674c678f0b719089;
        zob_rand_board[ 97] = 'h221c5d18fe86997a0f6d;
        zob_rand_board[ 98] = 'h211e4db2ad8670beb477;
        zob_rand_board[ 99] = 'hecf08bbe49753e2d6e89;
        zob_rand_board[100] = 'hbba3a56e11ee0d147289;
        zob_rand_board[101] = 'h61ceb25d9ed5346ea01d;
        zob_rand_board[102] = 'h0ab1a95d6720b66b726d;
        zob_rand_board[103] = 'h370e0de304330514271a;
        zob_rand_board[104] = 'h32643d05b26a5a83d4e4;
        zob_rand_board[105] = 'h9f5526df0ac665d1bb13;
        zob_rand_board[106] = 'hbada5b04edecc8f07b53;
        zob_rand_board[107] = 'hdf589b3e267a82639c5b;
        zob_rand_board[108] = 'h59fc46d821db5abc0ffc;
        zob_rand_board[109] = 'h1113ea725f04faaf8457;
        zob_rand_board[110] = 'hcd5803959c696cf9213b;
        zob_rand_board[111] = 'h4a8a49fa64b4b86d0356;
        zob_rand_board[112] = 'h6e7415756f203eaa3e20;
        zob_rand_board[113] = 'hc8ef732d57f7f71451be;
        zob_rand_board[114] = 'he6327e7440f4921835d7;
        zob_rand_board[115] = 'h828cd7e72f58b1f3112b;
        zob_rand_board[116] = 'h78ba680885adeb09aeba;
        zob_rand_board[117] = 'h140208acce273879f8b2;
        zob_rand_board[118] = 'hb89b4e06a1424073fda4;
        zob_rand_board[119] = 'ha887507073a4e2698391;
        zob_rand_board[120] = 'hca4915cdcc34b048b083;
        zob_rand_board[121] = 'hf1b8b6f0a9ee9a54445f;
        zob_rand_board[122] = 'h49033270595f0d2abc27;
        zob_rand_board[123] = 'h5b19590800d04043cee1;
        zob_rand_board[124] = 'h63c15fa7eb7624ed9dd1;
        zob_rand_board[125] = 'hf3f23b557fa9c50dfd7e;
        zob_rand_board[126] = 'h452fb8191777884d91fc;
        zob_rand_board[127] = 'h0b8c9cd28806854705d9;
        zob_rand_board[128] = 'hbd01098958c4f9280d06;
        zob_rand_board[129] = 'h6a0b700375bc44dc7769;
        zob_rand_board[130] = 'h801a42499e37f2a9e85d;
        zob_rand_board[131] = 'hb9b3cb1f29dd580cc6c2;
        zob_rand_board[132] = 'hfb9c1d3a846a62379e8f;
        zob_rand_board[133] = 'hf044d057498b6d6dd9a2;
        zob_rand_board[134] = 'h9f3859e5d58355240948;
        zob_rand_board[135] = 'h3732667cbe3df5be1373;
        zob_rand_board[136] = 'h5b95f1d024244709dc88;
        zob_rand_board[137] = 'h44887d05f783b147b9b4;
        zob_rand_board[138] = 'h61c544eb815576dfe98c;
        zob_rand_board[139] = 'h05629b02fb3342c86cf2;
        zob_rand_board[140] = 'h87aebcde006a035b98df;
        zob_rand_board[141] = 'ha459b21eddaf04e7b017;
        zob_rand_board[142] = 'h2407dc8cba5a9ff5759e;
        zob_rand_board[143] = 'h6abbae3796827935a310;
        zob_rand_board[144] = 'h2d86bb157a30a2b9549f;
        zob_rand_board[145] = 'h8d2af47741f19b43a7a1;
        zob_rand_board[146] = 'hfa94697a0575aad257ca;
        zob_rand_board[147] = 'h708046256d0ff65217b9;
        zob_rand_board[148] = 'h5502ba034985e2227358;
        zob_rand_board[149] = 'h8e8c9f401edeb58f96b1;
        zob_rand_board[150] = 'he8474d0306de250745e9;
        zob_rand_board[151] = 'h12e83a1443e2a8c5b7dc;
        zob_rand_board[152] = 'h12f9a6471066d0501511;
        zob_rand_board[153] = 'h454aeb2c4fdd6208c361;
        zob_rand_board[154] = 'h7417903f0c04d1bcf71a;
        zob_rand_board[155] = 'hb47257be1adb7dd2f027;
        zob_rand_board[156] = 'hf2bc0cfc4070c9df1ffb;
        zob_rand_board[157] = 'he823e036864c194ddee7;
        zob_rand_board[158] = 'h8d2855443e4a80dc6247;
        zob_rand_board[159] = 'h1c0f05b6909210d876ca;
        zob_rand_board[160] = 'h19e4ee5fb7343959bb98;
        zob_rand_board[161] = 'h121d6c73be54124988a9;
        zob_rand_board[162] = 'h82ec5b7ba9693c0a16fa;
        zob_rand_board[163] = 'h9eb36885386d1028944d;
        zob_rand_board[164] = 'he5c3c8a45ddda03b4c04;
        zob_rand_board[165] = 'hcf45d2a2604965a11395;
        zob_rand_board[166] = 'h9f515f47b38feaabeef0;
        zob_rand_board[167] = 'h156b52cc16de4766262a;
        zob_rand_board[168] = 'h1e5047167e019790f0da;
        zob_rand_board[169] = 'hf78e63e0b54755c3ba26;
        zob_rand_board[170] = 'hf93878dd8e37288225f0;
        zob_rand_board[171] = 'haac8c2797c7f9f70906c;
        zob_rand_board[172] = 'h8f9809aa3587c29e7692;
        zob_rand_board[173] = 'h2f2483442507c627bc2d;
        zob_rand_board[174] = 'h4742e560fb9afa03d17e;
        zob_rand_board[175] = 'hc7acb4367b6388a50c09;
        zob_rand_board[176] = 'h51a8014153f2e28cc0b5;
        zob_rand_board[177] = 'hc28d9ea2225e3b6e2361;
        zob_rand_board[178] = 'h7c3d32f334c33d59ec4f;
        zob_rand_board[179] = 'h004f2a27a541138d0ae5;
        zob_rand_board[180] = 'h450d346528e6644f7135;
        zob_rand_board[181] = 'hfe662e8535ee64aa36f1;
        zob_rand_board[182] = 'he67c7b0a6f6a7e1ffc9f;
        zob_rand_board[183] = 'h71d854f8230bc2681b9b;
        zob_rand_board[184] = 'h1038bcb927b2a1bccf66;
        zob_rand_board[185] = 'h29f42ce77392224a8186;
        zob_rand_board[186] = 'h662cb6c8c3ee809675cb;
        zob_rand_board[187] = 'h7bcb6247264c0b5a15b3;
        zob_rand_board[188] = 'hd18017f8df7c5035d645;
        zob_rand_board[189] = 'ha5171099204fc82e2fee;
        zob_rand_board[190] = 'h532fe07afe1ff47e331d;
        zob_rand_board[191] = 'hda02aa6e4b15c9fa31e6;
        zob_rand_board[192] = 'hac8133b77caea939703c;
        zob_rand_board[193] = 'he26c454c658c303eb21b;
        zob_rand_board[194] = 'h8c4237bb5649e39409e6;
        zob_rand_board[195] = 'heb0b7ed841a4df513e86;
        zob_rand_board[196] = 'hda80a6f7985c08779926;
        zob_rand_board[197] = 'h6c4c1090d93cd6ce074d;
        zob_rand_board[198] = 'hf8b02a5b63e7f703c8a8;
        zob_rand_board[199] = 'h5f576d1c482a0e4d307c;
        zob_rand_board[200] = 'h7504c3f5ebdd8a76dfb7;
        zob_rand_board[201] = 'h2db39b55bad667043156;
        zob_rand_board[202] = 'hd6434c2d97c8d6d743ef;
        zob_rand_board[203] = 'h252c0c8f22f4116e76a0;
        zob_rand_board[204] = 'hbb2b180743603e327d0c;
        zob_rand_board[205] = 'h2ca0a49a878c61ce9bef;
        zob_rand_board[206] = 'hbfd6e14cbcad58c951e6;
        zob_rand_board[207] = 'h4030d8de7cf7e519d727;
        zob_rand_board[208] = 'hb69e76f008ecb00056e3;
        zob_rand_board[209] = 'h5e0b57ce7963462d5974;
        zob_rand_board[210] = 'hc1937cfbdc010dacca70;
        zob_rand_board[211] = 'he184a4319fe23ea93b64;
        zob_rand_board[212] = 'hddcafbc1bd3bda08919d;
        zob_rand_board[213] = 'h0b35edb01950f86f8ab0;
        zob_rand_board[214] = 'h2d9c4afe0c5208b47aa7;
        zob_rand_board[215] = 'h09b644f7deb6832b224a;
        zob_rand_board[216] = 'ha39ed8ea535158b6b720;
        zob_rand_board[217] = 'h6f3f5deb3bd02152e7e1;
        zob_rand_board[218] = 'hd93efc929508628e9525;
        zob_rand_board[219] = 'h40887b4e9f72d45b5909;
        zob_rand_board[220] = 'h41c2970a915bc1cda627;
        zob_rand_board[221] = 'h4493ff32e5b67a49de92;
        zob_rand_board[222] = 'hfffe2005b5da204c302b;
        zob_rand_board[223] = 'hc8240ee9a9e7637332a1;
        zob_rand_board[224] = 'h89c619193a76055d2eb4;
        zob_rand_board[225] = 'ha133d6e80bd421a7ab64;
        zob_rand_board[226] = 'hb02f310405aff6429f59;
        zob_rand_board[227] = 'h8a528a311f1940fa716d;
        zob_rand_board[228] = 'hf8e2366f455cb4946246;
        zob_rand_board[229] = 'hd9cb463105b0b4d68a01;
        zob_rand_board[230] = 'h1165212b94dcc6e2d95d;
        zob_rand_board[231] = 'h54da4ffbe0d084bcc87d;
        zob_rand_board[232] = 'hb0aac200bff32d0fa7f9;
        zob_rand_board[233] = 'h84d17f2976d467dd95d6;
        zob_rand_board[234] = 'h72c9fb3123437c51dcba;
        zob_rand_board[235] = 'hfd4918bd07d1121ab9df;
        zob_rand_board[236] = 'hcf9cf3796f8cdf4bfb2c;
        zob_rand_board[237] = 'h9b51909871bfdd524b8f;
        zob_rand_board[238] = 'haa58dbb60ef2ce285aa9;
        zob_rand_board[239] = 'ha5ccf146563c4c487969;
        zob_rand_board[240] = 'h06a424fd153f89a7c49a;
        zob_rand_board[241] = 'h2aefef39dbbe56b60343;
        zob_rand_board[242] = 'h1e99d500ac9748b53e48;
        zob_rand_board[243] = 'h6a49a6742e1906d669a6;
        zob_rand_board[244] = 'hb65af7af3b4c4846e105;
        zob_rand_board[245] = 'h5fae50aa3bc13998faea;
        zob_rand_board[246] = 'h6deb04028c985847401a;
        zob_rand_board[247] = 'haca75775d746bda9f27c;
        zob_rand_board[248] = 'hb9e13e67d1f41c865cb0;
        zob_rand_board[249] = 'h633063788366e418c575;
        zob_rand_board[250] = 'hcc8451167a60a709fc75;
        zob_rand_board[251] = 'hc3510ab7926bc88d1556;
        zob_rand_board[252] = 'heb72013ed2a853dadcd5;
        zob_rand_board[253] = 'hd7b1b10ac7a426a756ea;
        zob_rand_board[254] = 'hd6bb04261d803fd6b99c;
        zob_rand_board[255] = 'hdcca3e428eb229e95d48;
        zob_rand_board[256] = 'hbc89432e069ae614d1e4;
        zob_rand_board[257] = 'hdd5ed970c3296379ceef;
        zob_rand_board[258] = 'h3ec1dbbeaae507a8aff6;
        zob_rand_board[259] = 'h42064b7b5f7e26a888e3;
        zob_rand_board[260] = 'h36bc7f0de96e1917298d;
        zob_rand_board[261] = 'h6b0a7400437f8949d32a;
        zob_rand_board[262] = 'h7a9e81f9e83d37bb12e9;
        zob_rand_board[263] = 'h14c9e29f37a83f075315;
        zob_rand_board[264] = 'hd68e12f39b8a887d5e76;
        zob_rand_board[265] = 'hffe02d5b2b8e307422c8;
        zob_rand_board[266] = 'hb9f2e6d49effcd2016d5;
        zob_rand_board[267] = 'h085982f0786275a70762;
        zob_rand_board[268] = 'h4901ef0e295d55f2c98f;
        zob_rand_board[269] = 'h8dd079b2987c7af97f0b;
        zob_rand_board[270] = 'h6b545a972cfe94be4400;
        zob_rand_board[271] = 'hc59ed095b9a099e078e1;
        zob_rand_board[272] = 'hf16baee593657178af7f;
        zob_rand_board[273] = 'h590952cc4b35bad7c889;
        zob_rand_board[274] = 'hbe9b3d78d5cf8bb593fb;
        zob_rand_board[275] = 'h746a847b4a51f999cd89;
        zob_rand_board[276] = 'ha8c4801666705ba30d8a;
        zob_rand_board[277] = 'h7b6dc727e5106447cac6;
        zob_rand_board[278] = 'hbc78321c4bed020e296a;
        zob_rand_board[279] = 'h3311e301a6e4a1fbb0b6;
        zob_rand_board[280] = 'h7f862b59ad9fadecf42b;
        zob_rand_board[281] = 'h75362e37fc4ca51911c6;
        zob_rand_board[282] = 'h670c9126043e551c8446;
        zob_rand_board[283] = 'hdd942c6200372385da95;
        zob_rand_board[284] = 'hd74c3e84dd4bb2445bf6;
        zob_rand_board[285] = 'hf081450c5ebff0292e6d;
        zob_rand_board[286] = 'h4c94ef8fccfe63e6a4e6;
        zob_rand_board[287] = 'h0c6ba188beef6c289e50;
        zob_rand_board[288] = 'h21b11a4374956a717c20;
        zob_rand_board[289] = 'h18f18a936e7db1c33186;
        zob_rand_board[290] = 'h13654d05e96a7bd5aaec;
        zob_rand_board[291] = 'h3d4dbca7c4f294c178db;
        zob_rand_board[292] = 'h4473e6388c37d1049096;
        zob_rand_board[293] = 'h869bbbbb0143396dc5ce;
        zob_rand_board[294] = 'haddf9841555fa1deb7c6;
        zob_rand_board[295] = 'h202fbbe6fd1028e65815;
        zob_rand_board[296] = 'hcf1a5ad5d1893359e6c7;
        zob_rand_board[297] = 'h1387912a7bfb7e732a41;
        zob_rand_board[298] = 'hdd4e6e0c133c7b0bfc86;
        zob_rand_board[299] = 'h2c4c64144316d39ee8c3;
        zob_rand_board[300] = 'h31d6d847711bdb53f36a;
        zob_rand_board[301] = 'h8b4bcbc1da46a9419ab2;
        zob_rand_board[302] = 'h0e46d23f82540e58d8e7;
        zob_rand_board[303] = 'h639904e11f3e0bd889bb;
        zob_rand_board[304] = 'h84beae5395398ad60dc8;
        zob_rand_board[305] = 'ha6398ee7d751aa273230;
        zob_rand_board[306] = 'h18213334e1c8f0c8e84d;
        zob_rand_board[307] = 'h852c463de1c0840465af;
        zob_rand_board[308] = 'h6ad627553e7986ce1ba9;
        zob_rand_board[309] = 'h6a6421502163cfb7d4eb;
        zob_rand_board[310] = 'h0fdda80247e06376eca3;
        zob_rand_board[311] = 'h32f5d7dc968f3f89c189;
        zob_rand_board[312] = 'h0c465d66f602c3c4cdc8;
        zob_rand_board[313] = 'hbffd0c654ab51422ad9a;
        zob_rand_board[314] = 'hcc5a7835bda90d7c6704;
        zob_rand_board[315] = 'h2b1cc58cab9ec5f5c8ec;
        zob_rand_board[316] = 'h7ccfb2cff574d5ef8ec1;
        zob_rand_board[317] = 'h29bcf066336edaf47361;
        zob_rand_board[318] = 'he4f13c732df520716fd4;
        zob_rand_board[319] = 'h45384dbd52f26be6a5d7;
        zob_rand_board[320] = 'h7409a5f01b0677f57da5;
        zob_rand_board[321] = 'hb5f64b1665dd8e3c8477;
        zob_rand_board[322] = 'h6fcdac5b1aad0b985604;
        zob_rand_board[323] = 'had44612b695f6cfb2ee3;
        zob_rand_board[324] = 'h5debfe8fce226f972ba7;
        zob_rand_board[325] = 'h45dbf054ff03699bb037;
        zob_rand_board[326] = 'h2fca6c2aa6c788539dec;
        zob_rand_board[327] = 'hcc0026677d9222c0ee79;
        zob_rand_board[328] = 'hf7e14f7e14b2ba8ab910;
        zob_rand_board[329] = 'h18a537d122ec04722772;
        zob_rand_board[330] = 'hb87271b42d105c8cc50c;
        zob_rand_board[331] = 'ha0760472886b6d318b73;
        zob_rand_board[332] = 'hcee4b1b318b20de7d1e5;
        zob_rand_board[333] = 'hdd53ed9da105f88dab3f;
        zob_rand_board[334] = 'h5cad8cad244d344e7278;
        zob_rand_board[335] = 'ha4f1ef8e41b413ae98af;
        zob_rand_board[336] = 'haad9f74cef948e375375;
        zob_rand_board[337] = 'he23cbd4da4b0ef8ff4c0;
        zob_rand_board[338] = 'h4c243ac325d67b44e61d;
        zob_rand_board[339] = 'h2df3e5b3ed88a3ba3b52;
        zob_rand_board[340] = 'h08b17a3094a76b133087;
        zob_rand_board[341] = 'h478353851b9e81836fa5;
        zob_rand_board[342] = 'h80ff242da59994ab4570;
        zob_rand_board[343] = 'h294624c12b4097dc094c;
        zob_rand_board[344] = 'h4a7f2e3ae2a5c02beaff;
        zob_rand_board[345] = 'h7b844c8e55f199d6114a;
        zob_rand_board[346] = 'h829707012778ea2a645c;
        zob_rand_board[347] = 'hce71815f9a713cbaa0d1;
        zob_rand_board[348] = 'h8a59db7f31869acb0039;
        zob_rand_board[349] = 'h2905a9521abbdf4c7581;
        zob_rand_board[350] = 'h63bc328e3470bceebda6;
        zob_rand_board[351] = 'hb7d5ae64ecb8ecd2d9e1;
        zob_rand_board[352] = 'ha832c71f95e20d63db4f;
        zob_rand_board[353] = 'h71bd3810cc7b007a95e5;
        zob_rand_board[354] = 'he3f508157f6719621837;
        zob_rand_board[355] = 'hd5b6486ab63ebcca3bf4;
        zob_rand_board[356] = 'hd302d1edc2755d35e3a7;
        zob_rand_board[357] = 'hf4b21784227603aee571;
        zob_rand_board[358] = 'h344b75232ffd77568d42;
        zob_rand_board[359] = 'h770e1c9ade789ae48d77;
        zob_rand_board[360] = 'h4725d4774ce2a1390f3f;
        zob_rand_board[361] = 'h9eca6e2cf63582bab81c;
        zob_rand_board[362] = 'h7e1fe253dae5a4589bd3;
        zob_rand_board[363] = 'hb06d383bb647ff863525;
        zob_rand_board[364] = 'h69dce4b98374c8a65da5;
        zob_rand_board[365] = 'h4776cedfca2283eefc72;
        zob_rand_board[366] = 'h25ba2631d2624dcc3ae8;
        zob_rand_board[367] = 'he0072243eb117891564b;
        zob_rand_board[368] = 'hf674797087af122338b4;
        zob_rand_board[369] = 'hb24e1603ff145c91edc7;
        zob_rand_board[370] = 'h1c89a495dbd0f3129bc9;
        zob_rand_board[371] = 'hc017d14e75b691a7adb3;
        zob_rand_board[372] = 'h87de770026535fe649ad;
        zob_rand_board[373] = 'h2eaba6c9607d0e3eeaf0;
        zob_rand_board[374] = 'h330b5136f53cfa81ca0a;
        zob_rand_board[375] = 'hcd3b15d6ddf34c771cc9;
        zob_rand_board[376] = 'h70b14814e55aa4e586ed;
        zob_rand_board[377] = 'h27990e0f4438c6d62597;
        zob_rand_board[378] = 'h2a3900b987230fa874d3;
        zob_rand_board[379] = 'h7fb7a6e3e87088ef98d7;
        zob_rand_board[380] = 'h889271dfa7f34de8bd33;
        zob_rand_board[381] = 'ha2555f8948aa958200d7;
        zob_rand_board[382] = 'h87740875a4ddbd7fdddd;
        zob_rand_board[383] = 'hf26b9cef9ade57162153;
        zob_rand_board[384] = 'hfdb7ef2ed8706a09214b;
        zob_rand_board[385] = 'h3445e1f7a4fda4f32f4a;
        zob_rand_board[386] = 'h3d0719cf223bef3bd4c1;
        zob_rand_board[387] = 'h28b7ae10a014b34b3464;
        zob_rand_board[388] = 'h6b2376ddc501527f3f1a;
        zob_rand_board[389] = 'h6b91469e15658c02f2fb;
        zob_rand_board[390] = 'h10f7bb446b47e9a0bbde;
        zob_rand_board[391] = 'h419379d4a1699158d26e;
        zob_rand_board[392] = 'h1d37ff996ff84f305536;
        zob_rand_board[393] = 'hb659c6a062982ef4c9c6;
        zob_rand_board[394] = 'h59f2d033691c011caba0;
        zob_rand_board[395] = 'h294e87d702a819a26b0a;
        zob_rand_board[396] = 'hd06c5bc7646a96bcf8aa;
        zob_rand_board[397] = 'hbda5c35a57af1b8e84be;
        zob_rand_board[398] = 'h099828c20eff0fa93729;
        zob_rand_board[399] = 'ha6da5fb8c2280bd22bef;
        zob_rand_board[400] = 'h82fa88936fb1c3fcb6f2;
        zob_rand_board[401] = 'h50d7fa8b0c47d461b064;
        zob_rand_board[402] = 'he59ee0764e85c73c18ff;
        zob_rand_board[403] = 'h5d26cc5677127212bbf4;
        zob_rand_board[404] = 'h36d18b49dc95171e7bd1;
        zob_rand_board[405] = 'h810736078e61c35171be;
        zob_rand_board[406] = 'h65cd5de049a02078ec6d;
        zob_rand_board[407] = 'heb5c271cee4cdd80563b;
        zob_rand_board[408] = 'h976d1af62a4b6d378a10;
        zob_rand_board[409] = 'h74505cb09919c83d4771;
        zob_rand_board[410] = 'hee7a6871d5fcac1f72a1;
        zob_rand_board[411] = 'hff1aa6985322d3f272a5;
        zob_rand_board[412] = 'h2ffb5a079659f75ed9de;
        zob_rand_board[413] = 'hf6a5583f7185cd903465;
        zob_rand_board[414] = 'h81250fb1fa1ee081d588;
        zob_rand_board[415] = 'h6b4c88b1cc691adecca3;
        zob_rand_board[416] = 'hd6791e343e7c53e12c35;
        zob_rand_board[417] = 'hfbaf924811506d39bc78;
        zob_rand_board[418] = 'h2dcd11a8937c97d91071;
        zob_rand_board[419] = 'h7db7ae20753df6f9d880;
        zob_rand_board[420] = 'he990840550085f7161a7;
        zob_rand_board[421] = 'hf07390f99531b3df938e;
        zob_rand_board[422] = 'h82b131755088ce205f00;
        zob_rand_board[423] = 'h28ab35bf11750f646906;
        zob_rand_board[424] = 'hf486505af6deaa4b965a;
        zob_rand_board[425] = 'h01845813068e8a39c10e;
        zob_rand_board[426] = 'h2f8ac57c7278785dcb85;
        zob_rand_board[427] = 'h5ae0f091f196f96c0ff0;
        zob_rand_board[428] = 'hdfc23effa57c48cc1247;
        zob_rand_board[429] = 'h6fca99530dc3ec32be60;
        zob_rand_board[430] = 'h0119275b06a95dc53c7c;
        zob_rand_board[431] = 'h77abe5224bf66b4762f5;
        zob_rand_board[432] = 'h56e63ca088a3837a19c2;
        zob_rand_board[433] = 'h89397d2c385baa5da775;
        zob_rand_board[434] = 'h354ce1974996a63d83c6;
        zob_rand_board[435] = 'ha01fceb411ba8cd1b105;
        zob_rand_board[436] = 'ha6e8bc883c5b9b2751b7;
        zob_rand_board[437] = 'h12724b9910775863d0c4;
        zob_rand_board[438] = 'h8efcea21360477a0a66b;
        zob_rand_board[439] = 'hf2b7ad8cc76299a53f49;
        zob_rand_board[440] = 'h78ab0afddffa389fdd8d;
        zob_rand_board[441] = 'h3d327aa6910fbebeb2aa;
        zob_rand_board[442] = 'h9eba73c83a7c0cc4873a;
        zob_rand_board[443] = 'hf5e5930bc4f4976cdb09;
        zob_rand_board[444] = 'h54b3b4812ff220a25d04;
        zob_rand_board[445] = 'h48c8344b85cfa7d0c113;
        zob_rand_board[446] = 'h8ed475a902b43e9d195c;
        zob_rand_board[447] = 'h59164bd34af425dae082;
        zob_rand_board[448] = 'h9535e94ec852b74d4b49;
        zob_rand_board[449] = 'hca233e60f85d13fc8fe3;
        zob_rand_board[450] = 'h176a70456162f90ca83c;
        zob_rand_board[451] = 'h462e5c89d8f76f424bfb;
        zob_rand_board[452] = 'h34ac90df4eff4efa2f5b;
        zob_rand_board[453] = 'h54ab2d6b1ad77720511f;
        zob_rand_board[454] = 'haa7f4d9414de2411bf37;
        zob_rand_board[455] = 'h34453ec4acc73182e0d1;
        zob_rand_board[456] = 'h7896ae0f285174055a21;
        zob_rand_board[457] = 'h428a14f5bcc9ae648cb0;
        zob_rand_board[458] = 'h407d1dc530bca658a331;
        zob_rand_board[459] = 'h036a8d15b3b504f585ea;
        zob_rand_board[460] = 'heaeec6b1323dadbf30cd;
        zob_rand_board[461] = 'h1c86d2b80f5a4d430f13;
        zob_rand_board[462] = 'h80ecd37c18385eda2c73;
        zob_rand_board[463] = 'he0fc9d6b62013160f1e8;
        zob_rand_board[464] = 'h76018eb8e275790902b2;
        zob_rand_board[465] = 'h0ced0db7965dab5d4c37;
        zob_rand_board[466] = 'h72a7125388cdc637f42d;
        zob_rand_board[467] = 'h94c149a71ee4b910146c;
        zob_rand_board[468] = 'h28f2caa73523054eb689;
        zob_rand_board[469] = 'h04e8254a93f44d24312d;
        zob_rand_board[470] = 'h0f671ca5e1845a1dea5b;
        zob_rand_board[471] = 'heba41eddf9668174ce55;
        zob_rand_board[472] = 'h8422d080b1fbaa5c4c00;
        zob_rand_board[473] = 'h0fbafe4f39da2304c9ee;
        zob_rand_board[474] = 'h7c8bbf966e1fc896c8e2;
        zob_rand_board[475] = 'hf313e5449e8c7c5bb1c8;
        zob_rand_board[476] = 'hafaea8e3047b931dbc1a;
        zob_rand_board[477] = 'hd49df4b28700124e90e4;
        zob_rand_board[478] = 'h3272d36cb53904cbbe6f;
        zob_rand_board[479] = 'hfda96bf2e036889fa14c;
        zob_rand_board[480] = 'h1fcde3539cc15f4cb372;
        zob_rand_board[481] = 'h35348c4b1759b0d00324;
        zob_rand_board[482] = 'ha48ff561b4d86ebb1f0c;
        zob_rand_board[483] = 'hde0e88221ca4a5f8ffc6;
        zob_rand_board[484] = 'h4ac27369023e6886a89e;
        zob_rand_board[485] = 'h7ce748df613aab056330;
        zob_rand_board[486] = 'h69dfc9d02018fab5d890;
        zob_rand_board[487] = 'hdef5d33004921d592a43;
        zob_rand_board[488] = 'hb83b821e6bc461252ce9;
        zob_rand_board[489] = 'hb20a4ce2eb148e9f4560;
        zob_rand_board[490] = 'hcf751a8cd0dd56c1c16b;
        zob_rand_board[491] = 'ha31077f6d3da5c2b8921;
        zob_rand_board[492] = 'hc2ff0cdae55e31957580;
        zob_rand_board[493] = 'h50838fc3ed9cfe6e516d;
        zob_rand_board[494] = 'h1c2d2d7cdc51de1b121f;
        zob_rand_board[495] = 'h834d784acdfdccb2e30e;
        zob_rand_board[496] = 'h3ad00b0f6297f70136b1;
        zob_rand_board[497] = 'h6ce40aea625682e87dea;
        zob_rand_board[498] = 'he159d82703cdc7c96e76;
        zob_rand_board[499] = 'h0d640d1d44b861935807;
        zob_rand_board[500] = 'h1f9659298e5c02721e2d;
        zob_rand_board[501] = 'h2c4dff6b45030c0f0351;
        zob_rand_board[502] = 'h15dccc726a39feed7ba6;
        zob_rand_board[503] = 'he67e37bd324a9f65fa1e;
        zob_rand_board[504] = 'h0d2bac9e14a2a5ab3ede;
        zob_rand_board[505] = 'h1907f526247afa1a44d9;
        zob_rand_board[506] = 'h08bba5cb114bb167dc98;
        zob_rand_board[507] = 'h4453481e91b05994033f;
        zob_rand_board[508] = 'h6cd03b468da9511e3a56;
        zob_rand_board[509] = 'h7046ba61df8ba4f43f71;
        zob_rand_board[510] = 'ha50375a7cd6943e5aa79;
        zob_rand_board[511] = 'h1870f8de54f240f49cd4;
        zob_rand_board[512] = 'h8c3ffb9e54169928a82f;
        zob_rand_board[513] = 'hfdaf92306f8fa2c686b9;
        zob_rand_board[514] = 'h4a76c98cb93b7a248c44;
        zob_rand_board[515] = 'h9894ecd5c2f975f6c9a8;
        zob_rand_board[516] = 'hca4f26d5a4e526d4112a;
        zob_rand_board[517] = 'h6fb938daaea941eb45d6;
        zob_rand_board[518] = 'hd422903dd90a0bf97ff7;
        zob_rand_board[519] = 'hc1a384b178f6221e25a6;
        zob_rand_board[520] = 'h9175db9a753534c38646;
        zob_rand_board[521] = 'h18c35a0a134bd3afbf27;
        zob_rand_board[522] = 'hd2caf8495ac41bf32bdf;
        zob_rand_board[523] = 'h7c9fde57e083f63cf864;
        zob_rand_board[524] = 'he45fc1a173f3d25b6082;
        zob_rand_board[525] = 'h3a4c6ffcbdcb3af5842b;
        zob_rand_board[526] = 'h14c758f8a0334f6817c9;
        zob_rand_board[527] = 'ha23371d3e34df8363d15;
        zob_rand_board[528] = 'h54f02257664e9a7c4807;
        zob_rand_board[529] = 'hbfa7e1611b2b4e9e11ad;
        zob_rand_board[530] = 'h23d5f4d75ff5598ede25;
        zob_rand_board[531] = 'h848cfca3f9b94fe551fa;
        zob_rand_board[532] = 'hcd8097dee2b4c6444fa4;
        zob_rand_board[533] = 'he42e89d901f94083fc5e;
        zob_rand_board[534] = 'h51576e37e2f35bd3d32d;
        zob_rand_board[535] = 'h1f72d8bb5814e27dd06f;
        zob_rand_board[536] = 'h5e18be1fe571c892e6d0;
        zob_rand_board[537] = 'h930bbe57e4323170a940;
        zob_rand_board[538] = 'hef81139c8a613153c3a2;
        zob_rand_board[539] = 'h2e7a54ee750af5b472a7;
        zob_rand_board[540] = 'h954ff26d9edcb350b5e5;
        zob_rand_board[541] = 'h28afcc748a6de593596b;
        zob_rand_board[542] = 'h8ffbaf0e752e070fff86;
        zob_rand_board[543] = 'hf9e0597cc1af2a0a79d6;
        zob_rand_board[544] = 'h982f10cc247927637597;
        zob_rand_board[545] = 'hda17d1a774028f277c09;
        zob_rand_board[546] = 'h45782bd3a67aba4dea6d;
        zob_rand_board[547] = 'h0db3cff7fc6b38be7afa;
        zob_rand_board[548] = 'hdee5dbc6a9af5abadaf3;
        zob_rand_board[549] = 'ha6aa742fe9e4eda20a02;
        zob_rand_board[550] = 'h6e75898ac29d00ef4977;
        zob_rand_board[551] = 'h4277f55161059c32d4bb;
        zob_rand_board[552] = 'h1159acf2e5fcdb38d93e;
        zob_rand_board[553] = 'hed3ef35410aa4e1a422b;
        zob_rand_board[554] = 'h6a00b4d6f6c5302fe546;
        zob_rand_board[555] = 'he47be1bfd67b37a455bb;
        zob_rand_board[556] = 'hc43c44b715aac440a561;
        zob_rand_board[557] = 'h59220775e6400f9357f1;
        zob_rand_board[558] = 'h7554da37582448f3e698;
        zob_rand_board[559] = 'h7537f06cb3cb27528655;
        zob_rand_board[560] = 'h1024540dd1f8381b925d;
        zob_rand_board[561] = 'he79f40a560f6c4a2ae89;
        zob_rand_board[562] = 'h2b8d783f60dad7aae77b;
        zob_rand_board[563] = 'h139e5fba4f1622954742;
        zob_rand_board[564] = 'h29921234246bb822a7c3;
        zob_rand_board[565] = 'h1503f8cbddb2ca774685;
        zob_rand_board[566] = 'hfdc1e0a5893ac8bbce58;
        zob_rand_board[567] = 'h299ae9a1cc264cda04d9;
        zob_rand_board[568] = 'hcd35b53bdbd74fcd72f9;
        zob_rand_board[569] = 'h165db9aff94ab57db583;
        zob_rand_board[570] = 'h32e4e18fa26af83c2dd8;
        zob_rand_board[571] = 'h7ee78d7d4630d8e9a5e8;
        zob_rand_board[572] = 'hc4e6d4271dd4e3303e08;
        zob_rand_board[573] = 'hf89961344873aab4f217;
        zob_rand_board[574] = 'h365a84e1b00787c3549d;
        zob_rand_board[575] = 'h48eea0aea6d790c57246;
        zob_rand_board[576] = 'h7dfbfdb1454a7564f24e;
        zob_rand_board[577] = 'h94f1473d3479cb50b07c;
        zob_rand_board[578] = 'h41dcc7aac256c10d422a;
        zob_rand_board[579] = 'h2d0f09ed4bd82fc9227b;
        zob_rand_board[580] = 'hc2b6365c813115f7aae4;
        zob_rand_board[581] = 'h37fb0d3abcef0fb90eae;
        zob_rand_board[582] = 'h790222024b02dfe497ae;
        zob_rand_board[583] = 'h9a6695a0e12360431896;
        zob_rand_board[584] = 'h51ea4f3e6eca9fc20e62;
        zob_rand_board[585] = 'he3ccdf3f98d77c0005d0;
        zob_rand_board[586] = 'h65e56773cd23bd5c84b5;
        zob_rand_board[587] = 'h6e1dc54c75a376f062a0;
        zob_rand_board[588] = 'hef8495a682d93a33a3d2;
        zob_rand_board[589] = 'heddff8ee5ce0ec8f4eac;
        zob_rand_board[590] = 'h74534d55f090368c6d59;
        zob_rand_board[591] = 'h18ef54fe5dd6cb074c26;
        zob_rand_board[592] = 'haab805595c7d12074745;
        zob_rand_board[593] = 'h469ae64bbdeee27d5582;
        zob_rand_board[594] = 'h8f4312d736bc4907e135;
        zob_rand_board[595] = 'hb101f7731f472bf4254b;
        zob_rand_board[596] = 'h46be80a1d5ad9ee88729;
        zob_rand_board[597] = 'h8eeb427f6f189939ffc4;
        zob_rand_board[598] = 'h71c2659c631ed5af9554;
        zob_rand_board[599] = 'h912601da3502d02876dc;
        zob_rand_board[600] = 'hf27472dea5efa6b6a8c3;
        zob_rand_board[601] = 'h12c3ba9dc765ffa58f4f;
        zob_rand_board[602] = 'hc7d5c2d2424549d0ecbc;
        zob_rand_board[603] = 'hc3f40e20ac83f7ebf9fe;
        zob_rand_board[604] = 'h9e18b9e846698cda5342;
        zob_rand_board[605] = 'hcfd2879202fad7563067;
        zob_rand_board[606] = 'h57c397c581d32858fbaf;
        zob_rand_board[607] = 'ha19ca95a1aa37df332e5;
        zob_rand_board[608] = 'h163d7af508da8867d60d;
        zob_rand_board[609] = 'h1a53f8d43dd2943ef2f0;
        zob_rand_board[610] = 'h779ad59354a19ea20fe8;
        zob_rand_board[611] = 'h24c3255c178211af3cef;
        zob_rand_board[612] = 'hcf4539db63166a924642;
        zob_rand_board[613] = 'h06e3d55763b2d1b897e1;
        zob_rand_board[614] = 'h0b448647a37231551d07;
        zob_rand_board[615] = 'hd9d2c110e7334f8d6c62;
        zob_rand_board[616] = 'h03392135f3c465ac07d1;
        zob_rand_board[617] = 'he0c7f0a40b254f4b85c3;
        zob_rand_board[618] = 'he7d8abf2d6ea0077fdf1;
        zob_rand_board[619] = 'h1cf4b054dafd484e4649;
        zob_rand_board[620] = 'h3303ba1246a3ca197841;
        zob_rand_board[621] = 'h1c9dba34d29a314c0c48;
        zob_rand_board[622] = 'h0b57eb6d6eb5ad86c50e;
        zob_rand_board[623] = 'hd3d6f611c592c355a692;
        zob_rand_board[624] = 'hfbf7c86e50c627ac3702;
        zob_rand_board[625] = 'h8c45575f5ab93017de02;
        zob_rand_board[626] = 'h3705227cb20109ee60fe;
        zob_rand_board[627] = 'h916f8119bde8077c4edf;
        zob_rand_board[628] = 'hfb3c98b1dc617ef67884;
        zob_rand_board[629] = 'h7b8aee3ef37802d1f06f;
        zob_rand_board[630] = 'h27bae9139e56746fe01a;
        zob_rand_board[631] = 'h752c004e385e76cb3d9c;
        zob_rand_board[632] = 'hbcccd436f3a80bdb7e1e;
        zob_rand_board[633] = 'h305b6ad111485db8a801;
        zob_rand_board[634] = 'h66a27757c0d602c4f1e8;
        zob_rand_board[635] = 'h45b75e813c11b1cf3c0c;
        zob_rand_board[636] = 'h93bb68bf8da769002c5b;
        zob_rand_board[637] = 'hb760d962438462c29715;
        zob_rand_board[638] = 'h71470c6b67e484d760c5;
        zob_rand_board[639] = 'h1e87d389f268161c0559;
        zob_rand_board[640] = 'h1b0e1f16953dc94173fb;
        zob_rand_board[641] = 'hd588081bcbf79b21921f;
        zob_rand_board[642] = 'hf83bb663e0191517188d;
        zob_rand_board[643] = 'hf5509d701eea96cf00f6;
        zob_rand_board[644] = 'h875e50c849d25a4a239a;
        zob_rand_board[645] = 'ha04432c22466e81f23c4;
        zob_rand_board[646] = 'h377298171a770c59459b;
        zob_rand_board[647] = 'h2087afd406d47adb8939;
        zob_rand_board[648] = 'h9ea47525391ad5dadf7c;
        zob_rand_board[649] = 'hb95572850ff83b04d465;
        zob_rand_board[650] = 'h92cd7a7c625c2b9deb59;
        zob_rand_board[651] = 'h2fc03d66175ea8f05941;
        zob_rand_board[652] = 'hfdca25a84b04efeca6b5;
        zob_rand_board[653] = 'he5661a960634d7a08572;
        zob_rand_board[654] = 'hafd614ba3d0c5aeb9377;
        zob_rand_board[655] = 'hd7b4d20eb43a94df6745;
        zob_rand_board[656] = 'h6ffc300222314c133961;
        zob_rand_board[657] = 'h40617c64b658027e8085;
        zob_rand_board[658] = 'h3cb9385cd2072270b49a;
        zob_rand_board[659] = 'h9ee3c98ed7357c85f5e2;
        zob_rand_board[660] = 'h61841b60f6eadefd4be9;
        zob_rand_board[661] = 'h5a3044fed5955b7731e7;
        zob_rand_board[662] = 'he5341f81a08879867a2e;
        zob_rand_board[663] = 'h480ab5bad23f3837ff04;
        zob_rand_board[664] = 'hcb3046cde38c875fbc0e;
        zob_rand_board[665] = 'hf0925f6b720a8eb3d2e3;
        zob_rand_board[666] = 'h7a5bdc80dc396e9c6f3d;
        zob_rand_board[667] = 'h1ab38b7364031b1a07cd;
        zob_rand_board[668] = 'hce3906fc4bf54a963ba7;
        zob_rand_board[669] = 'h2c7a6a6574772907a17b;
        zob_rand_board[670] = 'h9235a57a0835be0dfe93;
        zob_rand_board[671] = 'h2151bc921ac5ab938f83;
        zob_rand_board[672] = 'h78db47657577384a951c;
        zob_rand_board[673] = 'h2453f7290fd32f6b0c51;
        zob_rand_board[674] = 'hcb4120bb58ae9fd81653;
        zob_rand_board[675] = 'h3a67a8e7c3c3817d6410;
        zob_rand_board[676] = 'h03ba2cb5904a8ab5cd80;
        zob_rand_board[677] = 'h30c08b459200f7040ca4;
        zob_rand_board[678] = 'hc55f25ca12bdc4608724;
        zob_rand_board[679] = 'h93349095606aaf992524;
        zob_rand_board[680] = 'hb5d39a526feaa09b7117;
        zob_rand_board[681] = 'h152f961bdf8128546465;
        zob_rand_board[682] = 'hc84cd1e72bacbde0aea4;
        zob_rand_board[683] = 'h40c5aa47d0c0dd899472;
        zob_rand_board[684] = 'hfebf312bdbe991595fbb;
        zob_rand_board[685] = 'h1900f43c1c2f65839617;
        zob_rand_board[686] = 'h7ff1b708c21be84fa4cf;
        zob_rand_board[687] = 'h2e04938e78123355c6b4;
        zob_rand_board[688] = 'h5667f4f86f339ae4a91b;
        zob_rand_board[689] = 'hcc852c118eca8d25cae2;
        zob_rand_board[690] = 'h05b10d67eb453de89090;
        zob_rand_board[691] = 'hf9fb682f7c8e66558a5f;
        zob_rand_board[692] = 'h9783ea1d224391cee0b7;
        zob_rand_board[693] = 'h6a976c9349a2f15fdd94;
        zob_rand_board[694] = 'h30517eedf90c6b719e2d;
        zob_rand_board[695] = 'hcd07ee3406b2acc94e44;
        zob_rand_board[696] = 'hee47252d579ae154227d;
        zob_rand_board[697] = 'hc591d76bc33164880308;
        zob_rand_board[698] = 'h0e353d7a6d1b0d24398f;
        zob_rand_board[699] = 'h914967f2c3fd3eb19d7f;
        zob_rand_board[700] = 'hf7c10b99ab8aee97d56d;
        zob_rand_board[701] = 'h4e167c7de1c312420ed1;
        zob_rand_board[702] = 'ha72cdd0494294405633a;
        zob_rand_board[703] = 'h413b290ee96449ced8fb;
        zob_rand_board[704] = 'h8b0ceb866e2525d2fdae;
        zob_rand_board[705] = 'h7d495451fbac03781fdd;
        zob_rand_board[706] = 'h52eb1920115454faf53c;
        zob_rand_board[707] = 'h011b117f83db10a31f93;
        zob_rand_board[708] = 'hd6892b36a3b89bd3a70d;
        zob_rand_board[709] = 'hb8322ee1d176b96f3e16;
        zob_rand_board[710] = 'h9092fdd286251ad6f3d0;
        zob_rand_board[711] = 'h7b58e78bd2c95034c1c2;
        zob_rand_board[712] = 'hfecbdcccec6be6c4b3b8;
        zob_rand_board[713] = 'h81330502ae054cc8ee64;
        zob_rand_board[714] = 'h4e6cc1adb2b5125da44a;
        zob_rand_board[715] = 'h544b964b3121aa215239;
        zob_rand_board[716] = 'h742421dd4f7937b9641d;
        zob_rand_board[717] = 'h2b14deaa2b3f24702e83;
        zob_rand_board[718] = 'h1a79333fb74d6b6c3fe6;
        zob_rand_board[719] = 'hca858e3fa59d075c2bb9;
        zob_rand_board[720] = 'h72c9250e659c5251e3d9;
        zob_rand_board[721] = 'h4554fa7bd71a8ff3e300;
        zob_rand_board[722] = 'he58df71c3d66067fbc41;
        zob_rand_board[723] = 'h81b6e32c2ff115c341af;
        zob_rand_board[724] = 'h3c3d9795bd738b93a258;
        zob_rand_board[725] = 'hb60fe9d9b915f46144f4;
        zob_rand_board[726] = 'h1e3f6a93406f40346f64;
        zob_rand_board[727] = 'h7395972389f5b9389ed9;
        zob_rand_board[728] = 'h5cf207bcb54396baafd9;
        zob_rand_board[729] = 'h25d4174bfd09075bacb1;
        zob_rand_board[730] = 'h0a9cfad57f787f515485;
        zob_rand_board[731] = 'h902501e777a63891e007;
        zob_rand_board[732] = 'h27983099406e238959f3;
        zob_rand_board[733] = 'h82d633d91d22d37eea9d;
        zob_rand_board[734] = 'h6644d8b5039ad300d2f2;
        zob_rand_board[735] = 'hb4f25a5e07509c72f2dd;
        zob_rand_board[736] = 'hef148a555b5554202ce3;
        zob_rand_board[737] = 'hb8961a4e3d036c8375c0;
        zob_rand_board[738] = 'h8da34582369c63984b7b;
        zob_rand_board[739] = 'h6513d72e4e802b60e442;
        zob_rand_board[740] = 'h314564c4323d84030e10;
        zob_rand_board[741] = 'hda97cecbd7d972174ea7;
        zob_rand_board[742] = 'h18d177ea5fede5975c45;
        zob_rand_board[743] = 'h9ef1733af5963348d23f;
        zob_rand_board[744] = 'he4245fba3bf56d2ddd72;
        zob_rand_board[745] = 'h706d7ec0a727a5c0b0b7;
        zob_rand_board[746] = 'h42c2d5454e44454726b1;
        zob_rand_board[747] = 'h72ff69c5cbd82fe46788;
        zob_rand_board[748] = 'h96eb94ebeb7257d69efe;
        zob_rand_board[749] = 'h86d47e3b0b7b7841e9bb;
        zob_rand_board[750] = 'hc1e67a6bf01c54df347d;
        zob_rand_board[751] = 'hb7793af222c16d643c37;
        zob_rand_board[752] = 'h8e6394b0ccc3888dc9e5;
        zob_rand_board[753] = 'h94c0d1073e00a31e5cf8;
        zob_rand_board[754] = 'ha8e41a875c03d11cb113;
        zob_rand_board[755] = 'hd489bf3b3d511217b308;
        zob_rand_board[756] = 'h11fe02403261001b04f3;
        zob_rand_board[757] = 'hcae64ab91093eb235cf6;
        zob_rand_board[758] = 'ha52f349fe56f1d9b0412;
        zob_rand_board[759] = 'h21baff7ecb70b7cf02b5;
        zob_rand_board[760] = 'h8f8bf6d45ed03a13bacf;
        zob_rand_board[761] = 'h3928ca6d9d7d51665a95;
        zob_rand_board[762] = 'hd584832e109c1ad09083;
        zob_rand_board[763] = 'hf5f094700dbbc318956f;
        zob_rand_board[764] = 'hcde17232fc6f41509e64;
        zob_rand_board[765] = 'h1621c0f1a3f0ce9cb3cb;
        zob_rand_board[766] = 'h0e48993e07cee95bc107;
        zob_rand_board[767] = 'hff077abed9aef65008b8;

        zob_rand_btm = 'h9dcf7be3c66d42c98d9e;

        zob_rand_en_passant_col[ 0] = 'h2d6fbdd38c4196b4f4b4;
        zob_rand_en_passant_col[ 1] = 'h9b9655115230fd83517a;
        zob_rand_en_passant_col[ 2] = 'hd691f106c798f498b04e;
        zob_rand_en_passant_col[ 3] = 'heaeb4c9b712183b66147;
        zob_rand_en_passant_col[ 4] = 'hd828cea5d47207276e35;
        zob_rand_en_passant_col[ 5] = 'hd5f4805239c40ef79ffb;
        zob_rand_en_passant_col[ 6] = 'hfa96bcbac079cc3a487f;
        zob_rand_en_passant_col[ 7] = 'h4116289d6b2a65b96411;
        zob_rand_en_passant_col[ 8] = 'h267bc720054ffdacb316;
        zob_rand_en_passant_col[ 9] = 'h9c36f5e993026b4c5e07;
        zob_rand_en_passant_col[10] = 'hce6d7f2b0854c966ab06;
        zob_rand_en_passant_col[11] = 'h03d2768f74e100560447;
        zob_rand_en_passant_col[12] = 'h72c79a1c294910db4882;
        zob_rand_en_passant_col[13] = 'h9832182b1a14d65e3c8d;
        zob_rand_en_passant_col[14] = 'h6b76b4080891d411f9f3;
        zob_rand_en_passant_col[15] = 'h05548cbac385b449268b;
        zob_rand_en_passant_col[16] = 'h576d658df4d7ea003373;
        zob_rand_en_passant_col[17] = 'h4e510993ae4fce05b619;
        zob_rand_en_passant_col[18] = 'h0dc1c4ba6df8c3099719;
        zob_rand_en_passant_col[19] = 'hbb70968beb49dd9e336a;
        zob_rand_en_passant_col[20] = 'h5eecdb7766e022273676;
        zob_rand_en_passant_col[21] = 'hc1e39c0c3ab5cbd61cc9;
        zob_rand_en_passant_col[22] = 'h0fa6dab3b4d29216829f;
        zob_rand_en_passant_col[23] = 'ha1f785026e48a71c3c39;
        zob_rand_en_passant_col[24] = 'h69acd1ed135f7a7f671f;
        zob_rand_en_passant_col[25] = 'h55119c567368e1e643df;
        zob_rand_en_passant_col[26] = 'h53ae3909ce8b5b4aed4b;
        zob_rand_en_passant_col[27] = 'h0de9803adec4db0877eb;
        zob_rand_en_passant_col[28] = 'h01ab411622aa6933b7a8;
        zob_rand_en_passant_col[29] = 'h2c0aa82b8096f90bc8ba;
        zob_rand_en_passant_col[30] = 'h2a09fb93933c104d1896;
        zob_rand_en_passant_col[31] = 'he678f64efe2a4d4be65f;

        zob_rand_castle_mask[ 0] = 'h019771345df80a39dbfc;
        zob_rand_castle_mask[ 1] = 'hfe12a8928fddbb936e35;
        zob_rand_castle_mask[ 2] = 'he5d7ce125636e09314a7;
        zob_rand_castle_mask[ 3] = 'h77a70ada6c3fc3b5e085;
        zob_rand_castle_mask[ 4] = 'he1a08e03246ac0d3980f;
        zob_rand_castle_mask[ 5] = 'hb89869068b797879391d;
        zob_rand_castle_mask[ 6] = 'hb782b3f35938f6d1f705;
        zob_rand_castle_mask[ 7] = 'hc453a39b421220c0498f;
        zob_rand_castle_mask[ 8] = 'h4ebe4790d07ddd7bc593;
        zob_rand_castle_mask[ 9] = 'hc3ed3180c19bbacef888;
        zob_rand_castle_mask[10] = 'he38db7cdc394f3d7459e;
        zob_rand_castle_mask[11] = 'h16095ef3713112fa95c2;
        zob_rand_castle_mask[12] = 'hdf775f90e1fa11b0e508;
        zob_rand_castle_mask[13] = 'h46788a5466620642fcae;
        zob_rand_castle_mask[14] = 'hc41cd71b6eee7f0ef5c5;
        zob_rand_castle_mask[15] = 'h5b7e80b1e1e6ded45e5f;
     end
   
endmodule
