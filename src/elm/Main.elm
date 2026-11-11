module Main exposing (main)

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
import Config exposing (clock, speed, steps_per_clock)
import Cpu exposing (checkForInterrupt, interrupt, keyPressed, keyReleased, nStep, nStep_withInterrupt)
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
    , ticks : Int
    , ticksDiff : Float
    , ticksDiffReal : Float
    , screen : Html Msg

    -- video RAM the current screen was rendered from, to skip redrawing an unchanged frame
    , lastFrame : Maybe (Array ByteValue)
    }


init : () -> ( Model, Cmd Msg )
init _ =
    ( Model Nothing Nothing (Invalid Nothing "No ROM loaded yet") 0 0 0 0 greenScreenHtml Nothing, Cmd.none )



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

        Emulation posix ->
            case model.currentCpuState of
                Valid currentCpuState ->
                    let
                        lastTicks =
                            model.ticks
                    in
                    ( { model
                        | currentCpuState = nStep 2000 currentCpuState
                        , ticks = Time.posixToMillis posix
                        , ticksDiff = toFloat (Time.posixToMillis posix - lastTicks)
                        , ticksDiffReal = toFloat (Time.posixToMillis posix - lastTicks)
                      }
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
                        lastTicks =
                            model.ticks
                    in
                    ( { model
                        | currentCpuState = nStep_withInterrupt steps_per_clock currentCpuState
                        , ticks = Time.posixToMillis posix
                        , ticksDiff = toFloat (Time.posixToMillis posix - lastTicks)
                        , ticksDiffReal = toFloat (Time.posixToMillis posix - lastTicks)
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
            init ()

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
    Model (Just data) (Just disassembledProgram) initialCpuState 0 0 0 0 greenScreenHtml Nothing



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
                , Grid.row []
                    [ Grid.col []
                        [ h3 [] [ text "Screen" ]
                        , model.screen
                        ]
                    , Grid.col []
                        [ h3 [] [ text "Machine State" ]
                        , pre [] [ text (cpustate model.currentCpuState) ]
                        , pre [] [ text ("speed: " ++ String.fromFloat speed ++ " ms for 1ms") ]
                        , pre [] [ text ("clock diff: " ++ String.fromFloat (model.ticksDiffReal - clock) ++ " ms") ]
                        ]
                    , Grid.col []
                        [ h3 [] [ text "Code" ]
                        , div [ class "code-wrapper" ] [ pre [] [ text (withDefault "" model.disassembledProgram) ] ]
                        ]
                    ]
                ]


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

        --, Time.every 1 Emulation
        --, Time.every 17 TickInterrupt
        , Time.every 40 RenderScreen -- TODO: Probably should use cycle count, but this will do for now
        , Time.every clock EmulationWithInterrupt
        ]
