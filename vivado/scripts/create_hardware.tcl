proc listFromFile {filename} {
    set f [open $filename r]
    set data [split [string trim [read $f]]]
    close $f
    return $data
}
create_project numbat_1 numbat -part xczu7ev-ffvc1156-2-e
set_property BOARD_PART xilinx.com:zcu106:part0:2.6 [current_project]
source scripts/mpsoc_block_diag.tcl
make_wrapper -files [get_files numbat/numbat_1.srcs/sources_1/bd/mpsoc_block_diag/mpsoc_block_diag.bd] -top

set all_src_files [listFromFile hardware_source.f]
add_files -norecurse $all_src_files
add_files -fileset constrs_1 -norecurse numbat.xdc

update_compile_order -fileset sources_1
launch_runs synth_1 -jobs 8
wait_on_run synth_1
set_property strategy Performance_Explore [get_runs impl_1]
launch_runs impl_1 -to_step write_bitstream -jobs 16
wait_on_run impl_1
write_hw_platform -fixed -include_bit -force -file numbat/numbat_top.xsa
validate_hw_platform -verbose numbat/numbat_top.xsa
