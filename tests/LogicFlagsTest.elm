module LogicFlagsTest exposing (..)

import Expect
import LogicFlags exposing (check_flag_AC, check_flag_CY, flags_ZSP)
import MachineInstructions exposing (logic_flags_a, setFlagAC, setFlagCY, setFlagP, setFlagS, setFlagZ)
import Test exposing (Test, describe, test)


all : Test
all =
    describe "LogicFlags"
        [ describe "logic_flags_a"
            [ test "for newA=0" <|
                \() ->
                    let
                        newA =
                            0

                        expectedMachineStateDiffEvents =
                            [ setFlagCY False
                            , setFlagAC False
                            , setFlagZ True
                            , setFlagS False
                            , setFlagP True
                            ]
                    in
                    Expect.equal (logic_flags_a newA) expectedMachineStateDiffEvents
            , test "for newA=255" <|
                \() ->
                    let
                        newA =
                            255

                        expectedMachineStateDiffEvents =
                            [ setFlagCY False
                            , setFlagAC False
                            , setFlagZ False
                            , setFlagS True
                            , setFlagP True
                            ]
                    in
                    Expect.equal (logic_flags_a newA) expectedMachineStateDiffEvents
            , test "for newA=256" <|
                \() ->
                    let
                        newA =
                            256

                        expectedMachineStateDiffEvents =
                            [ setFlagCY False
                            , setFlagAC False
                            , setFlagZ True
                            , setFlagS False
                            , setFlagP True
                            ]
                    in
                    Expect.equal (logic_flags_a newA) expectedMachineStateDiffEvents
            ]
        , describe "flags_ZSP"
            [ test "0" <|
                \() ->
                    let
                        value =
                            0

                        expectedEvents =
                            [ setFlagZ True
                            , setFlagS False
                            , setFlagP True
                            ]
                    in
                    Expect.equal expectedEvents (flags_ZSP value)
            , test "2" <|
                \() ->
                    let
                        value =
                            2

                        expectedEvents =
                            [ setFlagZ False
                            , setFlagS False
                            , setFlagP False
                            ]
                    in
                    Expect.equal expectedEvents (flags_ZSP value)
            , test "133" <|
                \() ->
                    let
                        value =
                            133

                        expectedEvents =
                            [ setFlagZ False
                            , setFlagS True
                            , setFlagP False
                            ]
                    in
                    Expect.equal expectedEvents (flags_ZSP value)
            ]
        , describe "check_flag_CY"
            [ test "value=255" <|
                \() ->
                    let
                        value =
                            255

                        expectedEvent =
                            setFlagCY False
                    in
                    Expect.equal expectedEvent (check_flag_CY value)
            , test "value=256" <|
                \() ->
                    let
                        value =
                            256

                        expectedEvent =
                            setFlagCY True
                    in
                    Expect.equal expectedEvent (check_flag_CY value)
            ]
        , describe "check_flag_AC"
            [ test "valueOne=10, valueTwo=10" <|
                \() ->
                    let
                        valueOne =
                            10

                        valueTwo =
                            10

                        expectedEvent =
                            setFlagAC True
                    in
                    Expect.equal expectedEvent (check_flag_AC valueOne valueTwo)
            , test "valueOne=1, valueTwo=9" <|
                \() ->
                    let
                        valueOne =
                            1

                        valueTwo =
                            9

                        expectedEvent =
                            setFlagAC False
                    in
                    Expect.equal expectedEvent (check_flag_AC valueOne valueTwo)
            ]
        ]
