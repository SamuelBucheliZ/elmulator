module CpmShim exposing (Outcome, hexToBytes, runCpm)

{-| Runs CP/M programs (the Intel 8080 CPU test ROMs) on the emulator, the same way
the reference runner in superzazu/8080 does:

  - the program is loaded at 0x0100 and started there
  - `CALL 5` is the BDOS entry point: C=2 prints the character in E, C=9 prints the `$`
    terminated string at DE
  - `JMP 0` (the injected `OUT 0`) ends the test, and its cycles are counted like the reference

-}

import Array exposing (Array)
import Char
import Cpu
import EmulatorState exposing (EmulatorState(..), MachineState)


type alias Outcome =
    { output : String
    , instructions : Int
    , cycles : Int
    , exited : Bool
    }


{-| Runs a .COM program with the CP/M shim, for at most `maxInstructions` instructions.
A program that exits returns `exited = True`; one that is still running after
`maxInstructions` returns its output so far with `exited = False`. Unimplemented
opcodes are returned as `Err`.
-}
runCpm : Int -> List Int -> Result String Outcome
runCpm maxInstructions program =
    case Cpu.init (List.repeat 256 0 ++ program) of
        Valid initial ->
            let
                cpu =
                    initial.cpuState

                memory =
                    initial.memory
                        |> Array.set 0 0xD3
                        |> Array.set 1 0x00
                        |> Array.set 5 0xD3
                        |> Array.set 6 0x01
                        |> Array.set 7 0xC9
            in
            cpmSteps maxInstructions 0 [] { initial | memory = memory, cpuState = { cpu | pc = 0x0100, sp = 0 } }

        Invalid _ message ->
            Err message


cpmSteps : Int -> Int -> List Char -> MachineState -> Result String Outcome
cpmSteps maxInstructions count output machineState =
    if count >= maxInstructions then
        Ok
            { output = String.fromList (List.reverse output)
            , instructions = count
            , cycles = machineState.cpuState.cycleCount
            , exited = False
            }

    else if machineState.cpuState.pc == 0 then
        -- the injected OUT 0 ends the test; it is executed so that its cycles are counted
        case Cpu.oneStep machineState of
            Valid done ->
                Ok
                    { output = String.fromList (List.reverse output)
                    , instructions = count + 1
                    , cycles = done.cpuState.cycleCount
                    , exited = True
                    }

            Invalid _ message ->
                Err message

    else
        let
            output_ =
                if machineState.cpuState.pc == 5 then
                    bdos output machineState

                else
                    output
        in
        case Cpu.oneStep machineState of
            Valid next ->
                cpmSteps maxInstructions (count + 1) output_ next

            Invalid _ message ->
                Err ("after " ++ String.fromInt count ++ " instructions at pc " ++ String.fromInt machineState.cpuState.pc ++ ": " ++ message)


bdos : List Char -> MachineState -> List Char
bdos output machineState =
    let
        cpu =
            machineState.cpuState
    in
    if cpu.c == 2 then
        Char.fromCode cpu.e :: output

    else if cpu.c == 9 then
        printString (cpu.d * 256 + cpu.e) output machineState.memory

    else
        output


printString : Int -> List Char -> Array Int -> List Char
printString address output memory =
    case Array.get (modBy 0x00010000 address) memory of
        Just 36 ->
            -- '$'
            output

        Just byte ->
            printString (address + 1) (Char.fromCode byte :: output) memory

        Nothing ->
            output


{-| Decodes a string of hex digit pairs, e.g. "3e01" to [0x3E, 0x01].
-}
hexToBytes : String -> List Int
hexToBytes hex =
    pairs (String.toList hex)
        |> List.map (\( high, low ) -> digitValue high * 16 + digitValue low)


pairs : List Char -> List ( Char, Char )
pairs chars =
    pairsHelp chars []


{-| Tail recursive, so that long ROMs (CPUTEST is 19 KB) do not overflow the stack.
-}
pairsHelp : List Char -> List ( Char, Char ) -> List ( Char, Char )
pairsHelp chars acc =
    case chars of
        high :: low :: rest ->
            pairsHelp rest (( high, low ) :: acc)

        _ ->
            List.reverse acc


digitValue : Char -> Int
digitValue c =
    if Char.isDigit c then
        Char.toCode c - Char.toCode '0'

    else
        Char.toCode (Char.toLower c) - Char.toCode 'a' + 10
