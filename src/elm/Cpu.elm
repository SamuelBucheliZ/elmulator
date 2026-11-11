module Cpu exposing (..)

import Array exposing (Array)
import Bitwise
import Config exposing (interruptPeriodCycles)
import EmulatorState exposing (AddressValue, ByteValue, ConditionCodes, CpuState, EmulatorState(..), Flag, MachineState, MachineStateDiff(..), MachineStateDiffEvent(..), Memory, Ports, RegisterValue, SetCpuStateEvent(..), SetFlagEvent(..), SetPortEvent(..), SetShiftRegisterEvent(..), ShiftRegister)
import IO exposing (pressLeft, pressRight, pressSpace, relaseLeft, relaseRight, relaseSpace)
import MachineInstructions exposing (push_)
import Memory exposing (createMemoryProvider)
import OpCode exposing (OpCode, getCycles, getImplementation)
import OpCodeTable exposing (getOpCodeFromTable)
import UI.Msg exposing (GameKey(..))


oneStep : MachineState -> EmulatorState
oneStep cpuState =
    let
        opcode =
            getCurrentOpCode cpuState

        opCodeFromTable =
            getOpCodeFromTable opcode

        machineStateDiff =
            Maybe.withDefault (Failed (Just cpuState) "Error while getting OpCode") (Maybe.map (evaluate cpuState) opCodeFromTable)
    in
    apply machineStateDiff cpuState


nStep : Int -> MachineState -> EmulatorState
nStep n machineState =
    let
        ns =
            oneStep machineState
    in
    if n > 1 then
        case ns of
            Valid cs ->
                nStep (n - 1) cs

            Invalid _ _ ->
                ns

    else
        ns


{-| Runs instructions until the cycle counter reaches `targetCycles`.

Every `interruptPeriodCycles` the RST 2 interrupt is raised. `nextInterruptDue` is the cycle
count of the next one; it moves on by one period each time, whether or not the CPU accepts
the interrupt (the video timing keeps its rhythm). Returns the new state and the next due cycle.

-}
runCycles : Int -> Int -> MachineState -> ( EmulatorState, Int )
runCycles targetCycles nextInterruptDue machineState =
    if machineState.cpuState.cycleCount >= targetCycles then
        ( Valid machineState, nextInterruptDue )

    else
        case oneStep machineState of
            Invalid previous message ->
                ( Invalid previous message, nextInterruptDue )

            Valid next ->
                if next.cpuState.cycleCount >= nextInterruptDue then
                    case checkForInterrupt next of
                        Valid interrupted ->
                            runCycles targetCycles (nextInterruptDue + interruptPeriodCycles) interrupted

                        Invalid previous message ->
                            ( Invalid previous message, nextInterruptDue + interruptPeriodCycles )

                else
                    runCycles targetCycles nextInterruptDue next


checkForInterrupt : MachineState -> EmulatorState
checkForInterrupt machineState =
    let
        intEnabled =
            machineState.cpuState.intEnable
    in
    if intEnabled then
        generateInterrupt machineState 2

    else
        Valid machineState


interrupt : MachineState -> EmulatorState
interrupt machineState =
    generateInterrupt machineState 2


generateInterrupt : MachineState -> Int -> EmulatorState
generateInterrupt machineState number =
    let
        machineStateDiff =
            generateInterruptEvents machineState number
    in
    apply machineStateDiff machineState


generateInterruptEvents : MachineState -> Int -> MachineStateDiff
generateInterruptEvents machineState number =
    let
        newPc =
            8 * number

        -- while halted (on a HLT) the return address is the instruction after it
        returnPc =
            if getCurrentOpCode machineState == 0x76 then
                modBy 0x00010000 (machineState.cpuState.pc + 1)

            else
                machineState.cpuState.pc

        pcHigh =
            Bitwise.shiftRightBy 8 (Bitwise.and returnPc 0xFF00)

        pcLow =
            Bitwise.and returnPc 0xFF
    in
    let
        pushEvents =
            extractEvents (push_ pcHigh pcLow machineState)
    in
    Events
        (List.concat
            [ pushEvents

            -- Accepting an interrupt disables further interrupts until EI is executed
            , [ SetCpu (SetIntEnable False)
              , SetCpu (SetPC newPc)
              ]
            ]
        )


