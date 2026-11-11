module MachineInstructions exposing (..)

import Array
import BitOperations exposing (combineBytes, getAddressLE)
import Bitwise
import ConditionCodesFlags
import EmulatorState exposing (AddressValue, ByteValue, ConditionCodes, Flag, MachineState, MachineStateDiff(..), MachineStateDiffEvent(..), Memory, RegisterValue, SetCpuStateEvent(..), SetFlagEvent(..))
import LogicFlags exposing (check_flag_AC, check_flag_CY, flags_ZSP)
import Memory
import Psw



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


getFlagZ : MachineState -> Flag
getFlagZ machineState =
    let
        conditionCodes =
            getConditionCodes machineState
    in
    conditionCodes.z



-- general


logic_flags_a : RegisterValue -> List MachineStateDiffEvent
logic_flags_a newA =
    [ setFlagCY False
    , setFlagAC False
    ]
        ++ flags_ZSP newA


{-| DCR: decrement a register (or memory value) wrapping at 0 to 0xFF.
Affects Z, S, P and AC (AC is set when there is no borrow from bit 3,
i.e. the low nibble was not zero). CY is not affected.
-}
dcr_ : (RegisterValue -> MachineStateDiffEvent) -> RegisterValue -> MachineState -> MachineStateDiff
dcr_ diffEvent registerValue machineState =
    let
        newPc =
            getPC machineState + 1

        newRegisterValue =
            modBy 256 (registerValue - 1)
    in
    Events
        [ diffEvent newRegisterValue
        , setFlagZ (ConditionCodesFlags.zFlag newRegisterValue)
        , setFlagS (ConditionCodesFlags.sFlag newRegisterValue)
        , setFlagP (ConditionCodesFlags.pFlag newRegisterValue)
        , setFlagAC (Bitwise.and 0x0F registerValue > 0)
        , setPC newPc
        ]


mvi_d8_ : MachineStateDiffEvent -> MachineState -> MachineStateDiff
mvi_d8_ diffEvent machineState =
    let
        newPc =
            getPC machineState + 2
    in
    Events
        [ diffEvent
        , setPC newPc
        ]


lxi_d16_ : MachineStateDiffEvent -> MachineStateDiffEvent -> MachineState -> MachineStateDiff
lxi_d16_ firstDiffEvent secondDiffEvent machineState =
    let
        newPc =
            getPC machineState + 3
    in
    Events
        [ firstDiffEvent
        , secondDiffEvent
        , setPC newPc
        ]


inx_ : ByteValue -> (ByteValue -> MachineStateDiffEvent) -> ByteValue -> (ByteValue -> MachineStateDiffEvent) -> MachineState -> MachineStateDiff
inx_ firstArg firstDiffEvent secondArg secondDiffEvent machineState =
    let
        newPc =
            getPC machineState + 1

        newSecond =
            --l
            modBy 256 (secondArg + 1)
    in
    if newSecond == 0 then
        Events
            [ firstDiffEvent (modBy 256 (firstArg + 1))
            , secondDiffEvent newSecond
            , setPC newPc
            ]

    else
        Events
            [ secondDiffEvent newSecond
            , setPC newPc
            ]


dad_ : ByteValue -> ByteValue -> MachineState -> MachineStateDiff
dad_ firstRegister secondRegister machineState =
    let
        newPc =
            getPC machineState + 1

        hl =
            Bitwise.or (Bitwise.shiftLeftBy 8 (getH machineState)) (getL machineState)

        combinedRegister =
            Bitwise.or (Bitwise.shiftLeftBy 8 firstRegister) secondRegister
    in
    let
        newH =
            Bitwise.shiftRightBy 8 (Bitwise.and (hl + combinedRegister) 0xFF00)

        newL =
            Bitwise.and (hl + combinedRegister) 0xFF

        newCY =
            hl + combinedRegister > 0xFFFF
    in
    Events
        [ setRegisterH newH
        , setRegisterL newL
        , setFlagCY newCY
        , setPC newPc
        ]


mov_r_m_ : (ByteValue -> SetCpuStateEvent) -> MachineState -> MachineStateDiff
mov_r_m_ setRegisterEvent machineState =
    let
        memoryAddress =
            getAddressLE (getL machineState) (getH machineState)

        newPc =
            getPC machineState + 1

        memoryAccessResult =
            Memory.readMemory memoryAddress (getMemory machineState)
    in
    case memoryAccessResult of
        Memory.Valid valueFromMemory ->
            Events
                [ SetCpu (setRegisterEvent valueFromMemory)
                , setPC newPc
                ]

        Memory.Invalid message ->
            Failed (Just machineState) message


