// Copyright (c) 2025 Stacey Campbell
// SPDX-License-Identifier: MIT

module axi4lite_write
  (
   input             aresetb,
   input             clk,
  
   input [39:0]      axi_awaddr,
   input [2:0]       axi_awprot,
   input             axi_awvalid,
   input             axi_bready,
   input [31:0]      axi_wdata,
   input [3:0]       axi_wstrb,
   input             axi_wvalid,
  
   output reg        axi_awready,
   output [1:0]      axi_bresp,
   output reg        axi_bvalid,
   output reg        axi_wready,

   output reg [39:0] addr,
   output reg [31:0] data,
   output reg        valid
   );

   localparam STATE_IDLE = 0;
   localparam STATE_WAIT_DATA = 1;
   localparam STATE_WAIT_ADDR = 2;
   localparam STATE_BVALID = 3;
   
   reg [1:0]         state = STATE_IDLE;

   assign axi_bresp = 2'b0; // always okay

   always @(posedge clk)
     if (~aresetb)
       begin
          state <= STATE_IDLE;
          axi_awready <= 0;
          axi_wready <= 0;
          axi_bvalid <= 0;
          valid <= 0;
       end
     else
       case (state)
         STATE_IDLE :
           begin
              axi_awready <= 1;
              axi_wready <= 1;
              valid <= 0;
              axi_bvalid <= 0;
              if (axi_awvalid && axi_awready)
                begin
                   addr <= axi_awaddr;
                   if (axi_wvalid && axi_wready)
                     begin
                        data <= axi_wdata; // data and address arrived on same clock
                        valid <= 1;
                        axi_bvalid <= 1;
                        axi_awready <= 0;
                        axi_wready <= 0;
                        state <= STATE_BVALID;
                     end
                   else
                     begin
                        axi_awready <= 0; // address has arrived before data
                        state <= STATE_WAIT_DATA;
                     end
                end
              else if (axi_wvalid && axi_wready)
                begin
                   axi_wready <= 0; // data has arrived before address, see AMBA AXI spec A3.3.1 Dependencies between channel handshake signals
                   data <= axi_wdata;
                   state <= STATE_WAIT_ADDR;
                end
           end
         STATE_WAIT_DATA:
           if (axi_wvalid)
             begin
                data <= axi_wdata;
                valid <= 1; // address is already valid
                axi_bvalid <= 1;
                axi_wready <= 0;
                state <= STATE_BVALID;
             end
         STATE_WAIT_ADDR :
           if (axi_awvalid)
             begin
                addr <= axi_awaddr;
                valid <= 1; // data is already valid
                axi_bvalid <= 1;
                axi_awready <= 0;
                state <= STATE_BVALID;
             end
         STATE_BVALID :
           begin
              valid <= 0;
              if (axi_bready)
                begin
                   axi_awready <= 1;
                   axi_wready <= 1;
                   axi_bvalid <= 0;
                   state <= STATE_IDLE;
                end
           end
       endcase

endmodule
