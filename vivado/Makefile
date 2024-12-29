all:
	@echo create_hardware - build hardware
	@echo create_software - build software
	@echo clean - remove software generated files
	@echo distclean - remove hardware and software generated files

create_hardware: ../attack_mask.vh evaluate
	vivado -mode batch -source scripts/create_hardware.tcl

../attack_mask.vh: ../attack
	../attack > ../attack_mask.vh

../attack: ../attack.c
	(cd ..; $(MAKE) attack)

evaluate:
	(cd .. && $(MAKE))

create_software:
	xsct scripts/create_software.tcl

clean:
	rm -fr numbat_workspace vivado*.jou vivado*.log xrc.log vivado_pid*.str vitis_pid*.str gtwiz_us_nlv.log xrc.log

distclean: clean
	rm -fr .Xil numbat vivado.jou vivado.log vivado*backup.log vivado*backup.jou vivado_pid*.zip
