`include "vchess.vh"

module popcount
  (
   input clk,
   input reset,

   input [63:0] x0,
   output [5:0] population
   );

   reg [64:0]   x4;

   // Knuth's method
   wire [63:0]  k1 = 64'h5555555555555555;
   wire [63:0]  k2 = 64'h3333333333333333;
   wire [63:0]  k4 = 64'h0f0f0f0f0f0f0f0f;
   wire [63:0]  kf = 64'h0101010101010101;

   wire [63:0] x1 = x0 - ((x0 >> 1) & k1);
   wire [63:0] x2 = (x1 & k2) + ((x1 >> 2) & k2);
   wire [63:0] x3 = (x2 + (x2 >> 4)) & k4;

   assign population = x4;

   always @(posedge clk)
     x4 <= (x3 * kf) >> 56;

endmodule
