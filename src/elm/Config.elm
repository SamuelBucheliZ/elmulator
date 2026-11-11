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


{-| Cycles between two video interrupts. Space Invaders gets one RST 1 at mid-frame and one RST 2
at the end of each frame, so an interrupt every 1/120 s at 2 MHz (60 frames per second). The
game re-enables interrupts in its RST 1 handler, so both vectors are needed.
-}
interruptPeriodCycles : Int
interruptPeriodCycles =
    16667


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
