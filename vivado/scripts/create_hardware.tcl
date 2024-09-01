proc listFromFile {filename} {
    set f [open $filename r]
    set data [split [string trim [read $f]]]
    close $f
    return $data
}
create_project vchess_1 vchess -part xczu7ev-ffvc1156-2-e
set_property BOARD_PART xilinx.com:zcu106:part0:2.6 [current_project]
source scripts/mpsoc_preset.tcl
make_wrapper -files [get_files vchess/vchess_1.srcs/sources_1/bd/mpsoc_preset/mpsoc_preset.bd] -top

set all_src_files [listFromFile hardware_source.f]
add_files -norecurse $all_src_files

# set all_ip_files [listFromFile hardware_ip.f]
# foreach ip_file $all_ip_files {
#     import_ip $ip_file
#     set ip_name [file tail [file rootname $ip_file]]
# 
#     # upgrade_ip hack required to stop vivado occasionally throwing an error with "contains stale ip", grr
#     report_ip_status
#     upgrade_ip [get_ips $ip_name]
#     report_ip_status
#     
#     generate_target all [get_ips $ip_name]
#     update_compile_order -fileset sources_1
# }

# add_files -fileset constrs_1 -norecurse hardware/vchess_top.xdc
update_compile_order -fileset sources_1
launch_runs synth_1 -jobs 8
wait_on_run synth_1
set_property strategy Performance_Explore [get_runs impl_1]
launch_runs impl_1 -to_step write_bitstream -jobs 16
wait_on_run impl_1
write_hw_platform -fixed -include_bit -force -file vchess/vchess_top.xsa
validate_hw_platform -verbose vchess/vchess_top.xsa
