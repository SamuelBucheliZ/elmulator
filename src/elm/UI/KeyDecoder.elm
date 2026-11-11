module UI.KeyDecoder exposing (keyDecoderDown, keyDecoderUp)

{-| Keyboard shortcuts. The keys are shown in the button labels.

    l  load a ROM          p  pause / play
    r  reset               n  one step (pauses)
    e  run the steps given in the input box (pauses)
    i  interrupt
    a d s  the game keys: left, right, fire

Keys pressed while typing in a text field (the step count) are ignored.

-}

import Json.Decode as Decode
import UI.Msg exposing (GameKey(..), Msg(..))


keyDecoderDown : Decode.Decoder Msg
keyDecoderDown =
    keyDecoder
        |> Decode.andThen
            (\key ->
                case key of
                    "l" ->
                        Decode.succeed RomRequested

                    "p" ->
                        Decode.succeed TogglePause

                    "r" ->
                        Decode.succeed Reset

                    "n" ->
                        Decode.succeed (NextStepsRequested 1)

                    "e" ->
                        Decode.succeed StepsSubmitted

                    "i" ->
                        Decode.succeed InterruptRequested

                    "a" ->
                        Decode.succeed (KeyDown Left)

                    "d" ->
                        Decode.succeed (KeyDown Right)

                    "s" ->
                        Decode.succeed (KeyDown Space)

                    _ ->
                        Decode.fail "Pressed key is not an Elmulator shortcut"
            )


keyDecoderUp : Decode.Decoder Msg
keyDecoderUp =
    keyDecoder
        |> Decode.andThen
            (\key ->
                case key of
                    "a" ->
                        Decode.succeed (KeyUp Left)

                    "d" ->
                        Decode.succeed (KeyUp Right)

                    "s" ->
                        Decode.succeed (KeyUp Space)

                    _ ->
                        Decode.fail "Pressed key is not an Elmulator shortcut"
            )


{-| The pressed key, unless it was typed into a text field.
-}
keyDecoder : Decode.Decoder String
keyDecoder =
    Decode.map2 Tuple.pair
        (Decode.field "key" Decode.string)
        (Decode.at [ "target", "tagName" ] Decode.string)
        |> Decode.andThen
            (\( key, tagName ) ->
                if tagName == "INPUT" || tagName == "TEXTAREA" then
                    Decode.fail "typing in a text field"

                else
                    Decode.succeed key
            )
