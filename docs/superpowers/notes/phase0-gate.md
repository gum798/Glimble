# Phase 0 Gate — Results

Spike verified on the dev MacBook (macOS 26 Tahoe, Apple Silicon) on 2026-06-15.

| # | Bet | Result | Evidence |
|---|-----|--------|----------|
| 1 | Raw multitouch capture via private framework | **PASS** | App launched; OpenMultitouchSupport enumerated the built-in trackpad (DeviceID 504403158265495784, FamilyID 114) and the menu bar showed live `👆 2`/`👆 3` as fingers rested/lifted. |
| 2 | Public-AX window snapping + Chrome EnhancedUserInterface workaround | **PASS** | TextEdit **Snap Left** → left half under menu bar; **Maximize** → full visible frame; Google **Chrome Snap Right** → clean right half (exercises the EnhancedUserInterface disable/restore path). |
| 3 | OpenMultitouchSupport version/license/toolchain confirmed | **PASS** | Pinned `4.0.0`, MIT, swift-tools 6.2, dynamic XCFramework. See `openmultitouchsupport.md`. |
| 4 | Ad-hoc bundle assembles + signs (structural) | **PASS** | `build-app.sh` ad-hoc dry-run: framework embedded + re-signed, `@executable_path/../Frameworks` rpath added, `codesign --verify --strict` passed. |
| — | Notarization clears private framework | **DEFERRED** | Not a v1 bet — v1 ships no-account ad-hoc (spec §8). Re-evaluate only on a future Developer ID upgrade. |
| — | Clean-machine Gatekeeper launch | **DEFERRED** | Replaced by the ad-hoc quarantine-bypass flow (checklist C); not blocking for v1. |

## Coverage note
Verified on **macOS 26 / Apple Silicon only** (the available machine). The macOS 15 and Intel
cells of the original capture matrix were **not** tested in this session — no access. Not
treated as blocking: the framework works cleanly on the newest target. Validate the other
cells if/when those machines are available, or scope v1 to Apple Silicon + macOS 15–26.

## Decision

**GO for Phase 1.** The two v1-blocking bets (raw capture + AX window control) both pass on
real hardware, the dependency is pinned/licensed, and the ad-hoc distribution path is
structurally proven. No blockers.

Carry-forwards into the Phase 1 plan:
- Per-update TCC re-grant friction (ad-hoc) — surface in onboarding/release notes.
- Gatekeeper one-time "Open Anyway" — document in install instructions + the Homebrew tap.
- Optional later: validate Intel / macOS 15; upgrade to Developer ID notarization if the user
  base warrants removing the install friction.
