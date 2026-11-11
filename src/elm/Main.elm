module Main exposing (Clock, Model, Ui, initialModel, main, update)

import Array exposing (Array)
import Bootstrap.Button as Button
import Bootstrap.CDN as CDN
import Bootstrap.Form.Input as Input
import Bootstrap.Grid as Grid
import Bootstrap.Grid.Col as Col
import Browser
import Browser.Events
import Bytes exposing (Bytes)
import Canvas exposing (Renderable, rect, shapes)
import Canvas.Settings exposing (fill)
import Color exposing (Color)
import Config exposing (baseCyclesPerSecond, defaultSpeedFactor, interruptPeriodCycles, sliceInterval, speedFactors)
import Cpu exposing (interrupt, keyPressed, keyReleased, nStep, runCycles)
import EmulatorState exposing (ByteValue, EmulatorState(..), MachineState)
import File exposing (File)
import File.Select as Select
import FileDecoder exposing (decodeFile)
import Graphics exposing (canvasHeight, canvasWidth, renderScreen)
import Html exposing (Html, div, h1, h3, input, kbd, label, p, pre, span, text)
import Html.Attributes exposing (checked, class, height, style, type_, width)
import Html.Events exposing (onCheck, onClick)
import Maybe exposing (withDefault)
import Memory exposing (readMemorySlice)
import Task
import Time
import UI.Formatter exposing (cpustate)
import UI.KeyDecoder exposing (keyDecoderDown, keyDecoderUp)
import UI.Msg exposing (Msg(..))
import UI.Panels exposing (codePanel, cpuPanel, portsPanel, stackPanel)



-- MAIN


main : Program () Model Msg
main =
    Browser.element
        { init = init
        , view = view
        , update = update
        , subscriptions = subscriptions
        }



-- MODEL


{-| The whole application state, in three parts:

  - the machine: the ROM and the emulated 8080 with its memory and ports;
  - the clock: how far the emulated clock has run, and the speed and pause settings;
  - the UI: what is shown on the page, which is not part of the machine.

-}
type alias Model =
    { machine : Machine
    , clock : Clock
    , ui : Ui
    }


type alias Machine =
    { data : Maybe Bytes
    , currentCpuState : EmulatorState
    }


type alias Clock =
    { paused : Bool
    , startPaused : Bool
    , speedFactor : Float

    -- the time of the last slice, cycles owed but not yet run, the cycle count of the next
    -- RST 2 interrupt, and the cycles run in the current measurement window
    , lastSliceMillis : Int
    , cycleRemainder : Float
    , nextInterruptDue : Int
    , windowStartMillis : Int
    , cyclesInWindow : Int
    , measuredCyclesPerSecond : Int
    }


type alias Ui =
    { showCode : Bool

    -- the step count typed in the input box
    , nsteps : Int

    -- the video RAM the current screen was rendered from, to skip redrawing an unchanged frame
    , screen : Html Msg
    , lastFrame : Maybe (Array ByteValue)
    }


initialModel : Model
initialModel =
    { machine = initialMachine
    , clock = initialClock
    , ui = initialUi
    }


initialMachine : Machine
initialMachine =
    { data = Nothing
    , currentCpuState = Invalid Nothing "No ROM loaded yet"
    }


initialClock : Clock
initialClock =
    { paused = False
    , startPaused = False
    , speedFactor = defaultSpeedFactor
    , lastSliceMillis = 0
    , cycleRemainder = 0
    , nextInterruptDue = interruptPeriodCycles
    , windowStartMillis = 0
    , cyclesInWindow = 0
    , measuredCyclesPerSecond = 0
    }


initialUi : Ui
initialUi =
    { showCode = False
    , nsteps = 0
    , screen = greenScreenHtml
    , lastFrame = Nothing
    }


init : () -> ( Model, Cmd Msg )
init _ =
    ( initialModel, Cmd.none )



