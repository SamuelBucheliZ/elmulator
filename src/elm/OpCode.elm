module OpCode exposing (ImplOneByte, OpCode, OpCodeData, OpCodeSpec(..), getCycles, getImplementation, getName, getOpCodeLength)

import EmulatorState exposing (AddressValue, ByteValue, MachineState, MachineStateDiff(..), MachineStateDiffEvent(..), Memory)
import Memory exposing (MemoryAccessResult(..), MemoryProvider)


type alias ImplOneByte =
    MachineState -> MachineStateDiff


type alias ImplTwoBytes =
    ByteValue -> (MachineState -> MachineStateDiff)


type alias ImplThreeBytes =
    ByteValue -> ByteValue -> (MachineState -> MachineStateDiff)


type OpCodeSpec
    = OneByte ImplOneByte
    | TwoBytes ImplTwoBytes
    | ThreeBytes ImplThreeBytes


type alias OpCodeData =
    { name : String
    , cycles : Int
    , opCodeSpec : OpCodeSpec
    }


type alias OpCode =
    { hexCode : ByteValue
    , data : OpCodeData
    }


getOpCodeLength : OpCode -> Int
getOpCodeLength opCode =
    let
        opCodeSpec =
            getSpec opCode
    in
    case opCodeSpec of
        OneByte _ ->
            1

        TwoBytes _ ->
            2

        ThreeBytes _ ->
            3


getImplementation : OpCode -> MemoryProvider -> MemoryProvider -> (MachineState -> MachineStateDiff)
getImplementation opCode firstValueProvider secondValueProvider =
    let
        opCodeSpec =
            getSpec opCode
    in
    case opCodeSpec of
        OneByte implOneByte ->
            implOneByte

        TwoBytes implTwoBytes ->
            let
                firstArg =
                    firstValueProvider ()
            in
            unwrapMemoryAccessTwoBytes implTwoBytes firstArg

        ThreeBytes implThreeBytes ->
            let
                firstArg =
                    firstValueProvider ()

                secondArg =
                    secondValueProvider ()
            in
            unwrapMemoryAccessThreeBytes implThreeBytes firstArg secondArg


unwrapMemoryAccessTwoBytes : ImplTwoBytes -> MemoryAccessResult -> (MachineState -> MachineStateDiff)
unwrapMemoryAccessTwoBytes implTwoBytes firstAccessResult =
    case firstAccessResult of
        Valid byteValue ->
            implTwoBytes byteValue

        Invalid message ->
            illegalMemoryAccess message


unwrapMemoryAccessThreeBytes : ImplThreeBytes -> MemoryAccessResult -> MemoryAccessResult -> (MachineState -> MachineStateDiff)
unwrapMemoryAccessThreeBytes implThreeBytes firstAccessResult secondAccessResult =
    case ( firstAccessResult, secondAccessResult ) of
        ( Valid firstByteValue, Valid secondByteValue ) ->
            implThreeBytes firstByteValue secondByteValue

        ( Valid _, Invalid message ) ->
            illegalMemoryAccess message

        ( Invalid message, _ ) ->
            illegalMemoryAccess message


illegalMemoryAccess : String -> (MachineState -> MachineStateDiff)
illegalMemoryAccess message previousState =
    Failed (Just previousState) message


getSpec : OpCode -> OpCodeSpec
getSpec opCode =
    opCode.data.opCodeSpec


getName : OpCode -> String
getName opCode =
    opCode.data.name


getCycles : OpCode -> Int
getCycles opCode =
    opCode.data.cycles
