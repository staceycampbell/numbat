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
of numbat to stdin and stdout of a computer that is internet-connected to the KR260. Note that the
default IP address used will be `192.168.0.90`. This can be changed in either the source or with a
command line argument `-d xxx.xxx.xxx.xxx`.
```
cd numbat/vivado/comms
make
```
3. Load and run numbat on the KR260.
4. Start xboard and configure the computer engine path with the -fd option and the `numbattcp` bridge
   program with the -fcp option. For example:
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
  - Move generation in parallel with full position evaluation.
  - Move ordering with PV priority.
  - Zobrist hashing.
  - Transposition table lookup and write via AXI4 DMA
    - 2GByte TT in PS DDR4 HIGH address space for negamax
    - 2MByte TT in URAM for quiescence
  - Thrice repetition draw detection.
* The PS side (a single Arm Cortex-A53 MPCore) is coded in C. Functions performed are:
  - Negamax algorithm.
    - alpha beta pruning
    - iterative deepening depth first search
    - principal variation tracking
    - quiescence search
    - crude futility pruning
  - Game time control.
  - Lwip TCP stack for UCI communication.
  - UART for debug input/output.

## Code Notes

* The top level module is `numbat_top.sv`. The Vivado block diagram wrapper is instantiated
  inside this module.
* The code makes minimal use of System Verilog features and is mostly written in vanilla Verilog (2005).
* All evaluation algorithms are performed in parallel for a given board.
* Several algorithms (legal moves, evaluations) are table driven, and those tables are created
  and output to Verilog header files on the host Linux computer prior to Vivado synthesis.
* **All** module instantiation code is created with [Emacs Verilog-mode](https://veripool.org/verilog-mode/).
  - I generally only use AUTO_TEMPLATE, AUTOINST, AUTOWIRE, and AUTOREGINPUT.
  - I only use AUTOREGINPUT to detect unconnected module inputs. I never use it to create registers.
  - I am a `vi` user so I unconditionally use [Emacs Evil](https://www.emacswiki.org/emacs/Evil).
* The C code in `numbat/vivado/src` interacts with the Verilog via the
  [AXI4-Lite](https://en.wikipedia.org/wiki/Advanced_eXtensible_Interface#AXI4-Lite) `ctrl0_axi` interface.
* HDL synthesis tools eliminate redundant digital circuits and eliminate circuits with a constant known
  output. The evaluation and transposition Verilog is coded for clarity, but has considerable
  redundancy and many fixed output circuits, so the project relies on these tool optimizations to produce
  a small logic footprint.
  - The Vivado synthesis tool expends a lot of time on these optimizations in the mobility evaluation logic.
    For fast debug build times set the `EVAL_MOBILITY_DISABLE` parameter to 1 in `numbat_top.sv` to
    eliminate mobility scoring from the evaluation logic.

## Hardware Notes

* The Kria KR260 fan runs at full duty cycle for bare metal designs. This project has implemented
  a PL PWM driver to reduce fan noise. The PWM operates at 25kHz and has a programmable duty cycle.
  PS core temperature is monitored at 5 second intervals and the project is put in reset if the PS
  core exceeds 50C. The duty cycle has a floor setting of 10% to ensure the fan doesn't stall.
* There are two user-controlable LEDs on the KR260, these blink to indicate that a negamax operation
  is underway and are off when the PL is idle.
