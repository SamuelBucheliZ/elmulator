module MachineInstructions exposing (..)

import Array
import BitOperations exposing (combineBytes, getAddressLE)
import Bitwise
import ConditionCodesFlags
import EmulatorState exposing (AddressValue, ByteValue, ConditionCodes, Flag, MachineState, MachineStateDiff(..), MachineStateDiffEvent(..), Memory, RegisterValue, SetCpuStateEvent(..), SetFlagEvent(..))
import LogicFlags exposing (check_flag_AC, check_flag_CY, flags_ZSP)
import Memory
import Psw
import Registers exposing (Operand(..), Pair(..), Register(..), getPair, getRegister)



-- event creation


setMemory : AddressValue -> ByteValue -> MachineStateDiffEvent
setMemory address value =
    SetMemory address value


setRegisterA : RegisterValue -> MachineStateDiffEvent
setRegisterA newValue =
    SetCpu (SetRegisterA newValue)


setRegisterB : RegisterValue -> MachineStateDiffEvent
setRegisterB newValue =
    SetCpu (SetRegisterB newValue)


setRegisterC : RegisterValue -> MachineStateDiffEvent
setRegisterC newValue =
    SetCpu (SetRegisterC newValue)


setRegisterD : RegisterValue -> MachineStateDiffEvent
setRegisterD newValue =
    SetCpu (SetRegisterD newValue)


setRegisterE : RegisterValue -> MachineStateDiffEvent
setRegisterE newValue =
    SetCpu (SetRegisterE newValue)


setRegisterH : RegisterValue -> MachineStateDiffEvent
setRegisterH newValue =
    SetCpu (SetRegisterH newValue)


setRegisterL : RegisterValue -> MachineStateDiffEvent
setRegisterL newValue =
    SetCpu (SetRegisterL newValue)


setPC : AddressValue -> MachineStateDiffEvent
setPC newValue =
    SetCpu (SetPC newValue)


setSP : AddressValue -> MachineStateDiffEvent
setSP newValue =
    SetCpu (SetSP newValue)


setIntEnable : Flag -> MachineStateDiffEvent
setIntEnable newValue =
    SetCpu (SetIntEnable newValue)


setFlagCY : Flag -> MachineStateDiffEvent
setFlagCY newValue =
    SetCpu (SetFlag (SetFlagCY newValue))


setFlagAC : Flag -> MachineStateDiffEvent
setFlagAC newValue =
    SetCpu (SetFlag (SetFlagAC newValue))


setFlagZ : Flag -> MachineStateDiffEvent
setFlagZ newValue =
    SetCpu (SetFlag (SetFlagZ newValue))


setFlagS : Flag -> MachineStateDiffEvent
setFlagS newValue =
    SetCpu (SetFlag (SetFlagS newValue))


setFlagP : Flag -> MachineStateDiffEvent
setFlagP newValue =
    SetCpu (SetFlag (SetFlagP newValue))



-- access


getMemory : MachineState -> Memory
getMemory machineState =
    machineState.memory


getA : MachineState -> ByteValue
getA machineState =
    machineState.cpuState.a


getB : MachineState -> ByteValue
getB machineState =
    machineState.cpuState.b


getC : MachineState -> ByteValue
getC machineState =
    machineState.cpuState.c


getD : MachineState -> ByteValue
getD machineState =
    machineState.cpuState.d


getE : MachineState -> ByteValue
getE machineState =
    machineState.cpuState.e


getH : MachineState -> ByteValue
getH machineState =
    machineState.cpuState.h


getL : MachineState -> ByteValue
getL machineState =
    machineState.cpuState.l


getPC : MachineState -> AddressValue
getPC machineState =
    machineState.cpuState.pc


getSP : MachineState -> AddressValue
getSP machineState =
    machineState.cpuState.sp


getConditionCodes : MachineState -> ConditionCodes
getConditionCodes machineState =
    machineState.cpuState.conditionCodes


