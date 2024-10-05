`include "vchess.vh"

module popcount
  (
   input        clk,
   input        reset,

   input [63:0] x0,
   output [5:0] population
   );

   reg [64:0]   x0_t1;
   reg [64:0]   x1_t2;
   reg [64:0]   x3_t3;
   reg [64:0]   x4_t4, x4_t5;

   // Knuth's method
   wire [63:0]  k1 = 64'h5555555555555555;
   wire [63:0]  k2 = 64'h3333333333333333;
   wire [63:0]  k4 = 64'h0f0f0f0f0f0f0f0f;
   wire [63:0]  kf = 64'h0101010101010101;

   wire [63:0]  x2_t2 = (x1_t2 & k2) + ((x1_t2 >> 2) & k2);

   wire [63:0]  x0_t0 = x0;

   assign population = x4_t5;

   always @(posedge clk)
     begin
        x0_t1 <= x0_t0;
        x1_t2 <= x0_t1 - ((x0_t1 >> 1) & k1);
        x3_t3 <= (x2_t2 + (x2_t2 >> 4)) & k4;
        x4_t4 <= (x3_t3 * kf) >> 56;
        x4_t5 <= x4_t4;
     end

endmodule
