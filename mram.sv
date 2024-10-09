`include "vchess.vh"

module mram #
  (
   parameter RAM_WIDTH = 0,
   parameter MAX_POSITIONS_LOG2 = $clog2(`MAX_POSITIONS)
   )
   (
    input                            clk,

    input                            active_port_a_wr_en,
    input [MAX_POSITIONS_LOG2 - 1:0] active_port_a_addr,
    input                            active_port_b_wr_en,
    input [MAX_POSITIONS_LOG2 - 1:0] active_port_b_addr,
    input [RAM_WIDTH - 1:0]          active_port_a_wr_data,
    input [RAM_WIDTH - 1:0]          port_b_wr_data,

    output reg [RAM_WIDTH - 1:0]     port_a_rd_data,
    output reg [RAM_WIDTH - 1:0]     port_b_rd_data
    );
   
   reg [RAM_WIDTH - 1:0]             mram [0:`MAX_POSITIONS - 1]; // inferred dual port Xilinx Block RAM

   always @(posedge clk)
     begin
        if (active_port_a_wr_en)
          mram[active_port_a_addr] <= active_port_a_wr_data;
        port_a_rd_data <= mram[active_port_a_addr];

        if (active_port_b_wr_en)
          mram[active_port_b_addr] <= port_b_wr_data;
        port_b_rd_data <= mram[active_port_b_addr];
     end

endmodule