pop_ : (ByteValue -> MachineStateDiffEvent) -> (ByteValue -> MachineStateDiffEvent) -> MachineState -> MachineStateDiff
pop_ firstDiffEvent secondDiffEvent machineState =
    let
        newSp =
            getSP machineState + 2

        addressForTwo =
            getSP machineState

        addressForOne =
            getSP machineState + 1

        memory =
            getMemory machineState

        firstMemoryAccessResult =
            Memory.readMemory addressForOne memory

        secondMemoryAccessResult =
            Memory.readMemory addressForTwo memory

        newPc =
            getPC machineState + 1
    in
    case ( firstMemoryAccessResult, secondMemoryAccessResult ) of
        ( Memory.Valid firstByteValue, Memory.Valid secondByteValue ) ->
            Events
                [ secondDiffEvent secondByteValue
                , firstDiffEvent firstByteValue
                , setSP newSp
                , setPC newPc
                ]

        ( Memory.Valid _, Memory.Invalid message ) ->
            Failed (Just machineState) message

        ( Memory.Invalid message, _ ) ->
            Failed (Just machineState) message


push_ : ByteValue -> ByteValue -> MachineState -> MachineStateDiff
push_ firstArg secondArg machineState =
    let
        addressForOne =
            getSP machineState - 1

        addressForTwo =
            getSP machineState - 2

        newSp =
            getSP machineState - 2

        newPc =
            getPC machineState + 1
    in
    Events
        [ setMemory addressForOne firstArg
        , setMemory addressForTwo secondArg
        , setSP newSp
        , setPC newPc
        ]


logicalAuxiliaryCarry : ByteValue -> ByteValue -> Flag
logicalAuxiliaryCarry operandOne operandTwo =
    Bitwise.and 0x08 (Bitwise.or operandOne operandTwo) == 0x08


j_ : ByteValue -> ByteValue -> MachineStateDiff
j_ firstArg secondArg =
    let
        newPc =
            getAddressLE firstArg secondArg
    in
    Events [ setPC newPc ]


stax_rp_ : (MachineState -> ByteValue) -> (MachineState -> ByteValue) -> MachineState -> MachineStateDiff
stax_rp_ registerHigh registerLow machineState =
    let
        address =
            getAddressLE (registerLow machineState) (registerHigh machineState)

        newPc =
            getPC machineState + 1
    in
    Events
        [ setMemory address (getA machineState)
        , setPC newPc
        ]



-- 0x00


nop : MachineState -> MachineStateDiff
nop machineState =
    let
        newPc =
            getPC machineState + 1
    in
    Events [ setPC newPc ]



-- 0x02


stax_b : MachineState -> MachineStateDiff
stax_b machineState =
    stax_rp_ getB getC machineState



-- 0x07


rlc : MachineState -> MachineStateDiff
rlc machineState =
    let
        newPc =
            getPC machineState + 1

        currentA =
            getA machineState

        newA =
            modBy 256 (Bitwise.or (Bitwise.shiftLeftBy 1 currentA) (Bitwise.shiftRightBy 7 currentA))

        newCy =
            Bitwise.and 128 currentA == 128
    in
    Events
        [ setRegisterA newA
        , setFlagCY newCy
        , setPC newPc
        ]



-- 0x0a


ldax_b : MachineState -> MachineStateDiff
ldax_b machineState =
    let
        newPc =
            getPC machineState + 1

        memoryAddress =
            getAddressLE (getC machineState) (getB machineState)

        memoryAccessResult =
            Memory.readMemory memoryAddress (getMemory machineState)
    in
    case memoryAccessResult of
        Memory.Valid byteValue ->
            Events
                [ setRegisterA byteValue
                , setPC newPc
                ]

        Memory.Invalid message ->
            Failed (Just machineState) message



--0x0f


rrc : MachineState -> MachineStateDiff
rrc machineState =
    let
        newPc =
            getPC machineState + 1

        newA =
            Bitwise.or (Bitwise.shiftLeftBy 7 (Bitwise.and (getA machineState) 1)) (Bitwise.shiftRightBy 1 (getA machineState))

        newCY =
            1 == Bitwise.and (getA machineState) 1
    in
    Events
        [ setRegisterA newA
        , setFlagCY newCY
        , setPC newPc
        ]



