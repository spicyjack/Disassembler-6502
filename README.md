#  Disassembler

This is a simple [disassembler](https://en.wikipedia.org/wiki/Disassembler) for [MOS 6502](https://en.wikipedia.org/wiki/MOS_Technology_6502) [machine language](https://en.wikipedia.org/wiki/Machine_code), written in [Swift](https://en.wikipedia.org/wiki/Swift_(programming_language)). 

The disassembler allows the start address to be specified. It replaces addresses with symbolic labels if it can determine that the address falls within the bounds of the program. The map of numeric op-codes to symbolic op-codes can be customized at run-time, as can the handling of individual addressing modes.

For example, if the input file is the following sequence of bytes:
```
A9 01 C9 02 D0 04 85 22 F0 F6 00
```
then without any additional command-line arguments, the following output will be generated:
```
L0000 1000: a9 01        LDA #$01
      1002: c9 02        CMP #$02
      1004: d0 04 85     BNE $100a
      1007: 22            
      1008: f0 f6 00     BEQ L0000

LABELS
      L0000: $1000
```
The `BEQ` at address `0x1008` has been identified as branching to an address lying inside the program (`0x1000`). It has therefore been replaced by a symbolic label (`L0000`). 

At the end of the disassembly, a list of labels is given.

If no starting address is specified, a default of `0x1000` is used. A different starting address can be specified using the `--start-address` command-line argument. The value can be in decimal or hexadecimal; the latter should be prefixed by `0x`, as in `--start address 0x2000` to specify a start address of 8192.

As shown above, if the program contains address references outside the program, the disassembler will render them in numeric form. The `--labelled-addresses-file-name` command-line argument can be used to provide a list of additional addresses and their symbolic form. The syntax is 
```
<label> <address>
```
one per line, with arbitrary whitespace separating the two. For example,
```
L0000 0x100a
```
Running the previous example again, but providing also the `--labelled-addresses-file-name` command-line argument with a file containing this label/address pair will generate
```
L0001 1000: a9 01        LDA #$01
      1002: c9 02        CMP #$02
      1004: d0 04 85     BNE L0000
      1007: 22            
      1008: f0 f6 00     BEQ L0001

LABELS
      L0000: $100a
      L0001: $1000
```
where the target of the `BNE` at address `0x1004` has been replaced by the label `L000`. Note also that the auto-generated label for the target of the `BEQ` at address `0x1008` has changed so as to avoid a name-collision.

The `--op-code-prototypes-file-name` command-line argument can be used to provide a mapping from numeric op-codes to their symbolic equivalent. See [`Resources/opCodes.in`](Resources/opCodes.in) for an example. Similarly, the `--addressing-modes-file-name` command-line argument can be used to customize the handling of addressing modes. See [`Resources/addressingModes.in`](Resources/addressingModes.in) for an example.
