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

    output [RAM_WIDTH - 1:0]              ram_rd_data,
    output reg [MAX_POSITIONS_LOG2 - 1:0] ram_wr_addr,

    output reg                            sort_complete
    );

   reg                                    external_io = 0;

   reg [MAX_POSITIONS_LOG2 - 1:0]         port_a_addr;
   reg                                    port_a_wr_en = 0;
   reg [RAM_WIDTH - 1:0]                  port_a_wr_data;
   reg [RAM_WIDTH - 1:0]                  port_a_rd_data;
   
   reg [MAX_POSITIONS_LOG2 - 1:0]         port_b_addr;
   reg                                    port_b_wr_en = 0;
   reg [RAM_WIDTH - 1:0]                  port_b_wr_data;
   reg [RAM_WIDTH - 1:0]                  port_b_rd_data;
   
   reg [RAM_WIDTH - 1:0]                  mram [0:`MAX_POSITIONS - 1]; // inferred dual port Xilinx Block RAM

   wire [MAX_POSITIONS_LOG2 - 1:0]        active_port_a_addr = external_io ? ram_wr_addr : port_a_addr; // external write a port
   wire [MAX_POSITIONS_LOG2 - 1:0]        active_port_b_addr = external_io ? ram_rd_addr : port_b_addr; // external read b port

   wire [RAM_WIDTH - 1:0]                 active_port_a_wr_data = external_io ? ram_wr_data : port_a_wr_data;

   wire                                   active_port_a_wr_en = external_io ? ram_wr : port_a_wr_en;

   assign ram_rd_data = port_b_rd_data;

   always @(posedge clk)
     begin
        external_io <= 1;
        sort_complete <= 1;
        
        if (ram_wr_addr_init)
          ram_wr_addr <= 0;
        if (ram_wr)
          ram_wr_addr <= ram_wr_addr + 1;

        port_a_wr_en <= 0; // overridden below
        port_b_wr_en <= 0; // overridden below
        
        if (active_port_a_wr_en)
          mram[active_port_a_addr] <= active_port_a_wr_data;
        port_a_rd_data <= mram[active_port_a_addr];

        if (port_b_wr_en)
          mram[active_port_b_addr] <= port_b_wr_data;
        port_b_rd_data <= mram[active_port_b_addr];
     end

endmodule

