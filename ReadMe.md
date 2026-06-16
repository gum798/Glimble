# Glimble

A lightweight macOS menu-bar app that maps **trackpad gestures** to actions — snap windows,
fire keyboard shortcuts, run scripts, launch apps. As powerful as the big gesture tools, but
simple, with good defaults out of the box.

> macOS 15 (Sequoia) and 26 (Tahoe), Apple Silicon. Built-in trackpad.

## Install

### Homebrew (recommended)

```sh
brew tap gum798/glimble
brew trust gum798/glimble        # Homebrew 5+ requires trusting third-party tap casks
brew install --cask glimble
```

Update later with `brew update && brew upgrade --cask glimble`.

### Manual

Download `Glimble-<version>.dmg` from the [latest release](https://github.com/gum798/Glimble/releases),
open it, and drag **Glimble** to Applications.

### First launch — allow it past Gatekeeper

Glimble is ad-hoc signed (not notarized — it uses a private Apple framework to read raw
trackpad data, and notarization needs a paid Apple Developer account). On first launch macOS
blocks it. To allow it:

```sh
xattr -dr com.apple.quarantine "/Applications/Glimble.app"
```

…or open **System Settings ▸ Privacy & Security** and click **Open Anyway**.

### Permissions

Glimble needs two permissions (it prompts and links you to the right panes):

- **Input Monitoring** — to read multi-finger trackpad gestures.
- **Accessibility** — to move windows and send keyboard shortcuts.

After granting Input Monitoring, relaunch Glimble.

## Default gestures

| Gesture | Action |
|---|---|
| 3-finger tap | Maximize the focused window |
| 4-finger tap | Center the focused window |
| 3-finger swipe left | Snap window to the left half |
| 3-finger swipe right | Snap window to the right half |

Edit, add, or remove rules in **Settings** (menu-bar ▸ Settings…). The rule editor lets you set
a trigger by **performing the gesture** (click **Record**, then do the gesture). Rules can be
global or scoped to a specific app.

> If a Glimble gesture also triggers a built-in macOS gesture, disable that one in
> **System Settings ▸ Trackpad ▸ More Gestures** so Glimble's rule wins — macOS gestures can't
> be suppressed from outside.

## Build from source

```sh
swift build              # build
swift test               # run the GlimbleCore unit tests
swift run GlimbleApp     # run the menu-bar app

GLIMBLE_IDENTITY="-" ./scripts/build-app.sh    # assemble + ad-hoc sign Glimble.app
GLIMBLE_IDENTITY="-" ./scripts/release.sh      # package a .dmg
```

Requires the full Xcode toolchain (Swift 6+).

## How it works

- **`GlimbleCore`** — a pure, unit-tested Swift library: the touch model, the gesture
  recognizer (multi-finger swipes/taps), the rule model, matching, and persistence. No OS or
  private-framework imports, so it's fully testable.
- **`GlimbleApp`** — the menu-bar app: reads raw multitouch via
  [OpenMultitouchSupport](https://github.com/Kyome22/OpenMultitouchSupport), runs the engine,
  executes actions (CGEvent / Accessibility / `Process`), and hosts the SwiftUI settings +
  onboarding.

## License

TBD.
