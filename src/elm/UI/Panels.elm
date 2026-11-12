module UI.Panels exposing (codePanel, cpuPanel, portsPanel, stackPanel)

{-| The panels that show the state of the emulated machine.
-}

import Array
import EmulatorState exposing (AddressValue, ByteValue, MachineState, Memory)
import Hex
import Html exposing (Html, div, small, span, table, tbody, td, text, tr)
import Html.Attributes exposing (class, style)
import OpCode
import OpCodeTable


{-| The CPU: registers, flags, and the status of the emulation.
-}
cpuPanel : { paused : Bool, speed : String, measured : String } -> MachineState -> Html msg
cpuPanel status machineState =
    let
        cpu =
            machineState.cpuState
    in
    div []
        [ div [ class "mb-2" ]
            [ statusBadge status.paused
            , span [ class "small text-muted ml-2" ] [ text ("speed " ++ status.speed ++ ", " ++ status.measured) ]
            ]
        , div [ class "d-flex flex-wrap" ]
            [ registerBox "A" cpu.a
            , registerBox "B" cpu.b
            , registerBox "C" cpu.c
            , registerBox "D" cpu.d
            , registerBox "E" cpu.e
            , registerBox "H" cpu.h
            , registerBox "L" cpu.l
            , wordBox "SP" cpu.sp
            , wordBox "PC" cpu.pc
            ]
        , div [ class "mb-2" ]
            [ flagBadge "S" cpu.conditionCodes.s
            , flagBadge "Z" cpu.conditionCodes.z
            , flagBadge "AC" cpu.conditionCodes.ac
            , flagBadge "P" cpu.conditionCodes.p
            , flagBadge "CY" cpu.conditionCodes.cy
            , span [ class "ml-2" ] [ flagBadge "interrupts" cpu.intEnable ]
            ]
        , small [ class "text-muted text-monospace" ]
            [ text ("instructions " ++ String.fromInt machineState.step ++ "   cycles " ++ String.fromInt cpu.cycleCount) ]
        ]


statusBadge : Bool -> Html msg
statusBadge paused =
    if paused then
        span [ class "badge badge-warning" ] [ text "paused" ]

    else
        span [ class "badge badge-success" ] [ text "running" ]


registerBox : String -> ByteValue -> Html msg
registerBox name value =
    div [ class "border rounded text-center px-2 py-1 mb-2 mr-2", style "min-width" "64px" ]
        [ small [ class "text-muted" ] [ text name ]
        , div [ class "text-monospace font-weight-bold" ] [ text (Hex.padX2 value) ]
        , small [ class "text-muted text-monospace" ] [ text (String.fromInt value) ]
        ]


wordBox : String -> AddressValue -> Html msg
wordBox name value =
    div [ class "border rounded text-center px-2 py-1 mb-2 mr-2", style "min-width" "88px" ]
        [ small [ class "text-muted" ] [ text name ]
        , div [ class "text-monospace font-weight-bold" ] [ text (Hex.padX4 value) ]
        , small [ class "text-muted text-monospace" ] [ text (String.fromInt value) ]
        ]


flagBadge : String -> Bool -> Html msg
flagBadge name on =
    span
        [ class
            ("badge mr-1 "
                ++ (if on then
                        "badge-primary"

                    else
                        "badge-light border text-muted"
                   )
            )
        ]
        [ text name ]


{-| The two input ports as bit rows, and the shift register.
-}
portsPanel : MachineState -> Html msg
portsPanel machineState =
    div []
        [ portRow "port 1" machineState.ports.one portOneNames
        , portRow "port 2" machineState.ports.two (List.repeat 8 "")
        , small [ class "text-muted text-monospace" ]
            [ text
                ("shift register "
                    ++ Hex.padX2 machineState.shiftRegister.upper
                    ++ Hex.padX2 machineState.shiftRegister.lower
                    ++ " offset "
                    ++ String.fromInt machineState.shiftRegister.offset
                )
            ]
        ]


portOneNames : List String
portOneNames =
    [ "coin", "2P", "1P", "", "fire", "left", "right", "" ]


