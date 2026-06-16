# Glimble v1 — Plan 3: Distribution Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Ship Glimble: package the ad-hoc `Glimble.app` into a downloadable `.dmg`, provide a Homebrew cask for the user's own tap (`gum798/homebrew-glimble`), and document install + release.

**Architecture:** No-account distribution (spec §8). Packaging is shell (`hdiutil`); the cask is a Ruby file for the user's tap; install/Gatekeeper/permission guidance lives in `README.md` + the cask `caveats`. **Sparkle auto-update is intentionally deferred for v1** — tap-installed apps update via `brew upgrade --cask glimble`, so a second in-app updater would be redundant and would add ad-hoc/XPC signing complexity. Re-add Sparkle only if direct-download (non-Homebrew) users need in-app updates.

**Tech Stack:** `hdiutil` (DMG), `codesign` (ad-hoc, via existing `build-app.sh`), Homebrew Cask DSL, Markdown.

---

### Task 1: `release.sh` — package the app into a DMG

**Files:** Create `scripts/release.sh`

- [ ] **Step 1:** Create the script (content as implemented in this plan's commit — builds ad-hoc, stages the app + an `/Applications` symlink, makes a compressed DMG named `Glimble-<version>.dmg`, prints the sha256 for the cask).
- [ ] **Step 2:** Run `chmod +x scripts/release.sh && GLIMBLE_IDENTITY="-" ./scripts/release.sh` → produces `Glimble-<version>.dmg` and prints its sha256. Then `rm -f Glimble-*.dmg` (don't commit the artifact; it's gitignored).
- [ ] **Step 3:** Commit `scripts/release.sh`.

### Task 2: Homebrew cask for the tap

**Files:** Create `homebrew/glimble.rb`

- [ ] **Step 1:** Create the cask pointing at the GitHub release DMG, with `caveats` covering the one-time Gatekeeper bypass (`xattr -dr com.apple.quarantine` / "Open Anyway") and the two required permissions.
- [ ] **Step 2:** Commit. (The file is copied into `gum798/homebrew-glimble` as `Casks/glimble.rb` at publish time — see RELEASING.md.)

### Task 3: README

**Files:** Replace `ReadMe.md` (currently empty)

- [ ] **Step 1:** Write the README: what Glimble is, install (Homebrew tap + manual DMG), the Gatekeeper bypass, required permissions, default gestures, building from source, and the no-account/notarization-deferred note.
- [ ] **Step 2:** Commit.

### Task 4: Release runbook

**Files:** Create `docs/RELEASING.md`

- [ ] **Step 1:** Document the release steps: bump `CFBundleShortVersionString`/`CFBundleVersion`, run `release.sh`, create the GitHub release + upload the DMG, update the cask `version` + `sha256`, push to the `gum798/homebrew-glimble` tap. Include the one-time tap-repo creation steps.
- [ ] **Step 2:** Commit.

---

## Self-Review
- Spec §8 distribution (ad-hoc + GitHub + own tap, Gatekeeper bypass, permissions) → Tasks 1–4. Sparkle explicitly deferred with rationale. ✅
- User-gated at publish time (needs the user's GitHub repo + a created tap repo): the actual `gh release` upload and tap push — documented in RELEASING.md, not runnable in an automated session.
