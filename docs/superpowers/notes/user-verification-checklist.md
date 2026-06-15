# Glimble Phase 0 — User Verification Checklist

Everything buildable in an automated session is done and committed on branch `phase0-spike`:
the SwiftPM package, the tested pure geometry (`swift test` → 12 passing), the menu-bar spike
(touch capture + AX window snapping, compiles clean), and the signing/notarization scripts
(structurally verified with an ad-hoc dry-run).

**Distribution decision (2026-06-15):** v1 ships **no-account ad-hoc signing + GitHub releases +
your own Homebrew tap** — see spec §8. So **no Apple Developer account is needed** for the
Phase 0 gate. The whole gate (A–E) is now doable on this MacBook (Apple Silicon, macOS 26).
Full detail: `docs/superpowers/plans/2026-06-15-glimble-phase0-risk-burndown.md`.

## Prerequisites
- [ ] A Mac with a **built-in trackpad** (this one qualifies). Nothing else — no paid account.
- [ ] (Only if you later upgrade to notarization) Apple Developer Program + a Developer ID
      identity (`security find-identity -v -p codesigning`) + a `notarytool` profile.

## A. Live touch capture (Plan Task 5 / Task 10)
> Note: TCC grants are keyed to the running binary's code-signing identity. A grant given to
> the `swift run` dev binary does **not** carry over to the ad-hoc `.app` (section C) — the
> bundle will prompt again. That re-prompt is expected, not a bug. `swift run` is fine for
> proving capture works; the bundle is what you ship.
- [ ] `swift run GlimbleSpike` (a `👆 –` item appears in the menu bar).
- [ ] Grant **Input Monitoring** when prompted (System Settings ▸ Privacy & Security ▸ Input Monitoring), then relaunch.
- [ ] Rest 2/3/4 fingers on the trackpad → the menu-bar count shows `👆 2` / `👆 3` / `👆 4`; lifting shows `👆 0`.
- [ ] Repeat across as many of macOS 15/26 × Intel/Apple-Silicon as you can reach; record pass/fail in `docs/superpowers/notes/openmultitouchsupport.md`.

## B. AX window snapping (Plan Task 6)
- [ ] With the app running, grant **Accessibility** (System Settings ▸ Privacy & Security ▸ Accessibility), relaunch.
- [ ] Focus **TextEdit** → menu **Snap Left** fills the left half under the menu bar; **Maximize** fills the visible frame.
- [ ] Focus **Google Chrome** → **Snap Right** snaps cleanly (this exercises the `AXEnhancedUserInterface` workaround).

## C. Ad-hoc bundle + Gatekeeper-bypass launch (no account)
This proves the real distribution path: an ad-hoc `.app` that a user downloads, un-quarantines once, and runs.
- [ ] `GLIMBLE_IDENTITY="-" ./scripts/build-app.sh` → ends with `Signed Glimble Spike.app` (ad-hoc).
- [ ] `codesign -dvvv "Glimble Spike.app" 2>&1 | grep -E "Signature|flags"` → `Signature=adhoc`, `flags=…runtime…`.
- [ ] Simulate a download (apply quarantine, then do the user's one-time bypass):
      `xattr -w com.apple.quarantine "0081;0;Safari;" "Glimble Spike.app"` then
      `open "Glimble Spike.app"` → confirm macOS blocks it (Gatekeeper). Then remove it the way a
      user would: `xattr -dr com.apple.quarantine "Glimble Spike.app"` and `open` again → it launches,
      menu-bar item appears, finger counts + snapping work after granting the two permissions to the bundle.
- [ ] (Optional, real end-to-end) zip it (`ditto -c -k --keepParent "Glimble Spike.app" Glimble.zip`),
      upload to a GitHub release, download on another Mac, and confirm the "Open Anyway" flow in
      System Settings ▸ Privacy & Security works.

## D. Record the gate decision (Plan Task 11)
- [ ] Fill `docs/superpowers/notes/phase0-gate.md` with PASS/FAIL per bet — **capture matrix (A)** and
      **AX snap (B)** are the v1-blocking bets; ad-hoc launch (C) confirms the distribution path.
      Notarization is **not** a v1 bet (deferred with the no-account decision). Then a GO / NO-GO for Phase 1.

---
When the gate is **GO**, ping me and we move to the Phase 1 plan (full gesture engine, RuleStore,
ActionExecutor, onboarding, the Homebrew tap + release packaging, Sparkle). If anything is **NO-GO**,
tell me what failed and we adapt the design before building further.
