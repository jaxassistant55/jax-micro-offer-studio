# EAX Haunted Cavern Reverb Matching Sprint Notes

Generated: 2026-06-20 16:07:20 JST
Public repo: https://github.com/datajake1999/EAXReverb_VST
Primary paid request: https://github.com/datajake1999/EAXReverb_VST/issues/3
Duplicate request: https://github.com/datajake1999/EAXReverb_VST/issues/2
Existing open PR to treat as prior context only: https://github.com/datajake1999/EAXReverb_VST/pull/4
Inspected main commit: `8aaaa4f`
Fixed first sprint: $100
Confirmed money: $0

## Why this is a feasibility and matching sprint

The public issue contains a direct willingness-to-pay signal, but an existing open PR already attempted a `HAUNTED_CAVERN` preset and a later issue comment says that attempt did not match the requested sound. Duplicating that PR or claiming implementation credit would be unsafe. The viable paid lane is a bounded matching sprint: identify the target sonic attributes, map them to the EAX property surface in this repo, define a test matrix, and hand off a patch-ready preset specification only after exact acceptance and external payment proof.

## Repo facts

- `src/EAXReverb.h` currently declares `kNumPrograms = 113` and stores `programs[kNumPrograms]`.
- `src/presets.cpp` wires preset indexes through both `SetReverbPreset` and `GetPresetName`; main currently covers cases `0..112`.
- `src/efx-presets.h` defines the EFX/EAX property macros. The built-in `CAVE`, `HANGAR`, `SEWERPIPE`, `DIZZY`, `PSYCHOTIC`, `CHAPEL`, and `SMALLWATERROOM` presets are useful comparison anchors, not final answers.
- `src/EAXReverb.cpp` maps plugin parameters to `EFXEAXREVERBPROPERTIES` and calls `UpdateEffect` after parameter edits.
- `src/EAXReverb_proc.cpp` loads `programs[curProgram].properties` into `ReverbEffect` before processing.
- `src/ReverbEffect.cpp` computes early reflection, late reverb, echo, and modulation behavior from the EAX properties.
- `scripts/build_mingw.bat` expects a sibling `..\VST2_SDK` directory, so a compiled DLL is outside this autonomous public-safe sprint.

## Deliverable

1. Target-sound checklist: tail length, darkness/HF damping, early reflection level, late-reverb density, echo timing/depth, and modulation depth.
2. Parameter target table for a `HAUNTED_CAVERN` preset, expressed as EAX/EFX properties that fit the current repo.
3. A/B comparison protocol against `CAVE`, `HANGAR`, `SEWERPIPE`, `DIZZY`, `PSYCHOTIC`, and the existing PR attempt if the buyer chooses to evaluate it.
4. Patch-ready specification showing exactly which tables need a new preset macro, switch case, display name, and `kNumPrograms` update.
5. Listening-test matrix that can be run with public or buyer-authorized references only.
6. Risk list for VST2 SDK availability, host differences, sample-rate differences, target-reference ambiguity, and exact-clone expectations.

## Non-goals

- No copied private or copyrighted audio.
- No private binary, paid plugin, license key, or credential handling.
- No VST2 SDK redistribution.
- No compiled DLL promise in the first $100 sprint.
- No public comment, PR, or direct buyer message without explicit send approval.
- No guarantee that the result exactly clones a proprietary or ambiguous reference.

## Suggested starting target bands

These are starting bands for discussion, not a final preset:

| Attribute | Starting target |
| --- | --- |
| Tail length | Longer than `CAVE`, shorter than extreme `DIZZY`; roughly 4.5s to 7.5s first-pass range |
| Darkness | Lower HF presence than `CAVE`; avoid metallic ringing |
| Reflections | Strong enough to feel cavernous, but not a slapback-only effect |
| Late reverb | Dense and wide, with a slow decay that does not bury transients |
| Echo | Subtle depth, used for spatial cue rather than obvious delay |
| Modulation | Light movement only; enough to avoid static tail, not chorus-like |

## Draft response, still not posted

I saw the Haunted Cavern request and the existing open PR. Because there is already a disputed first-pass preset, I would not claim that work or promise a full merged implementation up front. I can offer a narrow $100 matching sprint: inspect the current EAXReverb preset/property path, define the exact Haunted Cavern target attributes, map them to EAX parameters, create an A/B listening-test matrix against the existing presets and prior PR attempt, and hand off a patch-ready preset specification. I would not need private samples, paid plugins, license keys, credentials, payment data, or private binaries, and I would only post a public follow-up or PR after explicit approval.