-- 0x12


stax_d : MachineState -> MachineStateDiff
stax_d machineState =
    stax_rp_ getD getE machineState



-- 0x1a


ldax_d : MachineState -> MachineStateDiff
ldax_d machineState =
    let
        newPc =
            getPC machineState + 1

        memoryAddress =
            Bitwise.or (Bitwise.shiftLeftBy 8 (getD machineState)) (getE machineState)

        memoryAccessResult =
            Memory.readMemory memoryAddress (getMemory machineState)
    in
    case memoryAccessResult of
        Memory.Valid byteValue ->
            Events
                [ setRegisterA byteValue
                , setPC newPc
                ]

        Memory.Invalid message ->
            Failed (Just machineState) message



-- 0x1f


rar : MachineState -> MachineStateDiff
rar machineState =
    let
        currentA =
            getA machineState

        newCy =
            Bitwise.and 1 currentA == 1

        newAWithoutCarry =
            Bitwise.shiftRightBy 1 currentA

        newA =
            if machineState.cpuState.conditionCodes.cy then
                newAWithoutCarry + 128

            else
                newAWithoutCarry

        newPc =
            getPC machineState + 1
    in
    Events
        [ setRegisterA newA
        , setFlagCY newCy
        , setPC newPc
        ]



-- 0x22


shld_d16 : ByteValue -> ByteValue -> MachineState -> MachineStateDiff
shld_d16 firstArg secondArg machineState =
    let
        newPc =
            getPC machineState + 3

        addressForL =
            getAddressLE firstArg secondArg

        addressForH =
            getAddressLE firstArg secondArg + 1
    in
    Events
        [ setMemory addressForL (getL machineState)
        , setMemory addressForH (getH machineState)
        , setPC newPc
        ]



-- 0x27 27 -- DAA
--(Decimal Adjust Accumulator)
--The eight-bit number in the accumulator is adjusted
--to form two four-bit Binary-Coded-Decimal digits by
--the following process:
--1. If the value of the least significant 4 bits of the
--   accumulator is greater than 9 or if the AC flag
--   is set, 6 is added to the accumulator.
--2. If the value of the most significant 4 bits of the
--   accumulator is now greater than 9, or if the CY
--   flag is set, 6 is added to the most significant 4
--   bits of the accumulator.
--NOTE: All flags are affected.


daa : MachineState -> MachineStateDiff
daa machineState =
    let
        currentA =
            getA machineState

        currentCY =
            machineState.cpuState.conditionCodes.cy

        currentAC =
            machineState.cpuState.conditionCodes.ac

        newPc =
            getPC machineState + 1

        -- step 1: low nibble adjustment
        lowAdjust =
            currentAC || Bitwise.and 0x0F currentA > 9

        lowCorrection =
            if lowAdjust then
                6

            else
                0

        afterLow =
            currentA + lowCorrection

        -- step 2: high nibble adjustment (on the value after step 1)
        highAdjust =
            currentCY || afterLow > 0x9F

        newA =
            modBy 256
                (if highAdjust then
                    afterLow + 0x60

                 else
                    afterLow
                )

        newAC =
            Bitwise.and 0x0F currentA + lowCorrection > 0x0F
    in
    Events
        [ setRegisterA newA
        , setPC newPc
        , setFlagCY (currentCY || highAdjust)
        , setFlagAC newAC
        , setFlagZ (ConditionCodesFlags.zFlag newA)
        , setFlagS (ConditionCodesFlags.sFlag newA)
        , setFlagP (ConditionCodesFlags.pFlag newA)
        ]



-- 0x2a


