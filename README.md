Numbat
======

![Numbats](image-of-numbat.jpg)

Numbat is a [UCI](https://en.wikipedia.org/wiki/Universal_Chess_Interface) chess engine written in Verilog and C.
It is targeted to run on a [Kria KR260 robotics starter kit](https://www.amd.com/en/products/system-on-modules/kria/k26/kr260-robotics-starter-kit.html).
The project is currently configured to be built on a Linux system using [AMD Vivado 2022.2](https://www.xilinx.com/support/download.html).

The UCI interface is accessed via TCP. The KR260 will appear at a static IP address. To modify that address change the
following lines in `numbat/vivado/main.c`.

```
IP4_ADDR(&ipaddr, 192, 168, 0, 90);
IP4_ADDR(&netmask, 255, 255, 255, 0);
IP4_ADDR(&gw, 192, 168, 0, 1);
```

## Build the project

```
cd numbat/vivado
make create_hardware && make create_software
```

Once built a Vitis 2022.2 workspace will be at this path:

```
numbat/vivado/numbat_workspace
```

The Vivado 2022.2 project file will be:
```
numbat/vivado/numbat/numbat_1.xpr
```

The project uses the GEM1 ethernet interface. This corresponds to ethernet port
[J10D](https://docs.amd.com/r/en-US/ug1092-kr260-starter-kit/Interfaces) on the KR260,
which is the upper right port on the RJ-45 block. Debug input/output also appears on the UART port
at J4 (115200 baud, 8N1).

## Run the project

1. Power up the KR260.
2. Use xsct to force the board into JTAG boot mode, see instructions in numbat/vivado/scripts/README.md. Without this step
   the KR260 PL clocks will not be running and the Zynq ARM will hang.
3. Start Vitis and select the workspace outlined above.
4. UCI commands can be directed to/from the IP you have selected at port 12320.

## Using numbat with xboard

Several steps are required to connect [xboard](https://www.gnu.org/software/xboard/) to numbat.

1. Obtain, compile and install polyglot. Polyglot provides a translation between UCI protocol and
   xboard protocol. I cloned [polyglot from github](https://github.com/ulthiel/polyglot.git).
2. Compile a small bridge application called `numbattcp` that connects the TCP listening port
of numbat to stdin and stdout of a computer that is internet-connected to the KR260.
```
cd numbat/vivado/comms
make
```
3. Load and run numbat on the KR260.
4. Start xboard and configure the computer engine path with the -fd option and the bridge command
   with the -fcp option. For example:
```
xboard -boardSize Medium -fUCI -fcp numbattcp \
       -fd /home/stacey/src/numbat/vivado/comms
```
5. In xboard: Engine->Common Engine Settings configure the path to polyglot.
6. Configure polyglot via xboard: Engine->Engine #1 Settings:
   * Give a path to the Polyglot Settings File
   * [Obtain a polyglot book.bin file](https://chess.stackexchange.com/q/35448).
   * Check Polyglot Book.
   * Specify the path to the book.
   * Click Polyglot Save.

## Simulating Verilog

The Verilog can be simulated with [Icarus Verilog](https://github.com/steveicarus/iverilog).
Waveforms can be viewed with [gtkwave](https://github.com/gtkwave/gtkwave).

Edit `tb.sv` and scroll down for instructions on how to simulate an arbitrary
[FEN](https://en.wikipedia.org/wiki/Forsyth%E2%80%93Edwards_Notation) position.

```
cd numbat/tb
make
./tb
gtkwave wave.vcd
```

## Architecture

* Numbat is a bare metal Vivado project.
* The PL side (FPGA fabric) is coded in Verilog. The PL side performs the following functions:
  - Legal move generation.
  - Position evaluation.
  - Zobrist hashing.
  - Transposition table lookup and write
    - 2GByte TT in PS DDR4 HIGH address space for negamax
    - 2MByte TT in URAM for quiescence
  - Thrice repetition draw detection.
* The PS side (a single Arm Cortex-A53 MPCore) is coded in C. Functions performed are:
  - Negamax algorithm.
  - Game time control.
  - Lwip TCP stack for UCI communication.
  - UART for debug input/output.
