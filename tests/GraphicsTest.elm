module GraphicsTest exposing (..)

import Array exposing (Array)
import Bitwise
import EmulatorState exposing (ByteValue)
import Expect
import Graphics exposing (Run, litRuns)
import Set exposing (Set)
import Test exposing (..)


videoRamSize : Int
videoRamSize =
    7168


{-| Straightforward per-pixel reading of the video RAM: the reference the runs must match.
A lit bit at row `r` and native x becomes canvas pixel (column r, row 255 - x).
-}
referencePixels : Array ByteValue -> Set ( Int, Int )
referencePixels videoRam =
    List.range 0 223
        |> List.concatMap
            (\row ->
                List.range 0 255
                    |> List.filterMap
                        (\x ->
                            let
                                byte =
                                    Array.get (row * 32 + x // 8) videoRam |> Maybe.withDefault 0
                            in
                            if Bitwise.and (Bitwise.shiftRightBy (modBy 8 x) byte) 1 == 1 then
                                Just ( row, 255 - x )

                            else
                                Nothing
                        )
            )
        |> Set.fromList


runPixels : List Run -> Set ( Int, Int )
runPixels runs =
    runs
        |> List.concatMap
            (\run ->
                List.range 0 (run.length - 1)
                    |> List.map (\offset -> ( run.x, run.y + offset ))
            )
        |> Set.fromList


{-| Deterministic pseudo random video RAM (linear congruential generator).
-}
pseudoRandomRam : Int -> Array ByteValue
pseudoRandomRam seed =
    List.range 1 videoRamSize
        |> List.foldl
            (\_ ( state, acc ) ->
                let
                    next =
                        modBy 2147483648 (state * 1103515245 + 12345)
                in
                ( next, Bitwise.and 0xFF (Bitwise.shiftRightBy 16 next) :: acc )
            )
            ( seed, [] )
        |> Tuple.second
        |> List.reverse
        |> Array.fromList


ramWith : (Int -> ByteValue) -> Array ByteValue
ramWith f =
    Array.fromList (List.map f (List.range 0 (videoRamSize - 1)))


all : Test
all =
    describe "Graphics"
        [ describe "litRuns matches the per-pixel reference"
            [ test "empty video RAM has no lit pixels" <|
                \() ->
                    let
                        ram =
                            ramWith (\_ -> 0)
                    in
                    Expect.equal [] (litRuns ram)
            , test "fully lit video RAM is one run per row covering the whole column" <|
                \() ->
                    let
                        ram =
                            ramWith (\_ -> 0xFF)

                        runs =
                            litRuns ram
                    in
                    Expect.all
                        [ \_ -> Expect.equal 224 (List.length runs)
                        , \_ -> Expect.equal True (List.all (\run -> run.length == 256 && run.y == 0) runs)
                        , \_ -> Expect.equal (referencePixels ram) (runPixels runs)
                        ]
                        ()
            , test "single lit bit in the first byte is at canvas (0, 255)" <|
                \() ->
                    let
                        ram =
                            ramWith
                                (\i ->
                                    if i == 0 then
                                        0x01

                                    else
                                        0
                                )
                    in
                    Expect.equal (Set.fromList [ ( 0, 255 ) ]) (runPixels (litRuns ram))
            , test "last bit of the last byte is at canvas (223, 0)" <|
                \() ->
                    let
                        ram =
                            ramWith
                                (\i ->
                                    if i == videoRamSize - 1 then
                                        0x80

                                    else
                                        0
                                )
                    in
                    Expect.equal (Set.fromList [ ( 223, 0 ) ]) (runPixels (litRuns ram))
            , test "runs crossing byte boundaries are merged" <|
                \() ->
                    let
                        -- bits 6 and 7 of byte 0 and bits 0 and 1 of byte 1 are lit: native x 6..9
                        ram =
                            ramWith
                                (\i ->
                                    if i == 0 then
                                        0xC0

                                    else if i == 1 then
                                        0x03

                                    else
                                        0
                                )

                        runs =
                            litRuns ram
                    in
                    Expect.equal [ { x = 0, y = 255 - 9, length = 4 } ] runs
            , test "pseudo random frame matches the reference" <|
                \() ->
                    let
                        ram =
                            pseudoRandomRam 42
                    in
                    Expect.equal (referencePixels ram) (runPixels (litRuns ram))
            ]
        ]
