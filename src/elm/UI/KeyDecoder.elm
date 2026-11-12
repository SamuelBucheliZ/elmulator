module UI.KeyDecoder exposing (keyDecoderDown, keyDecoderUp)

{-| Keyboard shortcuts of the emulator and the buttons of the arcade cabinet.

    l  load a ROM          p  pause / play
    r  reset               n  one step (pauses)
    e  run the steps given in the input box (pauses)
    i  interrupt

    cabinet buttons:  a left    d right    s fire    c coin
                      1 1P start    2 2P start

Keys pressed while typing in a text field (the step count) are ignored.

-}

import Cabinet exposing (gameKey, spaceInvaders)
import Json.Decode as Decode
import UI.Msg exposing (GameKey, Msg(..))


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

                    _ ->
                        case gameKey spaceInvaders key of
                            Just gameKeyPressed ->
                                Decode.succeed (KeyDown gameKeyPressed)

                            Nothing ->
                                Decode.fail "Pressed key is not an Elmulator shortcut"
            )


keyDecoderUp : Decode.Decoder Msg
keyDecoderUp =
    keyDecoder
        |> Decode.andThen
            (\key ->
                case gameKey spaceInvaders key of
                    Just gameKeyReleased ->
                        Decode.succeed (KeyUp gameKeyReleased)

                    Nothing ->
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
