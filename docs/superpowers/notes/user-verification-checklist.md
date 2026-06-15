# Glimble Phase 0 — User Verification Checklist

Everything buildable in an automated session is done and committed on branch `phase0-spike`:
the SwiftPM package, the tested pure geometry (`swift test` → 12 passing), the menu-bar spike
(touch capture + AX window snapping, compiles clean), and the signing/notarization scripts
(structurally verified with an ad-hoc dry-run).

What remains **requires your hardware + Apple Developer account** and can only be done by you.
Run these on a Mac with a built-in trackpad, signed in to the Apple Developer Program.
Full detail for each step lives in `docs/superpowers/plans/2026-06-15-glimble-phase0-risk-burndown.md`.

## Prerequisites (one-time)
- [ ] Apple Developer Program membership.
- [ ] A **Developer ID Application** identity in your keychain — check: `security find-identity -v -p codesigning` (the build session found **0**, so this is currently missing).
- [ ] A notary credential profile: `xcrun notarytool store-credentials glimble-notary --apple-id <id> --team-id <TEAMID> --password <app-specific-pw>`

## A. Live touch capture (Plan Task 5 / Task 10)
> Note: TCC grants are keyed to the running binary's code-signing identity. A grant given to
> the `swift run` dev binary does **not** carry over to the signed `.app` — the bundle will
> prompt again in section C/D. That re-prompt is expected, not a bug. `swift run` is fine for
> proving capture works; the bundle is what you ship.
- [ ] `swift run GlimbleSpike` (a `👆 –` item appears in the menu bar).
- [ ] Grant **Input Monitoring** when prompted (System Settings ▸ Privacy & Security ▸ Input Monitoring), then relaunch.
- [ ] Rest 2/3/4 fingers on the trackpad → the menu-bar count shows `👆 2` / `👆 3` / `👆 4`; lifting shows `👆 0`.
- [ ] Repeat across as many of macOS 15/26 × Intel/Apple-Silicon as you can reach; record pass/fail in `docs/superpowers/notes/openmultitouchsupport.md`.

## B. AX window snapping (Plan Task 6)
- [ ] With the app running, grant **Accessibility** (System Settings ▸ Privacy & Security ▸ Accessibility), relaunch.
- [ ] Focus **TextEdit** → menu **Snap Left** fills the left half under the menu bar; **Maximize** fills the visible frame.
- [ ] Focus **Google Chrome** → **Snap Right** snaps cleanly (this exercises the `AXEnhancedUserInterface` workaround).

## C. Sign + notarize (Plan Tasks 7–8)
- [ ] `GLIMBLE_IDENTITY="Developer ID Application: <NAME> (<TEAMID>)" ./scripts/build-app.sh` → ends with `Signed Glimble Spike.app`.
- [ ] `codesign -dvvv "Glimble Spike.app" 2>&1 | grep -E "Authority|flags"` → `Authority=Developer ID Application: …`, `flags=…runtime…`.
- [ ] `./scripts/notarize.sh` → `notarytool` prints **`status: Accepted`**; `stapler validate` → worked; `spctl -a -t exec -vv` → `source=Notarized Developer ID`, `accepted`.
- [ ] **If REJECTED:** `xcrun notarytool log <id> --keychain-profile glimble-notary` → paste JSON into the notes. **This is a project gate failure — stop and reassess before Phase 1.**

## D. Clean-machine Gatekeeper launch (Plan Task 9)
- [ ] Copy the stapled `Glimble Spike.app` to a clean macOS 26 machine that never built it; double-click.
- [ ] It launches with no "unverified developer" block and the menu-bar item appears. `spctl -a -t exec -vv "…/Glimble Spike.app"` → `accepted`, `Notarized Developer ID`.

## E. Record the gate decision (Plan Task 11)
- [ ] Fill `docs/superpowers/notes/phase0-gate.md` with PASS/FAIL per bet (notarization, capture matrix, AX snap, clean launch) and a GO / NO-GO for Phase 1.

---
When the gate is **GO**, ping me and we move to the Phase 1 plan (full gesture engine, RuleStore,
ActionExecutor, onboarding, Xcode-project migration, Sparkle). If anything is **NO-GO**, tell me
what failed and we adapt the design before building further.
