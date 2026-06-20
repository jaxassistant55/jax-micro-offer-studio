# FreeJoy Consumer-Control HID Patch Notes

Source paid-help lead: https://github.com/FreeJoy-Team/FreeJoy/issues/249

Local checkout: `/Users/jax/autonomous_earning_run_2026-06-09/non_bounty/FreeJoy`

Patch artifact: `/Users/jax/autonomous_earning_run_2026-06-09/non_bounty/freejoy_consumer_keys.patch`

## What The Patch Does

- Adds `REPORT_ID_CONSUMER_KEYS` to the existing FreeJoy HID report IDs.
- Expands the joystick HID report descriptor size from 86 to 132 bytes.
- Adds a second top-level Consumer Control application collection to the existing joystick HID report descriptor.
- Advertises seven consumer-control usages: mute, volume up, volume down, play/pause, next track, previous track, and stop.
- Adds `consumer_keys.h` and `consumer_keys.c` to build a compact 2-byte consumer-control report.
- Maps the prototype consumer keys to logical buttons 120 through 126:
  - 120: mute
  - 121: volume up
  - 122: volume down
  - 123: play/pause
  - 124: next track
  - 125: previous track
  - 126: stop
- Wires the new source file into `armgcc/makefile.app`.
- Sends the consumer-control report on endpoint 1 only when the consumer bitmask changes, then resumes normal joystick reports when there is no consumer-key state change.

## Verification Completed

- `git diff --check` passed.
- Static `JoystickHID_ReportDescriptor` initializer count is 132 bytes.
- `JoystickHID_SIZ_REPORT_DESC` is 132 bytes.
- GitHub issue 249 was checked live: open, zero comments, updated 2025-03-24.
- `make -C armgcc app` was attempted, but this machine does not have `arm-none-eabi-gcc` installed.

## Important Limits

- This is a firmware-side consumer-control HID slice, not a complete configurator-integrated full keyboard implementation.
- It has not been flashed to STM32 hardware.
- It has not been validated against Windows, macOS, Linux, or game/controller host behavior.
- The logical-button mapping is a prototype mapping through buttons 120-126. A production merge should either confirm this mapping is acceptable or add configurator/protocol support for assigning consumer usages explicitly.
- Do not deliver or PR this patch as paid work until a real requester accepts scope and external payment proof exists, unless the user explicitly decides to publish it unpaid.

## Buyer-Facing Scope

Proposed $100 fixed-scope delivery:

- Provide the patch and explain the descriptor/report wiring.
- Include the current verification log.
- Include a short maintainer note describing the remaining configurator and hardware-validation gates.
- No hardware flashing, no device warranty, no platform-specific support guarantee, and no full keyboard matrix/configurator implementation unless separately scoped.
