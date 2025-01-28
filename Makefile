CFLAGS := -Wall -g -O2
EVALHEADERS := evaluate_general.vh evaluate_pawns.vh evaluate_tropism.vh

all: $(EVALHEADERS) attack_mask.vh

attack_mask.vh: attack
	attack > attack_mask.vh

$(EVALHEADERS): evaluate
	evaluate

clean:
	rm -f attack attack.o attack_mask.vh evaluate $(EVALHEADERS)
	(cd ./misc && $(MAKE) clean)
	(cd ./tb && $(MAKE) clean)
