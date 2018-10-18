### Brainf*ck to 8085 Assembler compiler written in Red
---

#### Examples:
`5 * 10` in BF 
(Constant multiplication is optimised by the compiler)
``` rebol
bf/comment-start {+++++[->++++++++++<]} " ;"
```
yields
``` assembly
MVI D,10 ; Data starting at 0A00h
ADI 50 ; 5 * 10
STAX D ; Save to memory before exiting
HLT ; Exit
```
---

`5 - 3` in BF 
(Substraction is not yet optimised)
``` rebol
bf/comment-start {+++++>+++[-<->]} " ;"
```
yields
``` assembly
MVI D,10 ; Data starting at 0A00h
ADI 5 ; + 5
STAX D ; >
INX D
LDAX D
ADI 3 ; + 3
label1: NOP ; [
        DCR A ; - 1
        STAX D ; <
        DCX D
        LDAX D
        DCR A ; - 1
        STAX D ; >
        INX D
        LDAX D
        CPI 0
JNZ label1 ; ]
STAX D ; Save to memory before exiting
HLT ; Exit
```

#### Compatibility:
Many 8085 emulators / assemblers have different comment line starts, you can choose the one you need by using the `/comment-start` refinement or you disable all comments by using the `/no-comments` refinement. Default comment is a `#` without a preceeding space. To compile a snippet for [GNUSim8085](https://gnusim8085.github.io/) for example, you have to use `;` **without a preceeding space** as the comment, as follows:
```
bf/comment-start {... code goes here ...} ";"
```
On the other hand, the online interpreter [sim8085](https://www.sim8085.com/) **allow** you to include a preceeding space, to enchant readability.

Furthermore, some emulators / assemblers interpret a number followed by a `h` as a label, so only decimal addresses and numbers are used here. 

#### I / O:
Port 1, and currently only Port 1 is used as the Input / Output or the program (`,` and `.` in BF). The compiled program **does not** wait until input "is available". This behaiviour may improve in the future, but feel free to submit a PR if you want it :P.

#### How it works:
The compiler matches the BF code against a set of rules, and generates the mnemonics (You didn't expect this, did you? :P). On program execution, changes are always first performed on registers and then written to RAM on pointer move (`>` and `<`).
 - Register `A` contains the value of the current cell.
 - Register `D` and `E` contain the `16 Bit` address of the current cell. It's set to `0A00` Hex (`1000` decimal) on program start.

#### Optimisations:
The BF program is compiled to assembly applying some basic, naive optimisations: 
- A multiplication of two constants is replaced with an `ADI` instruction
- `[-]`, used for zeroing a cell, is replaced with a XOR of the register with itself (`XRA A`)
- Pointer moves below 5 get compiled to single increments of the pointer, whetever pointer moves above and including 5 get compiled to an `ADD` to safe cycles. This is done because the pointer is stored as a `16 Bit` address, and an `16 Bit` addition is in our case as expensive as 5 increments. E.g.:
```
+++ ->
    ...
    INX D 
    INX D
    INX D
    ...
++++++ ->
    ...
    ADI D,6
    ...
```
- Similiar to that above, single increments of a cell get compiled to an `INR`, but starting from 2 increments an addition is performed (`ADI`)
