module EmulationSpeedTest exposing (all)

import Cpu
import EmulatorState exposing (EmulatorState(..))
import Expect
import Main exposing (Model, initialModel, update)
import Test exposing (..)
import Time
import UI.Msg exposing (Msg(..))


{-| A model with a running machine that only executes NOPs (4 cycles each), and the given speed factor.
-}
modelAt : Float -> Model
modelAt factor =
    { initialModel
        | currentCpuState = Cpu.init (List.repeat 0x0100 0)
        , speedFactor = factor
    }


{-| Delivers emulation slices every 16 ms for `milliseconds` and returns the final model.
The first slice only starts the clock, so 1000 ms of ticks cover 992 ms of emulated time.
-}
runSlices : Int -> Float -> Model
runSlices milliseconds factor =
    List.range 0 (milliseconds // 16)
        |> List.foldl
            (\i model ->
                Tuple.first (update (EmulationWithInterrupt (Time.millisToPosix (1000 + i * 16))) model)
            )
            (modelAt factor)


emulatedCycles : Model -> Int
emulatedCycles model =
    case model.currentCpuState of
        Valid machineState ->
            machineState.cpuState.cycleCount

        Invalid _ _ ->
            -1


all : Test
all =
    describe "emulation speed"
        [ test "speed 1 runs one second of 2 MHz clock cycles" <|
            \() ->
                emulatedCycles (runSlices 1000 1)
                    |> Expect.all
                        [ Expect.atLeast 1982000
                        , Expect.atMost 1986000
                        ]
        , test "speed 2 runs twice as many cycles" <|
            \() ->
                emulatedCycles (runSlices 1000 2)
                    |> Expect.all
                        [ Expect.atLeast 3966000
                        , Expect.atMost 3970000
                        ]
        , test "speed 0.25 runs a quarter of the cycles" <|
            \() ->
                emulatedCycles (runSlices 1000 0.25)
                    |> Expect.all
                        [ Expect.atLeast 494000
                        , Expect.atMost 498000
                        ]
        , test "the measured rate is about 2 MHz at speed 1" <|
            \() ->
                (runSlices 1100 1).measuredCyclesPerSecond
                    |> Expect.all
                        [ Expect.atLeast 1950000
                        , Expect.atMost 2050000
                        ]
        ]