lhld : ByteValue -> ByteValue -> MachineState -> MachineStateDiff
lhld firstArg secondArg machineState =
    let
        addressForL =
            getAddressLE firstArg secondArg

        addressForH =
            getAddressLE firstArg secondArg + 1

        memoryAccessResultL =
            Memory.readMemory addressForL (getMemory machineState)

        memoryAccessResultH =
            Memory.readMemory addressForH (getMemory machineState)

        newPc =
            getPC machineState + 3
    in
    case ( memoryAccessResultL, memoryAccessResultH ) of
        ( Memory.Valid byteValueL, Memory.Valid byteValueH ) ->
            Events
                [ setRegisterL byteValueL
                , setRegisterH byteValueH
                , setPC newPc
                ]

        ( Memory.Valid _, Memory.Invalid message ) ->
            Failed (Just machineState) message

        ( Memory.Invalid message, _ ) ->
            Failed (Just machineState) message



-- 0x32


sta : ByteValue -> ByteValue -> MachineState -> MachineStateDiff
sta firstArg secondArg machineState =
    let
        address =
            getAddressLE firstArg secondArg

        newPc =
            getPC machineState + 3
    in
    Events
        [ setMemory address (getA machineState)
        , setPC newPc
        ]



-- 0x37


stc : MachineState -> MachineStateDiff
stc machineState =
    let
        newPc =
            getPC machineState + 1
    in
    Events
        [ setFlagCY True
        , setPC newPc
        ]



-- 0x3a


lda : ByteValue -> ByteValue -> MachineState -> MachineStateDiff
lda firstArg secondArg machineState =
    let
        newPc =
            getPC machineState + 3

        memoryAddress =
            getAddressLE firstArg secondArg

        memoryAccessResult =
            Memory.readMemory memoryAddress (getMemory machineState)
    in
    case memoryAccessResult of
        Memory.Valid byteValue ->
            Events
                [ setRegisterA byteValue
                , setPC newPc
                ]

        Memory.Invalid message ->
            Failed (Just machineState) message



-- 0xc1


pop_b : MachineState -> MachineStateDiff
pop_b machineState =
    pop_ (\data -> setRegisterB data) (\data -> setRegisterC data) machineState



-- 0xc3


jmp : ByteValue -> ByteValue -> MachineState -> MachineStateDiff
jmp firstArg secondArg _ =
    j_ firstArg secondArg



-- 0xc5


push_b : MachineState -> MachineStateDiff
push_b machineState =
    push_ (getB machineState) (getC machineState) machineState



-- 0xc9


ret : MachineState -> MachineStateDiff
ret machineState =
    let
        addressLow =
            getSP machineState

        addressHigh =
            getSP machineState + 1

        memSpLow =
            Memory.readMemory addressLow (getMemory machineState)

        memSpHigh =
            Memory.readMemory addressHigh (getMemory machineState)
    in
    case ( memSpLow, memSpHigh ) of
        ( Memory.Valid spLowByteValue, Memory.Valid spHighByteValue ) ->
            let
                newSp =
                    getSP machineState + 2

                memSpHighShifted =
                    Bitwise.shiftLeftBy 8 spHighByteValue

                newPC =
                    Bitwise.or spLowByteValue memSpHighShifted
            in
            Events
                [ setSP newSp
                , setPC newPC
                ]

        ( Memory.Valid _, Memory.Invalid message ) ->
            Failed (Just machineState) message

        ( Memory.Invalid message, _ ) ->
            Failed (Just machineState) message



-- 0xcd


call : ByteValue -> ByteValue -> MachineState -> MachineStateDiff
call firstArg secondArg machineState =
    let
        returnAddress =
            getPC machineState + 3

        memoryForH =
            getSP machineState - 1

        memoryForL =
            getSP machineState - 2

        newSp =
            getSP machineState - 2

        newPc =
            getAddressLE firstArg secondArg
    in
    Events
        [ setMemory memoryForH (Bitwise.and (Bitwise.shiftRightBy 8 returnAddress) 0xFF)
        , setMemory memoryForL (Bitwise.and returnAddress 0xFF)
        , setSP newSp
        , setPC newPc
        ]



