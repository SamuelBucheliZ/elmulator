module UI.Msg exposing (..)

import Bytes exposing (Bytes)
import File exposing (File)
import Time


type Msg
    = RomRequested
    | RomSelected File
    | RomLoaded Bytes
    | NextStepsRequested Int
    | EmulationWithInterrupt Time.Posix
    | KeyDown GameKey
    | KeyUp GameKey
    | Reset
    | TickInterrupt Time.Posix
    | RenderScreen Time.Posix
    | InterruptRequested
    | StepsUpdated String
    | StepsSubmitted
    | SpeedSelected Float


type GameKey
    = Left
    | Right
    | Space
