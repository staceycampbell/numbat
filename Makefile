verichess: verichess.sv
	iverilog -Wall -o verichess verichess.sv

test: verichess
	./verichess

clean:
	rm -f verichess wave.vcd
