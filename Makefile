SRC := tb.sv vchess.sv display_board.sv is_attacking.sv display_is_attacking.sv board_attack.sv all_moves.sv \
	evaluate.sv

tb: $(SRC) vchess.vh
	iverilog -Wall -o tb $(SRC)

clean:
	rm -f tb wave.vcd
