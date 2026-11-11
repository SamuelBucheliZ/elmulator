module IO exposing (..)

import Bitwise
import EmulatorState exposing (ByteValue, EmulatorState, MachineState, MachineStateDiff(..), MachineStateDiffEvent(..), RegisterValue, SetCpuStateEvent(..), SetPortEvent(..), SetShiftRegisterEvent(..))
import UI.Msg exposing (GameKey(..))


io_in : ByteValue -> MachineState -> MachineStateDiff
io_in address machineState =
    let
        newPc =
            machineState.cpuState.pc + 2

        shiftRegisterValue =
            Bitwise.or (Bitwise.shiftLeftBy 8 machineState.shiftRegister.upper) machineState.shiftRegister.lower
    in
    case address of
        1 ->
            Events
                [ SetCpu (SetRegisterA machineState.ports.one)
                , SetCpu (SetPC newPc)
                ]

        2 ->
            Events
                [ SetCpu (SetRegisterA machineState.ports.two)
                , SetCpu (SetPC newPc)
                ]

        3 ->
            Events
                [ SetCpu (SetRegisterA (Bitwise.and (Bitwise.shiftRightBy (8 - machineState.shiftRegister.offset) shiftRegisterValue) 0xFF))
                , SetCpu (SetPC newPc)
                ]

        _ ->
            Events [ SetCpu (SetPC newPc) ]


io_out : ByteValue -> MachineState -> MachineStateDiff
io_out address machineState =
    let
        newPc =
            machineState.cpuState.pc + 2

        data =
            machineState.cpuState.a
    in
    case address of
        2 ->
            Events
                [ SetShiftRegister (SetOffset (Bitwise.and data 0x07))
                , SetCpu (SetPC newPc)
                ]

        4 ->
            let
                newLower =
                    machineState.shiftRegister.upper
            in
            Events
                [ SetShiftRegister (SetLower newLower)
                , SetShiftRegister (SetUpper data)
                , SetCpu (SetPC newPc)
                ]

        _ ->
            Events [ SetCpu (SetPC newPc) ]


{-| Input bits of port 1 of the Space Invaders cabinet. A bit is 1 while its button is pressed.
Bit 3 is always 1.
-}
coinBit : ByteValue
coinBit =
    0x01


start2Bit : ByteValue
start2Bit =
    0x02


start1Bit : ByteValue
start1Bit =
    0x04


fireBit : ByteValue
fireBit =
    0x10


leftBit : ByteValue
leftBit =
    0x20


rightBit : ByteValue
rightBit =
    0x40


{-| The port 1 bit of a game key.
-}
inputBit : GameKey -> ByteValue
inputBit key =
    case key of
        Left ->
            leftBit

        Right ->
            rightBit

        Fire ->
            fireBit

        Coin ->
            coinBit

        Start1 ->
            start1Bit

        Start2 ->
            start2Bit


pressInput : ByteValue -> MachineState -> MachineStateDiff
pressInput bit machineState =
    Events [ SetPort (SetOne (Bitwise.or machineState.ports.one bit)) ]


releaseInput : ByteValue -> MachineState -> MachineStateDiff
releaseInput bit machineState =
    Events [ SetPort (SetOne (Bitwise.and machineState.ports.one (Bitwise.complement bit))) ]
