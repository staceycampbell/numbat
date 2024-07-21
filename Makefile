SRC := tb.sv vchess.sv display_board.sv is_attacked.sv display_is_attacked.sv

vchess: $(SRC)
	iverilog -Wall -o tb $(SRC)

clean:
	rm -f tb wave.vcd
