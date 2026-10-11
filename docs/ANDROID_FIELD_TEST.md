# SILKBOUND Android field-test checklist

**Build under test:** feature commit `4c6ad74a8373c226ec9a13b0dcf268417224660f`.
**Source build:** [GitHub Actions run 38115856673](https://github.com/westkitty/SilkBound/actions/runs/38115856673).
**Artifact:** [Android debug APK + checksum](https://github.com/westkitty/SilkBound/actions/runs/38115856673/artifacts/11692704418). This debug build is temporary; check expiration before use.

Record test device model, Android version, display dimensions, scaling, fresh install vs upgrade, input devices, build SHA, and whether this is a real phone, tablet, or emulator. Retain recorded evidence without publishing personal device identifiers.

## Test protocol (record PASS / FAIL / NOT RUN and evidence for each)

1. **Cold start and offline operation:** install the APK, launch in landscape with network disabled, find ship, move, mine guaranteed starter scrap and obtain items. No account or connection prompt should appear.
2. **True simultaneous touch:** hold the movement stick with one finger while repeatedly pressing jump and mining with a separate finger. No unrelated action should be canceled.
3. **Release outside the control:** hold MINE, drag that finger beyond the MINE button and lift elsewhere on the screen; mining should stop without stopping another active finger's movement. Repeat separately with the movement stick and jump. No controls should remain latched.
4. **Layout change and interruption:** enter settings, switch left-handed layout, enlarge then shrink touch targets, resume. Pause mid-action, background/foreground the app, and return. No movement, mining, jump or hit action should resume spontaneously.
5. **Return travel and safe reentry:** collect 6 scrap + 4 ferrite, repair drive, visit Glassfall, return, save/restart, and resume. Check that velocity and jump input do not carry between worlds and the captain does not appear within solid terrain. Test terrain edits/shelters survive.
6. **Timed Glassfall evidence:** follow the HUD east/west cell bearing, scan the original ridge before the geological shear, inspect **Glassfall / Before** in compendium, witness the physical changed terrain, scan the altered ridge, and inspect **Glassfall / After**. Preserve the result through process restart.
7. **Full progression:** fabricate the coolant loop, reach Drowned Remnant, interact with Vale, revisit earlier planets, and check quests, inventory and terrain changes. Do not invent a canon outcome from observed gameplay.
8. **Legibility and accessibility:** inspect the status objective, multi-material scan messages, bottom hotbar, utility controls, UI modals, left-handed layout and enlarged targets at the device's native scale. Check reduced-flash/shake settings, bright terrain and darker screen areas.
9. **Session resilience:** play at least 15 minutes. Note stutter, frame-time spikes, battery drain, device heating, sound glitches and whether touch-control release failures accumulate.
10. **Proof and comparison:** where possible, record a 30-60 s screen capture of the controls, a 30-60 s Glassfall sequence, save/load evidence and an instrumented before/after run on the same device. Do not report an FPS uplift without matched measurements.

## Results to preserve

| Check | PASS / FAIL / NOT RUN | Device evidence / notes |
|---|---|---|
| Offline first launch and salvage | NOT RUN | |
| Two-plus-finger input | NOT RUN | |
| Lift outside controls | NOT RUN | |
| Pause / settings / background | NOT RUN | |
| Safe world return and resume | NOT RUN | |
| Glassfall before/after | NOT RUN | |
| Drowned Remnant + persistent progress | NOT RUN | |
| UI sizing and reduced effects | NOT RUN | |
| Long-session reliability | NOT RUN | |
| Matched performance numbers | NOT RUN | |

**Release gate:** A CI-green debug APK is not a hardware-qualified release. Keep draft PR #2 unmerged until material failures are fixed or explicitly accepted, and document the actual device proof.
