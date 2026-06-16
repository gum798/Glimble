# Releasing Glimble

Glimble ships as an **ad-hoc-signed** `.dmg` via GitHub Releases, installable through a personal
Homebrew tap. No Apple Developer account required. (To remove the Gatekeeper friction later, get a
Developer ID, sign with it instead of `"-"`, run `scripts/notarize.sh`, and drop the `xattr`
caveat from the cask.)

## One-time: create the tap repo

1. Create a public GitHub repo named **`gum798/homebrew-glimble`** (the `homebrew-` prefix is
   required by Homebrew).
2. Add a `Casks/` directory. The cask file lives at `Casks/glimble.rb`.

## Per release

1. **Bump the version** in `Sources/GlimbleApp/Info.plist`:
   - `CFBundleShortVersionString` → the marketing version (e.g. `0.1.0`).
   - `CFBundleVersion` → increment every release (e.g. `1`, `2`, …).

2. **Build the DMG:**
   ```sh
   GLIMBLE_IDENTITY="-" ./scripts/release.sh
   ```
   This prints `Glimble-<version>.dmg` and its **sha256**. Copy that hash.

3. **Create the GitHub release** on `gum798/Glimble`:
   ```sh
   gh release create "v<version>" "Glimble-<version>.dmg" \
     --title "Glimble <version>" --notes "…"
   ```
   (The cask's `url` expects the asset at
   `releases/download/v<version>/Glimble-<version>.dmg`.)

4. **Update the cask** `homebrew/glimble.rb`:
   - set `version "<version>"`
   - set `sha256 "<the hash from step 2>"`
   Then copy it into the tap repo as `Casks/glimble.rb` and push:
   ```sh
   cp homebrew/glimble.rb ../homebrew-glimble/Casks/glimble.rb
   cd ../homebrew-glimble && git commit -am "glimble <version>" && git push
   ```

5. **Verify** end-to-end on a clean Mac:
   ```sh
   brew tap gum798/glimble
   brew install --cask glimble
   xattr -dr com.apple.quarantine "/Applications/Glimble.app"
   open "/Applications/Glimble.app"
   ```

## Notes

- **Updates** are delivered through Homebrew (`brew upgrade --cask glimble`); there is no in-app
  updater in v1 (Sparkle was intentionally deferred — see Plan 3).
- Because the app is ad-hoc signed, its code-signing identity changes every build, so users
  re-grant Input Monitoring + Accessibility after an update. A Developer ID upgrade removes that.
- Keep `scripts/build-app.sh` as the single source of truth for bundle assembly + signing;
  `release.sh` calls it.
