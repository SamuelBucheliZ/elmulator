module CpuBehaviourTest exposing (..)

{-| Behavioural tests: execute real opcodes through `Cpu.oneStep` (or the
instruction functions directly) and check the resulting machine state.

Unlike the event based tests in MachineInstructionsTest, these assert on
what the instruction does, so they keep passing when the internal event
list changes. They also document that states are immutable values, which is
what makes step-back/forward possible.

-}

import Array
import Cpu
import EmulatorState exposing (ConditionCodes, CpuState, EmulatorState(..), MachineState, MachineStateDiffEvent(..), Ports, SetPortEvent(..), ShiftRegister)
import Expect
import IO
import LogicFlags
import OpCode
import OpCodeTable
import Test exposing (..)
import UI.Msg exposing (GameKey(..))


noFlags : ConditionCodes
noFlags =
    ConditionCodes False False False False False


baseCpu : CpuState
baseCpu =
    CpuState 0 0 0 0 0 0 0 0 0 noFlags False 0


{-| A machine with the given CPU state and program bytes at address 0.
-}
machineWith : CpuState -> List Int -> MachineState
machineWith cpu program =
    MachineState cpu
        (Array.fromList (program ++ List.repeat (0x00010000 - List.length program) 0))
        (ShiftRegister 0 0 0)
        (Ports 0 0)
        0


{-| Executes one instruction. Errors are reported as a string.
-}
executeOne : MachineState -> Result String MachineState
executeOne machineState =
    case Cpu.oneStep machineState of
        Valid next ->
            Ok next

        Invalid _ message ->
            Err message


{-| Runs the given number of steps, returning the final state.
-}
executeSteps : Int -> MachineState -> Result String MachineState
executeSteps n machineState =
    if n <= 0 then
        Ok machineState

    else
        executeOne machineState
            |> Result.andThen (executeSteps (n - 1))


type alias Snapshot =
    { a : Int
    , pc : Int
    , cy : Bool
    , ac : Bool
    , z : Bool
    , s : Bool
    , p : Bool
    }


snapshot : MachineState -> Snapshot
snapshot machineState =
    let
        cc =
            machineState.cpuState.conditionCodes
    in
    { a = machineState.cpuState.a
    , pc = machineState.cpuState.pc
    , cy = cc.cy
    , ac = cc.ac
    , z = cc.z
    , s = cc.s
    , p = cc.p
    }


{-| Runs one instruction with the given program and projects the result.
-}
runSnapshot : MachineState -> Result String Snapshot
runSnapshot machineState =
    Result.map snapshot (executeOne machineState)


withA : Int -> CpuState
withA value =
    { baseCpu | a = value }


