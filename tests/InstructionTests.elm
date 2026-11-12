module InstructionTests exposing (..)

import EmulatorState exposing (MachineState, MachineStateDiff(..))
import Expect
import Instruction exposing (Instruction)
import OpCode exposing (ImplOneByte, OpCode, OpCodeData, OpCodeSpec)
import Test exposing (..)


all : Test
all =
    describe "Instruction"
        [ describe "instructionToString"
            [ test "for NOP" <|
                \() ->
                    let
                        dummyImpl =
                            \cpuState -> Failed (Just cpuState) "not implemented yet"

                        opCodeSpec =
                            OpCode.OneByte dummyImpl

                        opCodeData =
                            OpCodeData "NOP" 4 opCodeSpec

                        opCode =
                            OpCode 0x00 opCodeData
                    in
                    Instruction 1
                        opCode
                        [ 0x00 ]
                        |> Instruction.instructionToString
                        |> Expect.equal "0x0001:       00 -- NOP"
            , test "for JMP" <|
                \() ->
                    let
                        dummyImpl =
                            \_ -> \_ -> \cpuState -> Failed (Just cpuState) "not implemented yet"

                        opCodeSpec =
                            OpCode.ThreeBytes dummyImpl

                        opCodeData =
                            OpCodeData "JMP" 10 opCodeSpec

                        opCode =
                            OpCode 0xC3 opCodeData
                    in
                    Instruction 0xA1B2
                        opCode
                        [ 0xC3, 0xC4, 0x18 ]
                        |> Instruction.instructionToString
                        |> Expect.equal "0xa1b2: c3 c4 18 -- JMP"
            ]
        ]
