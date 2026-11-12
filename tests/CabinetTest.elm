module CabinetTest exposing (all)

import Cabinet exposing (gameKey, spaceInvaders)
import Expect
import Test exposing (..)
import UI.Msg exposing (GameKey(..))


all : Test
all =
    describe "Cabinet"
        [ test "Space Invaders keys" <|
            \() ->
                Expect.equal
                    [ Just Left, Just Right, Just Fire, Just Coin, Just Start1, Just Start2 ]
                    (List.map (gameKey spaceInvaders) [ "a", "d", "s", "c", "1", "2" ])
        , test "keys that are not game buttons have no meaning" <|
            \() ->
                Expect.equal
                    [ Nothing, Nothing, Nothing ]
                    (List.map (gameKey spaceInvaders) [ " ", "Enter", "ArrowLeft" ])
        ]