all : Test
all =
    describe "CPU behaviour"
        [ describe "parity and flag helpers"
            [ test "flags_ZSP masks an unwrapped result (0x100 behaves like 0)" <|
                \() ->
                    Expect.equal (LogicFlags.flags_ZSP 0) (LogicFlags.flags_ZSP 0x0100)
            ]
        , describe "ADD / ADI"
            [ test "ADD 0x80 + 0x80 wraps to 0 and sets Z, CY, P" <|
                \() ->
                    let
                        machineState =
                            machineWith { baseCpu | a = 0x80, b = 0x80 } [ 0x80 ]
                    in
                    Expect.equal
                        (Ok { a = 0x00, pc = 1, cy = True, ac = False, z = True, s = False, p = True })
                        (runSnapshot machineState)
            , test "ADI 0xFF + 0x01 wraps to 0 and sets CY and Z" <|
                \() ->
                    let
                        machineState =
                            machineWith (withA 0xFF) [ 0xC6, 0x01 ]
                    in
                    Expect.equal
                        (Ok { a = 0x00, pc = 2, cy = True, ac = True, z = True, s = False, p = True })
                        (runSnapshot machineState)
            ]
        , describe "INR / DCR"
            [ test "INR A on 0xFF wraps to 0 and sets Z (and AC)" <|
                \() ->
                    let
                        machineState =
                            machineWith (withA 0xFF) [ 0x3C ]
                    in
                    Expect.equal
                        (Ok { a = 0x00, pc = 1, cy = False, ac = True, z = True, s = False, p = True })
                        (runSnapshot machineState)
            , test "DCR M on memory 0 wraps to 0xFF in memory" <|
                \() ->
                    let
                        machineState =
                            { baseCpu | h = 0x00, l = 0x05 }
                                |> (\cpu -> machineWith cpu [ 0x35 ])
                                |> (\ms -> { ms | memory = Array.set 5 0 ms.memory })

                        memoryAfter =
                            executeOne machineState
                                |> Result.map (\ms -> Array.get 5 ms.memory)
                    in
                    Expect.equal (Ok (Just 0xFF)) memoryAfter
            ]
        , describe "DAD"
            [ test "DAD B carries out of 16 bits (BC=0xFFFF, HL=0x0001)" <|
                \() ->
                    let
                        cpu =
                            { baseCpu | b = 0xFF, c = 0xFF, h = 0x00, l = 0x01 }

                        result =
                            executeOne (machineWith cpu [ 0x09 ])
                                |> Result.map (\ms -> ( ms.cpuState.h, ms.cpuState.l, ms.cpuState.conditionCodes.cy ))
                    in
                    Expect.equal (Ok ( 0x00, 0x00, True )) result
            , test "DAD B without overflow clears CY" <|
                \() ->
                    let
                        cpu =
                            { baseCpu | b = 0x00, c = 0x10, h = 0x00, l = 0x01 }

                        result =
                            executeOne (machineWith cpu [ 0x09 ])
                                |> Result.map (\ms -> ( ms.cpuState.h, ms.cpuState.l, ms.cpuState.conditionCodes.cy ))
                    in
                    Expect.equal (Ok ( 0x00, 0x11, False )) result
            ]
        , describe "DAA"
            [ test "0x9B becomes 0x01 with carry out (BCD 99 + 2 style)" <|
                \() ->
                    Expect.equal
                        (Ok { a = 0x01, pc = 1, cy = True, ac = True, z = False, s = False, p = False })
                        (runSnapshot (machineWith (withA 0x9B) [ 0x27 ]))
            , test "0xA0 becomes 0x00 with carry out" <|
                \() ->
                    Expect.equal
                        (Ok { a = 0x00, pc = 1, cy = True, ac = False, z = True, s = False, p = True })
                        (runSnapshot (machineWith (withA 0xA0) [ 0x27 ]))
            , test "0x0A becomes 0x10 (low nibble adjusted, no carry)" <|
                \() ->
                    Expect.equal
                        (Ok { a = 0x10, pc = 1, cy = False, ac = True, z = False, s = False, p = False })
                        (runSnapshot (machineWith (withA 0x0A) [ 0x27 ]))
            , test "valid BCD value 0x12 is unchanged, but flags are still updated" <|
                \() ->
                    Expect.equal
                        (Ok { a = 0x12, pc = 1, cy = False, ac = False, z = False, s = False, p = True })
                        (runSnapshot (machineWith (withA 0x12) [ 0x27 ]))
            ]
        , describe "CMP / CPI"
            [ test "CPI 0x01 with A=0x10 has no borrow out of bit 3 (AC clear) and no carry" <|
                \() ->
                    Expect.equal
                        (Ok { a = 0x10, pc = 2, cy = False, ac = False, z = False, s = False, p = True })
                        (runSnapshot (machineWith (withA 0x10) [ 0xFE, 0x01 ]))
            , test "CPI 0x01 with A=0x12 sets AC" <|
                \() ->
                    Expect.equal
                        (Ok { a = 0x12, pc = 2, cy = False, ac = True, z = False, s = False, p = True })
                        (runSnapshot (machineWith (withA 0x12) [ 0xFE, 0x01 ]))
            , test "CPI 0x01 with A=0x00 borrows: CY and S set, A unchanged" <|
                \() ->
                    Expect.equal
                        (Ok { a = 0x00, pc = 2, cy = True, ac = False, z = False, s = True, p = True })
                        (runSnapshot (machineWith (withA 0x00) [ 0xFE, 0x01 ]))
            ]
        , describe "logical operations"
            [ test "ANA sets AC to the OR of bit 3 of both operands" <|
                \() ->
                    let
                        cpu =
                            { baseCpu | a = 0x08, b = 0x00 }
                    in
                    Expect.equal
                        (Ok { a = 0x00, pc = 1, cy = False, ac = True, z = True, s = False, p = True })
                        (runSnapshot (machineWith cpu [ 0xA0 ]))
            , test "ANI sets AC from bit 3 and clears CY" <|
                \() ->
                    Expect.equal
                        (Ok { a = 0x04, pc = 2, cy = False, ac = True, z = False, s = False, p = False })
                        (runSnapshot (machineWith (withA 0x0C) [ 0xE6, 0x04 ]))
            , test "ORA of 3 leaves P set (two 1-bits is even parity)" <|
                \() ->
                    let
                        cpu =
                            { baseCpu | a = 0x03, b = 0x00 }
                    in
                    Expect.equal
                        (Ok { a = 0x03, pc = 1, cy = False, ac = False, z = False, s = False, p = True })
                        (runSnapshot (machineWith cpu [ 0xB0 ]))
            ]
        , describe "interrupts"
            [ test "accepting an interrupt pushes PC, jumps to RST 2 and disables interrupts" <|
                \() ->
                    let
                        cpu =
                            { baseCpu | pc = 0x0123, sp = 0x2400, intEnable = True }

                        result =
                            case Cpu.interrupt (machineWith cpu []) of
                                Valid ms ->
                                    Ok
                                        { pc = ms.cpuState.pc
                                        , intEnable = ms.cpuState.intEnable
                                        , sp = ms.cpuState.sp
                                        , pushedHigh = Array.get 0x23FF ms.memory
                                        , pushedLow = Array.get 0x23FE ms.memory
                                        }

                                Invalid _ message ->
                                    Err message
                    in
                    Expect.equal
                        (Ok { pc = 0x10, intEnable = False, sp = 0x23FE, pushedHigh = Just 0x01, pushedLow = Just 0x23 })
                        result
            ]
        , describe "ports and IO"
            [ test "SetTwo writes port two (not port one)" <|
                \() ->
                    let
                        machineState =
                            machineWith baseCpu []

                        updated =
                            Cpu.applyEvent (SetPort (SetTwo 0x07)) machineState
                    in
                    Expect.equal ( 0x00, 0x07 ) ( updated.ports.one, updated.ports.two )
            , test "IN 3 reads the shift register at the configured offset" <|
                \() ->
                    let
                        base =
                            machineWith baseCpu [ 0xDB, 0x03 ]

                        machineState =
                            { base | shiftRegister = ShiftRegister 0xCD 0xAB 4 }
                    in
                    Expect.equal (Ok 0xBC) (executeOne machineState |> Result.map (\ms -> ms.cpuState.a))
            ]
        , describe "memory and timing"
            [ test "memory covers the full 16 bit address space" <|
                \() ->
                    case Cpu.init [ 1, 2, 3 ] of
                        Valid ms ->
                            Expect.equal 0x00010000 (Array.length ms.memory)

                        Invalid _ message ->
                            Expect.fail message
            , test "CZ takes 11 cycles when the condition is not met" <|
                \() ->
                    Expect.equal (Ok 11) (executeOne (machineWith baseCpu [ 0xCC, 0x00, 0x02 ]) |> Result.map (\ms -> ms.cpuState.cycleCount))
            , test "CZ takes 17 cycles when the condition is met" <|
                \() ->
                    let
                        cpu =
                            { baseCpu | conditionCodes = { noFlags | z = True } }
                    in
                    Expect.equal (Ok 17) (executeOne (machineWith cpu [ 0xCC, 0x00, 0x02 ]) |> Result.map (\ms -> ms.cpuState.cycleCount))
            , test "the base cycle count of the opcode table matches the 8080 manual" <|
                \() ->
                    Expect.equal (Just 11) (Maybe.map OpCode.getCycles (OpCodeTable.getOpCodeFromTable 0xCC))
            ]
        , describe "interrupt timing"
            [ test "RST 2 is raised once the cycle count passes the due cycle, when interrupts are enabled" <|
                \() ->
                    let
                        cpu =
                            { baseCpu | intEnable = True }

                        result =
                            case Cpu.runCycles 40000 33334 (machineWith cpu []) of
                                ( Valid ms, nextDue ) ->
                                    Ok { pc = ms.cpuState.pc, intEnable = ms.cpuState.intEnable, nextDue = nextDue }

                                ( Invalid _ message, _ ) ->
                                    Err message
                    in
                    -- the interrupt at cycle 33336 jumps to 0x0010 and disables interrupts; the NOPs after it
                    -- run from there, 4 cycles each, until 40000 cycles
                    Expect.equal (Ok { pc = 0x10 + 1666, intEnable = False, nextDue = 50001 }) result
            , test "the first interrupt of a frame is RST 1 (mid-frame), the next one RST 2" <|
                \() ->
                    let
                        cpu =
                            { baseCpu | intEnable = True }

                        result =
                            case Cpu.runCycles 17000 16667 (machineWith cpu []) of
                                ( Valid ms, nextDue ) ->
                                    Ok { pc = ms.cpuState.pc, nextDue = nextDue }

                                ( Invalid _ message, _ ) ->
                                    Err message
                    in
                    -- RST 1 at cycle 16668 jumps to 0x0008; the 332 cycles after it are 83 NOPs
                    Expect.equal (Ok { pc = 0x08 + 83, nextDue = 33334 }) result
            , test "a due interrupt is skipped while interrupts are disabled, and the schedule continues" <|
                \() ->
                    let
                        result =
                            case Cpu.runCycles 40000 33334 (machineWith baseCpu []) of
                                ( Valid ms, nextDue ) ->
                                    Ok { pc = ms.cpuState.pc, nextDue = nextDue }

                                ( Invalid _ message, _ ) ->
                                    Err message
                    in
                    Expect.equal (Ok { pc = 0x2710, nextDue = 50001 }) result
            ]
        , describe "cabinet inputs"
            [ test "the machine powers on with no button pressed" <|
                \() ->
                    case Cpu.init [ 0x00 ] of
                        Valid ms ->
                            Expect.equal ( 0x08, 0x08 ) ( ms.ports.one, ms.ports.two )

                        Invalid _ message ->
                            Expect.fail message
            , test "fire sets its bit of port 1 and releasing it clears only that bit" <|
                \() ->
                    let
                        base =
                            machineWith baseCpu []

                        machineState =
                            { base | ports = Ports 0x08 0x08 }

                        pressed =
                            case Cpu.keyPressed Fire machineState of
                                Valid ms ->
                                    ms

                                Invalid _ _ ->
                                    machineState

                        released =
                            case Cpu.keyReleased Fire pressed of
                                Valid ms ->
                                    ms

                                Invalid _ _ ->
                                    pressed
                    in
                    Expect.equal ( ( 0x18, 0x08 ), ( 0x08, 0x08 ) ) ( ( pressed.ports.one, pressed.ports.two ), ( released.ports.one, released.ports.two ) )
            ]
        , describe "generated instruction families"
            [ test "MOV M,B writes B to the byte at HL" <|
                \() ->
                    let
                        base =
                            machineWith { baseCpu | b = 0x5A, h = 0x00, l = 0x20 } [ 0x70 ]
                    in
                    executeOne base |> Result.map (\ms -> Array.get 0x20 ms.memory) |> Expect.equal (Ok (Just 0x5A))
            , test "MOV A,M reads the byte at HL" <|
                \() ->
                    let
                        base =
                            machineWith { baseCpu | h = 0x00, l = 0x20 } [ 0x7E ]

                        withByte =
                            { base | memory = Array.set 0x20 0x77 base.memory }
                    in
                    executeOne withByte |> Result.map (\ms -> ms.cpuState.a) |> Expect.equal (Ok 0x77)
            , test "INR M wraps 0xFF to 0 in memory and sets Z" <|
                \() ->
                    let
                        base =
                            machineWith { baseCpu | h = 0x00, l = 0x20 } [ 0x34 ]

                        withByte =
                            { base | memory = Array.set 0x20 0xFF base.memory }

                        result =
                            executeOne withByte
                                |> Result.map (\ms -> ( Array.get 0x20 ms.memory, ms.cpuState.conditionCodes.z ))
                    in
                    Expect.equal (Ok ( Just 0x00, True )) result
            , test "ADC B adds the carry flag" <|
                \() ->
                    let
                        cpu =
                            { baseCpu | a = 0x0F, b = 0x01, conditionCodes = { noFlags | cy = True } }
                    in
                    executeOne (machineWith cpu [ 0x88 ])
                        |> Result.map (\ms -> ( ms.cpuState.a, ms.cpuState.conditionCodes.ac ))
                        |> Expect.equal (Ok ( 0x11, True ))
            , test "SUB B sets carry on borrow" <|
                \() ->
                    let
                        cpu =
                            { baseCpu | a = 0x01, b = 0x02 }
                    in
                    executeOne (machineWith cpu [ 0x90 ])
                        |> Result.map (\ms -> ( ms.cpuState.a, ms.cpuState.conditionCodes.cy ))
                        |> Expect.equal (Ok ( 0xFF, True ))
            , test "LXI D loads the pair with the low byte first" <|
                \() ->
                    executeOne (machineWith baseCpu [ 0x11, 0x34, 0x12 ])
                        |> Result.map (\ms -> ( ms.cpuState.d, ms.cpuState.e, ms.cpuState.pc ))
                        |> Expect.equal (Ok ( 0x12, 0x34, 0x03 ))
            , test "DAD D adds DE to HL and sets carry" <|
                \() ->
                    let
                        cpu =
                            { baseCpu | d = 0xFF, e = 0xFF, h = 0x00, l = 0x02 }
                    in
                    executeOne (machineWith cpu [ 0x19 ])
                        |> Result.map (\ms -> ( ms.cpuState.h, ms.cpuState.l, ms.cpuState.conditionCodes.cy ))
                        |> Expect.equal (Ok ( 0x00, 0x01, True ))
            , test "INX SP wraps 0xFFFF to 0" <|
                \() ->
                    executeOne (machineWith { baseCpu | sp = 0xFFFF } [ 0x33 ])
                        |> Result.map (\ms -> ms.cpuState.sp)
                        |> Expect.equal (Ok 0x00)
            , test "JPE jumps when the parity flag is set and falls through otherwise" <|
                \() ->
                    let
                        odd =
                            machineWith { baseCpu | conditionCodes = { noFlags | p = False } } [ 0xEA, 0x34, 0x12 ]

                        even =
                            machineWith { baseCpu | conditionCodes = { noFlags | p = True } } [ 0xEA, 0x34, 0x12 ]
                    in
                    Expect.equal
                        ( Result.map (\ms -> ms.cpuState.pc) (executeOne odd), Result.map (\ms -> ms.cpuState.pc) (executeOne even) )
                        ( Ok 0x03, Ok 0x1234 )
            , test "HLT stays on its address" <|
                \() ->
                    executeOne (machineWith baseCpu [ 0x76 ])
                        |> Result.map (\ms -> ms.cpuState.pc)
                        |> Expect.equal (Ok 0x00)
            ]
        , describe "instruction coverage"
            [ test "every documented 8080 opcode is implemented" <|
                \() ->
                    let
                        undocumented =
                            [ 0x08, 0x10, 0x18, 0x20, 0x28, 0x30, 0x38, 0xCB, 0xD9, 0xDD, 0xED, 0xFD ]

                        missing =
                            List.range 0 0xFF
                                |> List.filter (\code -> not (List.member code undocumented))
                                |> List.filter
                                    (\code ->
                                        case OpCodeTable.getOpCodeFromTable code of
                                            Just opCode ->
                                                OpCode.getName opCode == "-"

                                            Nothing ->
                                                True
                                    )
                    in
                    Expect.equal [] missing
            ]
        , describe "16 bit address and stack wrap-around"
            [ test "PUSH B with SP=0 wraps to 0xFFFE/0xFFFF" <|
                \() ->
                    let
                        cpu =
                            { baseCpu | b = 0x12, c = 0x34, sp = 0x00 }

                        result =
                            executeOne (machineWith cpu [ 0xC5 ])
                                |> Result.map (\ms -> ( ms.cpuState.sp, Array.get 0xFFFF ms.memory, Array.get 0xFFFE ms.memory ))
                    in
                    Expect.equal (Ok ( 0xFFFE, Just 0x12, Just 0x34 )) result
            , test "CALL with SP=0 stores the return address at the top of memory" <|
                \() ->
                    let
                        result =
                            executeOne (machineWith baseCpu [ 0xCD, 0x00, 0x02 ])
                                |> Result.map (\ms -> { pc = ms.cpuState.pc, sp = ms.cpuState.sp, low = Array.get 0xFFFE ms.memory, high = Array.get 0xFFFF ms.memory })
                    in
                    Expect.equal (Ok { pc = 0x0200, sp = 0xFFFE, low = Just 0x03, high = Just 0x00 }) result
            , test "POP H with SP=0xFFFE reads the value back" <|
                \() ->
                    let
                        base =
                            machineWith { baseCpu | sp = 0xFFFE } [ 0xE1 ]

                        withStack =
                            { base | memory = base.memory |> Array.set 0xFFFE 0x34 |> Array.set 0xFFFF 0x12 }

                        result =
                            executeOne withStack
                                |> Result.map (\ms -> ( ms.cpuState.h, ms.cpuState.l, ms.cpuState.sp ))
                    in
                    Expect.equal (Ok ( 0x12, 0x34, 0x00 )) result
            , test "the program counter wraps after 0xFFFF" <|
                \() ->
                    let
                        base =
                            machineWith { baseCpu | pc = 0xFFFF } []

                        -- NOP at 0xFFFF, then the next instruction is at 0x0000
                        withNop =
                            { base | memory = Array.set 0xFFFF 0x00 base.memory }
                    in
                    Expect.equal (Ok 0x00) (executeOne withNop |> Result.map (\ms -> ms.cpuState.pc))
            ]
        , describe "immutability (required for step back/forward)"
            [ test "stepping returns new states and leaves earlier states untouched" <|
                \() ->
                    let
                        initial =
                            machineWith (withA 0x00) [ 0x3C, 0x3C ]

                        result =
                            executeOne initial
                                |> Result.andThen executeOne
                                |> Result.map (\second -> { before = snapshot initial, after = snapshot second })
                    in
                    Expect.equal
                        (Ok
                            { before = { a = 0x00, pc = 0x00, cy = False, ac = False, z = False, s = False, p = False }
                            , after = { a = 0x02, pc = 0x02, cy = False, ac = False, z = False, s = False, p = False }
                            }
                        )
                        result
            , test "executeSteps can be replayed from the same starting state" <|
                \() ->
                    let
                        initial =
                            machineWith (withA 0x00) [ 0x3C, 0x3C, 0x3C ]

                        first =
                            executeSteps 2 initial |> Result.map snapshot

                        second =
                            executeSteps 2 initial |> Result.map snapshot
                    in
                    Expect.equal first second
            ]
        ]