portRow : String -> ByteValue -> List String -> Html msg
portRow name value labels =
    div [ class "mb-2" ]
        [ small [ class "text-muted d-block" ] [ text (name ++ "  " ++ Hex.padX2 value) ]
        , div [ class "d-flex" ]
            (List.indexedMap (\bit label -> bitCell bit label value) labels)
        ]


bitCell : Int -> String -> ByteValue -> Html msg
bitCell bit label value =
    let
        on =
            modBy 2 (value // (2 ^ (7 - bit))) == 1
    in
    div [ class "text-center mr-1", style "width" "2.6em" ]
        [ div
            [ class
                ("border rounded small py-1 "
                    ++ (if on then
                            "bg-primary text-white"

                        else
                            "text-muted"
                       )
                )
            ]
            [ text
                (if on then
                    "1"

                 else
                    "0"
                )
            ]
        , small [ class "text-muted" ] [ text label ]
        ]


{-| The top of the stack: the words at SP and above.
-}
stackPanel : MachineState -> Html msg
stackPanel machineState =
    let
        sp =
            machineState.cpuState.sp
    in
    table [ class "table table-sm table-borderless text-monospace small mb-0" ]
        [ tbody []
            (List.map
                (\offset ->
                    let
                        address =
                            modBy 0x00010000 (sp + offset)
                    in
                    tr []
                        [ td [ class "text-muted pr-3" ]
                            [ text
                                ((if offset == 0 then
                                    "SP "

                                  else
                                    "   "
                                 )
                                    ++ Hex.padX4 address
                                )
                            ]
                        , td [] [ text (Hex.padX4 (wordAt machineState.memory address)) ]
                        ]
                )
                [ 0, 2, 4, 6 ]
            )
        ]


wordAt : Memory -> AddressValue -> AddressValue
wordAt memory address =
    let
        byte a =
            Array.get (modBy 0x00010000 a) memory |> Maybe.withDefault 0
    in
    byte address + 256 * byte (address + 1)


{-| The instructions at the program counter, decoded from the current memory.
-}
codePanel : MachineState -> Html msg
codePanel machineState =
    let
        pc =
            machineState.cpuState.pc
    in
    table [ class "table table-sm table-borderless text-monospace small mb-0" ]
        [ tbody []
            (List.indexedMap (codeRow pc) (instructionsAt machineState.memory pc 10))
        ]


codeRow : AddressValue -> Int -> Instruction -> Html msg
codeRow pc index instruction =
    tr
        [ class
            (if index == 0 then
                "table-primary"

             else
                ""
            )
        ]
        [ td [ class "pr-2" ]
            [ text
                (if instruction.address == pc then
                    "▶ "

                 else
                    "  "
                )
            , text (Hex.padX4 instruction.address)
            ]
        , td [ class "text-muted pr-3" ] [ text (String.join " " (List.map Hex.pad2 instruction.bytes)) ]
        , td [] [ text (operandText instruction) ]
        ]


type alias Instruction =
    { address : AddressValue
    , bytes : List ByteValue
    , name : String
    }


instructionsAt : Memory -> AddressValue -> Int -> List Instruction
instructionsAt memory start count =
    let
        byte a =
            Array.get (modBy 0x00010000 a) memory |> Maybe.withDefault 0
    in
    if count <= 0 then
        []

    else
        case OpCodeTable.getOpCodeFromTable (byte start) of
            Just opCode ->
                let
                    length =
                        OpCode.getOpCodeLength opCode
                in
                { address = start
                , bytes = List.map (\i -> byte (start + i)) (List.range 0 (length - 1))
                , name = OpCode.getName opCode
                }
                    :: instructionsAt memory (modBy 0x00010000 (start + length)) (count - 1)

            Nothing ->
                []


{-| The mnemonic with its operand filled in: "JNZ adr" with bytes C2 34 12 is "JNZ 0x1234".
-}
operandText : Instruction -> String
operandText instruction =
    case instruction.bytes of
        [ _, low, high ] ->
            instruction.name
                |> String.replace "adr" (Hex.padX4 (low + 256 * high))
                |> String.replace "D16" (Hex.padX4 (low + 256 * high))

        [ _, value ] ->
            String.replace "D8" (Hex.padX2 value) instruction.name

        _ ->
            instruction.name
