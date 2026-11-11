# Recording

```sh
vm record start 30
# ... act ...
vm record stop ./recordings take-1
```

`vm record` runs `rec` in the guest: ScreenCaptureKit at up to 60 Hz, with a 60 Hz wall-clock timer that writes the latest frame on each tick. The result:

- `take-1.mov`: constant 60 fps. A frame repeats when the screen hasn't changed, and the recording stops on time even on a still screen.
- `take-1.ticks.json`: one entry per tick, `1` when a new frame arrived and `0` for a repeat. This tells a still screen from a stalled capture.
- `take-1.fps.json`: frames over duration, distinct frames, dark frames, ticks the encoder dropped, the fresh-frame rate, and the longest hold.

## Size

`rec` records at the display's point size. At the full 3840x2400, the encoder dropped 96 of 593 ticks in bursts at each keyframe; at 1920x1200 it dropped none.

Don't use `screencapture -v` for this. It writes frames only when the screen changes, and its `-V` limit counts media time, so on a still screen it never stops.

## What a guest can and can't tell you

The guest has a paravirtual GPU and a virtual display, so click-to-motion milliseconds and frame timing measured in it aren't the host's. Use the guest for continuity, black frames, sizes and layout, and for comparing one guest run with another. Measure latency on real hardware.

The `record-and-verify` skill lists the checks to run on a recording before calling motion fixed.
