// Copyright (c) 2025 Stacey Campbell
// SPDX-License-Identifier: MIT

`include "numbat.vh"

module control #
  (
   parameter EVAL_WIDTH = 0,
   parameter MAX_POSITIONS_LOG2 = $clog2(`MAX_POSITIONS),
   parameter REPDET_WIDTH = 0,
   parameter HALF_MOVE_WIDTH = 0,
   parameter UCI_WIDTH = 4 + 6 + 6,
   parameter MAX_DEPTH_LOG2 = 0
   )
   (
    input                                 reset,
    input                                 clk,

    output reg                            soft_reset = 0,

    output reg [EVAL_WIDTH - 1:0]         random_score_mask = 0,

    output reg                            am_new_board_valid_out,
    output reg [`BOARD_WIDTH - 1:0]       am_new_board_out,
    output reg [3:0]                      am_castle_mask_out,
    output reg [3:0]                      am_en_passant_col_out,
    output reg                            am_white_to_move_out,
    output reg [HALF_MOVE_WIDTH-1:0]      am_half_move_out,
    output reg [`BOARD_WIDTH-1:0]         am_repdet_board_out,
    output reg [3:0]                      am_repdet_castle_mask_out,
    output reg [REPDET_WIDTH-1:0]         am_repdet_depth_out,
    output reg [REPDET_WIDTH-1:0]         am_repdet_wr_addr_out,
    output reg                            am_repdet_wr_en_out,

    output reg [MAX_POSITIONS_LOG2 - 1:0] am_move_index,
    output reg                            am_clear_moves,
    output reg                            am_quiescence_moves,

    output reg [31:0]                     am_pv_ctrl_out,

    output reg [MAX_DEPTH_LOG2 - 1:0]     am_killer_ply_out,
    output reg [`BOARD_WIDTH - 1:0]       am_killer_board_out,
    output reg                            am_killer_update_out,
    output reg                            am_killer_clear_out,
    output reg signed [EVAL_WIDTH - 1:0]  am_killer_bonus0_out,
    output reg signed [EVAL_WIDTH - 1:0]  am_killer_bonus1_out,

    output [`BOARD_WIDTH - 1:0]           trans_board_out,
    output                                trans_white_to_move_out,
    output [3:0]                          trans_castle_mask_out,
    output [3:0]                          trans_en_passant_col_out,

    output reg [7:0]                      trans_depth_out,
    output reg                            trans_entry_lookup_out,
    output reg                            trans_entry_store_out,
    output reg                            trans_hash_only_out,
    output reg                            trans_clear_trans_out,
    output reg signed [EVAL_WIDTH - 1:0]  trans_eval_out,
    output reg [`TRANS_NODES_WIDTH - 1:0] trans_nodes_out,
    output reg                            trans_capture_out,
    output reg [1:0]                      trans_flag_out,

    output reg                            led_uf1,
    output reg                            led_uf2,

    input [7:0]                           trans_depth_in,
    input                                 trans_entry_valid_in,
    input signed [EVAL_WIDTH - 1:0]       trans_eval_in,
    input [1:0]                           trans_flag_in,
    input [`TRANS_NODES_WIDTH - 1:0]      trans_nodes_in,
    input                                 trans_capture_in,
    input                                 trans_trans_idle_in,
    input                                 trans_collision_in,
    input [79:0]                          trans_hash_in,
    input [31:0]                          trans_trans,

    output [`BOARD_WIDTH - 1:0]           q_trans_board_out,
    output                                q_trans_white_to_move_out,
    output [3:0]                          q_trans_castle_mask_out,
    output [3:0]                          q_trans_en_passant_col_out,

    output reg [7:0]                      q_trans_depth_out,
    output reg                            q_trans_entry_lookup_out,
    output reg                            q_trans_entry_store_out,
    output reg                            q_trans_hash_only_out,
    output reg                            q_trans_clear_trans_out,
    output reg signed [EVAL_WIDTH - 1:0]  q_trans_eval_out,
    output reg [`TRANS_NODES_WIDTH - 1:0] q_trans_nodes_out,
    output reg                            q_trans_capture_out,
    output reg [1:0]                      q_trans_flag_out,

    output reg [31:0]                     fan_ctrl_write_wr_data,
    output reg                            fan_ctrl_write_wr_en,

    input [7:0]                           q_trans_depth_in,
    input                                 q_trans_entry_valid_in,
    input signed [EVAL_WIDTH - 1:0]       q_trans_eval_in,
    input [1:0]                           q_trans_flag_in,
    input [`TRANS_NODES_WIDTH - 1:0]      q_trans_nodes_in,
    input                                 q_trans_capture_in,
    input                                 q_trans_trans_idle_in,
    input                                 q_trans_collision_in,
    input [79:0]                          q_trans_hash_in,
    input [31:0]                          q_trans_trans,
   
    input                                 initial_mate,
    input                                 initial_stalemate,
    input signed [EVAL_WIDTH - 1:0]       initial_eval, // root node eval
    input                                 initial_thrice_rep, // root node thrice rep
    input                                 initial_fifty_move,
    input                                 initial_insufficient_material,
    input signed [31:0]                   initial_material_black,
    input signed [31:0]                   initial_material_white,
    input                                 initial_board_check,

    input                                 am_idle,
    input                                 am_moves_ready, // all moves now calculated
    input                                 am_move_ready, // move index by am_move_index now valid
    input [MAX_POSITIONS_LOG2 - 1:0]      am_move_count,

    input [`BOARD_WIDTH-1:0]              am_board_in,
    input [3:0]                           am_castle_mask_in,
    input [3:0]                           am_en_passant_col_in,
    input                                 am_white_to_move_in,
    input                                 am_white_in_check_in,
    input                                 am_black_in_check_in,
    input [63:0]                          am_white_is_attacking_in,
    input [63:0]                          am_black_is_attacking_in,
    input                                 am_capture_in,
    input signed [EVAL_WIDTH - 1:0]       am_eval_in, // user indexed move eval
    input                                 am_thrice_rep_in, // user indexed thrice rep
    input [HALF_MOVE_WIDTH - 1:0]         am_half_move_in,
    input                                 am_fifty_move_in,
    input [UCI_WIDTH - 1:0]               am_uci_in,
    input [5:0]                           am_attack_white_pop_in,
    input [5:0]                           am_attack_black_pop_in,
    input                                 am_insufficient_material_in,
    input                                 am_pv_in,
   
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
    output [0:0]                          ctrl0_axi_wready,

    input [31:0]                          misc_status,
    input [31:0]                          xorshift32_reg
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

   wire [15:0]                            wr_reg_addr = ctrl0_wr_addr[15:2];
   wire [15:0]                            rd_reg_addr = ctrl0_axi_araddr[15:2];
   wire [5:0]                             board_address = wr_reg_addr - 1;

   assign trans_board_out = am_new_board_out;
   assign trans_white_to_move_out = am_white_to_move_out;
   assign trans_castle_mask_out = am_castle_mask_out;
   assign trans_en_passant_col_out = am_en_passant_col_out;

   assign q_trans_board_out = am_new_board_out;
   assign q_trans_white_to_move_out = am_white_to_move_out;
   assign q_trans_castle_mask_out = am_castle_mask_out;
   assign q_trans_en_passant_col_out = am_en_passant_col_out;

   assign ctrl0_axi_arready = 1; // always ready
   assign ctrl0_axi_rresp = 2'b0; // always ok

   always @(posedge clk)
     begin
        fan_ctrl_write_wr_en <= 0; // special case for 100MHz clock domain
        if (ctrl0_wr_valid)
          case (wr_reg_addr)
            5'h0 :
              begin
                 am_new_board_valid_out <= ctrl0_wr_data[0];
                 am_clear_moves <= ctrl0_wr_data[1];
                 soft_reset <= ctrl0_wr_data[31];
              end
            5'h01 : am_move_index <= ctrl0_wr_data[MAX_POSITIONS_LOG2 - 1:0];
            5'h02 : {am_white_to_move_out, am_castle_mask_out, am_en_passant_col_out} <= ctrl0_wr_data;
            5'h03 : am_half_move_out <= ctrl0_wr_data;
            5'h04 : am_quiescence_moves <= ctrl0_wr_data[0];
            5'h08 : am_new_board_out[`SIDE_WIDTH * 0+:`SIDE_WIDTH] <= ctrl0_wr_data[`SIDE_WIDTH - 1:0];
            5'h09 : am_new_board_out[`SIDE_WIDTH * 1+:`SIDE_WIDTH] <= ctrl0_wr_data[`SIDE_WIDTH - 1:0];
            5'h0A : am_new_board_out[`SIDE_WIDTH * 2+:`SIDE_WIDTH] <= ctrl0_wr_data[`SIDE_WIDTH - 1:0];
            5'h0B : am_new_board_out[`SIDE_WIDTH * 3+:`SIDE_WIDTH] <= ctrl0_wr_data[`SIDE_WIDTH - 1:0];
            5'h0C : am_new_board_out[`SIDE_WIDTH * 4+:`SIDE_WIDTH] <= ctrl0_wr_data[`SIDE_WIDTH - 1:0];
            5'h0D : am_new_board_out[`SIDE_WIDTH * 5+:`SIDE_WIDTH] <= ctrl0_wr_data[`SIDE_WIDTH - 1:0];
            5'h0E : am_new_board_out[`SIDE_WIDTH * 6+:`SIDE_WIDTH] <= ctrl0_wr_data[`SIDE_WIDTH - 1:0];
            5'h0F : am_new_board_out[`SIDE_WIDTH * 7+:`SIDE_WIDTH] <= ctrl0_wr_data[`SIDE_WIDTH - 1:0];

            5'h10 : am_repdet_depth_out <= ctrl0_wr_data;
            5'h11 : am_repdet_castle_mask_out <= ctrl0_wr_data;
            5'h12 : {am_repdet_wr_en_out, am_repdet_wr_addr_out} <= {ctrl0_wr_data[31], ctrl0_wr_data[REPDET_WIDTH - 1:0]};
            5'h18 : am_repdet_board_out[`SIDE_WIDTH * 0+:`SIDE_WIDTH] <= ctrl0_wr_data[`SIDE_WIDTH - 1:0];
            5'h19 : am_repdet_board_out[`SIDE_WIDTH * 1+:`SIDE_WIDTH] <= ctrl0_wr_data[`SIDE_WIDTH - 1:0];
            5'h1A : am_repdet_board_out[`SIDE_WIDTH * 2+:`SIDE_WIDTH] <= ctrl0_wr_data[`SIDE_WIDTH - 1:0];
            5'h1B : am_repdet_board_out[`SIDE_WIDTH * 3+:`SIDE_WIDTH] <= ctrl0_wr_data[`SIDE_WIDTH - 1:0];
            5'h1C : am_repdet_board_out[`SIDE_WIDTH * 4+:`SIDE_WIDTH] <= ctrl0_wr_data[`SIDE_WIDTH - 1:0];
            5'h1D : am_repdet_board_out[`SIDE_WIDTH * 5+:`SIDE_WIDTH] <= ctrl0_wr_data[`SIDE_WIDTH - 1:0];
            5'h1E : am_repdet_board_out[`SIDE_WIDTH * 6+:`SIDE_WIDTH] <= ctrl0_wr_data[`SIDE_WIDTH - 1:0];
            5'h1F : am_repdet_board_out[`SIDE_WIDTH * 7+:`SIDE_WIDTH] <= ctrl0_wr_data[`SIDE_WIDTH - 1:0];

            252 : random_score_mask <= ctrl0_wr_data;

            256 : {led_uf2, led_uf1} <= ctrl0_wr_data;
            257 : // special case for 100MHz clock domain
              begin
                 fan_ctrl_write_wr_data <= ctrl0_wr_data;
                 fan_ctrl_write_wr_en <= 1;
              end

            520 : {trans_depth_out[7:0], trans_clear_trans_out, trans_hash_only_out, trans_flag_out[1:0],
                   trans_entry_store_out, trans_entry_lookup_out} <= {ctrl0_wr_data[15:8], ctrl0_wr_data[5:0]};
            521 : {trans_capture_out, trans_eval_out} <= {ctrl0_wr_data[31], ctrl0_wr_data[EVAL_WIDTH - 1:0]};
            525 : trans_nodes_out <= ctrl0_wr_data;
            
            600 : am_pv_ctrl_out <= ctrl0_wr_data;

            620 : {q_trans_depth_out[7:0], q_trans_clear_trans_out, q_trans_hash_only_out, q_trans_flag_out[1:0],
                   q_trans_entry_store_out, q_trans_entry_lookup_out} <= {ctrl0_wr_data[15:8], ctrl0_wr_data[5:0]};
            621 : {q_trans_capture_out, q_trans_eval_out} <= {ctrl0_wr_data[31], ctrl0_wr_data[EVAL_WIDTH - 1:0]};
            625 : q_trans_nodes_out <= ctrl0_wr_data;

            1024 : am_killer_board_out[`SIDE_WIDTH * 0+:`SIDE_WIDTH] <= ctrl0_wr_data[`SIDE_WIDTH - 1:0];
            1025 : am_killer_board_out[`SIDE_WIDTH * 1+:`SIDE_WIDTH] <= ctrl0_wr_data[`SIDE_WIDTH - 1:0];
            1026 : am_killer_board_out[`SIDE_WIDTH * 2+:`SIDE_WIDTH] <= ctrl0_wr_data[`SIDE_WIDTH - 1:0];
            1027 : am_killer_board_out[`SIDE_WIDTH * 3+:`SIDE_WIDTH] <= ctrl0_wr_data[`SIDE_WIDTH - 1:0];
            1028 : am_killer_board_out[`SIDE_WIDTH * 4+:`SIDE_WIDTH] <= ctrl0_wr_data[`SIDE_WIDTH - 1:0];
            1029 : am_killer_board_out[`SIDE_WIDTH * 5+:`SIDE_WIDTH] <= ctrl0_wr_data[`SIDE_WIDTH - 1:0];
            1030 : am_killer_board_out[`SIDE_WIDTH * 6+:`SIDE_WIDTH] <= ctrl0_wr_data[`SIDE_WIDTH - 1:0];
            1031 : am_killer_board_out[`SIDE_WIDTH * 7+:`SIDE_WIDTH] <= ctrl0_wr_data[`SIDE_WIDTH - 1:0];
            1032 : {am_killer_clear_out, am_killer_update_out} <= ctrl0_wr_data[1:0];
            1033 : am_killer_ply_out <= ctrl0_wr_data;
            1034 : am_killer_bonus0_out <= ctrl0_wr_data;
            1035 : am_killer_bonus1_out <= ctrl0_wr_data;
            default :
              begin
              end
          endcase
     end

   always @(posedge clk)
     begin
        if (ctrl0_axi_rready)
          ctrl0_axi_rvalid <= 0;
        if (ctrl0_axi_arvalid)
          begin
             case (rd_reg_addr)
               4'h0 :
                 begin
                    ctrl0_axi_rdata[0] <= am_new_board_valid_out;
                    ctrl0_axi_rdata[1] <= am_clear_moves;
                    ctrl0_axi_rdata[2] <= am_moves_ready;
                    ctrl0_axi_rdata[3] <= am_move_ready;
                    ctrl0_axi_rdata[4] <= initial_stalemate;
                    ctrl0_axi_rdata[5] <= initial_mate;
                    ctrl0_axi_rdata[6] <= initial_thrice_rep;
                    ctrl0_axi_rdata[7] <= am_idle;
                    ctrl0_axi_rdata[8] <= initial_fifty_move;
                    ctrl0_axi_rdata[9] <= initial_insufficient_material;
                    ctrl0_axi_rdata[10] <= initial_board_check;
                    ctrl0_axi_rdata[31] <= soft_reset;
                 end
               5'h01 : ctrl0_axi_rdata <= am_move_index;
               5'h02 : ctrl0_axi_rdata <= {am_white_to_move_out, am_castle_mask_out, am_en_passant_col_out};
               5'h03 : ctrl0_axi_rdata <= am_half_move_out;
               5'h04 : ctrl0_axi_rdata <= am_quiescence_moves;
               5'h08 : ctrl0_axi_rdata <= am_new_board_out[`SIDE_WIDTH * 0+:`SIDE_WIDTH];
               5'h09 : ctrl0_axi_rdata <= am_new_board_out[`SIDE_WIDTH * 1+:`SIDE_WIDTH];
               5'h0A : ctrl0_axi_rdata <= am_new_board_out[`SIDE_WIDTH * 2+:`SIDE_WIDTH];
               5'h0B : ctrl0_axi_rdata <= am_new_board_out[`SIDE_WIDTH * 3+:`SIDE_WIDTH];
               5'h0C : ctrl0_axi_rdata <= am_new_board_out[`SIDE_WIDTH * 4+:`SIDE_WIDTH];
               5'h0D : ctrl0_axi_rdata <= am_new_board_out[`SIDE_WIDTH * 5+:`SIDE_WIDTH];
               5'h0E : ctrl0_axi_rdata <= am_new_board_out[`SIDE_WIDTH * 6+:`SIDE_WIDTH];
               5'h0F : ctrl0_axi_rdata <= am_new_board_out[`SIDE_WIDTH * 7+:`SIDE_WIDTH];

               5'h10 : ctrl0_axi_rdata <= am_repdet_depth_out;
               5'h11 : ctrl0_axi_rdata <= am_repdet_castle_mask_out;
               5'h12 : ctrl0_axi_rdata <= {am_repdet_wr_en_out, am_repdet_wr_addr_out};
               5'h18 : ctrl0_axi_rdata <= am_repdet_board_out[`SIDE_WIDTH * 0+:`SIDE_WIDTH];
               5'h19 : ctrl0_axi_rdata <= am_repdet_board_out[`SIDE_WIDTH * 1+:`SIDE_WIDTH];
               5'h1A : ctrl0_axi_rdata <= am_repdet_board_out[`SIDE_WIDTH * 2+:`SIDE_WIDTH];
               5'h1B : ctrl0_axi_rdata <= am_repdet_board_out[`SIDE_WIDTH * 3+:`SIDE_WIDTH];
               5'h1C : ctrl0_axi_rdata <= am_repdet_board_out[`SIDE_WIDTH * 4+:`SIDE_WIDTH];
               5'h1D : ctrl0_axi_rdata <= am_repdet_board_out[`SIDE_WIDTH * 5+:`SIDE_WIDTH];
               5'h1E : ctrl0_axi_rdata <= am_repdet_board_out[`SIDE_WIDTH * 6+:`SIDE_WIDTH];
               5'h1F : ctrl0_axi_rdata <= am_repdet_board_out[`SIDE_WIDTH * 7+:`SIDE_WIDTH];

               128 : ctrl0_axi_rdata <= am_white_is_attacking_in[31:0];
               129 : ctrl0_axi_rdata <= am_white_is_attacking_in[63:32];
               130 : ctrl0_axi_rdata <= am_black_is_attacking_in[31:0];
               131 : ctrl0_axi_rdata <= am_black_is_attacking_in[63:32];
               132 : ctrl0_axi_rdata <= {am_pv_in, am_insufficient_material_in, am_fifty_move_in,
                                         am_thrice_rep_in, am_black_in_check_in, am_white_in_check_in, am_capture_in};
               133 : ctrl0_axi_rdata <= {am_white_to_move_in, am_castle_mask_in, am_en_passant_col_in};
               134 : ctrl0_axi_rdata <= am_eval_in;
               135 : ctrl0_axi_rdata <= am_move_count;
               136 : ctrl0_axi_rdata <= initial_eval;
               138 : ctrl0_axi_rdata <= am_half_move_in;
               139 : ctrl0_axi_rdata <= {am_uci_in[15:12], 1'b0, am_uci_in[11:9], 1'b0, am_uci_in[8:6], 1'b0, am_uci_in[5:3], 1'b0, am_uci_in[2:0]};
               140 : ctrl0_axi_rdata <= {am_attack_black_pop_in[5:0], am_attack_white_pop_in[5:0]};
               141 : ctrl0_axi_rdata <= initial_material_black;
               142 : ctrl0_axi_rdata <= initial_material_white;
               
               172 : ctrl0_axi_rdata[`SIDE_WIDTH - 1:0] <= am_board_in[`SIDE_WIDTH * 0+:`SIDE_WIDTH];
               173 : ctrl0_axi_rdata[`SIDE_WIDTH - 1:0] <= am_board_in[`SIDE_WIDTH * 1+:`SIDE_WIDTH];
               174 : ctrl0_axi_rdata[`SIDE_WIDTH - 1:0] <= am_board_in[`SIDE_WIDTH * 2+:`SIDE_WIDTH];
               175 : ctrl0_axi_rdata[`SIDE_WIDTH - 1:0] <= am_board_in[`SIDE_WIDTH * 3+:`SIDE_WIDTH];
               176 : ctrl0_axi_rdata[`SIDE_WIDTH - 1:0] <= am_board_in[`SIDE_WIDTH * 4+:`SIDE_WIDTH];
               177 : ctrl0_axi_rdata[`SIDE_WIDTH - 1:0] <= am_board_in[`SIDE_WIDTH * 5+:`SIDE_WIDTH];
               178 : ctrl0_axi_rdata[`SIDE_WIDTH - 1:0] <= am_board_in[`SIDE_WIDTH * 6+:`SIDE_WIDTH];
               179 : ctrl0_axi_rdata[`SIDE_WIDTH - 1:0] <= am_board_in[`SIDE_WIDTH * 7+:`SIDE_WIDTH];

               252 : ctrl0_axi_rdata <= random_score_mask;
               253 : ctrl0_axi_rdata <= trans_trans;
               254 : ctrl0_axi_rdata <= xorshift32_reg;
               255 : ctrl0_axi_rdata <= misc_status;
               256 : ctrl0_axi_rdata <= {led_uf2, led_uf1};
               257 : ctrl0_axi_rdata <= fan_ctrl_write_wr_data;

               512 : ctrl0_axi_rdata <= {trans_capture_in, trans_collision_in, trans_depth_in[7:0], 4'b0,
                                         trans_flag_in[1:0], trans_entry_valid_in, trans_trans_idle_in};
               514 : ctrl0_axi_rdata <= trans_eval_in;
               515 : ctrl0_axi_rdata <= trans_nodes_in;
               520 : ctrl0_axi_rdata <= {trans_depth_out[7:0], 2'b0, trans_clear_trans_out, trans_hash_only_out,
                                         trans_flag_out[1:0], trans_entry_store_out, trans_entry_lookup_out};
               521 : ctrl0_axi_rdata <= trans_capture_out << 31 | trans_eval_out[EVAL_WIDTH - 1:0];
               522 : ctrl0_axi_rdata <= trans_hash_in[31: 0];
               523 : ctrl0_axi_rdata <= trans_hash_in[63:32];
               524 : ctrl0_axi_rdata <= trans_hash_in[79:64];
               525 : ctrl0_axi_rdata <= trans_nodes_out;

               600 : ctrl0_axi_rdata <= am_pv_ctrl_out;
               
               612 : ctrl0_axi_rdata <= {q_trans_capture_in, q_trans_collision_in, q_trans_depth_in[7:0], 4'b0,
                                         q_trans_flag_in[1:0], q_trans_entry_valid_in, q_trans_trans_idle_in};
               614 : ctrl0_axi_rdata <= q_trans_eval_in;
               615 : ctrl0_axi_rdata <= q_trans_nodes_in;
               620 : ctrl0_axi_rdata <= {q_trans_depth_out[7:0], 2'b0, q_trans_clear_trans_out, q_trans_hash_only_out,
                                         q_trans_flag_out[1:0], q_trans_entry_store_out, q_trans_entry_lookup_out};
               621 : ctrl0_axi_rdata <= q_trans_capture_out << 31 | q_trans_eval_out[EVAL_WIDTH - 1:0];
               622 : ctrl0_axi_rdata <= q_trans_hash_in[31: 0];
               623 : ctrl0_axi_rdata <= q_trans_hash_in[63:32];
               624 : ctrl0_axi_rdata <= q_trans_hash_in[79:64];
               625 : ctrl0_axi_rdata <= q_trans_nodes_out;

               1024 : ctrl0_axi_rdata[`SIDE_WIDTH - 1:0] <= am_killer_board_out[`SIDE_WIDTH * 0+:`SIDE_WIDTH];
               1025 : ctrl0_axi_rdata[`SIDE_WIDTH - 1:0] <= am_killer_board_out[`SIDE_WIDTH * 1+:`SIDE_WIDTH];
               1026 : ctrl0_axi_rdata[`SIDE_WIDTH - 1:0] <= am_killer_board_out[`SIDE_WIDTH * 2+:`SIDE_WIDTH];
               1027 : ctrl0_axi_rdata[`SIDE_WIDTH - 1:0] <= am_killer_board_out[`SIDE_WIDTH * 3+:`SIDE_WIDTH];
               1028 : ctrl0_axi_rdata[`SIDE_WIDTH - 1:0] <= am_killer_board_out[`SIDE_WIDTH * 4+:`SIDE_WIDTH];
               1029 : ctrl0_axi_rdata[`SIDE_WIDTH - 1:0] <= am_killer_board_out[`SIDE_WIDTH * 5+:`SIDE_WIDTH];
               1030 : ctrl0_axi_rdata[`SIDE_WIDTH - 1:0] <= am_killer_board_out[`SIDE_WIDTH * 6+:`SIDE_WIDTH];
               1031 : ctrl0_axi_rdata[`SIDE_WIDTH - 1:0] <= am_killer_board_out[`SIDE_WIDTH * 7+:`SIDE_WIDTH];
               1032 : ctrl0_axi_rdata <= {am_killer_clear_out, am_killer_update_out};
               1033 : ctrl0_axi_rdata <= am_killer_ply_out;
               1034 : ctrl0_axi_rdata <= am_killer_bonus0_out;
               1035 : ctrl0_axi_rdata <= am_killer_bonus1_out;

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
