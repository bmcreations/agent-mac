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

## Lining actions up with frames

While a recording runs, each `vm ad` call is stamped on the guest clock before and after, and `vm record stop` writes `take-1.actions.json`: per call, its arguments, exit code, start and end in the movie, and `first_change_s`, the first tick after its start that got a new frame. The change happened between that tick and the one before, so it is an interval, `first_change_after_start_ms` relative to the call.

Any change on screen counts, a blinking caret or the menu bar clock too. `fresh_ticks_in_second_before` says how busy the screen was just before the call: near zero, the first change is likely the call's; with a caret blinking behind it, a Calculator launch "changed" the screen 0-14 ms after it started.

## Size

`rec` records at the display's point size. At the full 3840x2400, the encoder dropped 96 of 593 ticks in bursts at each keyframe; at 1920x1200 it dropped none.

Don't use `screencapture -v` for this. It writes frames only when the screen changes, and its `-V` limit counts media time, so on a still screen it never stops.

## What a guest can and can't tell you

The guest has a paravirtual GPU and a virtual display, so click-to-motion milliseconds and frame timing measured in it aren't the host's. Use the guest for continuity, black frames, sizes and layout, and for comparing one guest run with another. Measure latency on real hardware.

The `record-and-verify` skill lists the checks to run on a recording before calling motion fixed.