-- UPDATE


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        RomRequested ->
            ( model
            , Select.file [ "application/any" ] RomSelected
            )

        RomSelected file ->
            ( model
            , Task.perform RomLoaded (File.toBytes file)
            )

        RomLoaded content ->
            ( loadDataIntoMemory model content
            , Cmd.none
            )

        NextStepsRequested n ->
            -- stepping always pauses the emulator first, so that steps and running never interleave
            case model.machine.currentCpuState of
                Valid currentCpuState ->
                    if n < 1 then
                        ( pause model, Cmd.none )

                    else
                        ( pause (withCpuState (nStep n currentCpuState) model), Cmd.none )

                Invalid _ _ ->
                    ( pause model, Cmd.none )

        KeyDown key ->
            case model.machine.currentCpuState of
                Valid currentCpuState ->
                    ( withCpuState (keyPressed key currentCpuState) model
                    , Cmd.none
                    )

                Invalid _ _ ->
                    ( model
                    , Cmd.none
                    )

        KeyUp key ->
            case model.machine.currentCpuState of
                Valid currentCpuState ->
                    ( withCpuState (keyReleased key currentCpuState) model
                    , Cmd.none
                    )

                Invalid _ _ ->
                    ( model
                    , Cmd.none
                    )

        EmulationWithInterrupt posix ->
            let
                now =
                    Time.posixToMillis posix

                ( newCpuState, newClock ) =
                    if model.clock.paused then
                        ( model.machine.currentCpuState, keepClockAt now model.clock )

                    else
                        runSlice now model.clock model.machine.currentCpuState
            in
            ( withCpuState newCpuState { model | clock = newClock }
            , Cmd.none
            )

        RenderScreen _ ->
            case model.machine.currentCpuState of
                Valid machineState ->
                    let
                        frame =
                            readMemorySlice 0x2400 0x3FFF machineState.memory
                    in
                    if model.ui.lastFrame == Just frame then
                        ( model
                        , Cmd.none
                        )

                    else
                        ( withUi (\ui -> { ui | screen = renderFrame frame, lastFrame = Just frame }) model
                        , Cmd.none
                        )

                Invalid _ _ ->
                    ( model
                    , Cmd.none
                    )

        InterruptRequested ->
            case model.machine.currentCpuState of
                Valid currentCpuState ->
                    ( withCpuState (interrupt currentCpuState) model
                    , Cmd.none
                    )

                Invalid _ _ ->
                    ( model
                    , Cmd.none
                    )

        Reset ->
            case model.machine.data of
                Just data ->
                    ( loadDataIntoMemory model data, Cmd.none )

                Nothing ->
                    ( model, Cmd.none )

        ToggleCode ->
            ( withUi (\ui -> { ui | showCode = not ui.showCode }) model, Cmd.none )

        TogglePause ->
            ( withClock (\clock -> { clock | paused = not clock.paused, windowStartMillis = 0, cyclesInWindow = 0 }) model
            , Cmd.none
            )

        StartPausedChanged startPaused ->
            ( withClock (\clock -> { clock | startPaused = startPaused }) model, Cmd.none )

        SpeedSelected factor ->
            ( withClock (\clock -> { clock | speedFactor = factor }) model, Cmd.none )

        StepsUpdated n ->
            ( withUi (\ui -> { ui | nsteps = Maybe.withDefault 0 (String.toInt n) }) model, Cmd.none )

        StepsSubmitted ->
            update (NextStepsRequested model.ui.nsteps) model


withCpuState : EmulatorState -> Model -> Model
withCpuState cpuState model =
    let
        machine =
            model.machine
    in
    { model | machine = { machine | currentCpuState = cpuState } }


withClock : (Clock -> Clock) -> Model -> Model
withClock change model =
    { model | clock = change model.clock }


withUi : (Ui -> Ui) -> Model -> Model
withUi change model =
    { model | ui = change model.ui }


pause : Model -> Model
pause model =
    withClock (\clock -> { clock | paused = True }) model


{-| Keeps the clock and the measurement window at "now", so that resuming does not catch up.
-}
keepClockAt : Int -> Clock -> Clock
keepClockAt now clock =
    { clock
        | lastSliceMillis = now
        , cycleRemainder = 0
        , windowStartMillis = now
        , cyclesInWindow = 0
    }


{-| Runs one slice of emulation: the cycles owed since the last slice, at the selected speed.
An error keeps the last known state and the clock is not advanced.
-}
runSlice : Int -> Clock -> EmulatorState -> ( EmulatorState, Clock )
runSlice now clock state =
    case state of
        Valid currentCpuState ->
            let
                -- the first slice has no earlier time to measure from; a long pause (e.g. a hidden
                -- tab) is capped so that the emulator does not try to catch up all at once
                elapsed =
                    if clock.lastSliceMillis == 0 then
                        0

                    else
                        min 250 (now - clock.lastSliceMillis)

                owed =
                    clock.cycleRemainder + baseCyclesPerSecond * clock.speedFactor * toFloat elapsed / 1000

                cyclesToRun =
                    floor owed

                cyclesBefore =
                    currentCpuState.cpuState.cycleCount

                ( newCpuState, nextInterruptDue ) =
                    if cyclesToRun > 0 then
                        runCycles (cyclesBefore + cyclesToRun) clock.nextInterruptDue currentCpuState

                    else
                        ( Valid currentCpuState, clock.nextInterruptDue )

                -- an instruction may run past the target by a few cycles; the difference is owed later
                cyclesRun =
                    case newCpuState of
                        Valid machineState ->
                            machineState.cpuState.cycleCount - cyclesBefore

                        Invalid _ _ ->
                            cyclesToRun

                windowElapsed =
                    now - clock.windowStartMillis

                ( measured, windowStart, inWindow ) =
                    if windowElapsed >= 1000 then
                        ( round (toFloat (clock.cyclesInWindow + cyclesRun) * 1000 / toFloat windowElapsed)
                        , now
                        , 0
                        )

                    else
                        ( clock.measuredCyclesPerSecond, clock.windowStartMillis, clock.cyclesInWindow + cyclesRun )
            in
            ( newCpuState
            , { clock
                | lastSliceMillis = now
                , cycleRemainder = owed - toFloat cyclesRun
                , nextInterruptDue = nextInterruptDue
                , windowStartMillis = windowStart
                , cyclesInWindow = inWindow
                , measuredCyclesPerSecond = measured
              }
            )

        Invalid _ _ ->
            ( state, clock )


