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
   
    input [31:0]                          misc_status,
    input [31:0]                          xorshift32_reg,
   
    input [17:0]                          ctrl0_addr,
    input [127:0]                         ctrl0_din,
    input                                 ctrl0_en,
    input [15:0]                          ctrl0_we,
   
    output reg [127:0]                    ctrl0_dout
    );

   // should be empty
   /*AUTOREGINPUT*/

   /*AUTOWIRE*/

   wire [15:0]                            wr_reg_addr = ctrl0_addr[17:4];
   wire [15:0]                            rd_reg_addr = ctrl0_addr[17:4];

   wire                                   ctrl0_wr_valid = ctrl0_en && ctrl0_we != 0;

   assign trans_board_out = am_new_board_out;
   assign trans_white_to_move_out = am_white_to_move_out;
   assign trans_castle_mask_out = am_castle_mask_out;
   assign trans_en_passant_col_out = am_en_passant_col_out;

   assign q_trans_board_out = am_new_board_out;
   assign q_trans_white_to_move_out = am_white_to_move_out;
   assign q_trans_castle_mask_out = am_castle_mask_out;
   assign q_trans_en_passant_col_out = am_en_passant_col_out;

   integer                                byte_en;

   always @(posedge clk)
     begin
        fan_ctrl_write_wr_en <= 0; // special case for 100MHz clock domain
        if (ctrl0_wr_valid) // assume all non-128 bit transactions have 'h000f for byte enable
          case (wr_reg_addr)
            5'h0 :
              begin
                 am_new_board_valid_out <= ctrl0_din[0];
                 am_clear_moves <= ctrl0_din[1];
                 soft_reset <= ctrl0_din[31];
              end
            5'h01 : am_move_index <= ctrl0_din[MAX_POSITIONS_LOG2 - 1:0];
            5'h02 : {am_white_to_move_out, am_castle_mask_out, am_en_passant_col_out} <= ctrl0_din;
            5'h03 : am_half_move_out <= ctrl0_din;
            5'h04 : am_quiescence_moves <= ctrl0_din[0];
            5'h08 : // 128 bit transaction
              for (byte_en = 0; byte_en < 16; byte_en = byte_en + 1)
                if (ctrl0_we[byte_en])
                  am_new_board_out[byte_en * 8+:8] <= ctrl0_din[byte_en * 8+:8];
            5'h09 : // 128 bit transaction
              for (byte_en = 0; byte_en < 16; byte_en = byte_en + 1)
                if (ctrl0_we[byte_en])
                  am_new_board_out[128 + byte_en * 8+:8] <= ctrl0_din[byte_en * 8+:8];
            5'h10 : am_repdet_depth_out <= ctrl0_din;
            5'h11 : am_repdet_castle_mask_out <= ctrl0_din;
            5'h12 : {am_repdet_wr_en_out, am_repdet_wr_addr_out} <= {ctrl0_din[31], ctrl0_din[REPDET_WIDTH - 1:0]};
            5'h18 : // 128 bit transaction
              for (byte_en = 0; byte_en < 16; byte_en = byte_en + 1)
                if (ctrl0_we[byte_en])
                  am_repdet_board_out[byte_en * 8+:8] <= ctrl0_din[byte_en * 8+:8];
            5'h19 : // 128 bit transaction
              for (byte_en = 0; byte_en < 16; byte_en = byte_en + 1)
                if (ctrl0_we[byte_en])
                  am_repdet_board_out[128 + byte_en * 8+:8] <= ctrl0_din[byte_en * 8+:8];
            252 : random_score_mask <= ctrl0_din;
            256 : {led_uf2, led_uf1} <= ctrl0_din;
            257 : // special case for 100MHz clock domain
              begin
                 fan_ctrl_write_wr_data <= ctrl0_din;
                 fan_ctrl_write_wr_en <= 1;
              end
            520 : {trans_depth_out[7:0], trans_clear_trans_out, trans_hash_only_out, trans_flag_out[1:0],
                   trans_entry_store_out, trans_entry_lookup_out} <= {ctrl0_din[15:8], ctrl0_din[5:0]};
            521 : {trans_capture_out, trans_eval_out} <= {ctrl0_din[31], ctrl0_din[EVAL_WIDTH - 1:0]};
            525 : trans_nodes_out <= ctrl0_din;
            600 : am_pv_ctrl_out <= ctrl0_din;
            620 : {q_trans_depth_out[7:0], q_trans_clear_trans_out, q_trans_hash_only_out, q_trans_flag_out[1:0],
                   q_trans_entry_store_out, q_trans_entry_lookup_out} <= {ctrl0_din[15:8], ctrl0_din[5:0]};
            621 : {q_trans_capture_out, q_trans_eval_out} <= {ctrl0_din[31], ctrl0_din[EVAL_WIDTH - 1:0]};
            625 : q_trans_nodes_out <= ctrl0_din;
            1024 : // 128 bit transaction
              for (byte_en = 0; byte_en < 16; byte_en = byte_en + 1)
                if (ctrl0_we[byte_en])
                  am_killer_board_out[byte_en * 8+:8] <= ctrl0_din[byte_en * 8+:8];
            1025 : // 128 bit transaction
              for (byte_en = 0; byte_en < 16; byte_en = byte_en + 1)
                if (ctrl0_we[byte_en])
                  am_killer_board_out[128 + byte_en * 8+:8] <= ctrl0_din[byte_en * 8+:8];
            1032 : {am_killer_clear_out, am_killer_update_out} <= ctrl0_din[1:0];
            1033 : am_killer_ply_out <= ctrl0_din;
            1034 : am_killer_bonus0_out <= ctrl0_din;
            1035 : am_killer_bonus1_out <= ctrl0_din;
            
            default :
              begin
              end
          endcase
     end

   always @(posedge clk)
     case (rd_reg_addr)
       4'h0 :
         begin
            ctrl0_dout[0] <= am_new_board_valid_out;
            ctrl0_dout[1] <= am_clear_moves;
            ctrl0_dout[2] <= am_moves_ready;
            ctrl0_dout[3] <= am_move_ready;
            ctrl0_dout[4] <= initial_stalemate;
            ctrl0_dout[5] <= initial_mate;
            ctrl0_dout[6] <= initial_thrice_rep;
            ctrl0_dout[7] <= am_idle;
            ctrl0_dout[8] <= initial_fifty_move;
            ctrl0_dout[9] <= initial_insufficient_material;
            ctrl0_dout[10] <= initial_board_check;
            ctrl0_dout[31] <= soft_reset;
         end
       5'h01 : ctrl0_dout[31:0] <= am_move_index;
       5'h02 : ctrl0_dout[31:0] <= {am_white_to_move_out, am_castle_mask_out, am_en_passant_col_out};
       5'h03 : ctrl0_dout[31:0] <= am_half_move_out;
       5'h04 : ctrl0_dout[31:0] <= am_quiescence_moves;

       5'h10 : ctrl0_dout[31:0] <= am_repdet_depth_out;
       5'h11 : ctrl0_dout[31:0] <= am_repdet_castle_mask_out;
       5'h12 : ctrl0_dout[31:0] <= {am_repdet_wr_en_out, am_repdet_wr_addr_out};

       128 : ctrl0_dout[31:0] <= am_white_is_attacking_in[31:0];
       129 : ctrl0_dout[31:0] <= am_white_is_attacking_in[63:32];
       130 : ctrl0_dout[31:0] <= am_black_is_attacking_in[31:0];
       131 : ctrl0_dout[31:0] <= am_black_is_attacking_in[63:32];
       132 : ctrl0_dout[31:0] <= {am_pv_in, am_insufficient_material_in, am_fifty_move_in,
                                  am_thrice_rep_in, am_black_in_check_in, am_white_in_check_in, am_capture_in};
       133 : ctrl0_dout[31:0] <= {am_white_to_move_in, am_castle_mask_in, am_en_passant_col_in};
       134 : ctrl0_dout[31:0] <= am_eval_in;
       135 : ctrl0_dout[31:0] <= am_move_count;
       136 : ctrl0_dout[31:0] <= initial_eval;
       138 : ctrl0_dout[31:0] <= am_half_move_in;
       139 : ctrl0_dout[31:0] <= {am_uci_in[15:12], 1'b0, am_uci_in[11:9], 1'b0, am_uci_in[8:6], 1'b0, am_uci_in[5:3], 1'b0, am_uci_in[2:0]};
       140 : ctrl0_dout[31:0] <= {am_attack_black_pop_in[5:0], am_attack_white_pop_in[5:0]};
       141 : ctrl0_dout[31:0] <= initial_material_black;
       142 : ctrl0_dout[31:0] <= initial_material_white;
       
       252 : ctrl0_dout[31:0] <= random_score_mask;
       253 : ctrl0_dout[31:0] <= trans_trans;
       254 : ctrl0_dout[31:0] <= xorshift32_reg;
       255 : ctrl0_dout[31:0] <= misc_status;
       256 : ctrl0_dout[31:0] <= {led_uf2, led_uf1};
       257 : ctrl0_dout[31:0] <= fan_ctrl_write_wr_data;

       512 : ctrl0_dout[31:0] <= {trans_capture_in, trans_collision_in, trans_depth_in[7:0], 4'b0,
                                  trans_flag_in[1:0], trans_entry_valid_in, trans_trans_idle_in};
       514 : ctrl0_dout[31:0] <= trans_eval_in;
       515 : ctrl0_dout[31:0] <= trans_nodes_in;
       520 : ctrl0_dout[31:0] <= {trans_depth_out[7:0], 2'b0, trans_clear_trans_out, trans_hash_only_out,
                                  trans_flag_out[1:0], trans_entry_store_out, trans_entry_lookup_out};
       521 : ctrl0_dout[31:0] <= trans_capture_out << 31 | trans_eval_out[EVAL_WIDTH - 1:0];
       522 : ctrl0_dout[31:0] <= trans_hash_in[31: 0];
       523 : ctrl0_dout[31:0] <= trans_hash_in[63:32];
       524 : ctrl0_dout[31:0] <= trans_hash_in[79:64];
       525 : ctrl0_dout[31:0] <= trans_nodes_out;

       600 : ctrl0_dout[31:0] <= am_pv_ctrl_out;
       
       612 : ctrl0_dout[31:0] <= {q_trans_capture_in, q_trans_collision_in, q_trans_depth_in[7:0], 4'b0,
                                  q_trans_flag_in[1:0], q_trans_entry_valid_in, q_trans_trans_idle_in};
       614 : ctrl0_dout[31:0] <= q_trans_eval_in;
       615 : ctrl0_dout[31:0] <= q_trans_nodes_in;
       620 : ctrl0_dout[31:0] <= {q_trans_depth_out[7:0], 2'b0, q_trans_clear_trans_out, q_trans_hash_only_out,
                                  q_trans_flag_out[1:0], q_trans_entry_store_out, q_trans_entry_lookup_out};
       621 : ctrl0_dout[31:0] <= q_trans_capture_out << 31 | q_trans_eval_out[EVAL_WIDTH - 1:0];
       622 : ctrl0_dout[31:0] <= q_trans_hash_in[31: 0];
       623 : ctrl0_dout[31:0] <= q_trans_hash_in[63:32];
       624 : ctrl0_dout[31:0] <= q_trans_hash_in[79:64];
       625 : ctrl0_dout[31:0] <= q_trans_nodes_out;

       1032 : ctrl0_dout[31:0] <= {am_killer_clear_out, am_killer_update_out};
       1033 : ctrl0_dout[31:0] <= am_killer_ply_out;
       1034 : ctrl0_dout[31:0] <= am_killer_bonus0_out;
       1035 : ctrl0_dout[31:0] <= am_killer_bonus1_out;

       default : ctrl0_dout <= 0;
     endcase

endmodule
