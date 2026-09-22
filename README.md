# Mac Remapper

A native macOS menu bar app for remapping keys and building keyboard macros — globally or per app — plus the marketing/download website for it.

```
Mac Remapper/
├── app/    Swift Package containing the macOS app
└── docs/   Static website, served by GitHub Pages from /docs
```

## Path to 1.0.0

Everything left between where this stands now (built and logic-tested on a machine with only the Xcode Command Line Tools, so the SwiftUI target has never actually been compiled or run) and a tested, signed, publicly downloadable 1.0.0 release. Do this on a machine with full Xcode installed.

### 1. Set up on a machine with full Xcode
- [ ] Install Xcode from the App Store, launch it once so it finishes installing components.
- [ ] `git clone https://github.com/cksarge/Mac-Remapper.git` (or `git pull` if already cloned).
- [ ] Confirm `xcode-select -p` prints a path under `/Applications/Xcode.app`, not `CommandLineTools`.
- [ ] `cd app && swift build` — this should now build **both** `MacRemapperCore` and `MacRemapper` (only `MacRemapperCore` could build before).
- [ ] `swift test` — runs the `swift-testing` suite in `Tests/MacRemapperCoreTests` (equivalent to `CoreSmokeTest`, but the real test runner).

### 2. Get it compiling
The `MacRemapper` SwiftUI target has never been fed through a real Swift compiler. Treat the first build on Xcode as step one, not a formality — fix whatever compile errors/warnings Xcode surfaces before doing anything else. In target settings, also remove the **App Sandbox** capability if Xcode added it by default (a sandboxed app cannot create a system-wide `CGEventTap`), and confirm **Signing & Capabilities** is set to "Sign to Run Locally" for now.

### 3. Manually test the running app
Run via Xcode (⌘R) or `./build-app.sh && open build/MacRemapper.app`, then work through:
- [ ] **Onboarding**: with no Accessibility access granted, the app shows the onboarding screen; granting access in System Settings updates the app automatically, no restart.
- [ ] **Simple remap**: e.g. Global profile, `W` → `Up Arrow`; confirm in TextEdit.
- [ ] **Macro**: e.g. an unused key (F13) → Cmd+Shift+4, delay, Cmd+C; confirm both steps fire with the delay honored.
- [ ] **App-scoped precedence**: an app-scoped profile's mapping overrides a conflicting Global mapping only while that app is frontmost.
- [ ] **Modifier remap** (e.g. Caps Lock → Control): this path (`AppState.handleModifierKey`, `flagsChanged` field-swapping) was written but never verified on real hardware — test carefully, including pressing/releasing multiple modifiers together.
- [ ] **Menu bar UI**: enable/disable toggle, active-profile display, Settings window opens/closes without issue, Quit works cleanly.
- [ ] **Launch at Login** toggle actually registers (check System Settings → General → Login Items).
- [ ] **Import/export** round-trips a profile JSON file without ID collisions.
- [ ] Fix whatever breaks. This is the first real test pass the UI has ever gotten — expect to find and fix genuine bugs here.

### 4. Add a real app icon
No icon exists yet — `Info.plist` references `CFBundleIconFile: AppIcon`, but with no `.icns` file present the app currently falls back to macOS's generic app icon. Design a 1024×1024 icon, generate the required sizes (Xcode's asset catalog editor, or `iconutil`/an online generator), and add it as `app/Resources/AppIcon.icns` — `build-app.sh` already copies it into the bundle if present.