extractEvents : MachineStateDiff -> List MachineStateDiffEvent
extractEvents machineStateDiff =
    case machineStateDiff of
        Failed _ _ ->
            []

        Events list ->
            list


getCurrentOpCode : MachineState -> ByteValue
getCurrentOpCode machineState =
    let
        pc =
            machineState.cpuState.pc

        maybeOpCode =
            Array.get pc machineState.memory
    in
    case maybeOpCode of
        Just opCode ->
            opCode

        Nothing ->
            0



-- TODO: We should probably return a Maybe here and deal with problems in oneStep above


evaluate : MachineState -> OpCode -> MachineStateDiff
evaluate machineState opCode =
    let
        address =
            machineState.cpuState.pc

        memory =
            machineState.memory

        firstValueProvider =
            createMemoryProvider address 1 memory

        secondValueProvider =
            createMemoryProvider address 2 memory

        implementation =
            getImplementation opCode firstValueProvider secondValueProvider

        cycles =
            getCycles opCode
    in
    implementation machineState
        |> addCycles cycles


addCycles : Int -> MachineStateDiff -> MachineStateDiff
addCycles cycles machineStateDiff =
    case machineStateDiff of
        Failed _ _ ->
            machineStateDiff

        Events list ->
            Events (list ++ [ SetCpu (AddCycles cycles) ])


apply : MachineStateDiff -> MachineState -> EmulatorState
apply machineStateDiff cpuState =
    let
        newStep =
            cpuState.step + 1
    in
    case machineStateDiff of
        Failed maybePreviousState errorMessage ->
            Invalid maybePreviousState errorMessage

        Events machineStateDiffEvents ->
            --if invalidEvent machineStateDiffEvents then
            --    Invalid (Just cpuState) "Invalid event"
            --
            --else
            --    validate (List.foldl applyEvent { cpuState | step = newStep } machineStateDiffEvents)
            -- Enable above to search for an invalid event
            Valid (List.foldl applyEvent { cpuState | step = newStep } machineStateDiffEvents)


invalidEvent : List MachineStateDiffEvent -> Bool
invalidEvent events =
    List.length (List.filterMap findMemoryEvent events) > 1


findPCEvent : MachineStateDiffEvent -> Maybe Int
findPCEvent event =
    case event of
        SetCpu (SetPC value) ->
            if value > 0x1FFF then
                Just value

            else
                Nothing

        _ ->
            Nothing


findMemoryEvent : MachineStateDiffEvent -> Maybe Int
findMemoryEvent event =
    case event of
        SetMemory address value ->
            if address == 0x23E5 && value == 0x20 then
                Just value

            else if address == 0x23E4 && value == 0x68 then
                Just value

            else
                Nothing

        _ ->
            Nothing


applyEvent : MachineStateDiffEvent -> MachineState -> MachineState
applyEvent event machineState =
    case event of
        SetMemory address value ->
            setMemory address value machineState

        SetCpu setCpuStateEvent ->
            let
                newCpuState =
                    setCpuState setCpuStateEvent machineState.cpuState
            in
            { machineState | cpuState = newCpuState }

        SetShiftRegister shiftRegisterEvent ->
            let
                newShiftRegister =
                    setShiftRegister shiftRegisterEvent machineState.shiftRegister
            in
            { machineState | shiftRegister = newShiftRegister }

        SetPort setPortEvent ->
            let
                newPorts =
                    setPorts setPortEvent machineState.ports
            in
            { machineState | ports = newPorts }


{-| The 8080 has a 16 bit address space. Stack and pointer arithmetic can step
outside of it (e.g. PUSH with SP=0), so addresses wrap around like the hardware.
-}
wrapAddress : AddressValue -> AddressValue
wrapAddress address =
    modBy 0x00010000 address


setMemory : AddressValue -> ByteValue -> MachineState -> MachineState
setMemory address value cpuState =
    let
        updatedMemory =
            Array.set (wrapAddress address) value cpuState.memory
    in
    { cpuState | memory = updatedMemory }


