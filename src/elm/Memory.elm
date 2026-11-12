module Memory exposing (..)

import Array exposing (Array)
import EmulatorState exposing (AddressValue, ByteValue, Memory)
import Hex


type MemoryAccessResult
    = Valid ByteValue
    | Invalid String


readMemory : AddressValue -> Memory -> MemoryAccessResult
readMemory address memory =
    let
        readValue =
            Array.get (modBy 0x00010000 address) memory
    in
    case readValue of
        Just value ->
            Valid value

        Nothing ->
            Invalid ("Illegal memory access occurred at " ++ Hex.padX4 address)


type alias MemoryProvider =
    () -> MemoryAccessResult


createMemoryProvider : AddressValue -> Int -> Memory -> MemoryProvider
createMemoryProvider address offset memory =
    let
        readValue =
            Array.get (modBy 0x00010000 (address + offset)) memory
    in
    \_ ->
        case readValue of
            Just value ->
                Valid value

            Nothing ->
                Invalid ("Illegal memory access occurred at " ++ Hex.padX4 address)


readMemorySlice : AddressValue -> AddressValue -> Memory -> Array ByteValue
readMemorySlice startAddress endAddress memory =
    Array.slice startAddress endAddress memory
