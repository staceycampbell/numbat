CFLAGS := -Wall -O2
SRC := tb.sv display_board.sv is_attacking.sv display_is_attacking.sv board_attack.sv all_moves.sv \
	evaluate.sv

all: tb

tb: $(SRC) vchess.vh attack_mask.vh
	iverilog -Wall -o tb $(SRC)

attack_mask.vh: attack
	attack > attack_mask.vh

clean:
	rm -f tb wave.vcd attack attack.o attack_mask.vh