setCpuState : SetCpuStateEvent -> CpuState -> CpuState
setCpuState event cpuState =
    case event of
        SetRegisterA register ->
            { cpuState | a = register }

        SetRegisterB register ->
            { cpuState | b = register }

        SetRegisterC register ->
            { cpuState | c = register }

        SetRegisterD register ->
            { cpuState | d = register }

        SetRegisterE register ->
            { cpuState | e = register }

        SetRegisterH register ->
            { cpuState | h = register }

        SetRegisterL register ->
            { cpuState | l = register }

        -- PC and SP are 16 bit registers: wrap instead of growing past 0xFFFF or below 0
        SetPC value ->
            { cpuState | pc = modBy 0x00010000 value }

        SetSP value ->
            { cpuState | sp = modBy 0x00010000 value }

        SetFlag setFlagEvent ->
            { cpuState | conditionCodes = setFlag setFlagEvent cpuState.conditionCodes }

        SetIntEnable flag ->
            { cpuState | intEnable = flag }

        AddCycles cycles ->
            { cpuState | cycleCount = cpuState.cycleCount + cycles }


setFlag : SetFlagEvent -> ConditionCodes -> ConditionCodes
setFlag event conditionCodes =
    case event of
        SetFlagZ flag ->
            { conditionCodes | z = flag }

        SetFlagS flag ->
            { conditionCodes | s = flag }

        SetFlagP flag ->
            { conditionCodes | p = flag }

        SetFlagCY flag ->
            { conditionCodes | cy = flag }

        SetFlagAC flag ->
            { conditionCodes | ac = flag }


setShiftRegister : SetShiftRegisterEvent -> ShiftRegister -> ShiftRegister
setShiftRegister event shiftRegister =
    case event of
        SetLower data ->
            { shiftRegister | lower = data }

        SetUpper data ->
            { shiftRegister | upper = data }

        SetOffset data ->
            { shiftRegister | offset = data }


setPorts : SetPortEvent -> Ports -> Ports
setPorts event ports =
    case event of
        SetOne data ->
            { ports | one = data }

        SetTwo data ->
            { ports | two = data }


init : List ByteValue -> EmulatorState
init rom =
    let
        memory =
            initMemory rom

        conditionCodes =
            initConditionCodes

        shiftRegister =
            initShiftRegister

        ports =
            initPorts
    in
    Valid
        (MachineState
            (CpuState
                0x00
                -- A
                0x00
                -- B
                0x00
                -- C
                0x00
                -- D
                0x00
                -- E
                0x00
                -- H
                0x00
                -- L
                0xFFFF
                -- SP
                0x00
                -- PC
                conditionCodes
                False
                -- intEnable
                0
             -- cycleCount
            )
            memory
            shiftRegister
            ports
            0
        )


initMemory : List ByteValue -> Memory
initMemory rom =
    let
        lengthRom =
            List.length rom

        -- the 8080 has a 16 bit address space, i.e. 0x10000 bytes of memory
        paddingAmount =
            0x00010000 - lengthRom

        padding =
            List.repeat paddingAmount 0

        memory =
            List.concat [ rom, padding ]
    in
    Array.fromList memory


initConditionCodes : ConditionCodes
initConditionCodes =
    ConditionCodes False False False False False


initShiftRegister : ShiftRegister
initShiftRegister =
    ShiftRegister 0 0 0


initPorts : Ports
initPorts =
    Ports 14 8


keyPressed : GameKey -> MachineState -> EmulatorState
keyPressed key machineState =
    case key of
        Left ->
            apply (pressLeft machineState) machineState

        Right ->
            apply (pressRight machineState) machineState

        Space ->
            apply (pressSpace machineState) machineState


keyReleased : GameKey -> MachineState -> EmulatorState
keyReleased key machineState =
    case key of
        Left ->
            apply (relaseLeft machineState) machineState

        Right ->
            apply (relaseRight machineState) machineState

        Space ->
            apply (relaseSpace machineState) machineState
