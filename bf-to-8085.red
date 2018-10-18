Red [
    Author: "Nikita Korotkin"
    Original-Version: https://gist.github.com/dockimbel/7713170
]

bf: function [
    {Translates Brainf*ck code into 8085 assembler mnemonics.}
    prog [string!] "The bf-program"
    /comment-start cmn "The comment-line starter. # by default."
    /no-comments "Do not generate comments."
][
    unless comment-start [cmn: "#"]

    ;; Data is starting at address 0A00h
    outbuff: rejoin ["MVI D,10" rejoin either no-comments [[""]][[cmn space "Data starting at 0A00h"]] "^/"]
    ;; Last used jump-label index (e.g. when this is 22 then the last jump label would be label22)
    jmp-idx: 0
    ;; List of all labels, handled as a kind-of stack
    jmp-buff: copy []

    ;; Emits a mnemonic(-group) with a comment.
    emit: func [mnemonic df /indent ind][
        ; Handle intendation
        append/dup outbuff "^-" either indent [ind][length? jmp-buff]
        ; Format and write it to the buffer
        repend outbuff [mnemonic rejoin either any [no-comments none? df] [[""]][[cmn space df]] "^/"]
    ]

    ; Do + and - math. Used for optimisation.
    ; E.g. ++++--+++ would result in a +5
    sum-opt: func [instr][
        sum: 0
        foreach e instr [either e = #"+" [sum: sum + 1][sum: sum - 1]]
        sum
    ]

    ; Some rules to prevent repetitions
    bf-op: ["+" | "-"]
    bf-ops: [some bf-op]

    parse prog [
        any [
            ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
            ;; Loop Optimisations (Constants)
            ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
            
            ; Multiplication of constants
            copy op1 bf-ops "[" copy div some "-" ">" copy op2 bf-ops "<]" (
                sum1: (sum-opt op1) / length? div
                sum2: sum-opt op2

                emit rejoin ["ADI " sum1 * sum2] rejoin [sum1 " * " sum2]
            )

            ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
            ;; Loop Optimisations (Dynamic)
            ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

            ; Zeroing cell
            | "[" some "-" "]" (
                emit "XRA A" none
            )

            ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
            ;; Simple Optimisations 
            ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

            ; Move one cell to right
            | ">" not [">" | "<"] (
                emit "STAX D" ">"
                emit "INX D" none
                emit "LDAX D" none
            )

            ; Move one cell to left
            | "<" not [">" | "<"] (
                emit "STAX D" "<"
                emit "DCX D" none
                emit "LDAX D" none
            )

            ; Move multiple cells to left or right
            | copy c some [">" | "<"] (
                sum: 0
                foreach e c [sum: either e = #">" [sum + 1][sum - 1]] 

                emit "STAX D" rejoin [either positive? sum ["> "]["< "] absolute sum]

                either (absolute sum) > 5 [
                    emit "MOV A,E" none
                    emit rejoin [either positive? sum ["ADI "]["SUI "] absolute sum] none
                    emit "MOV E,A" none
                    emit "MVI A,0" none
                    emit either positive? sum ["ADC D"]["SBB D"] none
                    emit "MOV D,A" none
                ][
                    code: either positive? sum ["INX D"]["DCX D"]
                    loop sum [emit code none]
                ]
                
                emit "LDAX D" none
            )

            ; Single increment
            | "+" not bf-op (
                emit "INR A" "+ 1"
            )

            ; Single decrement
            | "-" not bf-op (
                emit "DCR A" "- 1"
            )

            ; Multiple increments/decrements
            | copy c bf-ops (
                sum: sum-opt c

                if sum <> 0 [
                    emit 
                        rejoin [either positive? sum ["ADI "]["SUI "] absolute sum]
                        rejoin [either positive? sum ["+ "]["- "] absolute sum]
                ]
            )

            ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
            ;; Without Optmisations
            ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

            ; Output
            | "." (
                emit "OUT 1" "."
            )

            ; Input
            | "," (
                emit "IN 1" ","
            )

            ; Label
            | "[" (
                jmp-idx: jmp-idx + 1
                append jmp-buff jmp-idx
                emit/indent rejoin ["label" jmp-idx ": NOP"] "[" (length? jmp-buff) - 1
            )

            ; Loop/Jump to label
            | "]" (
                emit "CPI 0" none
                emit rejoin ["JNZ label" take/last jmp-buff] "]"
            )
            | skip
        ]
    ]
    emit "STAX D" "Save to memory before exiting"
    emit "HLT" "Exit"
    outbuff
]
