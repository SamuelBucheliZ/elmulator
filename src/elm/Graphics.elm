module Graphics exposing (Run, canvasHeight, canvasWidth, litRuns, renderScreen)

{-| Turns the video RAM of the 8080 into canvas drawing commands.

The video RAM (0x2400-0x3FFF) holds 224 rows of 32 bytes. Each bit is one
pixel, the least significant bit being the leftmost pixel of its byte. The
monitor is rotated, so a video RAM row becomes a canvas column and the pixel
position x within the row becomes the canvas row y = 255 - x.

The previous implementation created one `Renderable` per pixel (about 57k per
frame) and joined the lists with `List.foldl (++)`, which is quadratic. Here
`litRuns` computes one `Run` per horizontal run of lit pixels in the video RAM
(a vertical run on the canvas), and `renderScreen` draws the whole frame as one
black background plus one white fill containing all runs.

Both functions are pure functions of the video RAM, so the rendered frame can be
cached without touching the emulator state (which keeps step back/forward safe).

-}

import Array exposing (Array)
import Bitwise
import Canvas exposing (Renderable, Shape, rect, shapes)
import Canvas.Settings exposing (fill)
import Color
import EmulatorState exposing (ByteValue)


{-| Canvas width: one column per video RAM row.
-}
canvasWidth : Int
canvasWidth =
    224


{-| Canvas height: one row per pixel of a video RAM row.
-}
canvasHeight : Int
canvasHeight =
    256


{-| A vertical run of lit pixels on the canvas: column `x`, rows `y` to `y + length - 1`.
-}
type alias Run =
    { x : Int
    , y : Int
    , length : Int
    }


renderScreen : Array ByteValue -> List Renderable
renderScreen videoRam =
    [ shapes [ fill Color.black ]
        [ rect ( 0, 0 ) (toFloat canvasWidth) (toFloat canvasHeight) ]
    , shapes [ fill Color.white ]
        (List.map runToShape (litRuns videoRam))
    ]


runToShape : Run -> Shape
runToShape run =
    rect ( toFloat run.x, toFloat run.y ) 1 (toFloat run.length)



-- RUN LENGTH SCAN


bytesPerRow : Int
bytesPerRow =
    32


pixelsPerRow : Int
pixelsPerRow =
    256


{-| All lit pixels of the frame as runs, row by row.
-}
litRuns : Array ByteValue -> List Run
litRuns videoRam =
    List.concatMap (rowRuns videoRam) (List.range 0 (canvasWidth - 1))


{-| State while scanning one video RAM row from left to right.

`runStart` is the first lit pixel of the current run, or -1 when no run is open.

-}
type alias RowScan =
    { runStart : Int
    , runs : List Run
    }


emptyScan : RowScan
emptyScan =
    { runStart = -1, runs = [] }


rowRuns : Array ByteValue -> Int -> List Run
rowRuns videoRam row =
    let
        rowOffset =
            row * bytesPerRow

        scan =
            List.foldl (scanByte videoRam row rowOffset) emptyScan (List.range 0 (bytesPerRow - 1))
                |> closeRunAt row (pixelsPerRow - 1)
    in
    scan.runs


scanByte : Array ByteValue -> Int -> Int -> Int -> RowScan -> RowScan
scanByte videoRam row rowOffset byteIndex scan =
    let
        byte =
            Array.get (rowOffset + byteIndex) videoRam
                |> Maybe.withDefault 0

        firstPixel =
            byteIndex * 8
    in
    if byte == 0 then
        -- fast path: no lit pixel in this byte, so any open run ends just before it
        closeRunAt row (firstPixel - 1) scan

    else
        List.foldl (scanBit row byte firstPixel) scan (List.range 0 7)


scanBit : Int -> ByteValue -> Int -> Int -> RowScan -> RowScan
scanBit row byte firstPixel bit scan =
    let
        x =
            firstPixel + bit

        isLit =
            Bitwise.and (Bitwise.shiftRightBy bit byte) 1 == 1
    in
    if isLit then
        if scan.runStart < 0 then
            { scan | runStart = x }

        else
            scan

    else
        closeRunAt row (x - 1) scan


{-| Ends the open run (if any) with its last lit pixel at `lastPixel`.
-}
closeRunAt : Int -> Int -> RowScan -> RowScan
closeRunAt row lastPixel scan =
    if scan.runStart < 0 then
        scan

    else
        { runStart = -1
        , runs = toRun row scan.runStart lastPixel :: scan.runs
        }


{-| Converts a run of native pixels (video RAM row `row`, x from `firstPixel` to
`lastPixel`) to canvas coordinates: column = row, canvas y = 255 - x.
-}
toRun : Int -> Int -> Int -> Run
toRun row firstPixel lastPixel =
    { x = row
    , y = 255 - lastPixel
    , length = lastPixel - firstPixel + 1
    }
