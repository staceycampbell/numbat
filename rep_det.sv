`include "vchess.vh"

module rep_det #
  (
   parameter REPDET_WIDTH = 0
   )
   (
    input                      clk,
    input                      reset,

    input [`BOARD_WIDTH - 1:0] board_in,
    input [3:0]                castle_mask_in,
    input                      board_valid,

    input                      clear_sample,

    input [`BOARD_WIDTH - 1:0] ram_board_in,
    input [3:0]                ram_castle_mask_in,
    input [REPDET_WIDTH - 1:0] ram_wr_addr_in,
    input                      ram_wr_en,
    input [REPDET_WIDTH - 1:0] ram_depth_in,

    output reg                 thrice_rep,
    output reg                 thrice_rep_valid
    );

   localparam RAM_WIDTH = `BOARD_WIDTH + 4;
   localparam RAM_COUNT = 1 << REPDET_WIDTH;
   
   reg [RAM_WIDTH - 1:0]       board_and_castle_mask;
   reg [REPDET_WIDTH - 1:0]    counter;
   reg [REPDET_WIDTH - 1:0]    ram_depth_te;
   reg [RAM_WIDTH - 1:0]       ram_read;
   reg [REPDET_WIDTH - 1:0]    ram_rd_addr;
   
   reg [RAM_WIDTH - 1:0]       ram_table [0:RAM_COUNT - 1];

   // should be empty
   /*AUTOREGINPUT*/

   /*AUTOWIRE*/

   always @(posedge clk)
     begin
        ram_read <= ram_table[ram_rd_addr];

        if (ram_wr_en)
          ram_table[ram_wr_addr_in] <= {ram_castle_mask_in, ram_board_in};
     end

   localparam STATE_IDLE = 0;
   localparam STATE_COUNT = 1;
   localparam STATE_WS = 2;
   localparam STATE_NO_REP_DET = 3;
   localparam STATE_REP_DET = 4;

   reg [2:0]                        state = STATE_IDLE;

   always @(posedge clk)
     if (reset)
       state <= STATE_IDLE;
     else
       case (state)
         STATE_IDLE :
           begin
              ram_rd_addr <= 0;
              board_and_castle_mask <= {castle_mask_in, board_in};
              counter <= 0;
              ram_depth_te <= ram_depth_in - 1;
              thrice_rep_valid <= 0;
              if (board_valid)
                if (ram_depth_in < 3)
                  state <= STATE_NO_REP_DET;
                else
                  state <= STATE_COUNT;
           end
         STATE_COUNT :
           if (board_and_castle_mask == ram_read)
             begin
                counter <= counter + 1;
                if (counter == 2)
                  state <= STATE_REP_DET;
             end
           else
             begin
                ram_rd_addr <= ram_rd_addr + 1;
                if (ram_rd_addr == ram_depth_te)
                  state <= STATE_NO_REP_DET;
                else
                  state <= STATE_WS;
             end
         STATE_WS : // wait state for ram read
           state <= STATE_COUNT;
         STATE_NO_REP_DET :
           begin
              thrice_rep <= 0;
              thrice_rep_valid <= 1;
              if (clear_sample)
                state <= STATE_IDLE;
           end
         STATE_REP_DET :
           begin
              thrice_rep <= 1;
              thrice_rep_valid <= 1;
              if (clear_sample)
                state <= STATE_IDLE;
           end
         default :
           state <= STATE_IDLE;
       endcase

endmodule

// Local Variables:
// verilog-auto-inst-param-value:t
// verilog-library-directories:(
//     "."
//     )
// End:
