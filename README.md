Numbat
======

![Numbats](image-of-numbat.jpg)

Numbat is a [UCI](https://en.wikipedia.org/wiki/Universal_Chess_Interface) chess engine written in Verilog and C.
It is targeted to run on a [Kria KR260 robotics starter kit](https://www.amd.com/en/products/system-on-modules/kria/k26/kr260-robotics-starter-kit.html).
The project is currently configured to be built on a Linux system using [AMD Vivado 2022.2](https://www.xilinx.com/support/download.html).

The UCI interface is accessed via TCP. The KR260 will appear at a static IP address. To modify that address change the
following lines in `main.c`.

```
IP4_ADDR(&ipaddr, 192, 168, 0, 90);
IP4_ADDR(&netmask, 255, 255, 255, 0);
IP4_ADDR(&gw, 192, 168, 0, 1);
```

To build the project:

```
cd numbat/vivado
make create_hardware && make create_software
```

Once built a Vitis 2022.2 workspace will be at:

```
numbat/vivado/numbat_workspace
```

The project uses the GEM1 ethernet interface. This corresponds to ethernet port
[J10D](https://docs.amd.com/r/en-US/ug1092-kr260-starter-kit/Interfaces) on the KR260,
which is the upper right port on the RJ-45 block. Debug input/output also appears on the UART port
at J4 (115200 baud, 8N1).

To run the built project:

1. Power up the KR260.
2. Use xsct to force the board into JTAG boot mode, see instructions in numbat/vivado/scripts/README.md. Without this step
   the KR260 PL clocks will not be running and the Zynq ARM will hang.
3. Start Vitis and select the workspace outlined above.
4. UCI commands can be directed to/from the IP you have selected at port 12320.
