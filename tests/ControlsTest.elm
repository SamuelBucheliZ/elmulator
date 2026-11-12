module ControlsTest exposing (all)

import Bytes.Encode
import Cpu
import EmulatorState exposing (EmulatorState(..))
import Expect
import Main exposing (Model, initialModel, update)
import Test exposing (..)
import Time
import UI.Msg exposing (Msg(..))


{-| A model with a running machine that only executes NOPs.
-}
nopModel : Model
nopModel =
    withMachine (Cpu.init (List.repeat 0x0100 0)) initialModel


withMachine : EmulatorState -> Model -> Model
withMachine cpuState model =
    let
        machine =
            model.machine
    in
    { model | machine = { machine | currentCpuState = cpuState } }


isPaused : Model -> Bool
isPaused model =
    model.clock.paused


{-| Delivers an emulation tick at each of the given times (in milliseconds).
-}
tickAt : List Int -> Model -> Model
tickAt times model =
    List.foldl (\millis m -> Tuple.first (update (EmulationWithInterrupt (Time.millisToPosix millis)) m)) model times


stepCount : Model -> Int
stepCount model =
    case model.machine.currentCpuState of
        Valid machineState ->
            machineState.step

        Invalid _ _ ->
            -1


cycles : Model -> Int
cycles model =
    case model.machine.currentCpuState of
        Valid machineState ->
            machineState.cpuState.cycleCount

        Invalid _ _ ->
            -1


{-| A ROM of eight zero bytes (NOPs), as a Bytes value, as delivered by the file picker.
-}
romBytes : Bytes.Encode.Encoder
romBytes =
    Bytes.Encode.sequence (List.repeat 8 (Bytes.Encode.unsignedInt8 0))


all : Test
all =
    describe "controls"
        [ describe "pause"
            [ test "a paused emulator does not advance" <|
                \() ->
                    let
                        paused =
                            { nopModel | clock = pausedClock nopModel.clock }
                    in
                    cycles (tickAt (List.range 1000 1500 |> List.map (\i -> i * 16)) paused)
                        |> Expect.equal 0
            , test "the play/pause button toggles the state" <|
                \() ->
                    let
                        once =
                            Tuple.first (update TogglePause nopModel)

                        twice =
                            Tuple.first (update TogglePause once)
                    in
                    Expect.equal ( True, False ) ( isPaused once, isPaused twice )
            , test "resuming does not catch up on the time spent paused" <|
                \() ->
                    let
                        paused =
                            { nopModel | clock = pausedClock nopModel.clock }

                        -- one second paused, then 100 ms running
                        afterPause =
                            tickAt (List.range 0 62 |> List.map (\i -> 1000 + i * 16)) paused

                        resumed =
                            tickAt (List.range 0 6 |> List.map (\i -> 2000 + i * 16)) (resumedModel afterPause)
                    in
                    -- about 104 ms of running time after the resume; a catch-up would show ~2 million cycles
                    cycles resumed
                        |> Expect.all
                            [ Expect.atLeast 190000
                            , Expect.atMost 215000
                            ]
            ]
        , describe "stepping"
            [ test "one step runs one instruction and pauses" <|
                \() ->
                    let
                        result =
                            Tuple.first (update (NextStepsRequested 1) nopModel)
                    in
                    Expect.equal ( 1, True ) ( stepCount result, isPaused result )
            , test "stepping while running pauses first" <|
                \() ->
                    let
                        running =
                            resumedModel nopModel

                        result =
                            Tuple.first (update (NextStepsRequested 3) running)
                    in
                    Expect.equal ( 3, True ) ( stepCount result, isPaused result )
            , test "the step count box is used by the execute button" <|
                \() ->
                    let
                        withCount =
                            { nopModel | ui = withSteps 5 nopModel.ui }
                    in
                    Expect.equal 5 (stepCount (Tuple.first (update StepsSubmitted withCount)))
            , test "zero steps do nothing but pause" <|
                \() ->
                    let
                        result =
                            Tuple.first (update (NextStepsRequested 0) nopModel)
                    in
                    Expect.equal ( 0, True ) ( stepCount result, isPaused result )
            ]
        , describe "loading and reset"
            [ test "a ROM starts running by default" <|
                \() ->
                    let
                        loaded =
                            Tuple.first (update (RomLoaded (Bytes.Encode.encode romBytes)) initialModel)
                    in
                    Expect.equal False (isPaused loaded)
            , test "a ROM starts paused when that setting is on" <|
                \() ->
                    let
                        loaded =
                            Tuple.first (update (RomLoaded (Bytes.Encode.encode romBytes)) (withStartPaused True initialModel))
                    in
                    Expect.equal ( True, True ) ( isPaused loaded, loaded.clock.startPaused )
            , test "reset starts the program again and keeps the speed and the start setting" <|
                \() ->
                    let
                        loaded =
                            withStartPaused True { initialModel | clock = withSpeed 2 initialModel.clock }
                                |> update (RomLoaded (Bytes.Encode.encode romBytes))
                                |> Tuple.first
                                |> update (NextStepsRequested 3)
                                |> Tuple.first
                                |> update Reset
                                |> Tuple.first
                    in
                    Expect.equal { steps = 0, paused = True, speed = 2, hasProgram = True } { steps = stepCount loaded, paused = isPaused loaded, speed = loaded.clock.speedFactor, hasProgram = loaded.machine.data /= Nothing }
            , test "reset without a ROM does nothing" <|
                \() ->
                    Expect.equal Nothing (Tuple.first (update Reset initialModel)).machine.data
            ]
        ]


pausedClock : Main.Clock -> Main.Clock
pausedClock clock =
    { clock | paused = True }


resumedModel : Model -> Model
resumedModel model =
    let
        clock =
            model.clock
    in
    { model | clock = { clock | paused = False } }


withStartPaused : Bool -> Model -> Model
withStartPaused startPaused model =
    let
        clock =
            model.clock
    in
    { model | clock = { clock | startPaused = startPaused } }


withSpeed : Float -> Main.Clock -> Main.Clock
withSpeed factor clock =
    { clock | speedFactor = factor }


withSteps : Int -> Main.Ui -> Main.Ui
withSteps count ui =
    { ui | nsteps = count }