-- 0xd1


pop_d : MachineState -> MachineStateDiff
pop_d machineState =
    pop_ (\data -> setRegisterD data) (\data -> setRegisterE data) machineState



-- 0xd5


push_d : MachineState -> MachineStateDiff
push_d machineState =
    push_ (getD machineState) (getE machineState) machineState



-- 0xdb
-- see IO
-- 0xe1


pop_h : MachineState -> MachineStateDiff
pop_h machineState =
    pop_ (\data -> setRegisterH data) (\data -> setRegisterL data) machineState



-- 0xe3


xthl : MachineState -> MachineStateDiff
xthl machineState =
    let
        newPc =
            getPC machineState + 1

        currentL =
            getL machineState

        currentH =
            getH machineState

        addressForL =
            getSP machineState

        addressForH =
            getSP machineState + 1

        memoryAccessResultForL =
            Memory.readMemory addressForL (getMemory machineState)

        memoryAccessResultForH =
            Memory.readMemory addressForH (getMemory machineState)
    in
    case ( memoryAccessResultForL, memoryAccessResultForH ) of
        ( Memory.Valid valueL, Memory.Valid valueH ) ->
            Events
                [ setRegisterL valueL
                , setRegisterH valueH
                , setMemory addressForL currentL
                , setMemory addressForH currentH
                , setPC newPc
                ]

        ( Memory.Invalid message, _ ) ->
            Failed (Just machineState) message

        ( Memory.Valid _, Memory.Invalid message ) ->
            Failed (Just machineState) message



-- 0xe5


push_h : MachineState -> MachineStateDiff
push_h machineState =
    push_ (getH machineState) (getL machineState) machineState



-- 0xe9


pchl : MachineState -> MachineStateDiff
pchl machineState =
    let
        newPc =
            Bitwise.or (Bitwise.shiftLeftBy 8 (getH machineState)) (getL machineState)
    in
    Events [ setPC newPc ]



-- 0xeb


xchg : MachineState -> MachineStateDiff
xchg machineState =
    let
        saveOne =
            getD machineState

        saveTwo =
            getE machineState

        newPc =
            getPC machineState + 1
    in
    Events
        [ setRegisterD (getH machineState)
        , setRegisterE (getL machineState)
        , setRegisterH saveOne
        , setRegisterL saveTwo
        , setPC newPc
        ]



-- 0xf1


pop_psw : MachineState -> MachineStateDiff
pop_psw machineState =
    let
        addressForA =
            getSP machineState + 1

        pswAccessResult =
            Memory.readMemory (getSP machineState) (getMemory machineState)

        newSp =
            getSP machineState + 2

        newPc =
            getPC machineState + 1

        memoryAccessResult =
            Memory.readMemory addressForA (getMemory machineState)
    in
    case ( pswAccessResult, memoryAccessResult ) of
        ( Memory.Valid psw, Memory.Valid byteValue ) ->
            Events
                (List.concat
                    [ Psw.readPSW psw
                    , [ setRegisterA byteValue
                      , setSP newSp
                      , setPC newPc
                      ]
                    ]
                )

        ( Memory.Invalid message, _ ) ->
            Failed (Just machineState) message

        ( Memory.Valid _, Memory.Invalid message ) ->
            Failed (Just machineState) message



-- 0xf5


push_psw : MachineState -> MachineStateDiff
push_psw machineState =
    let
        newPc =
            getPC machineState + 1

        addressForA =
            getSP machineState - 1

        addressForPSW =
            getSP machineState - 2

        newSP =
            getSP machineState - 2

        psw =
            Psw.createPSW (getConditionCodes machineState)
    in
    Events
        [ setMemory addressForA (getA machineState)
        , setMemory addressForPSW psw
        , setSP newSP
        , setPC newPc
        ]



-- 0xfb


ei : MachineState -> MachineStateDiff
ei machineState =
    let
        newPc =
            getPC machineState + 1
    in
    Events
        [ setIntEnable True
        , setPC newPc
        ]



