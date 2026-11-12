module PswTests exposing (..)

import Cpu
import EmulatorState exposing (ConditionCodes, MachineStateDiffEvent(..), SetCpuStateEvent(..), SetFlagEvent(..))
import Expect
import Psw
import Test exposing (..)


all : Test
all =
    describe "Psw"
        [ describe "createPsw"
            [ test "default (init)" <|
                \() ->
                    let
                        conditionCodes =
                            Cpu.initConditionCodes
                    in
                    conditionCodes
                        |> Psw.createPSW
                        |> Expect.equal 2
            , test "Flag S" <|
                \() ->
                    let
                        conditionCodes =
                            Cpu.initConditionCodes
                    in
                    { conditionCodes | s = True }
                        |> Psw.createPSW
                        |> Expect.equal 130
            , test "Flag Z" <|
                \() ->
                    let
                        conditionCodes =
                            Cpu.initConditionCodes
                    in
                    { conditionCodes | z = True }
                        |> Psw.createPSW
                        |> Expect.equal 66
            , test "Flag AC" <|
                \() ->
                    let
                        conditionCodes =
                            Cpu.initConditionCodes
                    in
                    { conditionCodes | ac = True }
                        |> Psw.createPSW
                        |> Expect.equal 18
            , test "Flag P" <|
                \() ->
                    let
                        conditionCodes =
                            Cpu.initConditionCodes
                    in
                    { conditionCodes | p = True }
                        |> Psw.createPSW
                        |> Expect.equal 6
            , test "Flag CY" <|
                \() ->
                    let
                        conditionCodes =
                            Cpu.initConditionCodes
                    in
                    { conditionCodes | cy = True }
                        |> Psw.createPSW
                        |> Expect.equal 3
            , test "Flag [S, Z, AC, P, CY]" <|
                \() ->
                    let
                        conditionCodes =
                            Cpu.initConditionCodes
                    in
                    { conditionCodes | s = True, z = True, ac = True, p = True, cy = True }
                        |> Psw.createPSW
                        |> Expect.equal 215
            ]
        , describe "readPSW"
            [ test "Flag []" <|
                \() ->
                    let
                        expectedMachineStateDiffEvents =
                            [ SetCpu (SetFlag (SetFlagZ False))
                            , SetCpu (SetFlag (SetFlagS False))
                            , SetCpu (SetFlag (SetFlagP False))
                            , SetCpu (SetFlag (SetFlagCY False))
                            , SetCpu (SetFlag (SetFlagAC False))
                            ]
                    in
                    Expect.equal expectedMachineStateDiffEvents (Psw.readPSW 2)
            , test "Flag [Z]" <|
                \() ->
                    let
                        expectedMachineStateDiffEvents =
                            [ SetCpu (SetFlag (SetFlagZ True))
                            , SetCpu (SetFlag (SetFlagS False))
                            , SetCpu (SetFlag (SetFlagP False))
                            , SetCpu (SetFlag (SetFlagCY False))
                            , SetCpu (SetFlag (SetFlagAC False))
                            ]
                    in
                    Expect.equal expectedMachineStateDiffEvents (Psw.readPSW 66)
            , test "Flag [S]" <|
                \() ->
                    let
                        expectedMachineStateDiffEvents =
                            [ SetCpu (SetFlag (SetFlagZ False))
                            , SetCpu (SetFlag (SetFlagS True))
                            , SetCpu (SetFlag (SetFlagP False))
                            , SetCpu (SetFlag (SetFlagCY False))
                            , SetCpu (SetFlag (SetFlagAC False))
                            ]
                    in
                    Expect.equal expectedMachineStateDiffEvents (Psw.readPSW 130)
            , test "Flag [P]" <|
                \() ->
                    let
                        expectedMachineStateDiffEvents =
                            [ SetCpu (SetFlag (SetFlagZ False))
                            , SetCpu (SetFlag (SetFlagS False))
                            , SetCpu (SetFlag (SetFlagP True))
                            , SetCpu (SetFlag (SetFlagCY False))
                            , SetCpu (SetFlag (SetFlagAC False))
                            ]
                    in
                    Expect.equal expectedMachineStateDiffEvents (Psw.readPSW 6)
            , test "Flag [CY]" <|
                \() ->
                    let
                        expectedMachineStateDiffEvents =
                            [ SetCpu (SetFlag (SetFlagZ False))
                            , SetCpu (SetFlag (SetFlagS False))
                            , SetCpu (SetFlag (SetFlagP False))
                            , SetCpu (SetFlag (SetFlagCY True))
                            , SetCpu (SetFlag (SetFlagAC False))
                            ]
                    in
                    Expect.equal expectedMachineStateDiffEvents (Psw.readPSW 3)
            , test "Flag [AC]" <|
                \() ->
                    let
                        expectedMachineStateDiffEvents =
                            [ SetCpu (SetFlag (SetFlagZ False))
                            , SetCpu (SetFlag (SetFlagS False))
                            , SetCpu (SetFlag (SetFlagP False))
                            , SetCpu (SetFlag (SetFlagCY False))
                            , SetCpu (SetFlag (SetFlagAC True))
                            ]
                    in
                    Expect.equal expectedMachineStateDiffEvents (Psw.readPSW 18)
            ]
        ]