move_m_r_ : (MachineState -> ByteValue) -> MachineState -> MachineStateDiff
move_m_r_ fromRegister machineState =
    let
        memoryAddress =
            getAddressLE (getL machineState) (getH machineState)

        newPc =
            getPC machineState + 1
    in
    Events
        [ setMemory memoryAddress (fromRegister machineState)
        , setPC newPc
        ]


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


ana_ : ByteValue -> MachineState -> MachineStateDiff
ana_ registerValue machineState =
    let
        newPc =
            getPC machineState + 1

        newA =
            Bitwise.and (getA machineState) registerValue
    in
    Events
        (List.concat
            [ [ setRegisterA newA
              , setPC newPc
              , setFlagCY False
              , setFlagAC (logicalAuxiliaryCarry (getA machineState) registerValue)
              ]
            , flags_ZSP newA
            ]
        )


{-| 8080 AND-operation auxiliary carry: the logical OR of bit 3 of both operands.
-}
logicalAuxiliaryCarry : ByteValue -> ByteValue -> Flag
logicalAuxiliaryCarry operandOne operandTwo =
    Bitwise.and 0x08 (Bitwise.or operandOne operandTwo) == 0x08


ora_ : ByteValue -> MachineState -> MachineStateDiff
ora_ value machineState =
    let
        newPc =
            getPC machineState + 1

        newA =
            Bitwise.or (getA machineState) value
    in
    Events
        (List.concat
            [ [ setRegisterA newA
              , setPC newPc
              , setFlagCY False
              , setFlagAC False
              ]
            , flags_ZSP newA
            ]
        )


mov_r_r_ : (ByteValue -> SetCpuStateEvent) -> (MachineState -> ByteValue) -> MachineState -> MachineStateDiff
mov_r_r_ setRegisterEvent fromRegister machineState =
    let
        newPc =
            getPC machineState + 1
    in
    Events
        [ SetCpu (setRegisterEvent (fromRegister machineState))
        , setPC newPc
        ]


add_r_ : (MachineState -> ByteValue) -> MachineState -> MachineStateDiff
add_r_ fromRegister machineState =
    let
        newPc =
            getPC machineState + 1

        newA =
            getA machineState + fromRegister machineState

        newAByte =
            modBy 256 newA
    in
    Events
        (List.concat
            [ [ setRegisterA newAByte
              , setPC newPc
              , check_flag_CY newA
              , check_flag_AC (getA machineState) (fromRegister machineState)
              ]
            , flags_ZSP newAByte
            ]
        )


inr_r_ : (ByteValue -> SetCpuStateEvent) -> (MachineState -> ByteValue) -> MachineState -> MachineStateDiff
inr_r_ setRegisterEvent fromRegister machineState =
    let
        newPc =
            getPC machineState + 1

        currentRegisterValue =
            fromRegister machineState

        newRegisterValue =
            modBy 256 (currentRegisterValue + 1)
    in
    Events
        (List.concat
            [ [ SetCpu (setRegisterEvent newRegisterValue)
              , setPC newPc
              , check_flag_AC currentRegisterValue 1
              ]
            , flags_ZSP newRegisterValue
            ]
        )


dcx_rp_ : (MachineState -> ByteValue) -> (ByteValue -> SetCpuStateEvent) -> (MachineState -> ByteValue) -> (ByteValue -> SetCpuStateEvent) -> MachineState -> MachineStateDiff
dcx_rp_ registerHigh highRegisterEvent registerLow lowRegisterEvent machineState =
    let
        newPC =
            getPC machineState + 1

        currentRegisterPairValue =
            getAddressLE (registerLow machineState) (registerHigh machineState)

        newValue =
            currentRegisterPairValue - 1

        newHigh =
            Bitwise.shiftRightBy 8 (Bitwise.and 0xFF00 newValue)

        newLow =
            Bitwise.and 0xFF newValue
    in
    Events
        [ SetCpu (highRegisterEvent newHigh)
        , SetCpu (lowRegisterEvent newLow)
        , setPC newPC
        ]