-- 0xfe


{-| CMP/CPI: compares A with the operand by subtracting, but discards the result.
Z, S, P, CY and AC are set; A is not changed.
-}



-- GENERIC OPERATIONS
-- The 8080 encodes its register operands in a 3 bit field:
-- 0=B 1=C 2=D 3=E 4=H 5=L 6=M (the byte at HL) 7=A.
-- Pairs are numbered 0=BC 1=DE 2=HL 3=SP.


hlAddress : MachineState -> AddressValue
hlAddress machineState =
    getAddressLE (getL machineState) (getH machineState)


memoryAt : AddressValue -> MachineState -> ByteValue
memoryAt address machineState =
    Array.get (modBy 0x00010000 address) machineState.memory
        |> Maybe.withDefault 0


operandValue : Operand -> MachineState -> ByteValue
operandValue operand machineState =
    case operand of
        Reg register ->
            getRegister register machineState.cpuState

        AtHL ->
            memoryAt (hlAddress machineState) machineState


writeOperand : Operand -> MachineState -> ByteValue -> MachineStateDiffEvent
writeOperand operand machineState value =
    case operand of
        Reg register ->
            SetCpu (registerEvent register value)

        AtHL ->
            setMemory (hlAddress machineState) value


registerEvent : Register -> ByteValue -> SetCpuStateEvent
registerEvent register value =
    case register of
        B ->
            SetRegisterB value

        C ->
            SetRegisterC value

        D ->
            SetRegisterD value

        E ->
            SetRegisterE value

        H ->
            SetRegisterH value

        L ->
            SetRegisterL value

        A ->
            SetRegisterA value


pairValue : Pair -> MachineState -> AddressValue
pairValue pair machineState =
    getPair pair machineState.cpuState


setPairEvents : Pair -> AddressValue -> List MachineStateDiffEvent
setPairEvents pair value =
    let
        high =
            Bitwise.and 0xFF (Bitwise.shiftRightBy 8 value)

        low =
            Bitwise.and 0xFF value
    in
    case pair of
        PairBC ->
            [ setRegisterB high, setRegisterC low ]

        PairDE ->
            [ setRegisterD high, setRegisterE low ]

        PairHL ->
            [ setRegisterH high, setRegisterL low ]

        PairSP ->
            [ setSP value ]


nextPc : Int -> MachineState -> AddressValue
nextPc size machineState =
    getPC machineState + size


{-| The condition codes of Jcc, Ccc and Rcc, selected by bits 3-5 of the opcode.
-}
conditionMet : Int -> ConditionCodes -> Bool
conditionMet index conditionCodes =
    case index of
        0 ->
            not conditionCodes.z

        1 ->
            conditionCodes.z

        2 ->
            not conditionCodes.cy

        3 ->
            conditionCodes.cy

        4 ->
            not conditionCodes.p

        5 ->
            conditionCodes.p

        6 ->
            not conditionCodes.s

        _ ->
            conditionCodes.s


movRegister : Operand -> Operand -> MachineState -> MachineStateDiff
movRegister destination source machineState =
    Events
        [ writeOperand destination machineState (operandValue source machineState)
        , setPC (nextPc 1 machineState)
        ]


mviRegister : Operand -> ByteValue -> MachineState -> MachineStateDiff
mviRegister destination value machineState =
    Events
        [ writeOperand destination machineState value
        , setPC (nextPc 2 machineState)
        ]


incRegister : Operand -> MachineState -> MachineStateDiff
incRegister operand machineState =
    let
        value =
            operandValue operand machineState

        result =
            modBy 256 (value + 1)
    in
    Events
        ([ writeOperand operand machineState result
         , setFlagAC (Bitwise.and 0x0F value == 0x0F)
         ]
            ++ flags_ZSP result
            ++ [ setPC (nextPc 1 machineState) ]
        )


