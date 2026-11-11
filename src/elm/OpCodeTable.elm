module OpCodeTable exposing (getOpCodeFromTable)

import Bitwise
import Dict exposing (Dict)
import EmulatorState exposing (ByteValue, MachineState, MachineStateDiff(..))
import IO
import MachineInstructions exposing (..)
import OpCode exposing (OpCode, OpCodeData, OpCodeSpec(..))


unknownInstruction : MachineState -> MachineStateDiff
unknownInstruction cpuState =
    Failed (Just cpuState) "unknown instruction"


explicitOpCodes : Dict Int OpCodeData
explicitOpCodes =
    Dict.fromList
        [ ( 0x00, OpCodeData "NOP" 4 (OneByte MachineInstructions.nop) )
        , ( 0x01, OpCodeData "LXI B,D16" 10 (ThreeBytes MachineInstructions.lxi_b_d16) )
        , ( 0x02, OpCodeData "STAX B" 7 (OneByte MachineInstructions.stax_b) )
        , ( 0x03, OpCodeData "INX B" 5 (OneByte MachineInstructions.inx_b) )
        , ( 0x04, OpCodeData "INR B" 5 (OneByte MachineInstructions.inr_b) )
        , ( 0x05, OpCodeData "DCR B" 5 (OneByte MachineInstructions.dcr_b) )
        , ( 0x06, OpCodeData "MVI B, D8" 7 (TwoBytes MachineInstructions.mvi_b_d8) )
        , ( 0x07, OpCodeData "RLC" 4 (OneByte MachineInstructions.rlc) )
        , ( 0x08, OpCodeData "-" 0 (OneByte unknownInstruction) )
        , ( 0x09, OpCodeData "DAD B" 10 (OneByte MachineInstructions.dad_b) )
        , ( 0x0A, OpCodeData "LDAX B" 7 (OneByte MachineInstructions.ldax_b) )
        , ( 0x0B, OpCodeData "DCX B" 5 (OneByte MachineInstructions.dcx_b) )
        , ( 0x0D, OpCodeData "DCR C" 5 (OneByte MachineInstructions.dcr_c) )
        , ( 0x0E, OpCodeData "MVI C,D8" 7 (TwoBytes MachineInstructions.mvi_c_d8) )
        , ( 0x0F, OpCodeData "RRC" 4 (OneByte MachineInstructions.rrc) )
        , ( 0x10, OpCodeData "-" 0 (OneByte unknownInstruction) )
        , ( 0x11, OpCodeData "LXI D,D16" 10 (ThreeBytes MachineInstructions.lxi_d_d16) )
        , ( 0x12, OpCodeData "STAX D" 7 (OneByte MachineInstructions.stax_d) )
        , ( 0x13, OpCodeData "INX D" 5 (OneByte MachineInstructions.inx_d) )
        , ( 0x16, OpCodeData "MVI D, D8" 7 (TwoBytes MachineInstructions.mvi_d_d8) )
        , ( 0x18, OpCodeData "-" 0 (OneByte unknownInstruction) )
        , ( 0x19, OpCodeData "DAD D" 10 (OneByte MachineInstructions.dad_d) )
        , ( 0x1A, OpCodeData "LDAX D" 7 (OneByte MachineInstructions.ldax_d) )
        , ( 0x1F, OpCodeData "RAR" 4 (OneByte MachineInstructions.rar) )
        , ( 0x21, OpCodeData "LXI H,D16" 10 (ThreeBytes MachineInstructions.lxi_h_d16) )
        , ( 0x22, OpCodeData "SHLD adr" 16 (ThreeBytes MachineInstructions.shld_d16) )
        , ( 0x23, OpCodeData "INX H" 5 (OneByte MachineInstructions.inx_h) )
        , ( 0x26, OpCodeData "MVI H,D8" 7 (TwoBytes MachineInstructions.mvi_h_d8) )
        , ( 0x27, OpCodeData "DAA" 4 (OneByte MachineInstructions.daa) )
        , ( 0x28, OpCodeData "-" 0 (OneByte unknownInstruction) )
        , ( 0x29, OpCodeData "DAD H" 10 (OneByte MachineInstructions.dad_h) )
        , ( 0x2A, OpCodeData "LHLD adr" 16 (ThreeBytes MachineInstructions.lhld) )
        , ( 0x2B, OpCodeData "DCX H" 5 (OneByte MachineInstructions.dcx_h) )
        , ( 0x2E, OpCodeData "MVI L, D8" 7 (TwoBytes MachineInstructions.mvi_l_d8) )
        , ( 0x31, OpCodeData "LXI SP, D16" 10 (ThreeBytes MachineInstructions.lxi_sp_d16) )
        , ( 0x32, OpCodeData "STA adr" 13 (ThreeBytes MachineInstructions.sta) )
        , ( 0x35, OpCodeData "DCR M" 10 (OneByte MachineInstructions.dcr_m) )
        , ( 0x36, OpCodeData "MVI M,D8" 10 (TwoBytes MachineInstructions.mvi_m_d8) )
        , ( 0x37, OpCodeData "STC" 4 (OneByte MachineInstructions.stc) )
        , ( 0x38, OpCodeData "-" 0 (OneByte unknownInstruction) )
        , ( 0x3A, OpCodeData "LDA adr" 13 (ThreeBytes MachineInstructions.lda) )
        , ( 0x3C, OpCodeData "INR A" 5 (OneByte MachineInstructions.inr_a) )
        , ( 0x3D, OpCodeData "DCR A" 5 (OneByte MachineInstructions.dcr_a) )
        , ( 0x3E, OpCodeData "MVI A,D8" 7 (TwoBytes MachineInstructions.mvi_a_d8) )
        , ( 0x46, OpCodeData "MOV B,M" 7 (OneByte MachineInstructions.mov_b_m) )
        , ( 0x47, OpCodeData "MOV B,A" 5 (OneByte MachineInstructions.mov_b_a) )
        , ( 0x4E, OpCodeData "MOV C,M" 7 (OneByte MachineInstructions.mov_c_m) )
        , ( 0x4F, OpCodeData "MOV C,A" 5 (OneByte MachineInstructions.mov_c_a) )
        , ( 0x56, OpCodeData "MOV D,M" 7 (OneByte MachineInstructions.mov_d_m) )
        , ( 0x57, OpCodeData "MOV D,A" 5 (OneByte MachineInstructions.mov_d_a) )
        , ( 0x5E, OpCodeData "MOV E,M" 7 (OneByte MachineInstructions.mov_e_m) )
        , ( 0x5F, OpCodeData "MOV E,A" 5 (OneByte MachineInstructions.mov_e_a) )
        , ( 0x61, OpCodeData "MOV H,C" 5 (OneByte MachineInstructions.mov_h_c) )
        , ( 0x66, OpCodeData "MOV H,M" 7 (OneByte MachineInstructions.mov_h_m) )
        , ( 0x67, OpCodeData "MOV H,A" 5 (OneByte MachineInstructions.mov_h_a) )
        , ( 0x6F, OpCodeData "MOV L,A" 5 (OneByte MachineInstructions.mov_l_a) )
        , ( 0x70, OpCodeData "MOV M,B" 7 (OneByte MachineInstructions.mov_m_b) )
        , ( 0x77, OpCodeData "MOV M,A" 7 (OneByte MachineInstructions.mov_m_a) )
        , ( 0x78, OpCodeData "MOV A,B" 5 (OneByte MachineInstructions.mov_a_b) )
        , ( 0x79, OpCodeData "MOV A,C" 5 (OneByte MachineInstructions.mov_a_c) )
        , ( 0x7A, OpCodeData "MOV A,D" 5 (OneByte MachineInstructions.mov_a_d) )
        , ( 0x7B, OpCodeData "MOV A,E" 5 (OneByte MachineInstructions.mov_a_e) )
        , ( 0x7C, OpCodeData "MOV A,H" 5 (OneByte MachineInstructions.mov_a_h) )
        , ( 0x7D, OpCodeData "MOV A,L" 5 (OneByte MachineInstructions.mov_a_l) )
        , ( 0x7E, OpCodeData "MOV A,M" 7 (OneByte MachineInstructions.mov_a_m) )
        , ( 0x80, OpCodeData "ADD B" 4 (OneByte MachineInstructions.add_b) )
        , ( 0xA0, OpCodeData "ANA B" 4 (OneByte MachineInstructions.ana_b) )
        , ( 0xA7, OpCodeData "ANA A" 4 (OneByte MachineInstructions.ana_a) )
        , ( 0xA8, OpCodeData "XRA B" 4 (OneByte MachineInstructions.xra_b) )
        , ( 0xAF, OpCodeData "XRA A" 4 (OneByte MachineInstructions.xra_a) )
        , ( 0xB0, OpCodeData "ORA B" 4 (OneByte MachineInstructions.ora_b) )
        , ( 0xB4, OpCodeData "ORA H" 4 (OneByte MachineInstructions.ora_h) )
        , ( 0xB6, OpCodeData "ORA M" 7 (OneByte MachineInstructions.ora_m) )
        , ( 0xC0, OpCodeData "RNZ" 5 (OneByte MachineInstructions.rnz) )
        , ( 0xC1, OpCodeData "POP B" 10 (OneByte MachineInstructions.pop_b) )
        , ( 0xC2, OpCodeData "JNZ adr" 10 (ThreeBytes MachineInstructions.jnz) )
        , ( 0xC3, OpCodeData "JMP adr" 10 (ThreeBytes MachineInstructions.jmp) )
        , ( 0xC4, OpCodeData "CNZ adr" 11 (ThreeBytes MachineInstructions.cnz) )
        , ( 0xC5, OpCodeData "PUSH B" 11 (OneByte MachineInstructions.push_b) )
        , ( 0xC6, OpCodeData "ADI D8" 7 (TwoBytes MachineInstructions.adi_d8) )
        , ( 0xC8, OpCodeData "RZ" 5 (OneByte MachineInstructions.rz) )
        , ( 0xC9, OpCodeData "RET" 10 (OneByte MachineInstructions.ret) )
        , ( 0xCA, OpCodeData "JZ adr" 10 (ThreeBytes MachineInstructions.jz) )
        , ( 0xCB, OpCodeData "-" 0 (OneByte unknownInstruction) )
        , ( 0xCC, OpCodeData "CZ adr" 11 (ThreeBytes MachineInstructions.cz) )
        , ( 0xCD, OpCodeData "CALL adr" 17 (ThreeBytes MachineInstructions.call) )
        , ( 0xD0, OpCodeData "RNC" 5 (OneByte MachineInstructions.rnc) )
        , ( 0xD1, OpCodeData "POP D" 10 (OneByte MachineInstructions.pop_d) )
        , ( 0xD2, OpCodeData "JNC adr" 10 (ThreeBytes MachineInstructions.jnc) )
        , ( 0xD3, OpCodeData "OUT D8" 10 (TwoBytes IO.io_out) )
        , ( 0xD4, OpCodeData "CNC adr" 11 (ThreeBytes MachineInstructions.cnc) )
        , ( 0xD5, OpCodeData "PUSH D" 11 (OneByte MachineInstructions.push_d) )
        , ( 0xD8, OpCodeData "RC" 5 (OneByte MachineInstructions.rc) )
        , ( 0xD9, OpCodeData "-" 0 (OneByte unknownInstruction) )
        , ( 0xDA, OpCodeData "JC adr" 10 (ThreeBytes MachineInstructions.jc) )
        , ( 0xDB, OpCodeData "IN D8" 10 (TwoBytes IO.io_in) )
        , ( 0xDD, OpCodeData "-" 0 (OneByte unknownInstruction) )
        , ( 0xE1, OpCodeData "POP H" 10 (OneByte MachineInstructions.pop_h) )
        , ( 0xE3, OpCodeData "XTHL" 18 (OneByte MachineInstructions.xthl) )
        , ( 0xE5, OpCodeData "PUSH H" 11 (OneByte MachineInstructions.push_h) )
        , ( 0xE6, OpCodeData "ANI D8" 7 (TwoBytes MachineInstructions.ani) )
        , ( 0xE9, OpCodeData "PCHL" 5 (OneByte MachineInstructions.pchl) )
        , ( 0xEB, OpCodeData "XCHG" 4 (OneByte MachineInstructions.xchg) )
        , ( 0xED, OpCodeData "-" 0 (OneByte unknownInstruction) )
        , ( 0xF1, OpCodeData "POP PSW" 10 (OneByte MachineInstructions.pop_psw) )
        , ( 0xF5, OpCodeData "PUSH PSW" 11 (OneByte MachineInstructions.push_psw) )
        , ( 0xF6, OpCodeData "ORI D8" 7 (TwoBytes MachineInstructions.ori_d8) )
        , ( 0xFB, OpCodeData "EI" 4 (OneByte MachineInstructions.ei) )
        , ( 0xFD, OpCodeData "-" 0 (OneByte unknownInstruction) )
        , ( 0xFE, OpCodeData "CPI D8" 7 (TwoBytes MachineInstructions.cpi) )
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
                Just (OpCodeData ("INX " ++ pairName pair) 5 (OneByte (incPair pair)))

            0x0B ->
                Just (OpCodeData ("DCX " ++ pairName pair) 5 (OneByte (decPair pair)))

            0x09 ->
                Just (OpCodeData ("DAD " ++ pairName pair) 10 (OneByte (dadPair pair)))

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
                (OneByte (movRegister row low))
            )

    else if code < 0xC0 then
        Just
            (OpCodeData (aluName aluNames row ++ " " ++ registerName low)
                (if low == 6 then
                    7

                 else
                    4
                )
                (OneByte (aluRegister row low))
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
                incRegister row

            else
                decRegister row
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
        (TwoBytes (mviRegister row))


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
