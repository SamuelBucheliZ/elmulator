module MachineInstructionsTest exposing (..)

import Array exposing (fromList)
import EmulatorState exposing (ConditionCodes, CpuState, MachineState, MachineStateDiff(..), MachineStateDiffEvent(..), Ports, SetCpuStateEvent(..), SetFlagEvent(..), ShiftRegister)
import Expect
import List exposing (range)
import MachineInstructions
import Test exposing (..)


allZeroMachineState : MachineState
allZeroMachineState =
    MachineState allZeroCpuState Array.empty (ShiftRegister 0 0 0) (Ports 0 0) 0


allZeroCpuState : CpuState
allZeroCpuState =
    { a = 0, b = 0, c = 0, d = 0, e = 0, h = 0, l = 0, sp = 0, pc = 0, conditionCodes = allFalseConditionCodes, intEnable = False, cycleCount = 0 }


allFalseConditionCodes : ConditionCodes
allFalseConditionCodes =
    ConditionCodes False False False False False


all : Test
all =
    describe "MachineInstructions"
        [ describe "0x00 - nop"
            [ test "for zero machine state" <|
                \() ->
                    let
                        expectedMachineStateDiff =
                            Events
                                [ SetCpu (SetPC 0x01)
                                ]
                    in
                    Expect.equal expectedMachineStateDiff (MachineInstructions.nop allZeroMachineState)
            ]
        , describe "0x02 - stax_b"
            [ test "for a=0x01, b=0x02, c=0x03 machine state" <|
                \() ->
                    let
                        a =
                            0x01

                        b =
                            0x02

                        c =
                            0x03

                        machineState =
                            { allZeroMachineState | cpuState = { a = a, b = b, c = c, d = 0, e = 0, h = 0, l = 0, sp = 0, pc = 0, conditionCodes = allFalseConditionCodes, intEnable = False, cycleCount = 0 } }

                        expectedMachineStateDiff =
                            Events
                                [ SetMemory 0x0203 0x01
                                , SetCpu (SetPC 0x01)
                                ]
                    in
                    Expect.equal expectedMachineStateDiff (MachineInstructions.stax_b machineState)
            ]
        , describe "0x07 - rlc"
            [ test "for a=0x01 machine state" <|
                \() ->
                    let
                        machineState =
                            { allZeroMachineState | cpuState = { a = 1, b = 0, c = 0, d = 0, e = 0, h = 0, l = 0, sp = 0, pc = 0, conditionCodes = allFalseConditionCodes, intEnable = False, cycleCount = 0 } }

                        expectedMachineStateDiff =
                            Events
                                [ SetCpu (SetRegisterA 0x02)
                                , SetCpu (SetFlag (SetFlagCY False))
                                , SetCpu (SetPC 0x01)
                                ]
                    in
                    Expect.equal expectedMachineStateDiff (MachineInstructions.rlc machineState)
            , test "for a=128 machine state" <|
                \() ->
                    let
                        machineState =
                            { allZeroMachineState | cpuState = { a = 128, b = 0, c = 0, d = 0, e = 0, h = 0, l = 0, sp = 0, pc = 0, conditionCodes = allFalseConditionCodes, intEnable = False, cycleCount = 0 } }

                        expectedMachineStateDiff =
                            Events
                                [ SetCpu (SetRegisterA 0x01)
                                , SetCpu (SetFlag (SetFlagCY True))
                                , SetCpu (SetPC 0x01)
                                ]
                    in
                    Expect.equal expectedMachineStateDiff (MachineInstructions.rlc machineState)
            ]
        , describe "0x0a - ldax_b"
            [ test "for c=2" <|
                \() ->
                    let
                        machineState =
                            { allZeroMachineState | cpuState = { a = 0, b = 0, c = 2, d = 0, e = 0, h = 0, l = 0, sp = 0, pc = 0, conditionCodes = allFalseConditionCodes, intEnable = False, cycleCount = 0 }, memory = fromList [ 0, 0, 10 ] }

                        expectedMachineStateDiff =
                            Events
                                [ SetCpu (SetRegisterA 10)
                                , SetCpu (SetPC 0x01)
                                ]
                    in
                    Expect.equal expectedMachineStateDiff (MachineInstructions.ldax_b machineState)
            ]
        , describe "0x0f - rrc"
            [ test "for a=0x01 machine state" <|
                \() ->
                    let
                        a =
                            0x01

                        machineState =
                            { allZeroMachineState | cpuState = { a = a, b = 0, c = 0, d = 0, e = 0, h = 0, l = 0, sp = 0, pc = 0, conditionCodes = allFalseConditionCodes, intEnable = False, cycleCount = 0 } }

                        expectedMachineStateDiff =
                            Events
                                [ SetCpu (SetRegisterA 0x80)
                                , SetCpu (SetFlag (SetFlagCY True))
                                , SetCpu (SetPC 1)
                                ]
                    in
                    Expect.equal expectedMachineStateDiff (MachineInstructions.rrc machineState)
            , test "for a=0x00 machine state" <|
                \() ->
                    let
                        a =
                            0x00

                        machineState =
                            { allZeroMachineState | cpuState = { a = a, b = 0, c = 0, d = 0, e = 0, h = 0, l = 0, sp = 0, pc = 0, conditionCodes = allFalseConditionCodes, intEnable = False, cycleCount = 0 } }

                        expectedMachineStateDiff =
                            Events
                                [ SetCpu (SetRegisterA 0x00)
                                , SetCpu (SetFlag (SetFlagCY False))
                                , SetCpu (SetPC 1)
                                ]
                    in
                    Expect.equal expectedMachineStateDiff (MachineInstructions.rrc machineState)
            ]
        , describe "0x12 - stax_d"
            [ test "for zero machine state" <|
                \() ->
                    let
                        a =
                            13

                        d =
                            0x01

                        e =
                            0x05

                        machineState =
                            { allZeroMachineState | cpuState = { a = a, b = 0, c = 0, d = d, e = e, h = 0, l = 0, sp = 0, pc = 0, conditionCodes = allFalseConditionCodes, intEnable = False, cycleCount = 0 } }

                        expectedMachineStateDiff =
                            Events
                                [ SetMemory 0x0105 13
                                , SetCpu (SetPC 0x01)
                                ]
                    in
                    Expect.equal expectedMachineStateDiff (MachineInstructions.stax_d machineState)
            ]
        , describe "0x1a - ldax_d"
            [ test "for zero machine state" <|
                \() ->
                    let
                        d =
                            0x01

                        e =
                            0x02

                        machineState =
                            { allZeroMachineState | cpuState = { a = 0, b = 0, c = 0, d = d, e = e, h = 0, l = 0, sp = 0, pc = 0, conditionCodes = allFalseConditionCodes, intEnable = False, cycleCount = 0 }, memory = fromList (range 0 0x0102) }

                        expectedMachineStateDiff =
                            Events
                                [ SetCpu (SetRegisterA 0x0102)
                                , SetCpu (SetPC 0x01)
                                ]
                    in
                    Expect.equal expectedMachineStateDiff (MachineInstructions.ldax_d machineState)
            ]
        , describe "0x1f - rar"
            [ test "for a=1, cy=False machine state" <|
                \() ->
                    let
                        a =
                            1

                        cy =
                            False

                        machineState =
                            { allZeroMachineState | cpuState = { a = a, b = 0, c = 0, d = 0, e = 0, h = 0, l = 0, sp = 0, pc = 0, conditionCodes = ConditionCodes False False False cy False, intEnable = False, cycleCount = 0 } }

                        expectedMachineStateDiff =
                            Events
                                [ SetCpu (SetRegisterA 0)
                                , SetCpu (SetFlag (SetFlagCY True))
                                , SetCpu (SetPC 0x01)
                                ]
                    in
                    Expect.equal expectedMachineStateDiff (MachineInstructions.rar machineState)
            , test "for a=1, cy=True machine state" <|
                \() ->
                    let
                        a =
                            1

                        cy =
                            True

                        machineState =
                            { allZeroMachineState | cpuState = { a = a, b = 0, c = 0, d = 0, e = 0, h = 0, l = 0, sp = 0, pc = 0, conditionCodes = ConditionCodes False False False cy False, intEnable = False, cycleCount = 0 } }

                        expectedMachineStateDiff =
                            Events
                                [ SetCpu (SetRegisterA 128)
                                , SetCpu (SetFlag (SetFlagCY True))
                                , SetCpu (SetPC 0x01)
                                ]
                    in
                    Expect.equal expectedMachineStateDiff (MachineInstructions.rar machineState)
            , test "for a=4, cy=True machine state" <|
                \() ->
                    let
                        a =
                            4

                        cy =
                            True

                        machineState =
                            { allZeroMachineState | cpuState = { a = a, b = 0, c = 0, d = 0, e = 0, h = 0, l = 0, sp = 0, pc = 0, conditionCodes = ConditionCodes False False False cy False, intEnable = False, cycleCount = 0 } }

                        expectedMachineStateDiff =
                            Events
                                [ SetCpu (SetRegisterA 130)
                                , SetCpu (SetFlag (SetFlagCY False))
                                , SetCpu (SetPC 0x01)
                                ]
                    in
                    Expect.equal expectedMachineStateDiff (MachineInstructions.rar machineState)
            , test "for a=0, cy=False machine state" <|
                \() ->
                    let
                        a =
                            0

                        cy =
                            False

                        machineState =
                            { allZeroMachineState | cpuState = { a = a, b = 0, c = 0, d = 0, e = 0, h = 0, l = 0, sp = 0, pc = 0, conditionCodes = ConditionCodes False False False cy False, intEnable = False, cycleCount = 0 } }

                        expectedMachineStateDiff =
                            Events
                                [ SetCpu (SetRegisterA 0)
                                , SetCpu (SetFlag (SetFlagCY False))
                                , SetCpu (SetPC 0x01)
                                ]
                    in
                    Expect.equal expectedMachineStateDiff (MachineInstructions.rar machineState)
            ]
        , describe "0x22 - shld_d16"
            [ test "for l=13, h=34 machine state" <|
                \() ->
                    let
                        l =
                            13

                        h =
                            34

                        machineState =
                            { allZeroMachineState | cpuState = { a = 0, b = 0, c = 0, d = 0, e = 0, h = h, l = l, sp = 0, pc = 0, conditionCodes = allFalseConditionCodes, intEnable = False, cycleCount = 0 }, memory = fromList (range 0 10) }

                        expectedMachineStateDiff =
                            Events
                                [ SetMemory 5 13
                                , SetMemory 6 34
                                , SetCpu (SetPC 3)
                                ]
                    in
                    Expect.equal expectedMachineStateDiff (MachineInstructions.shld_d16 0x05 0x00 machineState)
            ]
        , describe "0x2a - lhld"
            [ test "for zero machine state with memory" <|
                \() ->
                    let
                        machineState =
                            { allZeroMachineState | memory = fromList (range 0 10) }

                        expectedMachineStateDiff =
                            Events
                                [ SetCpu (SetRegisterL 0x04)
                                , SetCpu (SetRegisterH 0x05)
                                , SetCpu (SetPC 0x03)
                                ]
                    in
                    Expect.equal expectedMachineStateDiff (MachineInstructions.lhld 4 0 machineState)
            ]
        , describe "0x32 - sta"
            [ test "for a=0x01 machine state" <|
                \() ->
                    let
                        a =
                            0x01

                        machineState =
                            { allZeroMachineState | cpuState = { a = a, b = 0, c = 0, d = 0, e = 0, h = 0, l = 0, sp = 0, pc = 0, conditionCodes = allFalseConditionCodes, intEnable = False, cycleCount = 0 } }

                        expectedMachineStateDiff =
                            Events
                                [ SetMemory 0x0302 0x01
                                , SetCpu (SetPC 0x03)
                                ]
                    in
                    Expect.equal expectedMachineStateDiff (MachineInstructions.sta 0x02 0x03 machineState)
            ]
        , describe "0x37 - stc"
            [ test "for zero machine state" <|
                \() ->
                    let
                        expectedMachineStateDiff =
                            Events
                                [ SetCpu (SetFlag (SetFlagCY True))
                                , SetCpu (SetPC 0x01)
                                ]
                    in
                    Expect.equal expectedMachineStateDiff (MachineInstructions.stc allZeroMachineState)
            ]
        , describe "0x3a - lda"
            [ test "for zero machine state" <|
                \() ->
                    let
                        machineState =
                            { allZeroMachineState | cpuState = { a = 0, b = 0, c = 0, d = 0, e = 0, h = 0, l = 0, sp = 0, pc = 0, conditionCodes = allFalseConditionCodes, intEnable = False, cycleCount = 0 }, memory = fromList (range 0 0x0302) }

                        expectedMachineStateDiff =
                            Events
                                [ SetCpu (SetRegisterA 0x0302)
                                , SetCpu (SetPC 0x03)
                                ]
                    in
                    Expect.equal expectedMachineStateDiff (MachineInstructions.lda 0x02 0x03 machineState)
            ]
        , describe "0xc1 - pop_b"
            [ test "for a=0x00 machine state" <|
                \() ->
                    let
                        b =
                            0x01

                        c =
                            0x02

                        sp =
                            0x03

                        machineState =
                            { allZeroMachineState | cpuState = { a = 0, b = b, c = c, d = 0, e = 0, h = 0, l = 0, sp = sp, pc = 0, conditionCodes = allFalseConditionCodes, intEnable = False, cycleCount = 0 }, memory = fromList (range 0 0x04) }

                        expectedMachineStateDiff =
                            Events
                                [ SetCpu (SetRegisterC 0x03)
                                , SetCpu (SetRegisterB 0x04)
                                , SetCpu (SetSP 0x05)
                                , SetCpu (SetPC 0x01)
                                ]
                    in
                    Expect.equal expectedMachineStateDiff (MachineInstructions.pop_b machineState)
            ]
        , describe "0xc3 - jmp"
            [ test "for zero machine state" <|
                \() ->
                    let
                        expectedMachineStateDiff =
                            Events
                                [ SetCpu (SetPC 0x0302)
                                ]
                    in
                    Expect.equal expectedMachineStateDiff (MachineInstructions.jmp 0x02 0x03 allZeroMachineState)
            ]
        , describe "0xc5 - push_b"
            [ test "for zero machine state" <|
                \() ->
                    let
                        b =
                            0x03

                        c =
                            0x04

                        sp =
                            0x05

                        machineState =
                            { allZeroMachineState | cpuState = { a = 0, b = b, c = c, d = 0, e = 0, h = 0, l = 0, sp = sp, pc = 0, conditionCodes = allFalseConditionCodes, intEnable = False, cycleCount = 0 } }

                        expectedMachineStateDiff =
                            Events
                                [ SetMemory 0x04 0x03
                                , SetMemory 0x03 0x04
                                , SetCpu (SetSP 0x03)
                                , SetCpu (SetPC 0x01)
                                ]
                    in
                    Expect.equal expectedMachineStateDiff (MachineInstructions.push_b machineState)
            ]
        , describe "0xc9 - ret"
            [ test "for zero machine state" <|
                \() ->
                    let
                        machineState =
                            { allZeroMachineState | cpuState = { a = 0, b = 0, c = 0, d = 0, e = 0, h = 0, l = 0, sp = 0, pc = 0, conditionCodes = allFalseConditionCodes, intEnable = False, cycleCount = 0 }, memory = fromList (range 0 0x01) }

                        expectedMachineStateDiff =
                            Events
                                [ SetCpu (SetSP 0x02)
                                , SetCpu (SetPC 0x0100)
                                ]
                    in
                    Expect.equal expectedMachineStateDiff (MachineInstructions.ret machineState)
            ]
        , describe "0xcd - call"
            [ test "for sp=0x02 machine state" <|
                \() ->
                    let
                        sp =
                            0x02

                        machineState =
                            { allZeroMachineState | cpuState = { a = 0, b = 0, c = 0, d = 0, e = 0, h = 0, l = 0, sp = sp, pc = 0, conditionCodes = allFalseConditionCodes, intEnable = False, cycleCount = 0 } }

                        expectedMachineStateDiff =
                            Events
                                [ SetMemory 0x01 0x00
                                , SetMemory 0x00 0x03
                                , SetCpu (SetSP 0x00)
                                , SetCpu (SetPC 0x0302)
                                ]
                    in
                    Expect.equal expectedMachineStateDiff (MachineInstructions.call 0x02 0x03 machineState)
            ]
        , describe "0xd1 - pop_d"
            [ test "for zero machine state" <|
                \() ->
                    let
                        machineState =
                            { allZeroMachineState | cpuState = { a = 0, b = 0, c = 0, d = 0, e = 0, h = 0, l = 0, sp = 0, pc = 0, conditionCodes = allFalseConditionCodes, intEnable = False, cycleCount = 0 }, memory = fromList (range 0 0x01) }

                        expectedMachineStateDiff =
                            Events
                                [ SetCpu (SetRegisterE 0x00)
                                , SetCpu (SetRegisterD 0x01)
                                , SetCpu (SetSP 0x02)
                                , SetCpu (SetPC 0x01)
                                ]
                    in
                    Expect.equal expectedMachineStateDiff (MachineInstructions.pop_d machineState)
            ]
        , describe "0xd5 - push_d"
            [ test "for d=0x01, e=0x02, sp=0x03 machine state" <|
                \() ->
                    let
                        d =
                            0x01

                        e =
                            0x02

                        sp =
                            0x03

                        machineState =
                            { allZeroMachineState | cpuState = { a = 0, b = 0, c = 0, d = d, e = e, h = 0, l = 0, sp = sp, pc = 0, conditionCodes = allFalseConditionCodes, intEnable = False, cycleCount = 0 }, memory = fromList (range 0 0x01) }

                        expectedMachineStateDiff =
                            Events
                                [ SetMemory 2 1
                                , SetMemory 1 2
                                , SetCpu (SetSP 1)
                                , SetCpu (SetPC 1)
                                ]
                    in
                    Expect.equal expectedMachineStateDiff (MachineInstructions.push_d machineState)
            ]
        , describe "0xe1 - pop_h"
            [ test "for zero machine state" <|
                \() ->
                    let
                        machineState =
                            { allZeroMachineState | cpuState = { a = 0, b = 0, c = 0, d = 0, e = 0, h = 0, l = 0, sp = 0, pc = 0, conditionCodes = allFalseConditionCodes, intEnable = False, cycleCount = 0 }, memory = fromList (range 0 0x01) }

                        expectedMachineStateDiff =
                            Events
                                [ SetCpu (SetRegisterL 0x00)
                                , SetCpu (SetRegisterH 0x01)
                                , SetCpu (SetSP 0x02)
                                , SetCpu (SetPC 0x01)
                                ]
                    in
                    Expect.equal expectedMachineStateDiff (MachineInstructions.pop_h machineState)
            ]
        , describe "0xe3 - xthl"
            [ test "for h=4, l=5, sp=2 machine state" <|
                \() ->
                    let
                        h =
                            4

                        l =
                            5

                        sp =
                            2

                        machineState =
                            { allZeroMachineState | cpuState = { a = 0, b = 0, c = 0, d = 0, e = 0, h = h, l = l, sp = sp, pc = 0, conditionCodes = allFalseConditionCodes, intEnable = False, cycleCount = 0 }, memory = fromList (range 0 5) }

                        expectedMachineStateDiff =
                            Events
                                [ SetCpu (SetRegisterL 2)
                                , SetCpu (SetRegisterH 3)
                                , SetMemory 2 5
                                , SetMemory 3 4
                                , SetCpu (SetPC 0x01)
                                ]
                    in
                    Expect.equal expectedMachineStateDiff (MachineInstructions.xthl machineState)
            ]
        , describe "0xe5 - push_h"
            [ test "for h=0x01, e=0x02, sp=0x03 machine state" <|
                \() ->
                    let
                        h =
                            0x01

                        l =
                            0x02

                        sp =
                            0x03

                        machineState =
                            { allZeroMachineState | cpuState = { a = 0, b = 0, c = 0, d = 0, e = 0, h = h, l = l, sp = sp, pc = 0, conditionCodes = allFalseConditionCodes, intEnable = False, cycleCount = 0 }, memory = fromList (range 0 0x01) }

                        expectedMachineStateDiff =
                            Events
                                [ SetMemory 2 1
                                , SetMemory 1 2
                                , SetCpu (SetSP 1)
                                , SetCpu (SetPC 1)
                                ]
                    in
                    Expect.equal expectedMachineStateDiff (MachineInstructions.push_h machineState)
            ]
        , describe "0xe9 - pchl"
            [ test "for h=3, l=6 machine state" <|
                \() ->
                    let
                        h =
                            0x03

                        l =
                            0x06

                        machineState =
                            { allZeroMachineState | cpuState = { a = 0, b = 0, c = 0, d = 0, e = 0, h = h, l = l, sp = 0, pc = 0, conditionCodes = allFalseConditionCodes, intEnable = False, cycleCount = 0 } }

                        expectedMachineStateDiff =
                            Events [ SetCpu (SetPC 0x0306) ]
                    in
                    Expect.equal expectedMachineStateDiff (MachineInstructions.pchl machineState)
            ]
        , describe "0xf1 - pop_psw"
            [ test "for sp=(PSW all false) sp+1=10 machine state" <|
                \() ->
                    let
                        machineState =
                            { allZeroMachineState | cpuState = { a = 0, b = 0, c = 0, d = 0, e = 0, h = 0, l = 0, sp = 0, pc = 0, conditionCodes = allFalseConditionCodes, intEnable = False, cycleCount = 0 }, memory = fromList [ 2, 10 ] }

                        expectedMachineStateDiff =
                            Events
                                [ SetCpu (SetFlag (SetFlagZ False))
                                , SetCpu (SetFlag (SetFlagS False))
                                , SetCpu (SetFlag (SetFlagP False))
                                , SetCpu (SetFlag (SetFlagCY False))
                                , SetCpu (SetFlag (SetFlagAC False))
                                , SetCpu (SetRegisterA 10)
                                , SetCpu (SetSP 2)
                                , SetCpu (SetPC 1)
                                ]
                    in
                    Expect.equal expectedMachineStateDiff (MachineInstructions.pop_psw machineState)
            , test "for sp=(PSW Z) sp+1=10 machine state" <|
                \() ->
                    let
                        machineState =
                            { allZeroMachineState | cpuState = { a = 0, b = 0, c = 0, d = 0, e = 0, h = 0, l = 0, sp = 0, pc = 0, conditionCodes = allFalseConditionCodes, intEnable = False, cycleCount = 0 }, memory = fromList [ 66, 10 ] }

                        expectedMachineStateDiff =
                            Events
                                [ SetCpu (SetFlag (SetFlagZ True))
                                , SetCpu (SetFlag (SetFlagS False))
                                , SetCpu (SetFlag (SetFlagP False))
                                , SetCpu (SetFlag (SetFlagCY False))
                                , SetCpu (SetFlag (SetFlagAC False))
                                , SetCpu (SetRegisterA 10)
                                , SetCpu (SetSP 2)
                                , SetCpu (SetPC 1)
                                ]
                    in
                    Expect.equal expectedMachineStateDiff (MachineInstructions.pop_psw machineState)
            ]
        ]
