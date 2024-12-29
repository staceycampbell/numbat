// Copyright (c) 2025 Stacey Campbell
// SPDX-License-Identifier: MIT

`include "vchess.vh"

module xorshift32
  (
   input             clk,
   input             reset,
  
   output reg [31:0] x
   );

   reg [31:0]        x_int;
   
   function [31:0] xorshift32_func (input [31:0] x);
      begin
         reg [31:0] x_init, x0, x1, x2, x3;
         
         x_init = x == 0 ? 1 : x; // avoid 0
         x0 = ((x_init & 32'h0007ffff) << 13) ^ x;
         x1 = (x0 >> 17) ^ x0;
         x2 = ((x1 & 32'h07ffffff) << 5) ^ x1;
         x3 = x2 & 32'hffffffff;
         xorshift32_func = x3;
      end
   endfunction

   always @(posedge clk)
     x <= x_int;

   always @(posedge clk)
     if (reset)
       x_int <= 'hABCD;
     else
       x_int <= xorshift32_func(x_int);
   
endmodule

