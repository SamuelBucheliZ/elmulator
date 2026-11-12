module OpCodeTable exposing (getOpCodeFromTable)

import Bitwise
import Dict exposing (Dict)
import EmulatorState exposing (ByteValue, MachineState, MachineStateDiff(..))
import IO
import MachineInstructions exposing (..)
import OpCode exposing (OpCode, OpCodeData, OpCodeSpec(..))
import Registers exposing (operandFromCode, pairFromCode)


unknownInstruction : MachineState -> MachineStateDiff
unknownInstruction cpuState =
    Failed (Just cpuState) "unknown instruction"


explicitOpCodes : Dict Int OpCodeData
explicitOpCodes =
    Dict.fromList
        [ ( 0x00, OpCodeData "NOP" 4 (OneByte MachineInstructions.nop) )
        , ( 0x02, OpCodeData "STAX B" 7 (OneByte MachineInstructions.stax_b) )
        , ( 0x07, OpCodeData "RLC" 4 (OneByte MachineInstructions.rlc) )
        , ( 0x08, OpCodeData "-" 0 (OneByte unknownInstruction) )
        , ( 0x0A, OpCodeData "LDAX B" 7 (OneByte MachineInstructions.ldax_b) )
        , ( 0x0F, OpCodeData "RRC" 4 (OneByte MachineInstructions.rrc) )
        , ( 0x10, OpCodeData "-" 0 (OneByte unknownInstruction) )
        , ( 0x12, OpCodeData "STAX D" 7 (OneByte MachineInstructions.stax_d) )
        , ( 0x18, OpCodeData "-" 0 (OneByte unknownInstruction) )
        , ( 0x1A, OpCodeData "LDAX D" 7 (OneByte MachineInstructions.ldax_d) )
        , ( 0x1F, OpCodeData "RAR" 4 (OneByte MachineInstructions.rar) )
        , ( 0x22, OpCodeData "SHLD adr" 16 (ThreeBytes MachineInstructions.shld_d16) )
        , ( 0x27, OpCodeData "DAA" 4 (OneByte MachineInstructions.daa) )
        , ( 0x28, OpCodeData "-" 0 (OneByte unknownInstruction) )
        , ( 0x2A, OpCodeData "LHLD adr" 16 (ThreeBytes MachineInstructions.lhld) )
        , ( 0x32, OpCodeData "STA adr" 13 (ThreeBytes MachineInstructions.sta) )
        , ( 0x37, OpCodeData "STC" 4 (OneByte MachineInstructions.stc) )
        , ( 0x38, OpCodeData "-" 0 (OneByte unknownInstruction) )
        , ( 0x3A, OpCodeData "LDA adr" 13 (ThreeBytes MachineInstructions.lda) )
        , ( 0xC1, OpCodeData "POP B" 10 (OneByte MachineInstructions.pop_b) )
        , ( 0xC3, OpCodeData "JMP adr" 10 (ThreeBytes MachineInstructions.jmp) )
        , ( 0xC5, OpCodeData "PUSH B" 11 (OneByte MachineInstructions.push_b) )
        , ( 0xC9, OpCodeData "RET" 10 (OneByte MachineInstructions.ret) )
        , ( 0xCB, OpCodeData "-" 0 (OneByte unknownInstruction) )
        , ( 0xCD, OpCodeData "CALL adr" 17 (ThreeBytes MachineInstructions.call) )
        , ( 0xD1, OpCodeData "POP D" 10 (OneByte MachineInstructions.pop_d) )
        , ( 0xD3, OpCodeData "OUT D8" 10 (TwoBytes IO.io_out) )
        , ( 0xD5, OpCodeData "PUSH D" 11 (OneByte MachineInstructions.push_d) )
        , ( 0xD9, OpCodeData "-" 0 (OneByte unknownInstruction) )
        , ( 0xDB, OpCodeData "IN D8" 10 (TwoBytes IO.io_in) )
        , ( 0xDD, OpCodeData "-" 0 (OneByte unknownInstruction) )
        , ( 0xE1, OpCodeData "POP H" 10 (OneByte MachineInstructions.pop_h) )
        , ( 0xE3, OpCodeData "XTHL" 18 (OneByte MachineInstructions.xthl) )
        , ( 0xE5, OpCodeData "PUSH H" 11 (OneByte MachineInstructions.push_h) )
        , ( 0xE9, OpCodeData "PCHL" 5 (OneByte MachineInstructions.pchl) )
        , ( 0xEB, OpCodeData "XCHG" 4 (OneByte MachineInstructions.xchg) )
        , ( 0xED, OpCodeData "-" 0 (OneByte unknownInstruction) )
        , ( 0xF1, OpCodeData "POP PSW" 10 (OneByte MachineInstructions.pop_psw) )
        , ( 0xF5, OpCodeData "PUSH PSW" 11 (OneByte MachineInstructions.push_psw) )
        , ( 0xFB, OpCodeData "EI" 4 (OneByte MachineInstructions.ei) )
        , ( 0xFD, OpCodeData "-" 0 (OneByte unknownInstruction) )
        ]


