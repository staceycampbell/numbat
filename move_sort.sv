`include "vchess.vh"

module move_sort #
  (
   parameter RAM_WIDTH = 0,
   parameter EVAL_WIDTH = 0,
   parameter MAX_POSITIONS_LOG2 = $clog2(`MAX_POSITIONS)
   )
   (
    input                                 clk,
    input                                 reset,

    input                                 sort_start,
    input                                 sort_clear,
    input                                 white_to_move,

    input                                 ram_wr_addr_init,
    input [RAM_WIDTH - 1:0]               ram_wr_data,
    input                                 ram_wr,
    input [MAX_POSITIONS_LOG2 - 1:0]      ram_rd_addr,

    output reg [RAM_WIDTH - 1:0]          ram_rd_data,
    output reg [MAX_POSITIONS_LOG2 - 1:0] ram_wr_addr,

    output reg                            sort_complete
    );

   reg                                    external_io = 0;
   
   reg [MAX_POSITIONS_LOG2 - 1:0]         local_rd_addr, local_wr_addr;
   reg [RAM_WIDTH - 1:0]                  local_wr_data;
   reg                                    local_wr;

   reg [MAX_POSITIONS_LOG2 - 1:0]         local2_rd_addr, local2_wr_addr;
   reg [RAM_WIDTH - 1:0]                  local2_wr_data, local2_rd_data;
   reg                                    local2_wr;
   
   reg [RAM_WIDTH - 1:0]                  mram [0:`MAX_POSITIONS - 1];

   wire signed [EVAL_WIDTH - 1:0]         eval = $signed(ram_rd_data[EVAL_WIDTH - 1:0]);
   wire                                   black_in_check = ram_rd_data[EVAL_WIDTH];
   wire                                   white_in_check = ram_rd_data[EVAL_WIDTH + 1];

   wire [MAX_POSITIONS_LOG2 - 1:0]        rd_addr = external_io ? ram_rd_addr : local_rd_addr;
   wire [RAM_WIDTH - 1:0]                 wr_data = external_io ? ram_wr_data : ram_wr_data;
   wire                                   wr = external_io ? ram_wr : local_wr;

   always @(posedge clk)
     begin
        if (ram_wr_addr_init && external_io)
          ram_wr_addr <= 0;
        if (ram_wr)
          begin
             mram[ram_wr_addr] <= wr_data;
             if (external_io)
               ram_wr_addr <= ram_wr_addr + 1;
             else
               ram_wr_addr <= local_wr_addr;
          end
        ram_rd_data <= mram[rd_addr];

        if (local2_wr)
          mram[local2_wr_addr] <= local2_wr_data;
        local2_rd_data <= mram[local2_rd_addr];
     end

   localparam STATE_IDLE = 0;

   reg [2:0] state = STATE_IDLE;

   always @(posedge clk)
     if (reset)
       state <= STATE_IDLE;
     else
       case (state)
         STATE_IDLE :
           begin
              local_wr <= 0;
              local2_wr <= 0;
              external_io <= 1;
              sort_complete <= 1;
           end
       endcase

endmodule

