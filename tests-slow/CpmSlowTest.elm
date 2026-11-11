module CpmSlowTest exposing (all)

{-| The larger Intel 8080 CPU test programs. They run tens of millions of instructions
(the exerciser billions), which takes minutes to hours, so they are not part of `npm test`:
run them with `npm run test:slow`.
-}

import CpmShim exposing (hexToBytes, runCpm)
import Expect
import RomData
import Test exposing (..)


all : Test
all =
    describe "slow CP/M test ROMs"
        [ test "CPUTEST.COM passes after 33971311 instructions and 255653383 cycles" <|
            \() ->
                runCpm 100000000 (RomData.cputest |> hexToBytes)
                    |> Result.map (\outcome -> ( outcome.instructions, outcome.cycles, String.contains "CPU TESTS OK" outcome.output ))
                    |> Expect.equal (Ok ( 33971311, 255653383, True ))
        , test "8080EXM.COM passes its first instruction groups without an ERROR" <|
            \() ->
                -- a full run takes hours in the emulator; this checks the groups that finish in 400 million instructions
                runCpm 400000000 (RomData.exerciser8080 |> hexToBytes)
                    |> Result.map
                        (\outcome ->
                            ( String.contains "dad <b,d,h,sp>................  PASS!" outcome.output
                            , String.contains "aluop nn......................  PASS!" outcome.output
                            , String.contains "ERROR" outcome.output
                            )
                        )
                    |> Expect.equal (Ok ( True, True, False ))
        ]