{-| All opcodes. Explicitly listed opcodes win; the rest of the 8080 instruction set
is generated from its instruction families (see `familyOpCode`).
-}
opCodeTable : Dict Int OpCodeData
opCodeTable =
    Dict.union explicitOpCodes (Dict.fromList familyOpCodes)


familyOpCodes : List ( Int, OpCodeData )
familyOpCodes =
    List.filterMap
        (\code -> Maybe.map (\opCodeData -> ( code, opCodeData )) (familyOpCode code))
        (List.range 0x00 0xFF)


registerNames : List String
registerNames =
    [ "B", "C", "D", "E", "H", "L", "M", "A" ]


registerName : Int -> String
registerName index =
    List.drop index registerNames
        |> List.head
        |> Maybe.withDefault "?"


aluNames : List String
aluNames =
    [ "ADD", "ADC", "SUB", "SBB", "ANA", "XRA", "ORA", "CMP" ]


aluImmediateNames : List String
aluImmediateNames =
    [ "ADI", "ACI", "SUI", "SBI", "ANI", "XRI", "ORI", "CPI" ]


conditionNames : List String
conditionNames =
    [ "NZ", "Z", "NC", "C", "PO", "PE", "P", "M" ]


{-| The opcode with the given value if it belongs to an instruction family, with the
cycle counts of the Intel 8080 manual. Conditional calls and returns list the cycles
of the "condition not met" case; the extra cycles of the taken case are added by the
instruction itself.
-}
familyOpCode : Int -> Maybe OpCodeData
familyOpCode code =
    let
        lowNibble =
            Bitwise.and 0x0F code

        -- bits 3-5 of the opcode, the "row" of most families
        row =
            Bitwise.and 0x07 (Bitwise.shiftRightBy 3 code)

        -- bits 4-5, the register pair of INX/DCX/DAD/LXI
        pair =
            Bitwise.and 0x03 (Bitwise.shiftRightBy 4 code)

        -- bits 0-2 of the opcode
        low =
            Bitwise.and 0x07 code
    in
    if code < 0x40 then
        case lowNibble of
            0x03 ->
                Just (OpCodeData ("INX " ++ pairName pair) 5 (OneByte (incPair (pairFromCode pair))))

            0x0B ->
                Just (OpCodeData ("DCX " ++ pairName pair) 5 (OneByte (decPair (pairFromCode pair))))

            0x01 ->
                Just (OpCodeData ("LXI " ++ pairName pair ++ ",D16") 10 (ThreeBytes (lxiPair (pairFromCode pair))))

            0x09 ->
                Just (OpCodeData ("DAD " ++ pairName pair) 10 (OneByte (dadPair (pairFromCode pair))))

            0x04 ->
                Just (incDecOpCode "INR" row)

            0x0C ->
                Just (incDecOpCode "INR" row)

            0x05 ->
                Just (incDecOpCode "DCR" row)

            0x0D ->
                Just (incDecOpCode "DCR" row)

            0x06 ->
                Just (mviOpCode row)

            0x0E ->
                Just (mviOpCode row)

            0x07 ->
                rotateOpCode row

            0x0F ->
                rotateOpCode row

            _ ->
                Nothing

    else if code == 0x76 then
        Just (OpCodeData "HLT" 7 (OneByte hlt))

    else if code < 0x80 then
        Just
            (OpCodeData ("MOV " ++ registerName row ++ "," ++ registerName low)
                (if row == 6 || low == 6 then
                    7

                 else
                    5
                )
                (OneByte (movRegister (operandFromCode row) (operandFromCode low)))
            )

    else if code < 0xC0 then
        Just
            (OpCodeData (aluName aluNames row ++ " " ++ registerName low)
                (if low == 6 then
                    7

                 else
                    4
                )
                (OneByte (aluRegister row (operandFromCode low)))
            )

    else
        case lowNibble of
            0x00 ->
                Just (OpCodeData ("R" ++ conditionName row) 5 (OneByte (rcc row)))

            0x08 ->
                Just (OpCodeData ("R" ++ conditionName row) 5 (OneByte (rcc row)))

            0x02 ->
                Just (OpCodeData ("J" ++ conditionName row ++ " adr") 10 (ThreeBytes (jcc row)))

            0x0A ->
                Just (OpCodeData ("J" ++ conditionName row ++ " adr") 10 (ThreeBytes (jcc row)))

            0x04 ->
                Just (OpCodeData ("C" ++ conditionName row ++ " adr") 11 (ThreeBytes (ccc row)))

            0x0C ->
                Just (OpCodeData ("C" ++ conditionName row ++ " adr") 11 (ThreeBytes (ccc row)))

            0x06 ->
                Just (OpCodeData (aluName aluImmediateNames row ++ " D8") 7 (TwoBytes (aluImmediate row)))

            0x0E ->
                Just (OpCodeData (aluName aluImmediateNames row ++ " D8") 7 (TwoBytes (aluImmediate row)))

            0x07 ->
                Just (OpCodeData ("RST " ++ String.fromInt row) 11 (OneByte (rst row)))

            0x0F ->
                Just (OpCodeData ("RST " ++ String.fromInt row) 11 (OneByte (rst row)))

            0x09 ->
                Just (OpCodeData "SPHL" 5 (OneByte sphl))

            0x03 ->
                Just (OpCodeData "DI" 4 (OneByte di))

            _ ->
                Nothing


