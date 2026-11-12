module Registers exposing
    ( Operand(..)
    , Pair(..)
    , Register(..)
    , getPair
    , getRegister
    , operandFromCode
    , pairFromCode
    , setPair
    , setRegister
    )

{-| The registers of the 8080, as types.

Most opcodes encode their operands in a 3 bit field (B, C, D, E, H, L, the byte at HL, A) or a
2 bit field (BC, DE, HL, SP). The conversion from those bits happens once, in `operandFromCode`
and `pairFromCode`; the instructions then work with the types.

-}

import EmulatorState exposing (AddressValue, ByteValue, CpuState)


type Register
    = B
    | C
    | D
    | E
    | H
    | L
    | A


{-| A source or destination of an 8 bit operation: a register, or the byte at the address in HL.
-}
type Operand
    = Reg Register
    | AtHL


{-| A register pair. SP is not a register, but it takes part in the pair operations.
-}
type Pair
    = PairBC
    | PairDE
    | PairHL
    | PairSP


{-| The operand encoded in a 3 bit field: 0=B 1=C 2=D 3=E 4=H 5=L 6=(HL) 7=A.
-}
operandFromCode : Int -> Operand
operandFromCode code =
    case code of
        0 ->
            Reg B

        1 ->
            Reg C

        2 ->
            Reg D

        3 ->
            Reg E

        4 ->
            Reg H

        5 ->
            Reg L

        6 ->
            AtHL

        _ ->
            Reg A


{-| The pair encoded in a 2 bit field: 0=BC 1=DE 2=HL 3=SP.
-}
pairFromCode : Int -> Pair
pairFromCode code =
    case code of
        0 ->
            PairBC

        1 ->
            PairDE

        2 ->
            PairHL

        _ ->
            PairSP


getRegister : Register -> CpuState -> ByteValue
getRegister register cpu =
    case register of
        B ->
            cpu.b

        C ->
            cpu.c

        D ->
            cpu.d

        E ->
            cpu.e

        H ->
            cpu.h

        L ->
            cpu.l

        A ->
            cpu.a


setRegister : Register -> ByteValue -> CpuState -> CpuState
setRegister register value cpu =
    case register of
        B ->
            { cpu | b = value }

        C ->
            { cpu | c = value }

        D ->
            { cpu | d = value }

        E ->
            { cpu | e = value }

        H ->
            { cpu | h = value }

        L ->
            { cpu | l = value }

        A ->
            { cpu | a = value }


{-| The 16 bit value of a pair; the first register of a pair holds the high byte.
-}
getPair : Pair -> CpuState -> AddressValue
getPair pair cpu =
    case pair of
        PairBC ->
            combine cpu.b cpu.c

        PairDE ->
            combine cpu.d cpu.e

        PairHL ->
            combine cpu.h cpu.l

        PairSP ->
            cpu.sp


setPair : Pair -> AddressValue -> CpuState -> CpuState
setPair pair value cpu =
    let
        high =
            modBy 0x0100 (value // 0x0100)

        low =
            modBy 0x0100 value
    in
    case pair of
        PairBC ->
            { cpu | b = high, c = low }

        PairDE ->
            { cpu | d = high, e = low }

        PairHL ->
            { cpu | h = high, l = low }

        PairSP ->
            { cpu | sp = value }


combine : ByteValue -> ByteValue -> AddressValue
combine high low =
    high * 0x0100 + low