xra_r_ : (MachineState -> ByteValue) -> MachineState -> MachineStateDiff
xra_r_ fromRegister machineState =
    let
        newPc =
            getPC machineState + 1

        newA =
            Bitwise.xor (getA machineState) (fromRegister machineState)
    in
    Events
        (List.concat
            [ [ setRegisterA newA
              , setPC newPc
              , setFlagCY False
              , setFlagAC False
              ]
            , flags_ZSP newA
            ]
        )


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



-- 0x01


lxi_b_d16 : ByteValue -> ByteValue -> MachineState -> MachineStateDiff
lxi_b_d16 firstArg secondArg machineState =
    lxi_d16_ (setRegisterB secondArg) (setRegisterC firstArg) machineState



-- 0x02


stax_b : MachineState -> MachineStateDiff
stax_b machineState =
    stax_rp_ getB getC machineState



-- 0x03


inx_b : MachineState -> MachineStateDiff
inx_b machineState =
    inx_ (getB machineState) (\data -> setRegisterB data) (getC machineState) (\data -> setRegisterC data) machineState



-- 0x04


inr_b : MachineState -> MachineStateDiff
inr_b machineState =
    inr_r_ (\data -> SetRegisterB data) getB machineState



-- 0x05


dcr_b : MachineState -> MachineStateDiff
dcr_b machineState =
    dcr_ (\value -> setRegisterB value) (getB machineState) machineState



-- 0x06


mvi_b_d8 : ByteValue -> MachineState -> MachineStateDiff
mvi_b_d8 firstArg machineState =
    mvi_d8_ (setRegisterB firstArg) machineState



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



-- 0x09


dad_b : MachineState -> MachineStateDiff
dad_b machineState =
    dad_ (getB machineState) (getC machineState) machineState



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



-- 0x0b


dcx_b : MachineState -> MachineStateDiff
dcx_b machineState =
    dcx_rp_ getB (\data -> SetRegisterB data) getC (\data -> SetRegisterC data) machineState



-- 0x0d


dcr_c : MachineState -> MachineStateDiff
dcr_c machineState =
    dcr_ (\value -> setRegisterC value) (getC machineState) machineState



-- 0x0e


mvi_c_d8 : ByteValue -> MachineState -> MachineStateDiff
mvi_c_d8 firstArg machineState =
    mvi_d8_ (setRegisterC firstArg) machineState



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



-- 0x11


lxi_d_d16 : ByteValue -> ByteValue -> MachineState -> MachineStateDiff
lxi_d_d16 firstArg secondArg machineState =
    lxi_d16_ (setRegisterD secondArg) (setRegisterE firstArg) machineState



-- 0x12


stax_d : MachineState -> MachineStateDiff
stax_d machineState =
    stax_rp_ getD getE machineState



-- 0x13


inx_d : MachineState -> MachineStateDiff
inx_d machineState =
    inx_ (getD machineState) (\data -> setRegisterD data) (getE machineState) (\data -> setRegisterE data) machineState



-- 0x16


mvi_d_d8 : ByteValue -> MachineState -> MachineStateDiff
mvi_d_d8 firstArg machineState =
    mvi_d8_ (setRegisterD firstArg) machineState



-- 0x19


dad_d : MachineState -> MachineStateDiff
dad_d machineState =
    dad_ (getD machineState) (getE machineState) machineState



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



-- 0x21


lxi_h_d16 : ByteValue -> ByteValue -> MachineState -> MachineStateDiff
lxi_h_d16 firstArg secondArg machineState =
    lxi_d16_ (setRegisterH secondArg) (setRegisterL firstArg) machineState



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



-- 0x23


inx_h : MachineState -> MachineStateDiff
inx_h machineState =
    inx_ (getH machineState) (\data -> setRegisterH data) (getL machineState) (\data -> setRegisterL data) machineState



-- 0x26


mvi_h_d8 : ByteValue -> MachineState -> MachineStateDiff
mvi_h_d8 firstArg machineState =
    mvi_d8_ (setRegisterH firstArg) machineState



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



-- 0x29


dad_h : MachineState -> MachineStateDiff
dad_h machineState =
    dad_ (getH machineState) (getL machineState) machineState



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



-- 0x2b -- DCX H
-- it decreases the memory location pointed by HL pair by 1.


dcx_h : MachineState -> MachineStateDiff
dcx_h machineState =
    dcx_rp_ getH (\data -> SetRegisterH data) getL (\data -> SetRegisterL data) machineState



-- 0x2e


mvi_l_d8 : ByteValue -> MachineState -> MachineStateDiff
mvi_l_d8 firstArg machineState =
    mvi_d8_ (setRegisterL firstArg) machineState



-- 0x31


lxi_sp_d16 : ByteValue -> ByteValue -> MachineState -> MachineStateDiff
lxi_sp_d16 firstArg secondArg machineState =
    let
        newPc =
            getPC machineState + 3

        newSp =
            getAddressLE firstArg secondArg
    in
    Events
        [ setSP newSp
        , setPC newPc
        ]



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



-- 0x35


dcr_m : MachineState -> MachineStateDiff
dcr_m machineState =
    let
        newPc =
            machineState.cpuState.pc + 1

        address =
            getAddressLE machineState.cpuState.l machineState.cpuState.h

        memoryAccessResult =
            Memory.readMemory address machineState.memory
    in
    case memoryAccessResult of
        Memory.Valid memoryValue ->
            let
                newMemoryValue =
                    modBy 256 (memoryValue - 1)
            in
            Events
                [ setMemory address newMemoryValue
                , setFlagZ (ConditionCodesFlags.zFlag newMemoryValue)
                , setFlagS (ConditionCodesFlags.sFlag newMemoryValue)
                , setFlagP (ConditionCodesFlags.pFlag newMemoryValue)
                , setFlagAC (Bitwise.and 0x0F memoryValue > 0)
                , setPC newPc
                ]

        Memory.Invalid message ->
            Failed (Just machineState) message



-- 0x36


mvi_m_d8 : ByteValue -> MachineState -> MachineStateDiff
mvi_m_d8 firstArg machineState =
    let
        address =
            getAddressLE (getL machineState) (getH machineState)
    in
    mvi_d8_ (SetMemory address firstArg) machineState



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



-- 0x3c


inr_a : MachineState -> MachineStateDiff
inr_a machineState =
    inr_r_ (\data -> SetRegisterA data) getA machineState



-- 0x3d


dcr_a : MachineState -> MachineStateDiff
dcr_a machineState =
    dcr_ (\value -> setRegisterA value) (getA machineState) machineState



-- 0x3e


mvi_a_d8 : ByteValue -> MachineState -> MachineStateDiff
mvi_a_d8 firstArg machineState =
    mvi_d8_ (setRegisterA firstArg) machineState



-- 0x46


mov_b_m : MachineState -> MachineStateDiff
mov_b_m machineState =
    mov_r_m_ (\data -> SetRegisterB data) machineState



-- 0x47


mov_b_a : MachineState -> MachineStateDiff
mov_b_a machineState =
    mov_r_r_ (\data -> SetRegisterB data) getA machineState



-- 0x4e


mov_c_m : MachineState -> MachineStateDiff
mov_c_m machineState =
    mov_r_m_ (\data -> SetRegisterC data) machineState



-- 0x4f


mov_c_a : MachineState -> MachineStateDiff
mov_c_a machineState =
    mov_r_r_ (\data -> SetRegisterC data) getA machineState



-- 0x56


mov_d_m : MachineState -> MachineStateDiff
mov_d_m machineState =
    mov_r_m_ (\data -> SetRegisterD data) machineState



--0x57


mov_d_a : MachineState -> MachineStateDiff
mov_d_a machineState =
    mov_r_r_ (\data -> SetRegisterD data) getA machineState



-- 0x5e


mov_e_m : MachineState -> MachineStateDiff
mov_e_m machineState =
    mov_r_m_ (\data -> SetRegisterE data) machineState



-- 0x5f


mov_e_a : MachineState -> MachineStateDiff
mov_e_a machineState =
    mov_r_r_ (\data -> SetRegisterE data) getA machineState



-- 0x61


mov_h_c : MachineState -> MachineStateDiff
mov_h_c machineState =
    mov_r_r_ (\data -> SetRegisterH data) getC machineState



-- 0x66


mov_h_m : MachineState -> MachineStateDiff
mov_h_m machineState =
    mov_r_m_ (\data -> SetRegisterH data) machineState



-- 0x67


mov_h_a : MachineState -> MachineStateDiff
mov_h_a machineState =
    mov_r_r_ (\data -> SetRegisterH data) getA machineState



-- 0x6f


mov_l_a : MachineState -> MachineStateDiff
mov_l_a machineState =
    mov_r_r_ (\data -> SetRegisterL data) getA machineState



-- 0x70


mov_m_b : MachineState -> MachineStateDiff
mov_m_b machineState =
    move_m_r_ getB machineState



-- 0x77


mov_m_a : MachineState -> MachineStateDiff
mov_m_a machineState =
    move_m_r_ getA machineState



-- 0x78


mov_a_b : MachineState -> MachineStateDiff
mov_a_b machineState =
    mov_r_r_ (\data -> SetRegisterA data) getB machineState



-- 0x79


mov_a_c : MachineState -> MachineStateDiff
mov_a_c machineState =
    mov_r_r_ (\data -> SetRegisterA data) getC machineState



-- 0x7a


mov_a_d : MachineState -> MachineStateDiff
mov_a_d machineState =
    mov_r_r_ (\data -> SetRegisterA data) getD machineState



-- 0x7b


mov_a_e : MachineState -> MachineStateDiff
mov_a_e machineState =
    mov_r_r_ (\data -> SetRegisterA data) getE machineState



-- 0x7c


mov_a_h : MachineState -> MachineStateDiff
mov_a_h machineState =
    mov_r_r_ (\data -> SetRegisterA data) getH machineState



-- 0x7d


mov_a_l : MachineState -> MachineStateDiff
mov_a_l machineState =
    mov_r_r_ (\data -> SetRegisterA data) getL machineState



-- 0x7e


mov_a_m : MachineState -> MachineStateDiff
mov_a_m machineState =
    mov_r_m_ (\data -> SetRegisterA data) machineState



-- 0x80


add_b : MachineState -> MachineStateDiff
add_b machineState =
    add_r_ getB machineState



-- 0xa0


ana_b : MachineState -> MachineStateDiff
ana_b machineState =
    ana_ (getB machineState) machineState



-- 0xa7


ana_a : MachineState -> MachineStateDiff
ana_a machineState =
    ana_ (getA machineState) machineState



-- 0xa8


xra_b : MachineState -> MachineStateDiff
xra_b machineState =
    xra_r_ getB machineState



--0xaf


xra_a : MachineState -> MachineStateDiff
xra_a machineState =
    xra_r_ getA machineState



-- 0xb0


ora_b : MachineState -> MachineStateDiff
ora_b machineState =
    ora_ (getB machineState) machineState



-- 0xb4


ora_h : MachineState -> MachineStateDiff
ora_h machineState =
    ora_ (getH machineState) machineState



-- 0xb6


ora_m : MachineState -> MachineStateDiff
ora_m machineState =
    let
        memoryAddress =
            getAddressLE (getL machineState) (getH machineState)

        memoryAccessResult =
            Memory.readMemory memoryAddress (getMemory machineState)
    in
    case memoryAccessResult of
        Memory.Valid byteValue ->
            ora_ byteValue machineState

        Memory.Invalid message ->
            Failed (Just machineState) message



-- 0xc0


rnz : MachineState -> MachineStateDiff
rnz machineState =
    rcc 0 machineState



-- 0xc1


pop_b : MachineState -> MachineStateDiff
pop_b machineState =
    pop_ (\data -> setRegisterB data) (\data -> setRegisterC data) machineState



-- 0xc2


jnz : ByteValue -> ByteValue -> MachineState -> MachineStateDiff
jnz firstArg secondArg machineState =
    if machineState.cpuState.conditionCodes.z then
        let
            nwePc =
                getPC machineState + 3
        in
        Events [ setPC nwePc ]

    else
        j_ firstArg secondArg



-- 0xc3


jmp : ByteValue -> ByteValue -> MachineState -> MachineStateDiff
jmp firstArg secondArg _ =
    j_ firstArg secondArg



-- 0xc4


cnz : ByteValue -> ByteValue -> MachineState -> MachineStateDiff
cnz firstArg secondArg machineState =
    ccc 0 firstArg secondArg machineState



-- 0xc5


push_b : MachineState -> MachineStateDiff
push_b machineState =
    push_ (getB machineState) (getC machineState) machineState



-- 0xc6


adi_d8 : ByteValue -> MachineState -> MachineStateDiff
adi_d8 firstArg machineState =
    let
        x =
            getA machineState + firstArg

        newA =
            modBy 256 x

        newPc =
            getPC machineState + 2
    in
    Events
        [ setRegisterA newA
        , setFlagZ (ConditionCodesFlags.zFlag newA)
        , setFlagS (ConditionCodesFlags.sFlag newA)
        , setFlagP (ConditionCodesFlags.pFlag newA)
        , setFlagCY (ConditionCodesFlags.cyFlag x)
        , check_flag_AC (getA machineState) firstArg
        , setPC newPc
        ]



-- 0xc8


rz : MachineState -> MachineStateDiff
rz machineState =
    rcc 1 machineState



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



-- 0xca


jz : ByteValue -> ByteValue -> MachineState -> MachineStateDiff
jz firstArg secondArg machineState =
    if machineState.cpuState.conditionCodes.z then
        j_ firstArg secondArg

    else
        let
            newPc =
                getPC machineState + 3
        in
        Events [ setPC newPc ]



-- 0xcc


cz : ByteValue -> ByteValue -> MachineState -> MachineStateDiff
cz firstArg secondArg machineState =
    ccc 1 firstArg secondArg machineState



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



-- 0xd0


rnc : MachineState -> MachineStateDiff
rnc machineState =
    rcc 2 machineState



-- 0xd1


pop_d : MachineState -> MachineStateDiff
pop_d machineState =
    pop_ (\data -> setRegisterD data) (\data -> setRegisterE data) machineState



-- 0xd2


jnc : ByteValue -> ByteValue -> MachineState -> MachineStateDiff
jnc firstArg secondArg machineState =
    if machineState.cpuState.conditionCodes.cy then
        let
            newPc =
                getPC machineState + 3
        in
        Events [ setPC newPc ]

    else
        j_ firstArg secondArg



-- 0xd3
-- see IO
-- 0xd4


cnc : ByteValue -> ByteValue -> MachineState -> MachineStateDiff
cnc firstArg secondArg machineState =
    ccc 2 firstArg secondArg machineState



-- 0xd5


push_d : MachineState -> MachineStateDiff
push_d machineState =
    push_ (getD machineState) (getE machineState) machineState



-- 0xd8


rc : MachineState -> MachineStateDiff
rc machineState =
    rcc 3 machineState



-- 0xda


jc : ByteValue -> ByteValue -> MachineState -> MachineStateDiff
jc firstArg secondArg machineState =
    if machineState.cpuState.conditionCodes.cy then
        j_ firstArg secondArg

    else
        let
            newPc =
                getPC machineState + 3
        in
        Events [ setPC newPc ]



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



-- 0xe6


ani : ByteValue -> MachineState -> MachineStateDiff
ani firstArg machineState =
    let
        newPc =
            getPC machineState + 2

        newA =
            Bitwise.and (getA machineState) firstArg
    in
    Events
        (List.concat
            [ [ setRegisterA newA
              , setPC newPc
              , setFlagCY False
              , setFlagAC (logicalAuxiliaryCarry (getA machineState) firstArg)
              ]
            , flags_ZSP newA
            ]
        )



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



-- 0xf6


ori_d8 : ByteValue -> MachineState -> MachineStateDiff
ori_d8 firstArg machineState =
    let
        newA =
            Bitwise.or (getA machineState) firstArg

        newPc =
            getPC machineState + 2
    in
    Events
        (List.concat
            [ [ setRegisterA newA
              , setPC newPc
              ]
            , logic_flags_a newA
            ]
        )



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
cpi : ByteValue -> MachineState -> MachineStateDiff
cpi firstArg machineState =
    let
        currentA =
            getA machineState

        x =
            modBy 256 (currentA - firstArg)

        newPc =
            getPC machineState + 2
    in
    Events
        [ setFlagZ (ConditionCodesFlags.zFlag x)
        , setFlagS (ConditionCodesFlags.sFlag x)
        , setFlagP (ConditionCodesFlags.pFlag x)
        , setFlagCY (currentA < firstArg)
        , setFlagAC (subtractionAuxiliaryCarry currentA firstArg x)
        , setPC newPc
        ]


{-| Auxiliary carry of a subtraction `a - b = result`: True when there is NO
borrow from bit 3 into bit 4. Bit 4 of `a xor b xor result` is the borrow chain.
-}
subtractionAuxiliaryCarry : ByteValue -> ByteValue -> ByteValue -> Flag
subtractionAuxiliaryCarry a b result =
    Bitwise.and 0x10 (Bitwise.xor (Bitwise.xor a b) result) == 0x00



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


operandValue : Int -> MachineState -> ByteValue
operandValue index machineState =
    case index of
        0 ->
            getB machineState

        1 ->
            getC machineState

        2 ->
            getD machineState

        3 ->
            getE machineState

        4 ->
            getH machineState

        5 ->
            getL machineState

        6 ->
            memoryAt (hlAddress machineState) machineState

        _ ->
            getA machineState


writeRegister : Int -> MachineState -> ByteValue -> MachineStateDiffEvent
writeRegister index machineState value =
    case index of
        0 ->
            setRegisterB value

        1 ->
            setRegisterC value

        2 ->
            setRegisterD value

        3 ->
            setRegisterE value

        4 ->
            setRegisterH value

        5 ->
            setRegisterL value

        6 ->
            setMemory (hlAddress machineState) value

        _ ->
            setRegisterA value


pairValue : Int -> MachineState -> AddressValue
pairValue pair machineState =
    case pair of
        0 ->
            combineBytes (getB machineState) (getC machineState)

        1 ->
            combineBytes (getD machineState) (getE machineState)

        2 ->
            combineBytes (getH machineState) (getL machineState)

        _ ->
            getSP machineState


setPairEvents : Int -> AddressValue -> List MachineStateDiffEvent
setPairEvents pair value =
    let
        high =
            Bitwise.and 0xFF (Bitwise.shiftRightBy 8 value)

        low =
            Bitwise.and 0xFF value
    in
    case pair of
        0 ->
            [ setRegisterB high, setRegisterC low ]

        1 ->
            [ setRegisterD high, setRegisterE low ]

        2 ->
            [ setRegisterH high, setRegisterL low ]

        _ ->
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


movRegister : Int -> Int -> MachineState -> MachineStateDiff
movRegister destination source machineState =
    Events
        [ writeRegister destination machineState (operandValue source machineState)
        , setPC (nextPc 1 machineState)
        ]


mviRegister : Int -> ByteValue -> MachineState -> MachineStateDiff
mviRegister destination value machineState =
    Events
        [ writeRegister destination machineState value
        , setPC (nextPc 2 machineState)
        ]


incRegister : Int -> MachineState -> MachineStateDiff
incRegister index machineState =
    let
        value =
            operandValue index machineState

        result =
            modBy 256 (value + 1)
    in
    Events
        ([ writeRegister index machineState result
         , setFlagAC (Bitwise.and 0x0F value == 0x0F)
         ]
            ++ flags_ZSP result
            ++ [ setPC (nextPc 1 machineState) ]
        )


decRegister : Int -> MachineState -> MachineStateDiff
decRegister index machineState =
    let
        value =
            operandValue index machineState

        result =
            modBy 256 (value - 1)
    in
    Events
        ([ writeRegister index machineState result
         , setFlagAC (Bitwise.and 0x0F value > 0)
         ]
            ++ flags_ZSP result
            ++ [ setPC (nextPc 1 machineState) ]
        )


{-| Result, carry and auxiliary carry of `a + b + carryIn`.
-}
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


aluRegister : Int -> Int -> MachineState -> MachineStateDiff
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


incPair : Int -> MachineState -> MachineStateDiff
incPair pair machineState =
    Events (setPairEvents pair (modBy 0x00010000 (pairValue pair machineState + 1)) ++ [ setPC (nextPc 1 machineState) ])


decPair : Int -> MachineState -> MachineStateDiff
decPair pair machineState =
    Events (setPairEvents pair (modBy 0x00010000 (pairValue pair machineState - 1)) ++ [ setPC (nextPc 1 machineState) ])


dadPair : Int -> MachineState -> MachineStateDiff
dadPair pair machineState =
    let
        sum =
            pairValue 2 machineState + pairValue pair machineState
    in
    Events
        (setPairEvents 2 (modBy 0x00010000 sum)
            ++ [ setFlagCY (sum > 0xFFFF), setPC (nextPc 1 machineState) ]
        )


lxiPair : Int -> ByteValue -> ByteValue -> MachineState -> MachineStateDiff
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