pairName : Int -> String
pairName pair =
    case pair of
        0 ->
            "B"

        1 ->
            "D"

        2 ->
            "H"

        _ ->
            "SP"


aluName : List String -> Int -> String
aluName names index =
    List.drop index names
        |> List.head
        |> Maybe.withDefault "?"


conditionName : Int -> String
conditionName index =
    List.drop index conditionNames
        |> List.head
        |> Maybe.withDefault "?"


incDecOpCode : String -> Int -> OpCodeData
incDecOpCode name row =
    let
        implementation =
            if name == "INR" then
                incRegister (operandFromCode row)

            else
                decRegister (operandFromCode row)
    in
    OpCodeData (name ++ " " ++ registerName row)
        (if row == 6 then
            10

         else
            5
        )
        (OneByte implementation)


mviOpCode : Int -> OpCodeData
mviOpCode row =
    OpCodeData ("MVI " ++ registerName row ++ ",D8")
        (if row == 6 then
            10

         else
            7
        )
        (TwoBytes (mviRegister (operandFromCode row)))


rotateOpCode : Int -> Maybe OpCodeData
rotateOpCode row =
    case row of
        2 ->
            Just (OpCodeData "RAL" 4 (OneByte ral))

        5 ->
            Just (OpCodeData "CMA" 4 (OneByte cma))

        7 ->
            Just (OpCodeData "CMC" 4 (OneByte cmc))

        _ ->
            Nothing


getOpCodeFromTable : ByteValue -> Maybe OpCode
getOpCodeFromTable opCodeByte =
    Dict.get opCodeByte opCodeTable
        |> Maybe.map (\metaInfo -> OpCode opCodeByte metaInfo)
