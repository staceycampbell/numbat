Test Benches
============

## Prerequisites

The test benches use Icarus Verilog for simulation, and pgn-extract to create verification data from
a file of several thousand valid PGN games.

* [Icarus Verilog](https://github.com/steveicarus/iverilog) should be cloned, compiled, and installed.
* [pgn-extract](https://www.cs.kent.ac.uk/people/staff/djb/pgn-extract/) should be downloaded, uncompressed,
  compiled and installed.
* [GTKWave](https://gtkwave.sourceforge.net/) can be installed from a distro package, or
  [cloned](https://github.com/gtkwave/gtkwave), compiled, and installed.

## Analyse a FEN position with `tb.sv`

`tb.sv` will clock a board position through `all_moves` and output the initial
evaluation of that board, all legal moves that can be played from that position,
and the full evaluation of each of those moves.

1. Edit `tb.sv`, insert a FEN string, then pipe the FEN string through `../misc/fenconv`
   to produce the register settings required by `all_moves`.
2. Synthesize and run the simulation with:

```
make
./tb
```
3. Inspect standard output for move and evaluation data.
4. Inspect waveforms with GTKWave.
```
gtkwave ./wave.vcd
```
## Verify `all_moves` correctness and completeness with `amtrun`

`amtrun` selects a move from `numbat/misc/GriffySr.pgn` at random, then processes that
move through `all_moves`. As of the writing of this document `amtrun` iterates over 2000 moves
and takes several hours to complete a run successfully.

pgn-extract is used to:

* Verify that the subsequent move from the GriffySr game was one of the moves produced
  by `all_moves`.
* Verify that all the additional moves (if any) produced by `all_moves` are legal.

`amtrun` exits with an error message if either of these verification tests fail.