SRC := tb.sv vchess.sv
vchess: $(SRC)
	iverilog -Wall -o tb $(SRC)

clean:
	rm -f tb wave.vcd
