module Main exposing (Model, initialModel, main, update)

import Array exposing (Array)
import Bootstrap.Button as Button
import Bootstrap.CDN as CDN
import Bootstrap.Form.Input as Input
import Bootstrap.Grid as Grid
import Browser
import Browser.Events
import Bytes exposing (Bytes)
import Canvas exposing (Renderable, rect, shapes)
import Canvas.Settings exposing (fill)
import Color exposing (Color)
import Config exposing (baseCyclesPerSecond, defaultSpeedFactor, interruptPeriodCycles, sliceInterval, speedFactors)
import Cpu exposing (checkForInterrupt, interrupt, keyPressed, keyReleased, nStep, runCycles)
import EmulatorState exposing (ByteValue, EmulatorState(..), MachineState)
import File exposing (File)
import File.Select as Select
import FileDecoder exposing (decodeFile)
import Graphics exposing (canvasHeight, canvasWidth, renderScreen)
import Html exposing (Html, div, h1, h3, p, pre, text)
import Html.Attributes exposing (class, height, width)
import Html.Events exposing (onClick)
import Instruction exposing (Instruction, instructionToString)
import InstructionDisassembler exposing (disassembleToInstructions)
import Maybe exposing (withDefault)
import Memory exposing (readMemorySlice)
import Task
import Time
import UI.Formatter exposing (cpustate)
import UI.KeyDecoder exposing (keyDecoderDown, keyDecoderUp)
import UI.Msg exposing (Msg(..))



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
    , disassembledProgram : Maybe String
    , currentCpuState : EmulatorState
    , nsteps : Int
    , speedFactor : Float

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
    , disassembledProgram = Nothing
    , currentCpuState = Invalid Nothing "No ROM loaded yet"
    , nsteps = 0
    , speedFactor = defaultSpeedFactor
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
            case model.currentCpuState of
                Valid currentCpuState ->
                    ( { model | currentCpuState = nStep n currentCpuState }
                    , Cmd.none
                    )

                Invalid _ _ ->
                    ( model
                    , Cmd.none
                    )

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

        TickInterrupt _ ->
            case model.currentCpuState of
                Valid currentCpuState ->
                    ( { model | currentCpuState = checkForInterrupt currentCpuState }
                    , Cmd.none
                    )

                Invalid _ _ ->
                    ( model
                    , Cmd.none
                    )

        EmulationWithInterrupt posix ->
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
            ( { initialModel | speedFactor = model.speedFactor }, Cmd.none )

        SpeedSelected factor ->
            ( { model | speedFactor = factor }, Cmd.none )

        StepsUpdated n ->
            ( { model | nsteps = Maybe.withDefault 0 (String.toInt n) }, Cmd.none )

        StepsSubmitted ->
            case model.currentCpuState of
                Valid currentCpuState ->
                    ( { model | currentCpuState = nStep model.nsteps currentCpuState }
                    , Cmd.none
                    )

                Invalid _ _ ->
                    ( model
                    , Cmd.none
                    )


loadDataIntoMemory : Model -> Bytes -> Model
loadDataIntoMemory _ data =
    let
        decodedFile =
            decodeFile data

        initialCpuState =
            Cpu.init decodedFile

        disassembledProgram =
            disassemble data
    in
    { initialModel
        | data = Just data
        , disassembledProgram = Just disassembledProgram
        , currentCpuState = initialCpuState
    }



-- VIEW


disassemble : Bytes -> String
disassemble data =
    let
        decodedFile =
            decodeFile data

        disassembledFile =
            disassembleToInstructions decodedFile
    in
    String.join "\n" (List.map instructionToString disassembledFile)


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
                        ]
                    ]
                ]

        Just _ ->
            Grid.container []
                [ CDN.stylesheet -- creates an inline style node with the Bootstrap CSS
                , pageHeader
                , Button.button
                    [ Button.outlinePrimary
                    , Button.attrs
                        [ onClick (NextStepsRequested 1)
                        ]
                    ]
                    [ text "(n)ext step" ]
                , text "   "
                , Input.text [ Input.id "steps", Input.onInput StepsUpdated, Input.value (String.fromInt model.nsteps) ]
                , Button.button [ Button.outlinePrimary, Button.attrs [ onClick StepsSubmitted ] ] [ text "n(e)xt n steps" ]
                , text "   "
                , Button.button
                    [ Button.outlinePrimary
                    , Button.attrs
                        [ onClick (NextStepsRequested 20000)
                        ]
                    ]
                    [ text "ne(x)t 20000 steps" ]
                , text "   "
                , Button.button
                    [ Button.outlinePrimary
                    , Button.attrs
                        [ onClick InterruptRequested
                        ]
                    ]
                    [ text "(i)nterrupt" ]
                , text "   "
                , Button.button
                    [ Button.outlineDanger
                    , Button.attrs
                        [ onClick Reset
                        ]
                    ]
                    [ text "(r)eset" ]
                , speedControls model.speedFactor
                , Grid.row []
                    [ Grid.col []
                        [ h3 [] [ text "Screen" ]
                        , model.screen
                        ]
                    , Grid.col []
                        [ h3 [] [ text "Machine State" ]
                        , pre [] [ text (cpustate model.currentCpuState) ]
                        , pre [] [ text ("speed: " ++ String.fromFloat model.speedFactor ++ "x (target " ++ megahertz (baseCyclesPerSecond * model.speedFactor) ++ " MHz)") ]
                        , pre [] [ text ("measured: " ++ megahertz (toFloat model.measuredCyclesPerSecond) ++ " MHz") ]
                        ]
                    , Grid.col []
                        [ h3 [] [ text "Code" ]
                        , div [ class "code-wrapper" ] [ pre [] [ text (withDefault "" model.disassembledProgram) ] ]
                        ]
                    ]
                ]


{-| Formats a cycles per second value as MHz with two decimals.
-}
megahertz : Float -> String
megahertz cyclesPerSecond =
    String.fromFloat (toFloat (round (cyclesPerSecond / 10000)) / 100)


speedControls : Float -> Html Msg
speedControls selected =
    div [] <|
        text "speed:  "
            :: List.map
                (\factor ->
                    Button.button
                        [ if factor == selected then
                            Button.primary

                          else
                            Button.outlinePrimary
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
        []
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
