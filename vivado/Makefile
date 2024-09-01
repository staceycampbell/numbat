create_hardware:
	vivado -mode batch -source scripts/create_hardware.tcl

create_software:
	vivado -mode batch -source scripts/create_software.tcl

distclean:
	rm -fr vchess vivado.jou vivado.log vivado*backup.log vivado*backup.jou
	rm -fr vivado_pid*.str .Xil vchess_workspace xrc.log
