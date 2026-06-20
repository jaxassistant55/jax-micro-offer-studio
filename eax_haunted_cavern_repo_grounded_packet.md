# EAX Haunted Cavern Repo-Grounded Handoff Packet

Generated: 2026-06-20 15:12:08 JST
Offer page: https://jaxassistant55.github.io/jax-micro-offer-studio/eax-haunted-cavern-reverb-matching-sprint.html
Public repo: https://github.com/datajake1999/EAXReverb_VST
Local public clone: `/Users/jax/autonomous_earning_run_2026-06-09/non_bounty/EAXReverb_VST`
Inspected main commit: `8aaaa4f`
Primary paid request: https://github.com/datajake1999/EAXReverb_VST/issues/3
Duplicate request: https://github.com/datajake1999/EAXReverb_VST/issues/2
Prior open PR context: https://github.com/datajake1999/EAXReverb_VST/pull/4
Fixed first sprint: $100
Confirmed money: $0

## Current issue state

The primary issue asks for a Haunted Cavern reverb and says the requester is willing to pay. A prior contributor opened PR #4 to add a `HAUNTED_CAVERN` preset, but a later comment says the attempted preset was not close to the requested effect. That makes direct implementation or duplicate PR work a poor autonomous target. The safe offer is a matching and validation sprint that can be claimed only after exact buyer acceptance and payment proof.

## Files inspected

1. `src/EAXReverb.h`
   - `kNumPrograms = 113` on main.
   - The plugin stores `EAXReverbProgram programs[kNumPrograms]`.
   - A new preset requires increasing the program count and preserving array bounds.

2. `src/presets.cpp`
   - `SetReverbPreset` maps preset indexes to EFX preset macros.
   - `GetPresetName` maps the same indexes to display names.
   - Main currently ends at index 112 with `SMALLWATERROOM`; a new preset must update both switch tables.

3. `src/efx-presets.h`
   - Contains `EFXEAXREVERBPROPERTIES` fields: density, diffusion, gain, HF/LF gain, decay time, decay ratios, reflections, late reverb, echo, modulation, air absorption, references, room rolloff, and decay-HF limit.
   - The built-in `CAVE` preset is the closest obvious baseline, while `HANGAR`, `SEWERPIPE`, `DIZZY`, `PSYCHOTIC`, `CHAPEL`, and `SMALLWATERROOM` provide contrast points for tail length, darkness, echo, and modulation.

4. `src/EAXReverb.cpp`
   - Plugin parameters write into `programs[curProgram].properties`.
   - `UpdateEffect` is called after parameter changes in the property range.
   - The UI/display layer already exposes the relevant EAX properties.

5. `src/EAXReverb_proc.cpp`
   - `UpdateEffect` loads the current program properties into `ReverbEffect`.
   - Audio is processed block-by-block through `ReverbEffectProcess`.

6. `src/ReverbEffect.cpp` and `src/ReverbEffect.h`
   - The reverb engine computes early reflections, late reverb, echo, modulation, delay lines, and damping from the EAX properties.
   - A credible matching sprint should tune property values and validate behavior, not modify the core engine first.

7. `scripts/build_mingw.bat`
   - The build command expects `..\VST2_SDK`.
   - First-sprint delivery should not promise a DLL unless the buyer separately provides a lawful build setup.

8. `readme.md` and `LICENSE.TXT`
   - The project is LGPL-oriented and based on the OpenAL Soft EAX reverb implementation lineage.
   - Any future patch should preserve license notices and avoid importing proprietary audio or SDK material.

## Exact user steps to claim this lane

1. Open the live offer page: https://jaxassistant55.github.io/jax-micro-offer-studio/eax-haunted-cavern-reverb-matching-sprint.html
2. Open this packet: https://jaxassistant55.github.io/jax-micro-offer-studio/eax_haunted_cavern_repo_grounded_packet.md
3. Open the prepared notes: https://jaxassistant55.github.io/jax-micro-offer-studio/eax_haunted_cavern_reverb_matching_notes.md
4. Add only a seller-owned checkout, invoice, marketplace order, or payment-request URL. Do not ask Codex to create a payment processor account, KYC, tax, payout, or refund setup.
5. Open the primary public lead: https://github.com/datajake1999/EAXReverb_VST/issues/3
6. Review the existing open PR before contacting anyone: https://github.com/datajake1999/EAXReverb_VST/pull/4
7. Do not claim the prior PR or imply the first-pass preset is yours.
8. If you decide to contact the requester, use the draft response only after you approve it.
9. Require this exact acceptance before payment:

   I accept the EAX Haunted Cavern Reverb Matching Sprint fixed-scope terms at $100. I understand work starts only after seller-owned external payment proof exists; I will provide only public or buyer-authorized target audio references and non-sensitive notes; the deliverable is limited to a repo-grounded parameter target plan, comparison checklist, tuning and listening-test matrix, and patch-ready preset specification; and private audio extraction, copyrighted or private sample redistribution, VST SDK redistribution, compiled DLL delivery, public comment posting, pull request posting, exact clone guarantee, plugin-host support, or ongoing revisions are not included unless separately agreed before payment.

10. Ask the buyer for public or buyer-authorized target references only. Do not accept private copyrighted stems, paid plugin binaries, license keys, credentials, payment data, or private files.
11. Wait for external payment proof. If payment is pending, estimated, reversible, disputed, or not under your control, count $0.
12. Deliver the repo-grounded packet, notes, target-parameter table, and tuning/test matrix after proof.
13. Capture proof: buyer URL/message, exact accepted scope, payment reference, amount, fees, refund/hold state, delivery URL, buyer/platform acceptance if required, payout/payable/cleared status, and date.
14. Update the tracker only after posted, released, funded, payable, cleared, credited, or verified net money exists.

## Draft public response, still not posted

I saw the Haunted Cavern request and the existing open PR. Because there is already a disputed first-pass preset, I would not claim that work or promise a full merged implementation up front. I can offer a narrow $100 matching sprint: inspect the current EAXReverb preset/property path, define the exact Haunted Cavern target attributes, map them to EAX parameters, create an A/B listening-test matrix against the existing presets and prior PR attempt, and hand off a patch-ready preset specification. I would not need private samples, paid plugins, license keys, credentials, payment data, or private binaries, and I would only post a public follow-up or PR after explicit approval.
