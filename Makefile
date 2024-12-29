CFLAGS := -Wall -g -O2
EVALHEADERS := evaluate_general.vh evaluate_pawns.vh evaluate_tropism.vh

all: $(EVALHEADERS) attack_mask.vh mobility_mask.vh

attack_mask.vh: attack
	attack > attack_mask.vh

mobility_mask.vh: nbrq_mobility
	nbrq_mobility

$(EVALHEADERS): evaluate
	evaluate

clean:
	rm -f attack attack.o attack_mask.vh evaluate $(EVALHEADERS)
	rm -f nbrq_mobility mobility_mask.vh mobility_head.vh
	(cd ./misc && $(MAKE) clean)
	(cd ./tb && $(MAKE) clean)