decRegister : Operand -> MachineState -> MachineStateDiff
decRegister operand machineState =
    let
        value =
            operandValue operand machineState

        result =
            modBy 256 (value - 1)
    in
    Events
        ([ writeOperand operand machineState result
         , setFlagAC (Bitwise.and 0x0F value > 0)
         ]
            ++ flags_ZSP result
            ++ [ setPC (nextPc 1 machineState) ]
        )


addWithCarry : ByteValue -> ByteValue -> Int -> ( ByteValue, Flag, Flag )
addWithCarry a b carryIn =
    let
        sum =
            a + b + carryIn
    in
    ( modBy 256 sum
    , sum > 0xFF
    , Bitwise.and 0x0F a + Bitwise.and 0x0F b + carryIn > 0x0F
    )


{-| Result, borrow and auxiliary carry of `a - b - borrowIn`. AC is set when
there is no borrow from bit 3.
-}
subtractWithBorrow : ByteValue -> ByteValue -> Int -> ( ByteValue, Flag, Flag )
subtractWithBorrow a b borrowIn =
    let
        difference =
            a - b - borrowIn
    in
    ( modBy 256 difference
    , difference < 0
    , Bitwise.and 0x0F a - Bitwise.and 0x0F b - borrowIn >= 0
    )


{-| The events of the eight arithmetic/logic operations, selected by bits 3-5 of
the opcode: ADD, ADC, SUB, SBB, ANA, XRA, ORA, CMP. CMP does not change A.
-}
aluEvents : Int -> ByteValue -> MachineState -> List MachineStateDiffEvent
aluEvents operation value machineState =
    let
        a =
            getA machineState

        carryIn =
            if machineState.cpuState.conditionCodes.cy then
                1

            else
                0

        withResult result cy ac =
            setRegisterA result :: setFlagCY cy :: setFlagAC ac :: flags_ZSP result
    in
    case operation of
        0 ->
            let
                ( result, cy, ac ) =
                    addWithCarry a value 0
            in
            withResult result cy ac

        1 ->
            let
                ( result, cy, ac ) =
                    addWithCarry a value carryIn
            in
            withResult result cy ac

        2 ->
            let
                ( result, cy, ac ) =
                    subtractWithBorrow a value 0
            in
            withResult result cy ac

        3 ->
            let
                ( result, cy, ac ) =
                    subtractWithBorrow a value carryIn
            in
            withResult result cy ac

        4 ->
            let
                result =
                    Bitwise.and a value
            in
            setRegisterA result :: setFlagCY False :: setFlagAC (logicalAuxiliaryCarry a value) :: flags_ZSP result

        5 ->
            let
                result =
                    Bitwise.xor a value
            in
            withResult result False False

        6 ->
            let
                result =
                    Bitwise.or a value
            in
            withResult result False False

        _ ->
            let
                ( result, cy, ac ) =
                    subtractWithBorrow a value 0
            in
            setFlagCY cy :: setFlagAC ac :: flags_ZSP result


aluWith : Int -> ByteValue -> Int -> MachineState -> MachineStateDiff
aluWith operation value size machineState =
    Events (aluEvents operation value machineState ++ [ setPC (nextPc size machineState) ])


aluRegister : Int -> Operand -> MachineState -> MachineStateDiff
aluRegister operation source machineState =
    aluWith operation (operandValue source machineState) 1 machineState


aluImmediate : Int -> ByteValue -> MachineState -> MachineStateDiff
aluImmediate operation value machineState =
    aluWith operation value 2 machineState


{-| Pushes `returnAddress` and jumps to `target` (CALL, Ccc, RST).
-}
callAddress : AddressValue -> AddressValue -> MachineState -> MachineStateDiff
callAddress returnAddress target machineState =
    let
        sp =
            getSP machineState
    in
    Events
        [ setMemory (sp - 1) (Bitwise.and 0xFF (Bitwise.shiftRightBy 8 returnAddress))
        , setMemory (sp - 2) (Bitwise.and 0xFF returnAddress)
        , setSP (sp - 2)
        , setPC target
        ]