### 5. Enroll in the Apple Developer Program
[developer.apple.com/programs](https://developer.apple.com/programs) — $99/year. Required for a "Developer ID Application" signing certificate and for notarization, which together eliminate the Gatekeeper warning for everyone downloading the app.

### 6. Code sign with your real identity
Once the certificate is in your Keychain (Xcode → Settings → Accounts, or downloaded from the developer portal):
```sh
SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" ./build-app.sh release
```
(`build-app.sh` defaults to ad-hoc signing — fine for local testing only — and switches to your real identity plus the hardened runtime when `SIGN_IDENTITY` is set.)

### 7. Notarize
```sh
./make-dmg.sh   # packages build/MacRemapper.app into build/MacRemapper.dmg
xcrun notarytool submit build/MacRemapper.dmg --keychain-profile "AC_NOTARY" --wait
xcrun stapler staple build/MacRemapper.dmg
spctl -a -vvv -t install build/MacRemapper.dmg   # should print "accepted" / "source=Notarized Developer ID"
```
(`xcrun notarytool store-credentials AC_NOTARY` sets up the keychain profile once, using an app-specific password from appleid.apple.com.)

### 8. Cut the 1.0.0 release
- [ ] Bump `CFBundleShortVersionString` in `app/Resources/Info.plist` to `1.0.0`.
- [ ] `git tag v1.0.0 && git push origin v1.0.0`.
- [ ] On GitHub: Releases → Draft a new release → tag `v1.0.0` → attach `build/MacRemapper.dmg` **named exactly `MacRemapper.dmg`** (the download page's link depends on that exact filename) → publish.

### 9. Publish the website
- [ ] Push `main` to GitHub (see "committing & pushing" note below — already done for you as of this session).
- [ ] Repo Settings → Pages → Source: **Deploy from a branch** → Branch: `main`, folder: **/docs**.
- [ ] Confirm the live download button resolves to the release asset.

### 10. Final sanity pass
- [ ] On a Mac that has never run the app before (a spare machine, a fresh user account, or a VM), download the published `.dmg` and confirm it opens with a normal double-click — no right-click-Open workaround needed, since it's notarized now.
- [ ] Re-run the full manual test checklist from step 3 against this actual signed/notarized build, not just a debug build.

## The app

- **Native Swift/SwiftUI**, menu bar only (no Dock icon).
- Global, system-wide key remapping via a `CGEventTap` (the same mechanism apps like Karabiner-Elements and Rectangle use), which requires the user to grant **Accessibility** access.
- Two kinds of mappings per profile: a **simple remap** (one key/combo → another) and a **macro** (one key → an ordered sequence of keystrokes, each with its own delay).
- Profiles are either **Global** (always active) or scoped to a list of specific apps by bundle identifier; app-scoped profiles take precedence over Global for the same trigger key while that app is frontmost.
- Because global key remapping is incompatible with the App Store sandbox, this app is **not** distributed through the Mac App Store — it's a direct-download `.dmg` (see [docs/download.html](docs/download.html)).

### Project structure (`app/`)

`app/` is a **Swift Package**, not an `.xcodeproj` — see [Building without full Xcode](#building-without-full-xcode) below for why, and what changes once you have Xcode installed.

```
app/
├── Package.swift
├── Sources/
│   ├── MacRemapperCore/     Models, event tap, mapping engine, persistence — no SwiftUI dependency
│   └── MacRemapper/         SwiftUI menu bar UI + settings window (the actual app)
├── Tests/MacRemapperCoreTests/   swift-testing suite for MacRemapperCore
├── Sources/CoreSmokeTest/   Plain-Swift check runner for MacRemapperCore (see below)
├── Resources/Info.plist    App bundle Info.plist (LSUIElement, Accessibility usage string)
├── build-app.sh            Assembles MacRemapper.app from a `swift build` output (ad-hoc or real signing)
└── make-dmg.sh             Packages build/MacRemapper.app into a distributable build/MacRemapper.dmg
```

Key files:
- `Sources/MacRemapperCore/Core/EventTap/EventTapManager.swift` — the `CGEventTap` wrapper
- `Sources/MacRemapperCore/Core/Engine/MappingEngine.swift` — resolves an incoming key combo against active profiles
- `Sources/MacRemapperCore/Core/Engine/EventSynthesizer.swift` — posts remap/macro output events
- `Sources/MacRemapperCore/Core/Models/Profile.swift` — `Profile` / `ProfileScope`
- `Sources/MacRemapperCore/Core/Persistence/ProfileStore.swift` — JSON persistence
- `Sources/MacRemapper/Settings/KeyCaptureView.swift` — "press a key to record it" UI control

### Building without full Xcode

This project was built in an environment with only the Xcode **Command Line Tools** installed, not full Xcode.app. That matters because SwiftUI's `@State`/`@Binding` (and XCTest, and the newer `swift-testing` framework) rely on compiler macro plugins that only ship inside Xcode.app. Concretely:

- **`MacRemapperCore`** (models, event tap, mapping engine, persistence) has **no SwiftUI dependency**, so it builds and its tests run with just the Command Line Tools:
  ```sh
  cd app
  swift build --target MacRemapperCore
  swift run CoreSmokeTest      # plain-Swift check runner — no XCTest/swift-testing needed
  ```
  `Tests/MacRemapperCoreTests` holds the same coverage written against `swift-testing` (`import Testing`), for when you have full Xcode — run it with `swift test` at that point. Keep both in sync if you add coverage.
- **`MacRemapper`** (the actual SwiftUI app target) **requires full Xcode.app** to compile. Install Xcode from the App Store, then either:
  - Open `app/Package.swift` directly in Xcode (File → Open) and run the `MacRemapper` scheme, or
  - Run `./app/build-app.sh` from a shell where `xcode-select` points at a full Xcode install, to assemble `app/build/MacRemapper.app` (ad-hoc signed, ready to `open`).

Once Xcode is installed, `swift build`/`swift test` at the package root will build and test everything, including the UI target.

### First run

1. Build and run `MacRemapper` (via Xcode or `build-app.sh` + `open`).
2. On first launch, the app can't create its event tap without Accessibility access — it'll show an onboarding screen. Click through to System Settings → Privacy & Security → Accessibility and enable **Mac Remapper**; the app detects the grant automatically, no restart needed.
3. Click the menu bar icon → **Open Settings…** to create your first profile and mapping.
4. See [docs/download.html](docs/download.html) for the end-user install flow (relevant once you're testing a built `.dmg`).

### Known limitations / not yet implemented

- The app is **unsigned** and has **no app icon** yet — see [Path to 1.0.0](#path-to-100) above for both.
- Modifier-key-to-modifier-key remaps (e.g. Caps Lock → Control) are implemented via `flagsChanged` event field-swapping (`AppState.handleModifierKey`) — this is the standard approach, but multi-modifier-at-once edge cases are worth verifying on real hardware since this environment couldn't test physical key input.

## The website (`docs/`)

Plain HTML/CSS/JS, no build step, served directly by GitHub Pages from the `/docs` folder.

- `docs/index.html` — homepage/features
- `docs/download.html` — download page, links to the latest GitHub Release's `.dmg` via GitHub's stable `.../releases/latest/download/<asset-name>` URL
- `docs/css/styles.css`, `docs/js/main.js`

The GitHub links in `docs/index.html` and `docs/download.html` point at [github.com/cksarge/Mac-Remapper](https://github.com/cksarge/Mac-Remapper).

### Local preview

```sh
cd docs
python3 -m http.server 8000
# open http://localhost:8000
```

### Publishing

1. Push this repo to GitHub.
2. Repo Settings → Pages → Source: **Deploy from a branch** → Branch: `main`, folder: **/docs**.
3. Cut a GitHub Release and attach the built `.dmg` as `MacRemapper.dmg` (matching the filename the download page links to) so the "latest" URL resolves without editing the site on every release.

## License

MIT — see [LICENSE](LICENSE).
