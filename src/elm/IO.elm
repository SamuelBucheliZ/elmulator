module IO exposing (..)

import Bitwise
import EmulatorState exposing (ByteValue, EmulatorState, MachineState, MachineStateDiff(..), MachineStateDiffEvent(..), RegisterValue, SetCpuStateEvent(..), SetPortEvent(..), SetShiftRegisterEvent(..))


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


pressLeft : MachineState -> MachineStateDiff
pressLeft machineState =
    let
        newValue =
            Bitwise.or machineState.ports.one 16
    in
    Events [ SetPort (SetOne newValue) ]


relaseLeft : MachineState -> MachineStateDiff
relaseLeft machineState =
    let
        newValue =
            Bitwise.and machineState.ports.one (255 - 16)
    in
    Events [ SetPort (SetOne newValue) ]


pressRight : MachineState -> MachineStateDiff
pressRight machineState =
    let
        newValue =
            Bitwise.or machineState.ports.one 32
    in
    Events [ SetPort (SetOne newValue) ]


relaseRight : MachineState -> MachineStateDiff
relaseRight machineState =
    let
        newValue =
            Bitwise.and machineState.ports.one (255 - 32)
    in
    Events [ SetPort (SetOne newValue) ]


pressSpace : MachineState -> MachineStateDiff
pressSpace machineState =
    let
        newValue =
            Bitwise.or machineState.ports.one 8
    in
    Events [ SetPort (SetOne newValue) ]


relaseSpace : MachineState -> MachineStateDiff
relaseSpace machineState =
    let
        newValue =
            Bitwise.and machineState.ports.one (255 - 8)
    in
    Events [ SetPort (SetOne newValue) ]
