module Instruction exposing (DisassembledProgram, Instruction, instructionToString)

import EmulatorState exposing (AddressValue, ByteValue)
import Hex
import OpCode exposing (OpCode)


type alias Instruction =
    { address : AddressValue
    , opCode : OpCode
    , payload : List ByteValue
    }


type alias DisassembledProgram =
    List Instruction


instructionToString : Instruction -> String
instructionToString instruction =
    let
        address =
            Hex.padX4 instruction.address

        payloadHex =
            List.map Hex.pad2 instruction.payload

        payload =
            String.padLeft 8 ' ' (String.join " " payloadHex)

        instructionName =
            OpCode.getName instruction.opCode
    in
    address ++ ": " ++ payload ++ " -- " ++ instructionName
