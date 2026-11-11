module KeyDecoderTest exposing (all)

import Expect
import Json.Decode as Decode
import Test exposing (..)
import UI.KeyDecoder exposing (keyDecoderDown, keyDecoderUp)


pressed : String -> String -> Result Decode.Error String
pressed key tagName =
    Decode.decodeString keyDecoderDown
        ("{\"key\":\"" ++ key ++ "\",\"target\":{\"tagName\":\"" ++ tagName ++ "\"}}")
        |> Result.map Debug.toString


all : Test
all =
    describe "keyboard shortcuts"
        [ test "p toggles pause" <|
            \() ->
                pressed "p" "BODY"
                    |> Expect.equal (Ok "TogglePause")
        , test "n is a single step" <|
            \() ->
                pressed "n" "BODY"
                    |> Expect.equal (Ok "NextStepsRequested 1")
        , test "x no longer does anything" <|
            \() ->
                pressed "x" "BODY"
                    |> Expect.err
        , test "keys typed into the step count box are ignored" <|
            \() ->
                pressed "e" "INPUT"
                    |> Expect.err
        , test "the game keys are still decoded" <|
            \() ->
                Decode.decodeString keyDecoderUp "{\"key\":\"s\",\"target\":{\"tagName\":\"BODY\"}}"
                    |> Result.map Debug.toString
                    |> Expect.equal (Ok "KeyUp Space")
        ]
