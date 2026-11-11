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
    CpuState 0 0 0 0 0 0 0 0 0 allFalseConditionCodes False 0


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
        , describe "0x01 - lxi_b_d16"
            [ test "for zero machine state" <|
                \() ->
                    let
                        expectedMachineStateDiff =
                            Events
                                [ SetCpu (SetRegisterB 0x03)
                                , SetCpu (SetRegisterC 0x02)
                                , SetCpu (SetPC 0x03)
                                ]
                    in
                    Expect.equal expectedMachineStateDiff (MachineInstructions.lxi_b_d16 0x02 0x03 allZeroMachineState)
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
                            { allZeroMachineState | cpuState = CpuState a b c 0 0 0 0 0 0 allFalseConditionCodes False 0 }

                        expectedMachineStateDiff =
                            Events
                                [ SetMemory 0x0203 0x01
                                , SetCpu (SetPC 0x01)
                                ]
                    in
                    Expect.equal expectedMachineStateDiff (MachineInstructions.stax_b machineState)
            ]
        , describe "0x03 - inx_b"
            [ test "for zero machine state" <|
                \() ->
                    let
                        expectedMachineStateDiff1 =
                            Events
                                [ SetCpu (SetRegisterC 0x01)
                                , SetCpu (SetPC 0x01)
                                ]
                    in
                    Expect.equal expectedMachineStateDiff1 (MachineInstructions.inx_b allZeroMachineState)
            , test "for c=0xFF machine state" <|
                \() ->
                    let
                        c =
                            0xFF

                        machineState =
                            { allZeroMachineState | cpuState = CpuState 0 0 c 0 0 0 0 0 0 allFalseConditionCodes False 0 }

                        expectedMachineStateDiff2 =
                            Events
                                [ SetCpu (SetRegisterB 0x01)
                                , SetCpu (SetRegisterC 0x00)
                                , SetCpu (SetPC 0x01)
                                ]
                    in
                    Expect.equal expectedMachineStateDiff2 (MachineInstructions.inx_b machineState)
            ]
        , describe "0x04 - inr_b"
            [ test "for b=4 machine state" <|
                \() ->
                    let
                        b =
                            4

                        machineState =
                            { allZeroMachineState | cpuState = CpuState 0 b 0 0 0 0 0 0 0 allFalseConditionCodes False 0 }

                        expectedMachineStateDiff =
                            Events
                                [ SetCpu (SetRegisterB 0x05)
                                , SetCpu (SetPC 0x01)
                                , SetCpu (SetFlag (SetFlagAC False))
                                , SetCpu (SetFlag (SetFlagZ False))
                                , SetCpu (SetFlag (SetFlagS False))
                                , SetCpu (SetFlag (SetFlagP True))
                                ]
                    in
                    Expect.equal expectedMachineStateDiff (MachineInstructions.inr_b machineState)
            , test "for b=15 machine state" <|
                \() ->
                    let
                        b =
                            15

                        machineState =
                            { allZeroMachineState | cpuState = CpuState 0 b 0 0 0 0 0 0 0 allFalseConditionCodes False 0 }

                        expectedMachineStateDiff =
                            Events
                                [ SetCpu (SetRegisterB 0x10)
                                , SetCpu (SetPC 0x01)
                                , SetCpu (SetFlag (SetFlagAC True))
                                , SetCpu (SetFlag (SetFlagZ False))
                                , SetCpu (SetFlag (SetFlagS False))
                                , SetCpu (SetFlag (SetFlagP False))
                                ]
                    in
                    Expect.equal expectedMachineStateDiff (MachineInstructions.inr_b machineState)
            ]
        , describe "0x05 - dcr_b"
            [ test "for zero machine state" <|
                \() ->
                    let
                        expectedMachineStateDiff =
                            Events
                                [ SetCpu (SetRegisterB 0xFF)
                                , SetCpu (SetFlag (SetFlagZ False))
                                , SetCpu (SetFlag (SetFlagS True))
                                , SetCpu (SetFlag (SetFlagP True))
                                , SetCpu (SetFlag (SetFlagAC False))
                                , SetCpu (SetPC 0x01)
                                ]
                    in
                    Expect.equal expectedMachineStateDiff (MachineInstructions.dcr_b allZeroMachineState)
            , test "for b=0x01 machine state" <|
                \() ->
                    let
                        b =
                            0x01

                        machineState =
                            { allZeroMachineState | cpuState = CpuState 0 b 0 0 0 0 0 0 0 allFalseConditionCodes False 0 }

                        expectedMachineStateDiff =
                            Events
                                [ SetCpu (SetRegisterB 0)
                                , SetCpu (SetFlag (SetFlagZ True))
                                , SetCpu (SetFlag (SetFlagS False))
                                , SetCpu (SetFlag (SetFlagP True))
                                , SetCpu (SetFlag (SetFlagAC True))
                                , SetCpu (SetPC 0x01)
                                ]
                    in
                    Expect.equal expectedMachineStateDiff (MachineInstructions.dcr_b machineState)
            ]
        , describe "0x06 - mvi_b_d8"
            [ test "for zero machine state" <|
                \() ->
                    let
                        expectedMachineStateDiff =
                            Events
                                [ SetCpu (SetRegisterB 0x0D)
                                , SetCpu (SetPC 0x02)
                                ]
                    in
                    Expect.equal expectedMachineStateDiff (MachineInstructions.mvi_b_d8 0x0D allZeroMachineState)
            ]
        , describe "0x07 - rlc"
            [ test "for a=0x01 machine state" <|
                \() ->
                    let
                        machineState =
                            { allZeroMachineState | cpuState = CpuState 1 0 0 0 0 0 0 0 0 allFalseConditionCodes False 0 }

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
                            { allZeroMachineState | cpuState = CpuState 128 0 0 0 0 0 0 0 0 allFalseConditionCodes False 0 }

                        expectedMachineStateDiff =
                            Events
                                [ SetCpu (SetRegisterA 0x01)
                                , SetCpu (SetFlag (SetFlagCY True))
                                , SetCpu (SetPC 0x01)
                                ]
                    in
                    Expect.equal expectedMachineStateDiff (MachineInstructions.rlc machineState)
            ]
        , describe "0x09 - dad_b"
            [ test "for b=0x01, c=0x02, h=0x03, l=0x04 machine state" <|
                \() ->
                    let
                        b =
                            0x01

                        c =
                            0x02

                        h =
                            0x03

                        l =
                            0x04

                        machineState =
                            { allZeroMachineState | cpuState = CpuState 0 b c 0 0 h l 0 0 allFalseConditionCodes False 0 }

                        expectedMachineStateDiff =
                            Events
                                [ SetCpu (SetRegisterH 0x04)
                                , SetCpu (SetRegisterL 0x06)
                                , SetCpu (SetFlag (SetFlagCY False))
                                , SetCpu (SetPC 0x01)
                                ]
                    in
                    Expect.equal expectedMachineStateDiff (MachineInstructions.dad_b machineState)
            ]
        , describe "0x0a - ldax_b"
            [ test "for c=2" <|
                \() ->
                    let
                        machineState =
                            { allZeroMachineState | cpuState = CpuState 0 0 2 0 0 0 0 0 0 allFalseConditionCodes False 0, memory = fromList [ 0, 0, 10 ] }

                        expectedMachineStateDiff =
                            Events
                                [ SetCpu (SetRegisterA 10)
                                , SetCpu (SetPC 0x01)
                                ]
                    in
                    Expect.equal expectedMachineStateDiff (MachineInstructions.ldax_b machineState)
            ]
        , describe "0x0b - dcx_b"
            [ test "for b=0, c=5 machine state" <|
                \() ->
                    let
                        b =
                            0x01

                        c =
                            0x05

                        machineState =
                            { allZeroMachineState | cpuState = CpuState 0 b c 0 0 0 0 0 0 allFalseConditionCodes False 0 }

                        expectedMachineStateDiff =
                            Events
                                [ SetCpu (SetRegisterB 0x01)
                                , SetCpu (SetRegisterC 0x04)
                                , SetCpu (SetPC 0x01)
                                ]
                    in
                    Expect.equal expectedMachineStateDiff (MachineInstructions.dcx_b machineState)
            ]
        , describe "0x0d - dcr_c"
            [ test "for zero machine state" <|
                \() ->
                    let
                        expectedMachineStateDiff =
                            Events
                                [ SetCpu (SetRegisterC 0xFF)
                                , SetCpu (SetFlag (SetFlagZ False))
                                , SetCpu (SetFlag (SetFlagS True))
                                , SetCpu (SetFlag (SetFlagP True))
                                , SetCpu (SetFlag (SetFlagAC False))
                                , SetCpu (SetPC 0x01)
                                ]
                    in
                    Expect.equal expectedMachineStateDiff (MachineInstructions.dcr_c allZeroMachineState)
            , test "for c=0x01 machine state" <|
                \() ->
                    let
                        c =
                            0x01

                        machineState =
                            { allZeroMachineState | cpuState = CpuState 0 0 c 0 0 0 0 0 0 allFalseConditionCodes False 0 }

                        expectedMachineStateDiff =
                            Events
                                [ SetCpu (SetRegisterC 0)
                                , SetCpu (SetFlag (SetFlagZ True))
                                , SetCpu (SetFlag (SetFlagS False))
                                , SetCpu (SetFlag (SetFlagP True))
                                , SetCpu (SetFlag (SetFlagAC True))
                                , SetCpu (SetPC 0x01)
                                ]
                    in
                    Expect.equal expectedMachineStateDiff (MachineInstructions.dcr_c machineState)
            ]
        , describe "0x0e - mvi_c_d8"
            [ test "for zero machine state" <|
                \() ->
                    let
                        expectedMachineStateDiff =
                            Events
                                [ SetCpu (SetRegisterC 0x0D)
                                , SetCpu (SetPC 0x02)
                                ]
                    in
                    Expect.equal expectedMachineStateDiff (MachineInstructions.mvi_c_d8 0x0D allZeroMachineState)
            ]
        , describe "0x0f - rrc"
            [ test "for a=0x01 machine state" <|
                \() ->
                    let
                        a =
                            0x01

                        machineState =
                            { allZeroMachineState | cpuState = CpuState a 0 0 0 0 0 0 0 0 allFalseConditionCodes False 0 }

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
                            { allZeroMachineState | cpuState = CpuState a 0 0 0 0 0 0 0 0 allFalseConditionCodes False 0 }

                        expectedMachineStateDiff =
                            Events
                                [ SetCpu (SetRegisterA 0x00)
                                , SetCpu (SetFlag (SetFlagCY False))
                                , SetCpu (SetPC 1)
                                ]
                    in
                    Expect.equal expectedMachineStateDiff (MachineInstructions.rrc machineState)
            ]
        , describe "0x11 - lxi_d_d16"
            [ test "for zero machine state" <|
                \() ->
                    let
                        expectedMachineStateDiff =
                            Events
                                [ SetCpu (SetRegisterD 0x03)
                                , SetCpu (SetRegisterE 0x02)
                                , SetCpu (SetPC 0x03)
                                ]
                    in
                    Expect.equal expectedMachineStateDiff (MachineInstructions.lxi_d_d16 0x02 0x03 allZeroMachineState)
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
                            { allZeroMachineState | cpuState = CpuState a 0 0 d e 0 0 0 0 allFalseConditionCodes False 0 }

                        expectedMachineStateDiff =
                            Events
                                [ SetMemory 0x0105 13
                                , SetCpu (SetPC 0x01)
                                ]
                    in
                    Expect.equal expectedMachineStateDiff (MachineInstructions.stax_d machineState)
            ]
        , describe "0x13 - inx_d"
            [ test "for zero machine state" <|
                \() ->
                    let
                        expectedMachineStateDiff1 =
                            Events
                                [ SetCpu (SetRegisterE 0x01)
                                , SetCpu (SetPC 0x01)
                                ]
                    in
                    Expect.equal expectedMachineStateDiff1 (MachineInstructions.inx_d allZeroMachineState)
            , test "for e=0xFF machine state" <|
                \() ->
                    let
                        e =
                            0xFF

                        machineState =
                            { allZeroMachineState | cpuState = CpuState 0 0 0 0 e 0 0 0 0 allFalseConditionCodes False 0 }

                        expectedMachineStateDiff2 =
                            Events
                                [ SetCpu (SetRegisterD 0x01)
                                , SetCpu (SetRegisterE 0x00)
                                , SetCpu (SetPC 0x01)
                                ]
                    in
                    Expect.equal expectedMachineStateDiff2 (MachineInstructions.inx_d machineState)
            ]
        , describe "0x16 - mvi_d_d8"
            [ test "for zero machine state" <|
                \() ->
                    let
                        expectedMachineStateDiff =
                            Events
                                [ SetCpu (SetRegisterD 0x05)
                                , SetCpu (SetPC 0x02)
                                ]
                    in
                    Expect.equal expectedMachineStateDiff (MachineInstructions.mvi_d_d8 5 allZeroMachineState)
            ]
        , describe "0x19 - dad_d"
            [ test "for d=0x01, e=0x02, h=0x03, l=0x04 machine state" <|
                \() ->
                    let
                        d =
                            0x01

                        e =
                            0x02

                        h =
                            0x03

                        l =
                            0x04

                        machineState =
                            { allZeroMachineState | cpuState = CpuState 0 0 0 d e h l 0 0 allFalseConditionCodes False 0 }

                        expectedMachineStateDiff =
                            Events
                                [ SetCpu (SetRegisterH 0x04)
                                , SetCpu (SetRegisterL 0x06)
                                , SetCpu (SetFlag (SetFlagCY False))
                                , SetCpu (SetPC 0x01)
                                ]
                    in
                    Expect.equal expectedMachineStateDiff (MachineInstructions.dad_d machineState)
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
                            { allZeroMachineState | cpuState = CpuState 0 0 0 d e 0 0 0 0 allFalseConditionCodes False 0, memory = fromList (range 0 0x0102) }

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
                            { allZeroMachineState | cpuState = CpuState a 0 0 0 0 0 0 0 0 (ConditionCodes False False False cy False) False 0 }

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
                            { allZeroMachineState | cpuState = CpuState a 0 0 0 0 0 0 0 0 (ConditionCodes False False False cy False) False 0 }

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
                            { allZeroMachineState | cpuState = CpuState a 0 0 0 0 0 0 0 0 (ConditionCodes False False False cy False) False 0 }

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
                            { allZeroMachineState | cpuState = CpuState a 0 0 0 0 0 0 0 0 (ConditionCodes False False False cy False) False 0 }

                        expectedMachineStateDiff =
                            Events
                                [ SetCpu (SetRegisterA 0)
                                , SetCpu (SetFlag (SetFlagCY False))
                                , SetCpu (SetPC 0x01)
                                ]
                    in
                    Expect.equal expectedMachineStateDiff (MachineInstructions.rar machineState)
            ]
        , describe "0x21 - lxi_h_d16"
            [ test "for zero machine state" <|
                \() ->
                    let
                        expectedMachineStateDiff =
                            Events
                                [ SetCpu (SetRegisterH 0x03)
                                , SetCpu (SetRegisterL 0x02)
                                , SetCpu (SetPC 0x03)
                                ]
                    in
                    Expect.equal expectedMachineStateDiff (MachineInstructions.lxi_h_d16 0x02 0x03 allZeroMachineState)
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
                            { allZeroMachineState | cpuState = CpuState 0 0 0 0 0 h l 0 0 allFalseConditionCodes False 0, memory = fromList (range 0 10) }

                        expectedMachineStateDiff =
                            Events
                                [ SetMemory 5 13
                                , SetMemory 6 34
                                , SetCpu (SetPC 3)
                                ]
                    in
                    Expect.equal expectedMachineStateDiff (MachineInstructions.shld_d16 0x05 0x00 machineState)
            ]
        , describe "0x23 - inx_h"
            [ test "for zero machine state" <|
                \() ->
                    let
                        expectedMachineStateDiff1 =
                            Events
                                [ SetCpu (SetRegisterL 0x01)
                                , SetCpu (SetPC 0x01)
                                ]
                    in
                    Expect.equal expectedMachineStateDiff1 (MachineInstructions.inx_h allZeroMachineState)
            , test "for l=0xFF machine state" <|
                \() ->
                    let
                        l =
                            0xFF

                        machineState =
                            { allZeroMachineState | cpuState = CpuState 0 0 0 0 0 0 l 0 0 allFalseConditionCodes False 0 }

                        expectedMachineStateDiff2 =
                            Events
                                [ SetCpu (SetRegisterH 0x01)
                                , SetCpu (SetRegisterL 0x00)
                                , SetCpu (SetPC 0x01)
                                ]
                    in
                    Expect.equal expectedMachineStateDiff2 (MachineInstructions.inx_h machineState)
            ]
        , describe "0x26 - mvi_h_d8"
            [ test "for zero machine state" <|
                \() ->
                    let
                        expectedMachineStateDiff =
                            Events
                                [ SetCpu (SetRegisterH 0x0D)
                                , SetCpu (SetPC 0x02)
                                ]
                    in
                    Expect.equal expectedMachineStateDiff (MachineInstructions.mvi_h_d8 0x0D allZeroMachineState)
            ]
        , describe "0x29 - dad_h"
            [ test "for h=0x01, l=0x02 machine state" <|
                \() ->
                    let
                        h =
                            0x01

                        l =
                            0x02

                        machineState =
                            { allZeroMachineState | cpuState = CpuState 0 0 0 0 0 h l 0 0 allFalseConditionCodes False 0 }

                        expectedMachineStateDiff =
                            Events
                                [ SetCpu (SetRegisterH 0x02)
                                , SetCpu (SetRegisterL 0x04)
                                , SetCpu (SetFlag (SetFlagCY False))
                                , SetCpu (SetPC 0x01)
                                ]
                    in
                    Expect.equal expectedMachineStateDiff (MachineInstructions.dad_h machineState)
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
        , describe "0x2b - dcx_h"
            [ test "for h=0, l=5 machine state" <|
                \() ->
                    let
                        h =
                            0

                        l =
                            5

                        machineState =
                            { allZeroMachineState | cpuState = CpuState 0 0 0 0 0 h l 0 0 allFalseConditionCodes False 0 }

                        expectedMachineStateDiff =
                            Events
                                [ SetCpu (SetRegisterH 0)
                                , SetCpu (SetRegisterL 4)
                                , SetCpu (SetPC 0x01)
                                ]
                    in
                    Expect.equal expectedMachineStateDiff (MachineInstructions.dcx_h machineState)
            ]
        , describe "0x2e - mvi_l_d8"
            [ test "for zero machine state" <|
                \() ->
                    let
                        expectedMachineStateDiff =
                            Events
                                [ SetCpu (SetRegisterL 0x0D)
                                , SetCpu (SetPC 0x02)
                                ]
                    in
                    Expect.equal expectedMachineStateDiff (MachineInstructions.mvi_l_d8 0x0D allZeroMachineState)
            ]
        , describe "0x31 - lxi_sp_d16"
            [ test "for zero machine state" <|
                \() ->
                    let
                        expectedMachineStateDiff =
                            Events
                                [ SetCpu (SetSP 0x0302)
                                , SetCpu (SetPC 0x03)
                                ]
                    in
                    Expect.equal expectedMachineStateDiff (MachineInstructions.lxi_sp_d16 0x02 0x03 allZeroMachineState)
            ]
        , describe "0x32 - sta"
            [ test "for a=0x01 machine state" <|
                \() ->
                    let
                        a =
                            0x01

                        machineState =
                            { allZeroMachineState | cpuState = CpuState a 0 0 0 0 0 0 0 0 allFalseConditionCodes False 0 }

                        expectedMachineStateDiff =
                            Events
                                [ SetMemory 0x0302 0x01
                                , SetCpu (SetPC 0x03)
                                ]
                    in
                    Expect.equal expectedMachineStateDiff (MachineInstructions.sta 0x02 0x03 machineState)
            ]
        , describe "0x35 - dcr_m"
            [ test "for zero machine state" <|
                \() ->
                    let
                        machineState =
                            { allZeroMachineState | cpuState = CpuState 0 0 0 0 0 0 0 0 0 allFalseConditionCodes False 0, memory = fromList (range 2 2) }

                        expectedMachineStateDiff =
                            Events
                                [ SetMemory 0 0x01
                                , SetCpu (SetFlag (SetFlagZ False))
                                , SetCpu (SetFlag (SetFlagS False))
                                , SetCpu (SetFlag (SetFlagP False))
                                , SetCpu (SetFlag (SetFlagAC True))
                                , SetCpu (SetPC 0x01)
                                ]
                    in
                    Expect.equal expectedMachineStateDiff (MachineInstructions.dcr_m machineState)
            , test "for b=0x01 machine state" <|
                \() ->
                    let
                        h =
                            0x01

                        l =
                            0x02

                        machineState =
                            { allZeroMachineState | cpuState = CpuState 0 0 0 0 0 h l 0 0 allFalseConditionCodes False 0, memory = fromList (List.map (modBy 256) (range 0 0x0102)) }

                        expectedMachineStateDiff =
                            Events
                                [ SetMemory 0x0102 0x01
                                , SetCpu (SetFlag (SetFlagZ False))
                                , SetCpu (SetFlag (SetFlagS False))
                                , SetCpu (SetFlag (SetFlagP False))
                                , SetCpu (SetFlag (SetFlagAC True))
                                , SetCpu (SetPC 0x01)
                                ]
                    in
                    Expect.equal expectedMachineStateDiff (MachineInstructions.dcr_m machineState)
            ]
        , describe "0x36 - mvi_m_d8"
            [ test "for h=0x01,l=0x02 machine state" <|
                \() ->
                    let
                        h =
                            0x01

                        l =
                            0x02

                        machineState =
                            { allZeroMachineState | cpuState = CpuState 0 0 0 0 0 h l 0 0 allFalseConditionCodes False 0 }

                        expectedMachineStateDiff =
                            Events
                                [ SetMemory 0x0102 0x0D
                                , SetCpu (SetPC 0x02)
                                ]
                    in
                    Expect.equal expectedMachineStateDiff (MachineInstructions.mvi_m_d8 0x0D machineState)
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
                            { allZeroMachineState | cpuState = CpuState 0 0 0 0 0 0 0 0 0 allFalseConditionCodes False 0, memory = fromList (range 0 0x0302) }

                        expectedMachineStateDiff =
                            Events
                                [ SetCpu (SetRegisterA 0x0302)
                                , SetCpu (SetPC 0x03)
                                ]
                    in
                    Expect.equal expectedMachineStateDiff (MachineInstructions.lda 0x02 0x03 machineState)
            ]
        , describe "0x3c - inr_a"
            [ test "for a=7 machine state" <|
                \() ->
                    let
                        a =
                            7

                        machineState =
                            { allZeroMachineState | cpuState = CpuState a 0 0 0 0 0 0 0 0 allFalseConditionCodes False 0 }

                        expectedMachineStateDiff =
                            Events
                                [ SetCpu (SetRegisterA 0x08)
                                , SetCpu (SetPC 0x01)
                                , SetCpu (SetFlag (SetFlagAC False))
                                , SetCpu (SetFlag (SetFlagZ False))
                                , SetCpu (SetFlag (SetFlagS False))
                                , SetCpu (SetFlag (SetFlagP False))
                                ]
                    in
                    Expect.equal expectedMachineStateDiff (MachineInstructions.inr_a machineState)
            ]
        , describe "0x3d - dcr_a"
            [ test "for a=1" <|
                \() ->
                    let
                        machineState =
                            { allZeroMachineState | cpuState = CpuState 1 0 0 0 0 0 0 0 0 allFalseConditionCodes False 0, memory = fromList (range 0 10) }

                        expectedMachineStateDiff =
                            Events
                                [ SetCpu (SetRegisterA 0)
                                , SetCpu (SetFlag (SetFlagZ True))
                                , SetCpu (SetFlag (SetFlagS False))
                                , SetCpu (SetFlag (SetFlagP True))
                                , SetCpu (SetFlag (SetFlagAC True))
                                , SetCpu (SetPC 1)
                                ]
                    in
                    Expect.equal expectedMachineStateDiff (MachineInstructions.dcr_a machineState)
            , test "for a=0" <|
                \() ->
                    let
                        machineState =
                            { allZeroMachineState | cpuState = CpuState 0 0 0 0 0 0 0 0 0 allFalseConditionCodes False 0, memory = fromList (range 0 10) }

                        expectedMachineStateDiff =
                            Events
                                [ SetCpu (SetRegisterA 255)
                                , SetCpu (SetFlag (SetFlagZ False))
                                , SetCpu (SetFlag (SetFlagS True))
                                , SetCpu (SetFlag (SetFlagP True))
                                , SetCpu (SetFlag (SetFlagAC False))
                                , SetCpu (SetPC 1)
                                ]
                    in
                    Expect.equal expectedMachineStateDiff (MachineInstructions.dcr_a machineState)
            , test "for a=2" <|
                \() ->
                    let
                        machineState =
                            { allZeroMachineState | cpuState = CpuState 2 0 0 0 0 0 0 0 0 allFalseConditionCodes False 0, memory = fromList (range 0 10) }

                        expectedMachineStateDiff =
                            Events
                                [ SetCpu (SetRegisterA 1)
                                , SetCpu (SetFlag (SetFlagZ False))
                                , SetCpu (SetFlag (SetFlagS False))
                                , SetCpu (SetFlag (SetFlagP False))
                                , SetCpu (SetFlag (SetFlagAC True))
                                , SetCpu (SetPC 1)
                                ]
                    in
                    Expect.equal expectedMachineStateDiff (MachineInstructions.dcr_a machineState)
            ]
        , describe "0x3e - mvi_a_d8"
            [ test "for zero machine state" <|
                \() ->
                    let
                        expectedMachineStateDiff =
                            Events
                                [ SetCpu (SetRegisterA 0x0D)
                                , SetCpu (SetPC 0x02)
                                ]
                    in
                    Expect.equal expectedMachineStateDiff (MachineInstructions.mvi_a_d8 0x0D allZeroMachineState)
            ]
        , describe "0x46 - mov_b_m"
            [ test "for h=0x01,l=0x02 machine state" <|
                \() ->
                    let
                        h =
                            0x01

                        l =
                            0x02

                        machineState =
                            { allZeroMachineState | cpuState = CpuState 0 0 0 0 0 h l 0 0 allFalseConditionCodes False 0, memory = fromList (range 0 0x0102) }

                        expectedMachineStateDiff =
                            Events
                                [ SetCpu (SetRegisterB 0x0102)
                                , SetCpu (SetPC 0x01)
                                ]
                    in
                    Expect.equal expectedMachineStateDiff (MachineInstructions.mov_b_m machineState)
            ]
        , describe "0x47 - mov_b_a"
            [ test "for a=0x01 machine state" <|
                \() ->
                    let
                        a =
                            13

                        machineState =
                            { allZeroMachineState | cpuState = CpuState a 0 0 0 0 0 0 0 0 allFalseConditionCodes False 0 }

                        expectedMachineStateDiff =
                            Events
                                [ SetCpu (SetRegisterB 13)
                                , SetCpu (SetPC 0x01)
                                ]
                    in
                    Expect.equal expectedMachineStateDiff (MachineInstructions.mov_b_a machineState)
            ]
        , describe "0x4e - mov_c_m"
            [ test "for h=0x01,l=0x02 machine state" <|
                \() ->
                    let
                        h =
                            0x01

                        l =
                            0x0A

                        machineState =
                            { allZeroMachineState | cpuState = CpuState 0 0 0 0 0 h l 0 0 allFalseConditionCodes False 0, memory = fromList (range 0 0x010A) }

                        expectedMachineStateDiff =
                            Events
                                [ SetCpu (SetRegisterC 0x010A)
                                , SetCpu (SetPC 0x01)
                                ]
                    in
                    Expect.equal expectedMachineStateDiff (MachineInstructions.mov_c_m machineState)
            ]
        , describe "0x4f - mov_c_a"
            [ test "for a=0x01 machine state" <|
                \() ->
                    let
                        machineState =
                            { allZeroMachineState | cpuState = CpuState 1 0 0 0 0 0 0 0 0 allFalseConditionCodes False 0 }

                        expectedMachineStateDiff =
                            Events
                                [ SetCpu (SetRegisterC 1)
                                , SetCpu (SetPC 0x01)
                                ]
                    in
                    Expect.equal expectedMachineStateDiff (MachineInstructions.mov_c_a machineState)
            ]
        , describe "0x56 - mov_d_m"
            [ test "for h=0x01,l=0x02 machine state" <|
                \() ->
                    let
                        h =
                            0x01

                        l =
                            0x02

                        machineState =
                            { allZeroMachineState | cpuState = CpuState 0 0 0 0 0 h l 0 0 allFalseConditionCodes False 0, memory = fromList (range 0 0x0102) }

                        expectedMachineStateDiff =
                            Events
                                [ SetCpu (SetRegisterD 0x0102)
                                , SetCpu (SetPC 0x01)
                                ]
                    in
                    Expect.equal expectedMachineStateDiff (MachineInstructions.mov_d_m machineState)
            ]
        , describe "0x57 - mov_d_a"
            [ test "for a=0x01 machine state" <|
                \() ->
                    let
                        machineState =
                            { allZeroMachineState | cpuState = CpuState 1 0 0 0 0 0 0 0 0 allFalseConditionCodes False 0 }

                        expectedMachineStateDiff =
                            Events
                                [ SetCpu (SetRegisterD 0x01)
                                , SetCpu (SetPC 0x01)
                                ]
                    in
                    Expect.equal expectedMachineStateDiff (MachineInstructions.mov_d_a machineState)
            ]
        , describe "0x5e - mov_e_m"
            [ test "for h=0x01, l=0x02 machine state" <|
                \() ->
                    let
                        h =
                            0x01

                        l =
                            0x02

                        machineState =
                            { allZeroMachineState | cpuState = CpuState 0 0 0 0 0 h l 0 0 allFalseConditionCodes False 0, memory = fromList (range 0 0x0102) }

                        expectedMachineStateDiff =
                            Events
                                [ SetCpu (SetRegisterE 0x0102)
                                , SetCpu (SetPC 0x01)
                                ]
                    in
                    Expect.equal expectedMachineStateDiff (MachineInstructions.mov_e_m machineState)
            ]
        , describe "0x5f - mov_e_a"
            [ test "for a=0x01 machine state" <|
                \() ->
                    let
                        machineState =
                            { allZeroMachineState | cpuState = CpuState 1 0 0 0 0 0 0 0 0 allFalseConditionCodes False 0 }

                        expectedMachineStateDiff =
                            Events
                                [ SetCpu (SetRegisterE 0x01)
                                , SetCpu (SetPC 0x01)
                                ]
                    in
                    Expect.equal expectedMachineStateDiff (MachineInstructions.mov_e_a machineState)
            ]
        , describe "0x61 - mov_h_c"
            [ test "for a=0x01 machine state" <|
                \() ->
                    let
                        c =
                            15

                        machineState =
                            { allZeroMachineState | cpuState = CpuState 0 0 c 0 0 0 0 0 0 allFalseConditionCodes False 0 }

                        expectedMachineStateDiff =
                            Events
                                [ SetCpu (SetRegisterH 15)
                                , SetCpu (SetPC 0x01)
                                ]
                    in
                    Expect.equal expectedMachineStateDiff (MachineInstructions.mov_h_c machineState)
            ]
        , describe "0x66 - mov_h_m"
            [ test "for h=0x01, l=0x02 machine state" <|
                \() ->
                    let
                        h =
                            0x01

                        l =
                            0x02

                        machineState =
                            { allZeroMachineState | cpuState = CpuState 0 0 0 0 0 h l 0 0 allFalseConditionCodes False 0, memory = fromList (range 0 0x0102) }

                        expectedMachineStateDiff =
                            Events
                                [ SetCpu (SetRegisterH 0x0102)
                                , SetCpu (SetPC 0x01)
                                ]
                    in
                    Expect.equal expectedMachineStateDiff (MachineInstructions.mov_h_m machineState)
            ]
        , describe "0x67 - mov_h_a"
            [ test "for a=13 machine state" <|
                \() ->
                    let
                        a =
                            13

                        machineState =
                            { allZeroMachineState | cpuState = CpuState a 0 0 0 0 0 0 0 0 allFalseConditionCodes False 0 }

                        expectedMachineStateDiff =
                            Events
                                [ SetCpu (SetRegisterH 13)
                                , SetCpu (SetPC 0x01)
                                ]
                    in
                    Expect.equal expectedMachineStateDiff (MachineInstructions.mov_h_a machineState)
            ]
        , describe "0x6f - mov_l_a"
            [ test "for a=0x2 machine state" <|
                \() ->
                    let
                        a =
                            0x02

                        machineState =
                            { allZeroMachineState | cpuState = CpuState a 0 0 0 0 0 0 0 0 allFalseConditionCodes False 0 }

                        expectedMachineStateDiff =
                            Events
                                [ SetCpu (SetRegisterL 0x02)
                                , SetCpu (SetPC 0x01)
                                ]
                    in
                    Expect.equal expectedMachineStateDiff (MachineInstructions.mov_l_a machineState)
            ]
        , describe "0x70 - mov_m_b"
            [ test "for b=0xA0, h=0x01, l=0x02 machine state" <|
                \() ->
                    let
                        b =
                            0xA0

                        h =
                            0x01

                        l =
                            0x04

                        machineState =
                            { allZeroMachineState | cpuState = CpuState 0 b 0 0 0 h l 0 0 allFalseConditionCodes False 0, memory = fromList (range 0 0x0104) }

                        expectedMachineStateDiff =
                            Events
                                [ SetMemory 0x0104 160
                                , SetCpu (SetPC 0x01)
                                ]
                    in
                    Expect.equal expectedMachineStateDiff (MachineInstructions.mov_m_b machineState)
            ]
        , describe "0x77 - mov_m_a"
            [ test "for a=0x0D, h=0x01, l=0x02 machine state" <|
                \() ->
                    let
                        a =
                            0x0D

                        h =
                            0x01

                        l =
                            0x02

                        machineState =
                            { allZeroMachineState | cpuState = CpuState a 0 0 0 0 h l 0 0 allFalseConditionCodes False 0, memory = fromList (range 0 0x0102) }

                        expectedMachineStateDiff =
                            Events
                                [ SetMemory 0x0102 0x0D
                                , SetCpu (SetPC 0x01)
                                ]
                    in
                    Expect.equal expectedMachineStateDiff (MachineInstructions.mov_m_a machineState)
            ]
        , describe "0x78 - mov_a_b"
            [ test "for a=0x00, b=0x01 machine state" <|
                \() ->
                    let
                        a =
                            0x00

                        b =
                            0x04

                        machineState =
                            { allZeroMachineState | cpuState = CpuState a b 0 0 0 0 0 0 0 allFalseConditionCodes False 0 }

                        expectedMachineStateDiff =
                            Events
                                [ SetCpu (SetRegisterA 0x04)
                                , SetCpu (SetPC 0x01)
                                ]
                    in
                    Expect.equal expectedMachineStateDiff (MachineInstructions.mov_a_b machineState)
            ]
        , describe "0x79 - mov_a_c"
            [ test "for c=10 machine state" <|
                \() ->
                    let
                        c =
                            10

                        machineState =
                            { allZeroMachineState | cpuState = CpuState 0 0 c 0 0 0 0 0 0 allFalseConditionCodes False 0 }

                        expectedMachineStateDiff =
                            Events
                                [ SetCpu (SetRegisterA 10)
                                , SetCpu (SetPC 0x01)
                                ]
                    in
                    Expect.equal expectedMachineStateDiff (MachineInstructions.mov_a_c machineState)
            ]
        , describe "0x7a - mov_a_d"
            [ test "for d=0x02 machine state" <|
                \() ->
                    let
                        d =
                            0x02

                        machineState =
                            { allZeroMachineState | cpuState = CpuState 0 0 0 d 0 0 0 0 0 allFalseConditionCodes False 0 }

                        expectedMachineStateDiff =
                            Events
                                [ SetCpu (SetRegisterA 0x02)
                                , SetCpu (SetPC 0x01)
                                ]
                    in
                    Expect.equal expectedMachineStateDiff (MachineInstructions.mov_a_d machineState)
            ]
        , describe "0x7b - mov_a_e"
            [ test "for a=0x00, e=0x01 machine state" <|
                \() ->
                    let
                        a =
                            0x00

                        e =
                            0x01

                        machineState =
                            { allZeroMachineState | cpuState = CpuState a 0 0 0 e 0 0 0 0 allFalseConditionCodes False 0 }

                        expectedMachineStateDiff =
                            Events
                                [ SetCpu (SetRegisterA 0x01)
                                , SetCpu (SetPC 0x01)
                                ]
                    in
                    Expect.equal expectedMachineStateDiff (MachineInstructions.mov_a_e machineState)
            ]
        , describe "0x7c - mov_a_h"
            [ test "for h=0x02 machine state" <|
                \() ->
                    let
                        h =
                            0x02

                        machineState =
                            { allZeroMachineState | cpuState = CpuState 0 0 0 0 0 h 0 0 0 allFalseConditionCodes False 0 }

                        expectedMachineStateDiff =
                            Events
                                [ SetCpu (SetRegisterA 0x02)
                                , SetCpu (SetPC 0x01)
                                ]
                    in
                    Expect.equal expectedMachineStateDiff (MachineInstructions.mov_a_h machineState)
            ]
        , describe "0x7d - mov_a_l"
            [ test "for l=0x02 machine state" <|
                \() ->
                    let
                        l =
                            0x02

                        machineState =
                            { allZeroMachineState | cpuState = CpuState 0 0 0 0 0 0 l 0 0 allFalseConditionCodes False 0 }

                        expectedMachineStateDiff =
                            Events
                                [ SetCpu (SetRegisterA 0x02)
                                , SetCpu (SetPC 0x01)
                                ]
                    in
                    Expect.equal expectedMachineStateDiff (MachineInstructions.mov_a_l machineState)
            ]
        , describe "0x7e - mov_a_m"
            [ test "for h=0x0, l=0x02 machine state" <|
                \() ->
                    let
                        h =
                            0x01

                        l =
                            0x02

                        machineState =
                            { allZeroMachineState | cpuState = CpuState 0 0 0 0 0 h l 0 0 allFalseConditionCodes False 0, memory = fromList (range 0 0x0102) }

                        expectedMachineStateDiff =
                            Events
                                [ SetCpu (SetRegisterA 0x0102)
                                , SetCpu (SetPC 0x01)
                                ]
                    in
                    Expect.equal expectedMachineStateDiff (MachineInstructions.mov_a_m machineState)
            ]
        , describe "0x80 - add_b"
            [ test "for a=10, b=1 machine state" <|
                \() ->
                    let
                        a =
                            10

                        b =
                            1

                        machineState =
                            { allZeroMachineState | cpuState = CpuState a b 0 0 0 0 0 0 0 allFalseConditionCodes False 0 }

                        expectedMachineStateDiff =
                            Events
                                [ SetCpu (SetRegisterA 11)
                                , SetCpu (SetPC 0x01)
                                , SetCpu (SetFlag (SetFlagCY False))
                                , SetCpu (SetFlag (SetFlagAC False))
                                , SetCpu (SetFlag (SetFlagZ False))
                                , SetCpu (SetFlag (SetFlagS False))
                                , SetCpu (SetFlag (SetFlagP False))
                                ]
                    in
                    Expect.equal expectedMachineStateDiff (MachineInstructions.add_b machineState)
            , test "for a=10, b=10 machine state" <|
                \() ->
                    let
                        a =
                            10

                        b =
                            10

                        machineState =
                            { allZeroMachineState | cpuState = CpuState a b 0 0 0 0 0 0 0 allFalseConditionCodes False 0 }

                        expectedMachineStateDiff =
                            Events
                                [ SetCpu (SetRegisterA 20)
                                , SetCpu (SetPC 0x01)
                                , SetCpu (SetFlag (SetFlagCY False))
                                , SetCpu (SetFlag (SetFlagAC True))
                                , SetCpu (SetFlag (SetFlagZ False))
                                , SetCpu (SetFlag (SetFlagS False))
                                , SetCpu (SetFlag (SetFlagP True))
                                ]
                    in
                    Expect.equal expectedMachineStateDiff (MachineInstructions.add_b machineState)
            , test "for a=255, b=255 machine state" <|
                \() ->
                    let
                        a =
                            255

                        b =
                            255

                        machineState =
                            { allZeroMachineState | cpuState = CpuState a b 0 0 0 0 0 0 0 allFalseConditionCodes False 0 }

                        expectedMachineStateDiff =
                            Events
                                [ SetCpu (SetRegisterA 254)
                                , SetCpu (SetPC 0x01)
                                , SetCpu (SetFlag (SetFlagCY True))
                                , SetCpu (SetFlag (SetFlagAC True))
                                , SetCpu (SetFlag (SetFlagZ False))
                                , SetCpu (SetFlag (SetFlagS True))
                                , SetCpu (SetFlag (SetFlagP False))
                                ]
                    in
                    Expect.equal expectedMachineStateDiff (MachineInstructions.add_b machineState)
            ]
        , describe "0xa0 - ana_b"
            [ test "for a=5, b=5 machine state" <|
                \() ->
                    let
                        a =
                            5

                        b =
                            5

                        machineState =
                            { allZeroMachineState | cpuState = CpuState a b 0 0 0 0 0 0 0 allFalseConditionCodes False 0 }

                        expectedMachineStateDiff =
                            Events
                                [ SetCpu (SetRegisterA 5)
                                , SetCpu (SetPC 0x01)
                                , SetCpu (SetFlag (SetFlagCY False))
                                , SetCpu (SetFlag (SetFlagAC False))
                                , SetCpu (SetFlag (SetFlagZ False))
                                , SetCpu (SetFlag (SetFlagS False))
                                , SetCpu (SetFlag (SetFlagP True))
                                ]
                    in
                    Expect.equal expectedMachineStateDiff (MachineInstructions.ana_b machineState)
            , test "for a=128, b=133 machine state" <|
                \() ->
                    let
                        a =
                            128

                        b =
                            133

                        machineState =
                            { allZeroMachineState | cpuState = CpuState a b 0 0 0 0 0 0 0 allFalseConditionCodes False 0 }

                        expectedMachineStateDiff =
                            Events
                                [ SetCpu (SetRegisterA 128)
                                , SetCpu (SetPC 0x01)
                                , SetCpu (SetFlag (SetFlagCY False))
                                , SetCpu (SetFlag (SetFlagAC False))
                                , SetCpu (SetFlag (SetFlagZ False))
                                , SetCpu (SetFlag (SetFlagS True))
                                , SetCpu (SetFlag (SetFlagP False))
                                ]
                    in
                    Expect.equal expectedMachineStateDiff (MachineInstructions.ana_b machineState)
            ]
        , describe "0xa7 - ana_a"
            [ test "for a=0x80 machine state" <|
                \() ->
                    let
                        a =
                            0x80

                        machineState =
                            { allZeroMachineState | cpuState = CpuState a 0 0 0 0 0 0 0 0 allFalseConditionCodes False 0 }

                        expectedMachineStateDiff =
                            Events
                                [ SetCpu (SetRegisterA 0x80)
                                , SetCpu (SetPC 0x01)
                                , SetCpu (SetFlag (SetFlagCY False))
                                , SetCpu (SetFlag (SetFlagAC False))
                                , SetCpu (SetFlag (SetFlagZ False))
                                , SetCpu (SetFlag (SetFlagS True))
                                , SetCpu (SetFlag (SetFlagP False))
                                ]
                    in
                    Expect.equal expectedMachineStateDiff (MachineInstructions.ana_a machineState)
            , test "for a=0x00 machine state" <|
                \() ->
                    let
                        a =
                            0x00

                        machineState =
                            { allZeroMachineState | cpuState = CpuState a 0 0 0 0 0 0 0 0 allFalseConditionCodes False 0 }

                        expectedMachineStateDiff =
                            Events
                                [ SetCpu (SetRegisterA 0x00)
                                , SetCpu (SetPC 0x01)
                                , SetCpu (SetFlag (SetFlagCY False))
                                , SetCpu (SetFlag (SetFlagAC False))
                                , SetCpu (SetFlag (SetFlagZ True))
                                , SetCpu (SetFlag (SetFlagS False))
                                , SetCpu (SetFlag (SetFlagP True))
                                ]
                    in
                    Expect.equal expectedMachineStateDiff (MachineInstructions.ana_a machineState)
            ]
        , describe "0xa8 - xra_b"
            [ test "for a=0x04, b=0x07 machine state" <|
                \() ->
                    let
                        a =
                            0x04

                        b =
                            0x07

                        machineState =
                            { allZeroMachineState | cpuState = CpuState a b 0 0 0 0 0 0 0 allFalseConditionCodes False 0 }

                        expectedMachineStateDiff =
                            Events
                                [ SetCpu (SetRegisterA 0x03)
                                , SetCpu (SetPC 0x01)
                                , SetCpu (SetFlag (SetFlagCY False))
                                , SetCpu (SetFlag (SetFlagAC False))
                                , SetCpu (SetFlag (SetFlagZ False))
                                , SetCpu (SetFlag (SetFlagS False))
                                , SetCpu (SetFlag (SetFlagP True))
                                ]
                    in
                    Expect.equal expectedMachineStateDiff (MachineInstructions.xra_b machineState)
            ]
        , describe "0xaf - xra_a"
            [ test "for a=0x00 machine state" <|
                \() ->
                    let
                        a =
                            0x00

                        machineState =
                            { allZeroMachineState | cpuState = CpuState a 0 0 0 0 0 0 0 0 allFalseConditionCodes False 0 }

                        expectedMachineStateDiff =
                            Events
                                [ SetCpu (SetRegisterA 0x00)
                                , SetCpu (SetPC 0x01)
                                , SetCpu (SetFlag (SetFlagCY False))
                                , SetCpu (SetFlag (SetFlagAC False))
                                , SetCpu (SetFlag (SetFlagZ True))
                                , SetCpu (SetFlag (SetFlagS False))
                                , SetCpu (SetFlag (SetFlagP True))
                                ]
                    in
                    Expect.equal expectedMachineStateDiff (MachineInstructions.xra_a machineState)
            ]
        , describe "0x0b - ora_b"
            [ test "for a=3, b=5 machine state" <|
                \() ->
                    let
                        a =
                            3

                        b =
                            5

                        machineState =
                            { allZeroMachineState | cpuState = CpuState a b 0 0 0 0 0 0 0 allFalseConditionCodes False 0 }

                        expectedMachineStateDiff =
                            Events
                                [ SetCpu (SetRegisterA 7)
                                , SetCpu (SetPC 0x01)
                                , SetCpu (SetFlag (SetFlagCY False))
                                , SetCpu (SetFlag (SetFlagAC False))
                                , SetCpu (SetFlag (SetFlagZ False))
                                , SetCpu (SetFlag (SetFlagS False))
                                , SetCpu (SetFlag (SetFlagP False))
                                ]
                    in
                    Expect.equal expectedMachineStateDiff (MachineInstructions.ora_b machineState)
            ]
        , describe "0xc0 - rnz"
            [ test "for z=True" <|
                \() ->
                    let
                        z =
                            True

                        machineState =
                            { allZeroMachineState | cpuState = CpuState 0 0 0 0 0 0 0 0 0 (ConditionCodes z False False False False) False 0 }

                        expectedMachineStateDiff =
                            Events
                                [ SetCpu (SetPC 0x01)
                                ]
                    in
                    Expect.equal expectedMachineStateDiff (MachineInstructions.rnz machineState)
            , test "for z=False" <|
                \() ->
                    let
                        z =
                            False

                        machineState =
                            { allZeroMachineState | cpuState = CpuState 0 0 0 0 0 0 0 0 0 (ConditionCodes z False False False False) False 0, memory = fromList (range 0 5) }

                        expectedMachineStateDiff =
                            Events
                                [ SetCpu (SetSP 2)
                                , SetCpu (SetPC 0x0100)
                                , SetCpu (AddCycles 6)
                                ]
                    in
                    Expect.equal expectedMachineStateDiff (MachineInstructions.rnz machineState)
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
                            { allZeroMachineState | cpuState = CpuState 0 b c 0 0 0 0 sp 0 allFalseConditionCodes False 0, memory = fromList (range 0 0x04) }

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
        , describe "0xc4 - cnz"
            [ test "for z=0 machine state" <|
                \() ->
                    let
                        pc =
                            0x3056

                        sp =
                            0x02

                        machineState =
                            { allZeroMachineState | cpuState = CpuState 0 0 0 0 0 0 0 sp pc allFalseConditionCodes False 0 }

                        expectedMachineStateDiff =
                            Events
                                [ SetMemory 0x01 0x30
                                , SetMemory 0x00 0x59
                                , SetCpu (SetSP 0x00)
                                , SetCpu (SetPC 0x0A)
                                , SetCpu (AddCycles 6)
                                ]
                    in
                    Expect.equal expectedMachineStateDiff (MachineInstructions.cnz 10 0 machineState)
            , test "for z=1 machine state" <|
                \() ->
                    let
                        machineState =
                            { allZeroMachineState | cpuState = CpuState 0 0 0 0 0 0 0 0 0 (ConditionCodes True False False False False) False 0 }

                        expectedMachineStateDiff =
                            Events
                                [ SetCpu (SetPC 3)
                                ]
                    in
                    Expect.equal expectedMachineStateDiff (MachineInstructions.cnz 0 10 machineState)
            ]
        , describe "0xb0 - ora_b"
            [ test "for a=1, b=11 machine state" <|
                \() ->
                    let
                        a =
                            1

                        b =
                            11

                        machineState =
                            { allZeroMachineState | cpuState = CpuState a b 0 0 0 0 0 0 0 allFalseConditionCodes False 0 }

                        expectedMachineStateDiff =
                            Events
                                [ SetCpu (SetRegisterA 11)
                                , SetCpu (SetPC 0x01)
                                , SetCpu (SetFlag (SetFlagCY False))
                                , SetCpu (SetFlag (SetFlagAC False))
                                , SetCpu (SetFlag (SetFlagZ False))
                                , SetCpu (SetFlag (SetFlagS False))
                                , SetCpu (SetFlag (SetFlagP False))
                                ]
                    in
                    Expect.equal expectedMachineStateDiff (MachineInstructions.ora_b machineState)
            ]
        , describe "0xb4 - ora_h"
            [ test "for a=1, h=10 machine state" <|
                \() ->
                    let
                        a =
                            1

                        h =
                            10

                        machineState =
                            { allZeroMachineState | cpuState = CpuState a 0 0 0 0 h 0 0 0 allFalseConditionCodes False 0 }

                        expectedMachineStateDiff =
                            Events
                                [ SetCpu (SetRegisterA 11)
                                , SetCpu (SetPC 0x01)
                                , SetCpu (SetFlag (SetFlagCY False))
                                , SetCpu (SetFlag (SetFlagAC False))
                                , SetCpu (SetFlag (SetFlagZ False))
                                , SetCpu (SetFlag (SetFlagS False))
                                , SetCpu (SetFlag (SetFlagP False))
                                ]
                    in
                    Expect.equal expectedMachineStateDiff (MachineInstructions.ora_h machineState)
            ]
        , describe "0xb6 - ora_m"
            [ test "for h=0x00, l=0x04 machine state" <|
                \() ->
                    let
                        h =
                            0x00

                        l =
                            4

                        machineState =
                            { allZeroMachineState | cpuState = CpuState 1 0 0 0 0 h l 0 0 allFalseConditionCodes False 0, memory = fromList (range 0 0x04) }

                        expectedMachineStateDiff =
                            Events
                                [ SetCpu (SetRegisterA 0x05)
                                , SetCpu (SetPC 0x01)
                                , SetCpu (SetFlag (SetFlagCY False))
                                , SetCpu (SetFlag (SetFlagAC False))
                                , SetCpu (SetFlag (SetFlagZ False))
                                , SetCpu (SetFlag (SetFlagS False))
                                , SetCpu (SetFlag (SetFlagP True))
                                ]
                    in
                    Expect.equal expectedMachineStateDiff (MachineInstructions.ora_m machineState)
            ]
        , describe "0xc2 - jnz"
            [ test "for zero machine state" <|
                \() ->
                    let
                        expectedMachineStateDiff =
                            Events
                                [ SetCpu (SetPC 0x0201)
                                ]
                    in
                    Expect.equal expectedMachineStateDiff (MachineInstructions.jnz 0x01 0x02 allZeroMachineState)
            , test "for z=true machine state" <|
                \() ->
                    let
                        z =
                            True

                        machineState =
                            { allZeroMachineState | cpuState = CpuState 0 0 0 0 0 0 0 0 0 (ConditionCodes z False False False False) False 0 }

                        expectedMachineStateDiff =
                            Events
                                [ SetCpu (SetPC 0x03)
                                ]
                    in
                    Expect.equal expectedMachineStateDiff (MachineInstructions.jnz 0x01 0x02 machineState)
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
                            { allZeroMachineState | cpuState = CpuState 0 b c 0 0 0 0 sp 0 allFalseConditionCodes False 0 }

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
        , describe "0xc6 - adi_d8"
            [ test "for zero machine state" <|
                \() ->
                    let
                        expectedMachineStateDiff =
                            Events
                                [ SetCpu (SetRegisterA 0x02)
                                , SetCpu (SetFlag (SetFlagZ False))
                                , SetCpu (SetFlag (SetFlagS False))
                                , SetCpu (SetFlag (SetFlagP False))
                                , SetCpu (SetFlag (SetFlagCY False))
                                , SetCpu (SetFlag (SetFlagAC False))
                                , SetCpu (SetPC 0x02)
                                ]
                    in
                    Expect.equal expectedMachineStateDiff (MachineInstructions.adi_d8 0x02 allZeroMachineState)
            ]
        , describe "0xc8 - rz"
            [ test "for zero machine state" <|
                \() ->
                    let
                        expectedMachineStateDiff =
                            Events
                                [ SetCpu (SetPC 1)
                                ]
                    in
                    Expect.equal expectedMachineStateDiff (MachineInstructions.rz allZeroMachineState)
            , test "for sp=0x01, z=true machine state" <|
                \() ->
                    let
                        sp =
                            0x01

                        z =
                            True

                        machineState =
                            { allZeroMachineState | cpuState = CpuState 0 0 0 0 0 0 0 sp 0 (ConditionCodes z False False False False) False 0, memory = fromList (range 0 0x02) }

                        expectedMachineStateDiff =
                            Events
                                [ SetCpu (SetSP 0x03)
                                , SetCpu (SetPC 0x0201)
                                , SetCpu (AddCycles 6)
                                ]
                    in
                    Expect.equal expectedMachineStateDiff (MachineInstructions.rz machineState)
            ]
        , describe "0xc9 - ret"
            [ test "for zero machine state" <|
                \() ->
                    let
                        machineState =
                            { allZeroMachineState | cpuState = CpuState 0 0 0 0 0 0 0 0 0 allFalseConditionCodes False 0, memory = fromList (range 0 0x01) }

                        expectedMachineStateDiff =
                            Events
                                [ SetCpu (SetSP 0x02)
                                , SetCpu (SetPC 0x0100)
                                ]
                    in
                    Expect.equal expectedMachineStateDiff (MachineInstructions.ret machineState)
            ]
        , describe "0xca - jz"
            [ test "z=0" <|
                \() ->
                    let
                        machineState =
                            { allZeroMachineState | cpuState = CpuState 0 0 0 0 0 0 0 0 0 (ConditionCodes False False False False False) False 0, memory = fromList (range 0 0x01) }

                        expectedMachineStateDiff =
                            Events
                                [ SetCpu (SetPC 3)
                                ]
                    in
                    Expect.equal expectedMachineStateDiff (MachineInstructions.jz 0 0 machineState)
            , test "z=1" <|
                \() ->
                    let
                        machineState =
                            { allZeroMachineState | cpuState = CpuState 0 0 0 0 0 0 0 0 0 (ConditionCodes True False False False False) False 0, memory = fromList (range 0 0x01) }

                        expectedMachineStateDiff =
                            Events
                                [ SetCpu (SetPC 16)
                                ]
                    in
                    Expect.equal expectedMachineStateDiff (MachineInstructions.jz 16 0 machineState)
            ]
        , describe "0xcc - cz"
            [ test "for z=False machine state" <|
                \() ->
                    let
                        machineState =
                            { allZeroMachineState | cpuState = CpuState 0 0 0 0 0 0 0 0 0 allFalseConditionCodes False 0 }

                        expectedMachineStateDiff =
                            Events
                                [ SetCpu (SetPC 3)
                                ]
                    in
                    Expect.equal expectedMachineStateDiff (MachineInstructions.cz 5 0 machineState)
            , test "for z=True, sp=10 machine state" <|
                \() ->
                    let
                        pc =
                            0x0402

                        sp =
                            10

                        z =
                            True

                        machineState =
                            { allZeroMachineState | cpuState = CpuState 0 0 0 0 0 0 0 sp pc (ConditionCodes z False False False False) False 0 }

                        expectedMachineStateDiff =
                            Events
                                [ SetMemory 9 0x04
                                , SetMemory 8 0x05
                                , SetCpu (SetSP 8)
                                , SetCpu (SetPC 5)
                                , SetCpu (AddCycles 6)
                                ]
                    in
                    Expect.equal expectedMachineStateDiff (MachineInstructions.cz 5 0 machineState)
            ]
        , describe "0xcd - call"
            [ test "for sp=0x02 machine state" <|
                \() ->
                    let
                        sp =
                            0x02

                        machineState =
                            { allZeroMachineState | cpuState = CpuState 0 0 0 0 0 0 0 sp 0 allFalseConditionCodes False 0 }

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
        , describe "0xd0 - rnc"
            [ test "for c=True machine state" <|
                \() ->
                    let
                        cy =
                            True

                        machineState =
                            { allZeroMachineState | cpuState = CpuState 0 0 0 0 0 0 0 0 0 (ConditionCodes False False False cy False) False 0 }

                        expectedMachineStateDiff =
                            Events [ SetCpu (SetPC 0x01) ]
                    in
                    Expect.equal expectedMachineStateDiff (MachineInstructions.rnc machineState)
            , test "for c=False machine state" <|
                \() ->
                    let
                        cy =
                            False

                        sp =
                            5

                        machineState =
                            { allZeroMachineState | cpuState = CpuState 0 0 0 0 0 0 0 sp 0 (ConditionCodes False False False cy False) False 0, memory = fromList (range 0 10) }

                        expectedMachineStateDiff =
                            Events
                                [ SetCpu (SetSP 7)
                                , SetCpu (SetPC 0x0605)
                                , SetCpu (AddCycles 6)
                                ]
                    in
                    Expect.equal expectedMachineStateDiff (MachineInstructions.rnc machineState)
            ]
        , describe "0xd1 - pop_d"
            [ test "for zero machine state" <|
                \() ->
                    let
                        machineState =
                            { allZeroMachineState | cpuState = CpuState 0 0 0 0 0 0 0 0 0 allFalseConditionCodes False 0, memory = fromList (range 0 0x01) }

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
        , describe "0xd2 - jnc"
            [ test "for cy=True machine state" <|
                \() ->
                    let
                        cy =
                            True

                        machineState =
                            { allZeroMachineState | cpuState = CpuState 0 0 0 0 0 0 0 0 0 (ConditionCodes False False False cy False) False 0 }

                        expectedMachineStateDiff =
                            Events [ SetCpu (SetPC 0x03) ]
                    in
                    Expect.equal expectedMachineStateDiff (MachineInstructions.jnc 0x04 0x17 machineState)
            , test "for cy=False machine state" <|
                \() ->
                    let
                        cy =
                            False

                        machineState =
                            { allZeroMachineState | cpuState = CpuState 0 0 0 0 0 0 0 0 0 (ConditionCodes False False False cy False) False 0 }

                        expectedMachineStateDiff =
                            Events [ SetCpu (SetPC 0x1704) ]
                    in
                    Expect.equal expectedMachineStateDiff (MachineInstructions.jnc 0x04 0x17 machineState)
            ]
        , describe "0xd4 - cnc"
            [ test "for pc=10, sp=10 machine state" <|
                \() ->
                    let
                        pc =
                            10

                        sp =
                            10

                        machineState =
                            { allZeroMachineState | cpuState = CpuState 0 0 0 0 0 0 0 sp pc allFalseConditionCodes False 0 }

                        expectedMachineStateDiff =
                            Events
                                [ SetMemory 9 0
                                , SetMemory 8 13
                                , SetCpu (SetSP 8)
                                , SetCpu (SetPC 0x0A01)
                                , SetCpu (AddCycles 6)
                                ]
                    in
                    Expect.equal expectedMachineStateDiff (MachineInstructions.cnc 0x01 0x0A machineState)
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
                            { allZeroMachineState | cpuState = CpuState 0 0 0 d e 0 0 sp 0 allFalseConditionCodes False 0, memory = fromList (range 0 0x01) }

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
        , describe "0xd8 - rc"
            [ test "cy=0" <|
                \() ->
                    let
                        machineState =
                            { allZeroMachineState | cpuState = CpuState 0 0 0 0 0 0 0 0 0 (ConditionCodes False False False False False) False 0, memory = fromList (range 0 0x01) }

                        expectedMachineStateDiff =
                            Events
                                [ SetCpu (SetPC 1)
                                ]
                    in
                    Expect.equal expectedMachineStateDiff (MachineInstructions.rc machineState)
            , test "cy=1" <|
                \() ->
                    let
                        machineState =
                            { allZeroMachineState | cpuState = CpuState 0 0 0 0 0 0 0 5 0 (ConditionCodes False False False True False) False 0, memory = fromList (range 0 0x10) }

                        expectedMachineStateDiff =
                            Events
                                [ SetCpu (SetSP 7)
                                , SetCpu (SetPC 0x0605)
                                , SetCpu (AddCycles 6)
                                ]
                    in
                    Expect.equal expectedMachineStateDiff (MachineInstructions.rc machineState)
            ]
        , describe "0xda - jc"
            [ test "cy=0" <|
                \() ->
                    let
                        machineState =
                            { allZeroMachineState | cpuState = CpuState 0 0 0 0 0 0 0 0 0 (ConditionCodes False False False False False) False 0, memory = fromList (range 0 0x01) }

                        expectedMachineStateDiff =
                            Events
                                [ SetCpu (SetPC 3)
                                ]
                    in
                    Expect.equal expectedMachineStateDiff (MachineInstructions.jc 0 0 machineState)
            , test "cy=1" <|
                \() ->
                    let
                        machineState =
                            { allZeroMachineState | cpuState = CpuState 0 0 0 0 0 0 0 0 0 (ConditionCodes False False False True False) False 0, memory = fromList (range 0 0x01) }

                        expectedMachineStateDiff =
                            Events
                                [ SetCpu (SetPC 16)
                                ]
                    in
                    Expect.equal expectedMachineStateDiff (MachineInstructions.jc 16 0 machineState)
            ]
        , describe "0xe1 - pop_h"
            [ test "for zero machine state" <|
                \() ->
                    let
                        machineState =
                            { allZeroMachineState | cpuState = CpuState 0 0 0 0 0 0 0 0 0 allFalseConditionCodes False 0, memory = fromList (range 0 0x01) }

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
                            { allZeroMachineState | cpuState = CpuState 0 0 0 0 0 h l sp 0 allFalseConditionCodes False 0, memory = fromList (range 0 5) }

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
                            { allZeroMachineState | cpuState = CpuState 0 0 0 0 0 h l sp 0 allFalseConditionCodes False 0, memory = fromList (range 0 0x01) }

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
        , describe "0xe6 - ani"
            [ test "for a=0x01 machine state" <|
                \() ->
                    let
                        a =
                            0x01

                        machineState =
                            { allZeroMachineState | cpuState = CpuState a 0 0 0 0 0 0 0 0 allFalseConditionCodes False 0 }

                        expectedMachineStateDiff =
                            Events
                                [ SetCpu (SetRegisterA 0x01)
                                , SetCpu (SetPC 0x02)
                                , SetCpu (SetFlag (SetFlagCY False))
                                , SetCpu (SetFlag (SetFlagAC False))
                                , SetCpu (SetFlag (SetFlagZ False))
                                , SetCpu (SetFlag (SetFlagS False))
                                , SetCpu (SetFlag (SetFlagP False))
                                ]
                    in
                    Expect.equal expectedMachineStateDiff (MachineInstructions.ani 0x01 machineState)
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
                            { allZeroMachineState | cpuState = CpuState 0 0 0 0 0 h l 0 0 allFalseConditionCodes False 0 }

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
                            { allZeroMachineState | cpuState = CpuState 0 0 0 0 0 0 0 0 0 allFalseConditionCodes False 0, memory = fromList [ 2, 10 ] }

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
                            { allZeroMachineState | cpuState = CpuState 0 0 0 0 0 0 0 0 0 allFalseConditionCodes False 0, memory = fromList [ 66, 10 ] }

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
        , describe "0xf6 - ori_d8"
            [ test "for a=0, in 10 machine state" <|
                \() ->
                    let
                        a =
                            0

                        machineState =
                            { allZeroMachineState | cpuState = CpuState a 0 0 0 0 0 0 0 0 allFalseConditionCodes False 0 }

                        expectedMachineStateDiff =
                            Events
                                [ SetCpu (SetRegisterA 10)
                                , SetCpu (SetPC 2)
                                , SetCpu (SetFlag (SetFlagCY False))
                                , SetCpu (SetFlag (SetFlagAC False))
                                , SetCpu (SetFlag (SetFlagZ False))
                                , SetCpu (SetFlag (SetFlagS False))
                                , SetCpu (SetFlag (SetFlagP True))
                                ]
                    in
                    Expect.equal expectedMachineStateDiff (MachineInstructions.ori_d8 10 machineState)
            , test "for a=0, in 0 machine state" <|
                \() ->
                    let
                        a =
                            0

                        machineState =
                            { allZeroMachineState | cpuState = CpuState a 0 0 0 0 0 0 0 0 allFalseConditionCodes False 0 }

                        expectedMachineStateDiff =
                            Events
                                [ SetCpu (SetRegisterA 0)
                                , SetCpu (SetPC 2)
                                , SetCpu (SetFlag (SetFlagCY False))
                                , SetCpu (SetFlag (SetFlagAC False))
                                , SetCpu (SetFlag (SetFlagZ True))
                                , SetCpu (SetFlag (SetFlagS False))
                                , SetCpu (SetFlag (SetFlagP True))
                                ]
                    in
                    Expect.equal expectedMachineStateDiff (MachineInstructions.ori_d8 0 machineState)
            ]
        ]
