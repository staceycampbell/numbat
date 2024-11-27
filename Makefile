CFLAGS := -Wall -g
SRC := display_board.sv is_attacking.sv display_is_attacking.sv board_attack.sv all_moves.sv \
	evaluate.sv rep_det.sv popcount.sv move_sort.sv mram.sv evaluate_general.sv \
	evaluate_pawns.sv evaluate_mob.sv evaluate_mob_square.sv evaluate_killer.sv latency_sm.sv \
	evaluate_bishops.sv evaluate_castling.sv
EVALHEADERS := evaluate_general.vh evaluate_pawns.vh

all: tb tbtrans

tb: tb.sv $(SRC) vchess.vh attack_mask.vh mobility_mask.vh $(EVALHEADERS)
	iverilog -Wall -o tb tb.sv $(SRC)

tbtrans: tbtrans.sv trans.sv vchess.vh attack_mask.vh
	iverilog -Wall -o tbtrans tbtrans.sv trans.sv

amt: amt.sv $(SRC) vchess.vh attack_mask.vh amt_board.vh
	iverilog -Wall -o amt amt.sv $(SRC)

attack_mask.vh: attack
	attack > attack_mask.vh

mobility_mask.vh: nbrq_mobility
	nbrq_mobility

$(EVALHEADERS): evaluate
	evaluate

srclist:
	@echo $(SRC)

clean:
	rm -f tb wave.vcd attack attack.o attack_mask.vh mobility_mask.vh amt amt_board.vh tbtrans evaluate $(EVALHEADERS)
	rm -f nbrq_mobility mobility_mask.vh mobility_head.vh
