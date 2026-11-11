module Config exposing (..)

{-| Emulation timing, in terms of the real Intel 8080 clock.

The emulator runs in short slices, driven by a timer. Each slice advances the
emulated clock by the number of cycles that the speed factor selected in the UI
asks for:

    cycles per second =
        baseCyclesPerSecond * speed factor

so a speed factor of 1 is the speed of a real 8080 at 2 MHz.

-}


{-| The clock of the Intel 8080, in cycles per second.
-}
baseCyclesPerSecond : Float
baseCyclesPerSecond =
    2000000


{-| Cycles between two RST 2 interrupts: 60 interrupts per second at 2 MHz, as in the
video timing of Space Invaders.
-}
interruptPeriodCycles : Int
interruptPeriodCycles =
    33333


{-| Milliseconds between two emulation slices (about 60 per second).
-}
sliceInterval : Float
sliceInterval =
    16


{-| Selectable speed factors.
-}
speedFactors : List Float
speedFactors =
    [ 0.25, 0.5, 1, 2, 4 ]


defaultSpeedFactor : Float
defaultSpeedFactor =
    1
