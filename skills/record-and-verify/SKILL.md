---
name: record-and-verify
description: Use when a UI change involves motion, timing or a visual glitch (animations, transitions, resizing, flicker, black frames) and you're about to call it fixed or hand it to a person, so the claim rests on a recording rather than a few screenshots.
---

# Recording and checking UI motion in the guest

Screenshots miss what happens between them. A burst of stills at 5–7 fps
skipped a dark box mid-animation and a 900 ms delay that a person then found
by hand. Judge motion from a recording of every frame.

## Record

```sh
./vm record start 30                 # max seconds; holds the host awake
./vm ad click <ref>                  # trigger the motion
./vm record stop <dir> take-1        # take-1.mov, .ticks.json, .fps.json, .actions.json
```

Read `take-1.fps.json` before looking at the video:

- `dropped_ticks` must be 0 and `fps` close to 60. If not, the recording
  can't show a glitch either way; record again, don't judge it.
- `fresh_ticks` / duration is how often the screen actually changed. Under
  30 per second while something is moving is a stall, not a still screen.
- `dark_frames` above 0 is a black flash worth finding in the video.
- `longest_hold_ms` during motion shows a hitch.

`ticks.json` marks each 60 Hz tick 1 (new frame) or 0 (repeat), so you can
find the exact moment a stall starts.

`actions.json` lines up each `vm ad` call with the movie: `start_s`, and
`first_change_after_start_ms`, an interval for the first new frame after the
call started. Trust it only when `fresh_ticks_in_second_before` is near 0;
otherwise something else on screen (a caret, the clock) was changing. Guest
milliseconds aren't real hardware's: compare guest runs with each other.

## Cover what the person will do

One clean take proves one case. Before you call it fixed:

- Record at two window sizes, including the smallest the app allows. A fix
  that holds in a wide window can jump in a narrow one.
- Record every variant the change touches (each orientation, mode or state),
  not just the one you were looking at.
- Record the exact sequence the person reported, starting from the same state.
- Aim from a snapshot taken in that run. Coordinates from another run miss
  when the layout moves.

## Report

- Lead with each symptom the person reported, and for each say fixed, still
  there, or not checked.
- Name the build in the guest and the files: `.mov`, `.fps.json`, and any
  contact sheet you made.
- Measure latency (click-to-motion milliseconds) on real hardware, not in the
  guest: its GPU and display are virtual. The guest is right for continuity,
  black frames, sizes and layout, and for comparing one guest run with
  another.
- If a gate failed or you skipped a case, say which. Don't round it up to
  "works".
