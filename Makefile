CFLAGS := -Wall -O2
SRC := display_board.sv is_attacking.sv display_is_attacking.sv board_attack.sv all_moves.sv \
	evaluate.sv rep_det.sv

all: tb amt

tb: tb.sv $(SRC) vchess.vh attack_mask.vh
	iverilog -Wall -o tb tb.sv $(SRC)

amt: amt.sv $(SRC) vchess.vh attack_mask.vh
	iverilog -Wall -o amt amt.sv $(SRC)

attack_mask.vh: attack
	attack > attack_mask.vh

clean:
	rm -f tb wave.vcd attack attack.o attack_mask.vh amt
