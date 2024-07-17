module tb;

   reg clk = 0;
   reg reset = 1;
   integer t = 0;

   // should be empty
   /*AUTOREGINPUT*/

   /*AUTOWIRE*/

   initial
     begin
        $dumpfile("wave.vcd");
        $dumpvars(0, tb);
        forever
          #1 clk = ~clk;
     end

   always @(posedge clk)
     begin
        t <= t + 1;
        reset <= t < 64;

        if (t >= 512)
          $finish;
     end

   /* vchess AUTO_TEMPLATE (
    );*/
   vchess vchess
     (/*AUTOINST*/
      // Inputs
      .reset                            (reset),
      .clk                              (clk));

endmodule

// Local Variables:
// verilog-auto-inst-param-value:t
// verilog-library-directories:(
//     "."
//     )
// End:

