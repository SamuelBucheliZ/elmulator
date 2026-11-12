module LogicFlags exposing (..)

import Bitwise
import ConditionCodesFlags
import EmulatorState exposing (ByteValue, Flag, MachineStateDiffEvent(..), SetCpuStateEvent(..), SetFlagEvent(..))


setFlagZ : Flag -> MachineStateDiffEvent
setFlagZ newValue =
    SetCpu (SetFlag (SetFlagZ newValue))


setFlagS : Flag -> MachineStateDiffEvent
setFlagS newValue =
    SetCpu (SetFlag (SetFlagS newValue))


setFlagP : Flag -> MachineStateDiffEvent
setFlagP newValue =
    SetCpu (SetFlag (SetFlagP newValue))


setFlagCY : Flag -> MachineStateDiffEvent
setFlagCY newValue =
    SetCpu (SetFlag (SetFlagCY newValue))


setFlagAC : Flag -> MachineStateDiffEvent
setFlagAC newValue =
    SetCpu (SetFlag (SetFlagAC newValue))


{-| Zero, sign and parity flags of an 8 bit result. The value is masked to
8 bits first, so an unwrapped intermediate result (e.g. 0x100) yields Z=True.
-}
flags_ZSP : ByteValue -> List MachineStateDiffEvent
flags_ZSP value =
    let
        byteValue =
            Bitwise.and 0xFF value
    in
    [ setFlagZ (byteValue == 0)
    , setFlagS (Bitwise.and 128 byteValue == 128)
    , setFlagP (ConditionCodesFlags.pFlag byteValue)
    ]


check_flag_CY : ByteValue -> MachineStateDiffEvent
check_flag_CY value =
    setFlagCY (value > 255)


check_flag_AC : ByteValue -> ByteValue -> MachineStateDiffEvent
check_flag_AC valueOne valueTwo =
    let
        lowerA =
            Bitwise.and 0x0F valueOne

        lowerR =
            Bitwise.and 0x0F valueTwo
    in
    if Bitwise.and 0x10 (lowerA + lowerR) == 0x10 then
        setFlagAC True

    else
        setFlagAC False
