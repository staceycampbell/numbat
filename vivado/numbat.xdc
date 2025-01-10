set_property PACKAGE_PIN F8      [get_ports "led_uf1"] ;# Bank  66 VCCO - som240_1_d1 - IO_L17P_T2U_N8_AD10P_66
set_property IOSTANDARD LVCMOS18 [get_ports "led_uf1"]
set_property PACKAGE_PIN E8      [get_ports "led_uf2"] ;# Bank  66 VCCO - som240_1_d1 - IO_L17N_T2U_N9_AD10N_66
set_property IOSTANDARD LVCMOS18 [get_ports "led_uf2"]

# use Raspberry Pi GPIO RPI_GPIO21_PCM_DOUT pin 40 header for testing
set_property PACKAGE_PIN W11     [get_ports "fan_pwm"] ;# Bank  44 VCCO - som240_2_d59 - IO_L11N_AD9N_44
set_property IOSTANDARD LVCMOS33 [get_ports "fan_pwm"]

# False paths
#set _xlnx_shared_i0 [get_cells -hier *identified_false_path*]
#set_false_path -to $_xlnx_shared_i0
#set_false_path -from $_xlnx_shared_i0
