Setting Bootmodes
=================

Once applications and custom HW designs are generated, developers need to move them to target. If using the Kria Starter Kit, developers can use various boot-modes to test monolithic boot to application software using the following TCL scripts to set the preferred development boot process. Developers will first put the functions in a <boot>.tcl script. Then, with the host machine connected with their SOM kit, they use the following commands in XSDB or XSCT:

```
connect
source jtag.tcl
boot_jtag
```

