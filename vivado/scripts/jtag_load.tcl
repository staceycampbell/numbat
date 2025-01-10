proc boot_jtag { } {
    ############################
    # Switch to JTAG boot mode #
    ############################
    targets -set -filter {name =~ "PSU"}
    # update multiboot to ZERO
    mwr 0xffca0010 0x0
    # change boot mode to JTAG
    mwr 0xff5e0200 0x0100
    # reset
    rst -system
}

connect
boot_jtag

after 2000
targets -set -filter {name =~ "PSU"}
fpga "../numbat_workspace/numbat_standalone/hw/numbat_top.bit"
mwr 0xffca0038 0x1FF

# Download pmufw.elf
targets -set -filter {name =~ "MicroBlaze PMU"}
after 500
dow ../numbat_workspace/numbat_standalone/export/numbat_standalone/sw/numbat_standalone/boot/pmufw.elf
con
after 500

# Select A53 Core 0
targets -set -filter {name =~ "Cortex-A53 #0"}
rst -processor -clear-registers
dow ../numbat_workspace/numbat_standalone/export/numbat_standalone/sw/numbat_standalone/boot/fsbl.elf
con
after 10000
stop


dow ../numbat_workspace/swnumbat_app/Debug/swnumbat_app.elf
after 500
con