{-| Starts a program from its first instruction. The speed and the "start paused" setting
are kept; the program starts paused if that setting is on.
-}
loadDataIntoMemory : Model -> Bytes -> Model
loadDataIntoMemory model data =
    { machine =
        { data = Just data
        , currentCpuState = Cpu.init (decodeFile data)
        }
    , clock =
        { initialClock
            | speedFactor = model.clock.speedFactor
            , startPaused = model.clock.startPaused
            , paused = model.clock.startPaused
        }
    , ui =
        { initialUi
            | showCode = model.ui.showCode
            , nsteps = model.ui.nsteps
        }
    }



-- VIEW


view : Model -> Html Msg
view model =
    case model.machine.data of
        Nothing ->
            Grid.container []
                [ CDN.stylesheet -- creates an inline style node with the Bootstrap CSS
                , pageHeader
                , Grid.row []
                    [ Grid.col []
                        [ Button.button
                            [ Button.outlineSuccess
                            , Button.attrs
                                [ onClick RomRequested
                                ]
                            ]
                            [ text "(l)oad rom" ]
                        , text " "
                        , startPausedCheckbox model.clock.startPaused
                        ]
                    ]
                ]

        Just _ ->
            Grid.container []
                [ CDN.stylesheet -- creates an inline style node with the Bootstrap CSS
                , pageHeader
                , toolbar model
                , Grid.row []
                    [ Grid.col [ Col.lg7 ]
                        [ h3 [] [ text "Screen" ]
                        , model.ui.screen
                        , keyLegend
                        ]
                    , Grid.col [ Col.lg5 ]
                        ([ h3 [] [ text "CPU" ]
                         , withMachine model.machine.currentCpuState
                            (cpuPanel
                                { paused = model.clock.paused
                                , speed = String.fromFloat model.clock.speedFactor ++ "x"
                                , measured = megahertz (toFloat model.clock.measuredCyclesPerSecond) ++ " MHz"
                                }
                            )
                         , h3 [ class "mt-3" ] [ text "Ports" ]
                         , withMachine model.machine.currentCpuState portsPanel
                         , h3 [ class "mt-3" ] [ text "Stack" ]
                         , withMachine model.machine.currentCpuState stackPanel
                         , div [ class "mt-3" ]
                            [ Button.button
                                [ Button.outlineSecondary, Button.small, Button.attrs [ onClick ToggleCode ] ]
                                [ text
                                    (if model.ui.showCode then
                                        "hide code"

                                     else
                                        "show code"
                                    )
                                ]
                            ]
                         ]
                            ++ (if model.ui.showCode then
                                    [ h3 [ class "mt-3" ] [ text "Code" ]
                                    , withMachine model.machine.currentCpuState codePanel
                                    ]

                                else
                                    []
                               )
                        )
                    ]
                ]


{-| The machine of the emulator, if it has one (an error keeps the last known state).
-}
machineOf : EmulatorState -> Maybe MachineState
machineOf state =
    case state of
        Valid machineState ->
            Just machineState

        Invalid maybeMachineState _ ->
            maybeMachineState


{-| Shows a panel of the machine, or a note when there is no machine state.
-}
withMachine : EmulatorState -> (MachineState -> Html Msg) -> Html Msg
withMachine state viewPanel =
    case machineOf state of
        Just machineState ->
            viewPanel machineState

        Nothing ->
            text "no CPU state"


{-| Formats a cycles per second value as MHz with two decimals.
-}
megahertz : Float -> String
megahertz cyclesPerSecond =
    String.fromFloat (toFloat (round (cyclesPerSecond / 10000)) / 100)


