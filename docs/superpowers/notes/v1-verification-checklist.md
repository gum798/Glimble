# Glimble v1 — Hardware Verification Checklist

Everything in v1 is implemented, builds clean, passes 42 unit tests, and packages into an
ad-hoc `Glimble.app` / `.dmg`. What an automated session can't do is **run the GUI and perform
real trackpad gestures** — that's this checklist. Run it on this MacBook (Apple Silicon,
macOS 26); no Apple account needed. Branch: `phase1-v1`.

## 1. Launch & permissions
- [ ] `swift run GlimbleApp` → `👆` appears in the menu bar; the **Welcome to Glimble**
      onboarding window opens on first run.
- [ ] Click **Grant…** for **Input Monitoring** → toggle Glimble on in System Settings →
      relaunch (`swift run GlimbleApp` again). The onboarding row shows a green check.
- [ ] Click **Grant…** for **Accessibility** → toggle on. Row shows green.

## 2. Default gestures (the curated presets)
With both permissions granted:
- [ ] Focus a window (e.g. TextEdit). **3-finger tap** → window **maximizes**.
- [ ] **4-finger tap** → window **centers** (60% size, centered).
- [ ] **3-finger swipe left** → window snaps to the **left half**.
- [ ] **3-finger swipe right** → window snaps to the **right half**.
- [ ] Verify a normal 1-finger move and 2-finger scroll do **nothing** (no false triggers).

## 3. Settings — rule list
- [ ] Menu-bar ▸ **Settings…** opens the window showing **4 rules**.
- [ ] Toggle a rule off → perform its gesture → nothing happens. Toggle on → it works again.
      (Changes take effect live, no restart.)
- [ ] Delete a rule (trash icon) → its gesture stops working. (It's removed from
      `~/Library/Application Support/Glimble/rules.json` too.)

## 4. Live gesture recorder (the headline UX)
- [ ] **Add Rule** → in the editor click **Record**, then **perform a gesture** on the trackpad
      → the trigger field fills with e.g. "3-finger swipe up".
- [ ] Pick an action (e.g. **Snap left**), leave scope **All apps**, **Save**.
- [ ] Perform that gesture → the action runs. (Confirms record → save → execute end-to-end.)
- [ ] While recording, confirm the gesture does **not** also fire its old action (recording
      intercepts; normal execution resumes after capture).

## 5. App-scoped rules
- [ ] Add a rule scoped to a specific app (Scope picker → choose e.g. Safari) with a distinct
      action. Verify it fires **only** when that app is frontmost, and the global rule for the
      same gesture fires elsewhere.

## 6. Keyboard-shortcut action
- [ ] (Optional, needs a rule with a shortcut — not in defaults.) If you add a `.keyboardShortcut`
      rule via JSON or a future editor field, verify the keystroke is delivered to the focused app.
      (v1 editor exposes window + shell actions; keyboard/AppleScript/Shortcuts/launch are in the
      model + executor and reachable via the rules.json file.)

## 7. Launch at login
- [ ] Menu-bar ▸ **Open at Login** → check it appears in System Settings ▸ General ▸ Login Items.
      Toggle off → it's removed.

## 8. Distribution (no account)
- [ ] `GLIMBLE_IDENTITY="-" ./scripts/release.sh` → produces `Glimble-0.1.0.dmg` + prints sha256.
- [ ] Open the DMG, drag Glimble to Applications, then
      `xattr -dr com.apple.quarantine "/Applications/Glimble.app"` and launch → it runs.
- [ ] (When ready to publish) follow `docs/RELEASING.md`: create the `gum798/homebrew-glimble`
      tap, GitHub release, paste the sha256 into `homebrew/glimble.rb`.

---

## Known v1 limitations (by design — deferred to v1.x)
- Editor UI exposes window + shell actions; the other action types (keyboard shortcut,
  AppleScript, Shortcuts, launch app) exist in the model/executor and work from `rules.json`,
  but need editor fields — a small follow-up.
- No drawn-shape gestures, Force-Touch, pinch/rotate, or external trackpads yet (v1.x).
- Ad-hoc signing → re-grant permissions after each update (a Developer ID upgrade removes this).

When this checklist passes, the branch is ready to merge to `main`. If anything misbehaves,
tell me exactly what and I'll fix it.
