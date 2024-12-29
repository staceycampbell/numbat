// Copyright (c) 2025 Stacey Campbell
// SPDX-License-Identifier: MIT

module sync
  (
   input  clk,
   input  async_in,
   output sync_out
   );


   reg    sync_0_identified_false_path;
   reg    sync_1_identified_false_path;
   
   assign sync_out = sync_1_identified_false_path;

   always @(posedge clk)
     begin
        sync_0_identified_false_path <= async_in;
        sync_1_identified_false_path <= sync_0_identified_false_path;
     end
   
endmodule
