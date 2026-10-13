# SILKBOUND Android field-test checklist

**Existing documented reference build:** feature implementation commit `4e4b99802b44a7fe70d8239c2e2b39c1b2a3e9ab`. The more recent verified GitHub baseline is `c8c798571d1dba12b50459be778ac5b967947b05`, successful [Actions run 38304192370](https://github.com/westkitty/SilkBound/actions/runs/38304192370). **Do not mistake that APK for the newer, local uncommitted P001/P002/P003 title/death/navigation implementation.** Record the exact new APK SHA once Git delivery and CI are explicitly authorized.
**Source build:** [GitHub Actions run 38118392548](https://github.com/westkitty/SilkBound/actions/runs/38118392548).
**Artifact:** [Android debug APK + checksum](https://github.com/westkitty/SilkBound/actions/runs/38118392548/artifacts/11694422822). This debug build is temporary; check expiration before use.

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

11. **Scanner signal and viewport traversal:** at Ashlands, mine at least one material and scan repeatedly while moving between chunks. Verify the signal bearing changes with player position, old scan highlights expire, and terrain never disappears when the camera crosses chunk boundaries, zooms or changes orientation. Verify that distant terrain remains physically solid even when its artwork is offscreen.

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
| Scanner bearing and terrain visibility | NOT RUN | |

**Release gate:** A CI-green debug APK is not a hardware-qualified release. Keep draft PR #2 unmerged until material failures are fixed or explicitly accepted, and document the actual device proof.


## New Game OMNI shell field tests (local P001 / P002 / P003 candidate)

Run these against a future Android APK containing the **new shell commit**, not the earlier c8c7985 baseline. On a test device, back up any existing SilkBound `user://` save data before installing a destructive New Expedition candidate.

1. With no saved expedition, cold-launch offline in landscape. Confirm the full-screen-darkened ship title shows **Begin first expedition**, not a false Continue. Open Settings, change sound/handedness, use X and Android Back to return to the title; gameplay must not start until Begin.
2. Background/foreground and close the app while the initial title is open; reopen. No unconfirmed game save should have been created.
3. Begin and mine at least one actual resource. Use Pause -> Settings -> Back; verify Pause remains open and the world simulation remains suspended. Repeat Pause -> Field Log/Compendium -> Back.
4. Open Ship -> Navigation/Storage -> Back; confirm the correct Ship screen is restored. Back again returns to field play without spawning duplicate input listeners.
5. Use **Save and return to title**. Confirm Continue appears; selecting it restores the exact same seed, planet, ship, inventory, world edits and quest state. A failed save must keep the player in the field rather than presenting a false Continue.
6. From a valid-save title select **Begin a different expedition**. Back/cancel the irreversible confirmation; Continue and verify all old progress remains. Only perform Confirm after making a disposable or backed-up test save.
7. In a disposable test run, trigger final death. Confirm neither header X, Android Back, pause, nor an arbitrary tap can hide the final-death decision into an unusable world. Begin a new captain and confirm new progress is separate.
8. Relaunch an ended-run save to the memorial title; verify Continue is absent, Settings returns to title, canceled new-captain confirmation leaves the memorial intact, and explicit confirmation starts a different life.
9. Check the title and modal controls on a smaller phone and larger tablet at native landscape scale, with larger touch targets and both handed layouts. Record visual clipping, OS gesture overlap, any stuck inputs, and real device logs.

All nine checks are **NOT RUN on physical Android** for the new, uncommitted shell candidate. Local Godot 4.7.2 test mode did verify the behavioral paths with 234 assertions and rendered 1280x720 title/Settings captures.

## Game OMNI P004 / P006 native Android acceptance checklist

These tests apply to the next build **including** the local P004/P006 source. Prior successful CI APKs do not contain this batch.

- [ ] First-ever Begin shows stage 1/5. Move on the touch stick to progress; simply standing and receiving input must not falsely complete movement.
- [ ] Break actual mineable terrain with MINE (hold), then SCAN to reveal local materials; guide advances only on a real successful cut and scanner invocation.
- [ ] Craft shelter walls from obtainable materials in MAKE; guide detects real ingredient deduction. Revisit the ship with USE/SHIP to finish stage 5/5.
- [ ] Background, reopen and Continue between guide steps; progress and mined drops survive without extra resources or missing drops.
- [ ] Open Field Guide from Pause, Back returns to Pause; Skip remains optional and does not alter gameplay objectives, ship, or resources.
- [ ] On a compact phone, verify all ten action hitboxes are physically reachable, their labels readable and not overlapped by the status panel, movement stick or bottom rail.
- [ ] Swipe to hotbar slots 6–8; selecting them scrolls into view. Manually swipe without selecting a slot and verify the rail does not keep snapping back during refresh.
- [ ] Test left-handed layout and larger target size, including simultaneous movement+mining and finger releases outside controls; no stuck movement.
- [ ] Verify UI and modal behavior with landscape display cutouts/system gestures on phone and tablet. Measure actual coordinates or include a screenshot in the test record.
- [ ] Run the exact GitHub Android CI for the new commit and review verbose Godot lifetime messages; record object type and count separately from gameplay acceptance.

**Physical device status: NOT RUN.** No Android performance, thermals, or APK acceptance claim follows from a desktop screenshot.
