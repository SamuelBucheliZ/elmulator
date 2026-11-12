module HexTests exposing (..)

import Expect
import Hex
import Test exposing (..)


all : Test
all =
    describe "Hex"
        [ describe "toString"
            [ test "for 0" <|
                \() ->
                    0
                        |> Hex.toString
                        |> Expect.equal "0"
            , test "for 1" <|
                \() ->
                    1
                        |> Hex.toString
                        |> Expect.equal "1"
            , test "for 2" <|
                \() ->
                    2
                        |> Hex.toString
                        |> Expect.equal "2"
            , test "for 3" <|
                \() ->
                    3
                        |> Hex.toString
                        |> Expect.equal "3"
            , test "for 4" <|
                \() ->
                    4
                        |> Hex.toString
                        |> Expect.equal "4"
            , test "for 5" <|
                \() ->
                    5
                        |> Hex.toString
                        |> Expect.equal "5"
            , test "for 6" <|
                \() ->
                    6
                        |> Hex.toString
                        |> Expect.equal "6"
            , test "for 7" <|
                \() ->
                    7
                        |> Hex.toString
                        |> Expect.equal "7"
            , test "for 8" <|
                \() ->
                    8
                        |> Hex.toString
                        |> Expect.equal "8"
            , test "for 9" <|
                \() ->
                    9
                        |> Hex.toString
                        |> Expect.equal "9"
            , test "for 10" <|
                \() ->
                    10
                        |> Hex.toString
                        |> Expect.equal "a"
            , test "for 11" <|
                \() ->
                    11
                        |> Hex.toString
                        |> Expect.equal "b"
            , test "for 12" <|
                \() ->
                    12
                        |> Hex.toString
                        |> Expect.equal "c"
            , test "for 13" <|
                \() ->
                    13
                        |> Hex.toString
                        |> Expect.equal "d"
            , test "for 14" <|
                \() ->
                    14
                        |> Hex.toString
                        |> Expect.equal "e"
            , test "for 15" <|
                \() ->
                    15
                        |> Hex.toString
                        |> Expect.equal "f"
            , test "for 255" <|
                \() ->
                    255
                        |> Hex.toString
                        |> Expect.equal "ff"
            ]
        , describe "toPaddedString"
            [ test "for 254" <|
                \() ->
                    254
                        |> Hex.toPaddedString 5
                        |> Expect.equal "000fe"
            ]
        ]
