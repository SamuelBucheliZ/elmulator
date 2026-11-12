module CpmRomTest exposing (all)

{-| The Intel 8080 CPU test ROMs that are quick to run (see tests/roms/README.md).
TST8080 and 8080PRE finish in about a thousand instructions. The bigger CPUTEST and
8080 exerciser programs are in tests-slow/.
-}

import CpmShim exposing (hexToBytes, runCpm)
import Expect
import RomData
import Test exposing (..)


all : Test
all =
    describe "CP/M test ROMs"
        [ test "TST8080.COM reports CPU IS OPERATIONAL after 651 instructions and 4924 cycles" <|
            \() ->
                runCpm 100000 (RomData.tst8080 |> hexToBytes)
                    |> Result.map (\outcome -> ( outcome.instructions, outcome.cycles, String.contains "CPU IS OPERATIONAL" outcome.output ))
                    |> Expect.equal (Ok ( 651, 4924, True ))
        , test "8080PRE.COM completes its preliminary tests after 1061 instructions and 7817 cycles" <|
            \() ->
                runCpm 100000 (RomData.prelim8080 |> hexToBytes)
                    |> Result.map (\outcome -> ( outcome.instructions, outcome.cycles, String.contains "8080 Preliminary tests complete" outcome.output ))
                    |> Expect.equal (Ok ( 1061, 7817, True ))
        ]
