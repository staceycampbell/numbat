`include "vchess.vh"

module popcount
  (
   input        clk,
   input        reset,

   input [63:0] x0,
   output [5:0] population
   );

   reg [5:0]    sum;

   assign population = sum;

   always @(posedge clk)
     sum <= x0[ 0] + x0[ 1] + x0[ 2] + x0[ 3] + x0[ 4] + x0[ 5] + x0[ 6] + x0[ 7] +
            x0[ 8] + x0[ 9] + x0[10] + x0[11] + x0[12] + x0[13] + x0[14] + x0[15] +
            x0[16] + x0[17] + x0[18] + x0[19] + x0[20] + x0[21] + x0[22] + x0[23] +
            x0[24] + x0[25] + x0[26] + x0[27] + x0[28] + x0[29] + x0[30] + x0[31] +
            x0[32] + x0[33] + x0[34] + x0[35] + x0[36] + x0[37] + x0[38] + x0[39] +
            x0[40] + x0[41] + x0[42] + x0[43] + x0[44] + x0[45] + x0[46] + x0[47] +
            x0[48] + x0[49] + x0[50] + x0[51] + x0[52] + x0[53] + x0[54] + x0[55] +
            x0[56] + x0[57] + x0[58] + x0[59] + x0[60] + x0[61] + x0[62] + x0[63];

endmodule
