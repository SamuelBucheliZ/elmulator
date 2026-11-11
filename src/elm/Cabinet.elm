module Cabinet exposing (Cabinet, gameKey, spaceInvaders)

{-| A profile of the arcade machine the emulator plays: which keyboard keys press which
buttons, and the state of its ports at power on.

Space Invaders is the only cabinet so far. The bit layout of the ports that a button
sets is in IO.keyEvent.

-}

import EmulatorState exposing (Ports)
import UI.Msg exposing (GameKey(..))


type alias Cabinet =
    { name : String
    , keys : List ( String, GameKey )

    -- bit 3 is always 1; no button is pressed at power on
    , initialPorts : Ports
    }


spaceInvaders : Cabinet
spaceInvaders =
    { name = "Space Invaders"
    , keys =
        [ ( "a", Left )
        , ( "d", Right )
        , ( "s", Fire )
        , ( "c", Coin )
        , ( "1", Start1 )
        , ( "2", Start2 )
        ]
    , initialPorts = Ports 8 8
    }


{-| The button that a keyboard key presses, if the cabinet has one.
-}
gameKey : Cabinet -> String -> Maybe GameKey
gameKey cabinet key =
    cabinet.keys
        |> List.filter (\( keyName, _ ) -> keyName == key)
        |> List.head
        |> Maybe.map Tuple.second
