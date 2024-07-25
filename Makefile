SRC := tb.sv vchess.sv display_board.sv is_attacking.sv display_is_attacking.sv

tb: $(SRC) vchess.vh
	iverilog -Wall -o tb $(SRC)

clean:
	rm -f tb wave.vcd
