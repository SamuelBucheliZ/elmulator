module ConditionCodesFlagsTest exposing (..)

import ConditionCodesFlags
import Expect
import Test exposing (..)


all : Test
all =
    describe "ConditionCodesFlags"
        [ describe "zFlag"
            [ test "0" <|
                \() ->
                    let
                        zFlag =
                            ConditionCodesFlags.zFlag 0
                    in
                    Expect.equal True zFlag
            , test "1" <|
                \() ->
                    let
                        zFlag =
                            ConditionCodesFlags.zFlag 1
                    in
                    Expect.equal False zFlag
            , test "-1" <|
                \() ->
                    let
                        zFlag =
                            ConditionCodesFlags.zFlag -1
                    in
                    Expect.equal False zFlag
            ]
        , describe "sFlag"
            [ test "128" <|
                \() ->
                    let
                        sFlag =
                            ConditionCodesFlags.sFlag 128
                    in
                    Expect.equal True sFlag
            , test "64" <|
                \() ->
                    let
                        sFlag =
                            ConditionCodesFlags.sFlag 64
                    in
                    Expect.equal False sFlag
            ]
        , describe "pFlag"
            [ test "0" <|
                \() ->
                    let
                        pFlag =
                            ConditionCodesFlags.pFlag 0
                    in
                    Expect.equal True pFlag
            , test "1" <|
                \() ->
                    let
                        pFlag =
                            ConditionCodesFlags.pFlag 1
                    in
                    Expect.equal False pFlag
            , test "14" <|
                \() ->
                    let
                        pFlag =
                            ConditionCodesFlags.pFlag 14
                    in
                    Expect.equal False pFlag
            , test "3 (two bits set is even parity)" <|
                \() ->
                    Expect.equal True (ConditionCodesFlags.pFlag 3)
            , test "7 (three bits set is odd parity)" <|
                \() ->
                    Expect.equal False (ConditionCodesFlags.pFlag 7)
            , test "255 (eight bits set is even parity)" <|
                \() ->
                    Expect.equal True (ConditionCodesFlags.pFlag 255)
            , test "256 only looks at the low 8 bits" <|
                \() ->
                    Expect.equal True (ConditionCodesFlags.pFlag 256)
            ]
        , describe "cyFlagAdd"
            [ test "256" <|
                \() ->
                    let
                        cFlag =
                            ConditionCodesFlags.cyFlag 256
                    in
                    Expect.equal True cFlag
            , test "128" <|
                \() ->
                    let
                        cFlag =
                            ConditionCodesFlags.cyFlag 128
                    in
                    Expect.equal False cFlag
            ]

        --, describe "acFlag"
        --    []
        ]
