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


{-| The buttons of the Space Invaders cabinet. A bit is 1 while its button is pressed.

Port 1: coin (bit 0), 2P start (bit 1), 1P start (bit 2), fire (bit 4), left (bit 5), right (bit 6).
Bit 3 is always 1. In a one player game the game reads the player controls from port 1
(the input routine at 0x17C0 of the ROM reads port 1 when the flag at 0x2067 is set).

-}
keyEvent : Bool -> GameKey -> MachineState -> MachineStateDiff
keyEvent pressed key machineState =
    case key of
        Left ->
            portOneEvent pressed 0x20 machineState

        Right ->
            portOneEvent pressed 0x40 machineState

        Fire ->
            portOneEvent pressed 0x10 machineState

        Coin ->
            portOneEvent pressed 0x01 machineState

        Start1 ->
            portOneEvent pressed 0x04 machineState

        Start2 ->
            portOneEvent pressed 0x02 machineState


portOneEvent : Bool -> ByteValue -> MachineState -> MachineStateDiff
portOneEvent pressed bit machineState =
    Events [ SetPort (SetOne (changeBit pressed bit machineState.ports.one)) ]


changeBit : Bool -> ByteValue -> ByteValue -> ByteValue
changeBit pressed bit value =
    if pressed then
        Bitwise.or value bit

    else
        Bitwise.and value (Bitwise.complement bit)
