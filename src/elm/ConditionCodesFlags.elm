module ConditionCodesFlags exposing (..)

import Bitwise


zFlag : Int -> Bool
zFlag result =
    if result == 0 then
        True

    else
        False


sFlag : Int -> Bool
sFlag result =
    if Bitwise.and 128 result == 128 then
        True

    else
        False


{-| Parity flag: True when the low 8 bits of the result contain an
even number of 1-bits (8080 "P" flag). Not the same as "result is even".
-}
pFlag : Int -> Bool
pFlag result =
    let
        onesCount =
            List.range 0 7
                |> List.map (\bit -> Bitwise.and 1 (Bitwise.shiftRightBy bit result))
                |> List.sum
    in
    modBy 2 onesCount == 0


cyFlag : Int -> Bool
cyFlag result =
    if result > 255 then
        True

    else
        False


acFlag : Int -> Bool
acFlag result =
    False