{-| Adds `extra` cycles to a successful instruction (taken conditional calls and returns).
-}
withExtraCycles : Int -> MachineStateDiff -> MachineStateDiff
withExtraCycles extra machineStateDiff =
    case machineStateDiff of
        Events list ->
            Events (list ++ [ SetCpu (AddCycles extra) ])

        Failed _ _ ->
            machineStateDiff


jcc : Int -> ByteValue -> ByteValue -> MachineState -> MachineStateDiff
jcc condition low high machineState =
    if conditionMet condition machineState.cpuState.conditionCodes then
        Events [ setPC (getAddressLE low high) ]

    else
        Events [ setPC (nextPc 3 machineState) ]


ccc : Int -> ByteValue -> ByteValue -> MachineState -> MachineStateDiff
ccc condition low high machineState =
    if conditionMet condition machineState.cpuState.conditionCodes then
        withExtraCycles 6 (callAddress (nextPc 3 machineState) (getAddressLE low high) machineState)

    else
        Events [ setPC (nextPc 3 machineState) ]


rcc : Int -> MachineState -> MachineStateDiff
rcc condition machineState =
    if conditionMet condition machineState.cpuState.conditionCodes then
        withExtraCycles 6 (ret machineState)

    else
        Events [ setPC (nextPc 1 machineState) ]


rst : Int -> MachineState -> MachineStateDiff
rst number machineState =
    callAddress (nextPc 1 machineState) (number * 8) machineState


incPair : Pair -> MachineState -> MachineStateDiff
incPair pair machineState =
    Events (setPairEvents pair (modBy 0x00010000 (pairValue pair machineState + 1)) ++ [ setPC (nextPc 1 machineState) ])


decPair : Pair -> MachineState -> MachineStateDiff
decPair pair machineState =
    Events (setPairEvents pair (modBy 0x00010000 (pairValue pair machineState - 1)) ++ [ setPC (nextPc 1 machineState) ])


dadPair : Pair -> MachineState -> MachineStateDiff
dadPair pair machineState =
    let
        sum =
            pairValue PairHL machineState + pairValue pair machineState
    in
    Events
        (setPairEvents PairHL (modBy 0x00010000 sum)
            ++ [ setFlagCY (sum > 0xFFFF), setPC (nextPc 1 machineState) ]
        )


lxiPair : Pair -> ByteValue -> ByteValue -> MachineState -> MachineStateDiff
lxiPair pair low high machineState =
    Events (setPairEvents pair (getAddressLE low high) ++ [ setPC (nextPc 3 machineState) ])


ral : MachineState -> MachineStateDiff
ral machineState =
    let
        currentA =
            getA machineState

        carryIn =
            if machineState.cpuState.conditionCodes.cy then
                1

            else
                0
    in
    Events
        [ setRegisterA (modBy 256 (Bitwise.shiftLeftBy 1 currentA + carryIn))
        , setFlagCY (Bitwise.and 0x80 currentA == 0x80)
        , setPC (nextPc 1 machineState)
        ]


cma : MachineState -> MachineStateDiff
cma machineState =
    Events
        [ setRegisterA (Bitwise.xor (getA machineState) 0xFF)
        , setPC (nextPc 1 machineState)
        ]


cmc : MachineState -> MachineStateDiff
cmc machineState =
    Events
        [ setFlagCY (not machineState.cpuState.conditionCodes.cy)
        , setPC (nextPc 1 machineState)
        ]


di : MachineState -> MachineStateDiff
di machineState =
    Events
        [ setIntEnable False
        , setPC (nextPc 1 machineState)
        ]


{-| HLT keeps the program counter on the HLT. An accepted interrupt pushes the
address after the HLT instead (see `Cpu`), so the processor resumes after it.
-}
hlt : MachineState -> MachineStateDiff
hlt machineState =
    Events [ setPC (getPC machineState) ]


sphl : MachineState -> MachineStateDiff
sphl machineState =
    Events
        [ setSP (hlAddress machineState)
        , setPC (nextPc 1 machineState)
        ]
