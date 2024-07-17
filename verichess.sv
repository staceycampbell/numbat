module tb;

   reg clk = 0;
   reg reset = 1;
   integer t = 0;

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

endmodule
