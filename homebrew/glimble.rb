# Homebrew Cask for Glimble — install into the tap repo `gum798/homebrew-glimble`
# as `Casks/glimble.rb`. Users then run:
#   brew tap gum798/glimble
#   brew install --cask glimble
#
# Per release: bump `version` and replace `sha256` with the value printed by
# scripts/release.sh (see docs/RELEASING.md).
cask "glimble" do
  version "0.1.2"
  sha256 "74a080e0fb3be68ffdeba558e559d62050e8193b3422911de5defd59d38d65b6"

  url "https://github.com/gum798/Glimble/releases/download/v#{version}/Glimble-#{version}.dmg"
  name "Glimble"
  desc "Trackpad gesture mapper (gesture → window/keyboard/script actions)"
  homepage "https://github.com/gum798/Glimble"

  depends_on macos: :sequoia

  app "Glimble.app"

  caveats <<~EOS
    Glimble is ad-hoc signed (not notarized), so macOS Gatekeeper blocks it on first
    launch. To allow it, run:

      xattr -dr com.apple.quarantine "/Applications/Glimble.app"

    (or open System Settings ▸ Privacy & Security and click "Open Anyway").

    Glimble then needs two permissions — it will prompt and link you to the right panes:
      • Input Monitoring  — to read multi-finger trackpad gestures
      • Accessibility     — to move windows and send keyboard shortcuts

    Tip: if a Glimble gesture also triggers a built-in macOS gesture, disable that one in
    System Settings ▸ Trackpad ▸ More Gestures so Glimble's rule wins.
  EOS
end
