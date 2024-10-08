`include "vchess.vh"

module move_sort #
  (
   parameter RAM_WIDTH = 0,
   parameter MAX_POSITIONS_LOG2 = $clog2(`MAX_POSITIONS)
   )
   (
    input                                 clk,
    input                                 reset,

    input                                 ram_wr_addr_init,
    input [RAM_WIDTH - 1:0]               ram_wr_data,
    input                                 ram_wr,
    input [MAX_POSITIONS_LOG2 - 1:0]      ram_rd_addr,

    output reg [RAM_WIDTH - 1:0]          ram_rd_data,
    output reg [MAX_POSITIONS_LOG2 - 1:0] ram_wr_addr
    );

   reg [RAM_WIDTH - 1:0]                  mram [0:`MAX_POSITIONS - 1];

   always @(posedge clk)
     begin
        if (ram_wr_addr_init)
          ram_wr_addr <= 0;
        if (ram_wr)
          begin
             mram[ram_wr_addr] <= ram_wr_data;
             ram_wr_addr <= ram_wr_addr + 1;
          end
        ram_rd_data <= mram[ram_rd_addr];
     end

endmodule

