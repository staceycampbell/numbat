CFLAGS := -Wall -g
SRC := $(addprefix ../, is_attacking.sv board_attack.sv all_moves.sv \
	evaluate.sv popcount.sv move_sort.sv mram.sv evaluate_general.sv \
	evaluate_pawns.sv evaluate_mob.sv evaluate_mob_square.sv evaluate_killer.sv latency_sm.sv \
	evaluate_bishops.sv evaluate_castling.sv evaluate_rooks.sv evaluate_tropism.sv evaluate_pv.sv)
EVSRC := $(addprefix ../, evaluate.sv evaluate_bishops.sv evaluate_castling.sv evaluate_general.sv \
	evaluate_killer.sv evaluate_mob.sv evaluate_mob_square.sv evaluate_pawns.sv evaluate_pv.sv \
	evaluate_rooks.sv evaluate_tropism.sv popcount.sv latency_sm.sv board_attack.sv \
	is_attacking.sv)
TBSRC := display_board.sv display_is_attacking.sv
HEADERS := $(addprefix ../, evaluate_general.vh evaluate_pawns.vh evaluate_tropism.vh numbat.vh attack_mask.vh mobility_mask.vh)

all: tb et tbtrans amt

tb: tb.sv $(SRC) $(TBSRC) $(HEADERS)
	iverilog -g2012 -I.. -Wall -o tb tb.sv $(SRC) $(TBSRC)

et: et.sv $(EVSRC) $(HEADERS) et_board.vh
	iverilog -g2012 -I.. -Wall -o et et.sv $(EVSRC)

tbtrans: tbtrans.sv ../trans.sv $(HEADERS)
	iverilog -g2012 -I.. -Wall -o tbtrans tbtrans.sv ../trans.sv

amt: amt.sv $(SRC) $(TBSRC) $(HEADERS) amt_board.vh
	iverilog -g2012 -I.. -Wall -o amt amt.sv $(SRC) $(TBSRC)

amt_board.vh: ../misc/fenconv
	echo '6k1/2p2pPp/2qp1R2/4p1P1/4P3/1r1n2NP/3QN1K1/r7 b - - 1 39' | ../misc/fenconv > amt_board.vh

et_board.vh: amt_board.vh
	cp amt_board.vh et_board.vh

../misc/fenconv:
	cd ../misc && $(MAKE)

$(HEADERS):
	cd .. && $(MAKE)

srclist:
	@echo $(SRC)

evsrclist:
	@echo $(EVSRC)

clean:
	rm -f tb wave.vcd attack attack.o amt amt_board.vh tbtrans et et_board.vh game.* log.*
