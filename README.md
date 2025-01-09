Numbat
======

Numbat is a UCI chess engine written in Verilog and C. The project is coded to be built with
[AMD Vivado 2022.2](https://www.xilinx.com/support/download.html) for a
[Kria KR260 robotics starter kit](https://www.amd.com/en/products/system-on-modules/kria/k26/kr260-robotics-starter-kit.html).

To build:

```
cd numbat/vivado
make create_hardware && make create_software
```