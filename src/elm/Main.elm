module Main exposing (Model, initialModel, main, update)

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


type alias Model =
    { data : Maybe Bytes
    , currentCpuState : EmulatorState
    , nsteps : Int
    , speedFactor : Float
    , paused : Bool
    , showCode : Bool
    , startPaused : Bool

    -- emulation timing: the time of the last slice, cycles owed but not yet run, the cycle count
    -- of the next RST 2 interrupt, and the cycles run in the current measurement window
    , lastSliceMillis : Int
    , cycleRemainder : Float
    , nextInterruptDue : Int
    , windowStartMillis : Int
    , cyclesInWindow : Int
    , measuredCyclesPerSecond : Int
    , screen : Html Msg

    -- video RAM the current screen was rendered from, to skip redrawing an unchanged frame
    , lastFrame : Maybe (Array ByteValue)
    }


initialModel : Model
initialModel =
    { data = Nothing
    , currentCpuState = Invalid Nothing "No ROM loaded yet"
    , nsteps = 0
    , speedFactor = defaultSpeedFactor
    , paused = False
    , showCode = False
    , startPaused = False
    , lastSliceMillis = 0
    , cycleRemainder = 0
    , nextInterruptDue = interruptPeriodCycles
    , windowStartMillis = 0
    , cyclesInWindow = 0
    , measuredCyclesPerSecond = 0
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
            case model.currentCpuState of
                Valid currentCpuState ->
                    if n < 1 then
                        ( { model | paused = True }, Cmd.none )

                    else
                        ( { model | paused = True, currentCpuState = nStep n currentCpuState }, Cmd.none )

                Invalid _ _ ->
                    ( { model | paused = True }, Cmd.none )

        KeyDown key ->
            case model.currentCpuState of
                Valid currentCpuState ->
                    ( { model | currentCpuState = keyPressed key currentCpuState }
                    , Cmd.none
                    )

                Invalid _ _ ->
                    ( model
                    , Cmd.none
                    )

        KeyUp key ->
            case model.currentCpuState of
                Valid currentCpuState ->
                    ( { model | currentCpuState = keyReleased key currentCpuState }
                    , Cmd.none
                    )

                Invalid _ _ ->
                    ( model
                    , Cmd.none
                    )

        EmulationWithInterrupt posix ->
            if model.paused then
                -- keep the clock and the measurement window at "now", so that resuming does not catch up
                ( { model
                    | lastSliceMillis = Time.posixToMillis posix
                    , cycleRemainder = 0
                    , windowStartMillis = Time.posixToMillis posix
                    , cyclesInWindow = 0
                  }
                , Cmd.none
                )

            else
                case model.currentCpuState of
                    Valid currentCpuState ->
                        let
                            now =
                                Time.posixToMillis posix

                            -- the first slice has no earlier time to measure from; a long pause (e.g. a hidden
                            -- tab) is capped so that the emulator does not try to catch up all at once
                            elapsed =
                                if model.lastSliceMillis == 0 then
                                    0

                                else
                                    min 250 (now - model.lastSliceMillis)

                            owed =
                                model.cycleRemainder + baseCyclesPerSecond * model.speedFactor * toFloat elapsed / 1000

                            cyclesToRun =
                                floor owed

                            cyclesBefore =
                                currentCpuState.cpuState.cycleCount

                            ( newCpuState, nextInterruptDue ) =
                                if cyclesToRun > 0 then
                                    runCycles (cyclesBefore + cyclesToRun) model.nextInterruptDue currentCpuState

                                else
                                    ( Valid currentCpuState, model.nextInterruptDue )

                            -- an instruction may run past the target by a few cycles; the difference is owed later
                            cyclesRun =
                                case newCpuState of
                                    Valid machineState ->
                                        machineState.cpuState.cycleCount - cyclesBefore

                                    Invalid _ _ ->
                                        cyclesToRun

                            windowElapsed =
                                now - model.windowStartMillis

                            ( measured, windowStart, inWindow ) =
                                if windowElapsed >= 1000 then
                                    ( round (toFloat (model.cyclesInWindow + cyclesRun) * 1000 / toFloat windowElapsed)
                                    , now
                                    , 0
                                    )

                                else
                                    ( model.measuredCyclesPerSecond, model.windowStartMillis, model.cyclesInWindow + cyclesRun )
                        in
                        ( { model
                            | currentCpuState = newCpuState
                            , lastSliceMillis = now
                            , cycleRemainder = owed - toFloat cyclesRun
                            , nextInterruptDue = nextInterruptDue
                            , windowStartMillis = windowStart
                            , cyclesInWindow = inWindow
                            , measuredCyclesPerSecond = measured
                          }
                        , Cmd.none
                        )

                    Invalid _ _ ->
                        ( model
                        , Cmd.none
                        )

        RenderScreen _ ->
            case model.currentCpuState of
                Valid machineState ->
                    let
                        frame =
                            readMemorySlice 0x2400 0x3FFF machineState.memory
                    in
                    if model.lastFrame == Just frame then
                        ( model
                        , Cmd.none
                        )

                    else
                        ( { model
                            | screen = renderFrame frame
                            , lastFrame = Just frame
                          }
                        , Cmd.none
                        )

                Invalid _ _ ->
                    ( model
                    , Cmd.none
                    )

        InterruptRequested ->
            case model.currentCpuState of
                Valid currentCpuState ->
                    ( { model | currentCpuState = interrupt currentCpuState }
                    , Cmd.none
                    )

                Invalid _ _ ->
                    ( model
                    , Cmd.none
                    )

        Reset ->
            case model.data of
                Just data ->
                    ( loadDataIntoMemory model data, Cmd.none )

                Nothing ->
                    ( model, Cmd.none )

        ToggleCode ->
            ( { model | showCode = not model.showCode }, Cmd.none )

        TogglePause ->
            ( { model | paused = not model.paused, windowStartMillis = 0, cyclesInWindow = 0 }, Cmd.none )

        StartPausedChanged startPaused ->
            ( { model | startPaused = startPaused }, Cmd.none )

        SpeedSelected factor ->
            ( { model | speedFactor = factor }, Cmd.none )

        StepsUpdated n ->
            ( { model | nsteps = Maybe.withDefault 0 (String.toInt n) }, Cmd.none )

        StepsSubmitted ->
            update (NextStepsRequested model.nsteps) model


{-| Starts a program from its first instruction. The speed and the "start paused" setting
are kept; the program starts paused if that setting is on.
-}
loadDataIntoMemory : Model -> Bytes -> Model
loadDataIntoMemory model data =
    let
        decodedFile =
            decodeFile data

        initialCpuState =
            Cpu.init decodedFile
    in
    { model
        | data = Just data
        , currentCpuState = initialCpuState
        , paused = model.startPaused
        , lastSliceMillis = 0
        , cycleRemainder = 0
        , nextInterruptDue = interruptPeriodCycles
        , windowStartMillis = 0
        , cyclesInWindow = 0
        , measuredCyclesPerSecond = 0
        , screen = greenScreenHtml
        , lastFrame = Nothing
    }



-- VIEW


view : Model -> Html Msg
view model =
    case model.data of
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
                        , startPausedCheckbox model.startPaused
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
                        , model.screen
                        , keyLegend
                        ]
                    , Grid.col [ Col.lg5 ]
                        ([ h3 [] [ text "CPU" ]
                         , withMachine model.currentCpuState
                            (cpuPanel
                                { paused = model.paused
                                , speed = String.fromFloat model.speedFactor ++ "x"
                                , measured = megahertz (toFloat model.measuredCyclesPerSecond) ++ " MHz"
                                }
                            )
                         , h3 [ class "mt-3" ] [ text "Ports" ]
                         , withMachine model.currentCpuState portsPanel
                         , h3 [ class "mt-3" ] [ text "Stack" ]
                         , withMachine model.currentCpuState stackPanel
                         , div [ class "mt-3" ]
                            [ Button.button
                                [ Button.outlineSecondary, Button.small, Button.attrs [ onClick ToggleCode ] ]
                                [ text
                                    (if model.showCode then
                                        "hide code"

                                     else
                                        "show code"
                                    )
                                ]
                            ]
                         ]
                            ++ (if model.showCode then
                                    [ h3 [ class "mt-3" ] [ text "Code" ]
                                    , withMachine model.currentCpuState codePanel
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
            , startPausedCheckbox model.startPaused
            ]
        , toolbarSection "Run"
            [ Button.button
                [ if model.paused then
                    Button.primary

                  else
                    Button.outlinePrimary
                , Button.small
                , Button.attrs [ onClick TogglePause ]
                ]
                [ text
                    (if model.paused then
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
                    , Input.value (String.fromInt model.nsteps)
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
        , toolbarSection "Speed (relative to a real 8080 at 2 MHz)" (speedButtons model.speedFactor)
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