{-| The control panel: each group has a title, and the buttons of a group are next to each other.
-}
toolbar : Model -> Html Msg
toolbar model =
    div [ class "border rounded p-2 mb-3" ]
        [ toolbarSection "Program"
            [ Button.button [ Button.outlineSuccess, Button.small, Button.attrs [ onClick RomRequested ] ] [ text "(l)oad ROM" ]
            , Button.button [ Button.outlineDanger, Button.small, Button.attrs [ onClick Reset ] ] [ text "(r)eset" ]
            , startPausedCheckbox model.clock.startPaused
            ]
        , toolbarSection "Run"
            [ Button.button
                [ if model.clock.paused then
                    Button.primary

                  else
                    Button.outlinePrimary
                , Button.small
                , Button.attrs [ onClick TogglePause ]
                ]
                [ text
                    (if model.clock.paused then
                        "(p)lay"

                     else
                        "(p)ause"
                    )
                ]
            ]
        , toolbarSection "Step (pauses the emulator)"
            [ Button.button [ Button.outlinePrimary, Button.small, Button.attrs [ onClick (NextStepsRequested 1) ] ] [ text "(n)ext instruction" ]
            , span [ class "mx-2 small" ] [ text "or run" ]
            , span [ style "display" "inline-block", style "width" "6em" ]
                [ Input.text
                    [ Input.id "steps"
                    , Input.small
                    , Input.onInput StepsUpdated
                    , Input.value (String.fromInt model.ui.nsteps)
                    ]
                ]
            , span [ class "mx-2 small" ] [ text "instructions" ]
            , Button.button [ Button.outlinePrimary, Button.small, Button.attrs [ onClick StepsSubmitted ] ] [ text "(e)xecute" ]
            , p [ class "small text-muted mb-0 mt-1" ]
                [ text "Stepping runs instructions only: the 60 Hz timer interrupt is generated while running, not while stepping." ]
            ]
        , toolbarSection "Interrupt"
            [ Button.button [ Button.outlinePrimary, Button.small, Button.attrs [ onClick InterruptRequested ] ] [ text "(i)nterrupt now" ]
            ]
        , toolbarSection "Speed (relative to a real 8080 at 2 MHz)" (speedButtons model.clock.speedFactor)
        ]


{-| A titled group of controls in the toolbar.
-}
toolbarSection : String -> List (Html Msg) -> Html Msg
toolbarSection title children =
    div [ class "d-inline-block align-top mr-4 mb-2" ]
        [ div [ class "small text-muted mb-1" ] [ text title ]
        , div [] (List.map (\child -> span [ class "mr-1" ] [ child ]) children)
        ]


startPausedCheckbox : Bool -> Html Msg
startPausedCheckbox startPaused =
    label []
        [ input [ type_ "checkbox", checked startPaused, onCheck StartPausedChanged ] []
        , text " start paused"
        ]


{-| The game buttons and their keys, shown next to the screen.
-}
keyLegend : Html Msg
keyLegend =
    div [ class "small text-muted mt-2" ]
        [ keyChip "A" "left"
        , keyChip "D" "right"
        , keyChip "S" "fire"
        , keyChip "C" "coin"
        , keyChip "1" "1P start"
        , keyChip "2" "2P start"
        ]


keyChip : String -> String -> Html Msg
keyChip key action =
    span [ class "mr-3 text-nowrap" ]
        [ kbd [ class "mr-1" ] [ text key ]
        , text action
        ]


speedButtons : Float -> List (Html Msg)
speedButtons selected =
    List.map
        (\factor ->
            Button.button
                [ if factor == selected then
                    Button.primary

                  else
                    Button.outlinePrimary
                , Button.small
                , Button.attrs [ onClick (SpeedSelected factor) ]
                ]
                [ text (String.fromFloat factor ++ "x") ]
        )
        speedFactors


pageHeader : Html Msg
pageHeader =
    div []
        [ h1 [] [ text "Elmulator ", p [ class "lead" ] [ text "A 8080 Emulator written in Elm" ] ]
        ]



-- TODO: Clean up screen rendering (magic constants, green scren handling, etc.)


renderFrame : Array ByteValue -> Html Msg
renderFrame videoRam =
    Canvas.toHtml ( canvasWidth, canvasHeight )
        [ class "screen" ]
        (renderScreen videoRam)


greenScreenHtml : Html Msg
greenScreenHtml =
    Canvas.toHtml ( canvasWidth, canvasHeight )
        []
        greenScreen


greenScreen : List Renderable
greenScreen =
    [ shapes [ fill Color.green ] [ rect ( 0, 0 ) (toFloat canvasWidth) (toFloat canvasHeight) ] ]



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.batch
        [ Browser.Events.onKeyDown keyDecoderDown
        , Browser.Events.onKeyUp keyDecoderUp

        --, Time.every 17 TickInterrupt
        , Time.every 40 RenderScreen
        , Time.every sliceInterval EmulationWithInterrupt
        ]
