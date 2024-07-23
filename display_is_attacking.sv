module display_is_attacking #
  (
   parameter COLOR_ATTACKS = "White"
   )
   (
    input        clk,
    input        reset,
    input [63:0] attacked,
    input        attacked_valid,

    output reg   display_done = 0
    );

   localparam PIECE_WIDTH = 1;
   localparam SIDE_WIDTH = 8;

   reg [7:0]     piece_char [0:1];
   reg [$clog2(64) - 1:0] index, row_start;
   reg [2:0]              col;

   initial
     begin
        piece_char[0] = ".";
        piece_char[1] = "X";
     end

   localparam STATE_INIT = 0;
   localparam STATE_TITLE = 1;
   localparam STATE_ROW = 2;

   reg [1:0] state = STATE_INIT;

   always @(posedge clk)
     if (reset)
       state <= STATE_INIT;
     else
       case (state)
         STATE_INIT :
           begin
              display_done <= 0;
              row_start <= SIDE_WIDTH * 7;
              index <= SIDE_WIDTH * 7;
              col <= 0;
              if (attacked_valid)
                state <= STATE_TITLE;
           end
         STATE_TITLE :
           begin
              $display("%s", COLOR_ATTACKS);
              state <= STATE_ROW;
           end
         STATE_ROW :
           begin
              $write("%c ", piece_char[attacked[index+:PIECE_WIDTH]]);
              index <= index + PIECE_WIDTH;
              if (col == 7)
                begin
                   col <= 0;
                   row_start <= row_start - SIDE_WIDTH;
                   index <= row_start - SIDE_WIDTH;
                   $write("\n");
                end
              else
                col <= col + 1;
              if (index == SIDE_WIDTH - PIECE_WIDTH)
                begin
                   $write("\n");
                   display_done = 1;
                   state <= STATE_INIT;
                end
           end
       endcase

endmodule
