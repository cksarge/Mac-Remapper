# Mac Remapper

A native macOS menu bar app for remapping keys and building keyboard and mouse macros, globally or per app. This repo also holds the marketing and download website.

**Website:** [cksarge.github.io/Mac-Remapper](https://cksarge.github.io/Mac-Remapper) · **Download:** [latest release](https://github.com/cksarge/Mac-Remapper/releases/latest)

```
Mac-Remapper/
├── app/    Swift Package containing the macOS app
└── docs/   Static website, served by GitHub Pages from /docs
```

## Features

- **Simple remaps**: any key or key combo to any other, including modifier-to-modifier (e.g. Right ⌘ → ⌃).
- **Macros**: one trigger key runs a sequence of steps:
  - **Keystroke**: presses a key combo.
  - **Delay**: waits, in ms or s.
  - **Mouse Click**: left, middle or right; single or double; at the pointer or at x,y coordinates picked on screen.
  - **Scroll**: scrolls up or down by a number of pixels.
  - **Type Text**: types any Unicode text.
  - **Open Webpage**: opens a link in the default browser (`https://` is added if missing).
  - **Marker**: a named position that repeats can refer to.
  - **Repeat**: re-runs the last N steps or a marker-to-marker block, N more times or forever, before or alongside the following steps.
  - **Run Shortcut**: runs a Shortcuts app shortcut, optionally waiting for it to finish.
- **Run control**: per macro, pressing the trigger while it runs can ignore / restart / run another copy / stop. An optional separate stop key and a **Stop Running Macros** menu item are also available.
- **Profiles**: **Global** or scoped to specific apps. Profiles can be dragged into priority order, and overridden mappings show a warning.
- **Menu bar app**: a native menu with live status and an on/off switch, plus Launch at Login and import/export of profiles as JSON.
- **Update notices**: checks the latest GitHub release at launch and every 12 hours, and shows **Update Available** in the menu when a newer version exists. Installing stays manual.

Global key remapping needs a system-wide `CGEventTap`, which the App Store sandbox doesn't allow. So the app ships as a direct-download `.dmg`, not through the Mac App Store.

## Getting started

### Requirements

- macOS 13 Ventura or later. Development has been done on the latest macOS.
- **Full Xcode** (from the App Store), not just the Command Line Tools. SwiftUI's property wrappers and the `swift-testing` framework rely on compiler plugins that only ship inside Xcode.app. Check with `xcode-select -p`, which should print a path inside `/Applications/Xcode.app`.

### Build, test, run

```sh
git clone https://github.com/cksarge/Mac-Remapper.git
cd Mac-Remapper/app

swift build                # builds everything
swift test                 # swift-testing suite (Tests/MacRemapperCoreTests)
./rebuild-and-run.sh       # builds MacRemapper.app and launches it
```

`app/` is a Swift Package, not an `.xcodeproj`. To work in Xcode, open `app/Package.swift` and run the `MacRemapper` scheme.

On first launch the app shows an onboarding screen asking for **Accessibility** access, which the event tap requires. Grant it in System Settings → Privacy & Security → Accessibility. The app notices within a second, no restart needed. Then use the menu bar icon → **Open Settings…** to create a profile.

### The Accessibility grant resets on every rebuild

Builds are **ad-hoc signed**, and macOS ties the Accessibility grant to the exact binary. After a rebuild, the old grant silently stops working, even though the System Settings toggle still looks on. `rebuild-and-run.sh` handles this for you: it quits the app, rebuilds, runs `tccutil reset Accessibility com.macremapper.app`, and relaunches. You then grant access again. Signing with a stable Developer ID certificate would make the grant survive rebuilds and updates.

### Tests

- `swift test`: the main suite. It covers codable round-trips and legacy file formats, mapping precedence and conflict detection, profile persistence, and the macro runner (step order, repeats, markers, the 10 ms safety pause, cancellation).
- `swift run CoreSmokeTest`: a dependency-free check runner with the same core coverage, which also works with only the Command Line Tools installed. Keep the two in sync when adding coverage.

The macro runner is tested through a `MacroPerformer` protocol. Tests substitute a recording performer, so nothing is actually typed or clicked.

## How it works

### A key press, end to end

1. **`EventTapManager`** owns a session-level `CGEventTap` for key down/up and modifier changes. Its callback runs on the main run loop.
2. **`AppState.handle(event:type:)`** decides what happens:
   - Events the app posted itself (tagged with a marker in `eventSourceUserData`) pass straight through, so macro output never triggers mappings.
   - A key-down matching a running macro's **stop key** cancels that macro.
   - Otherwise it asks the engine.
3. **`MappingEngine.resolve`** is a single dictionary lookup in a table rebuilt whenever profiles or the frontmost app change. It returns one of three results:
   - **Passthrough:** no mapping matches, so the event is left untouched.
   - **Remap:** the event's key code and flags are rewritten in place.
   - **Macro:** the event is swallowed, along with its key-up, and the macro starts. Key auto-repeats are ignored, so holding a trigger key doesn't start the macro over and over.

**Precedence:** app-scoped profiles beat Global ones. Within the same level, the profile **higher in the list** wins, and within a profile, the earlier mapping wins. `MappingPrecedence` applies the same rule to flag overridden mappings in the UI.

### Macros

- **`MacroRunner`** interprets the steps on a background thread:
  - Markers are no-ops.
  - A block runs normally the first time it's reached; a Repeat step then runs it N *more* times (or until cancelled).
  - Repeats set to continue alongside the following steps run on their own thread, sharing one `MacroRunToken`. Cancelling the token stops everything that run spawned.
  - If a repeated block contains no delay above 0, iterations are spaced 10 ms apart.
- **`SystemMacroPerformer`** does the real work:
  - **Keys:** posts `CGEvent`s with explicit flags, so modifiers still held from the trigger don't leak into the output.
  - **Text:** typed through `keyboardSetUnicodeString`.
  - **Clicks:** mouse events, with the optional cursor return.
  - **Shortcuts:** runs `/usr/bin/shortcuts run <name>`. No entitlement or developer account needed.
- **The forever-repeat safeguard:** a macro that repeats forever with no stop key always stops when its trigger is pressed again (`Mapping.effectiveRetriggerBehavior`), so it can never be left unstoppable.

### Persistence

Profiles are saved as JSON at `~/Library/Application Support/MacRemapper/profiles.json`. Saves happen 0.5 s after each change (debounced) and again on quit. Decoders accept older formats:
- **Combos:** combos saved with macOS's implicit fn flag are repaired.
- **Old macro steps:** steps that had a delay attached expand into a Delay step followed by a Keystroke step.
- **Missing settings:** mappings without `macroOptions` load with the defaults.

Keep that backward compatibility when changing the models, since users' existing files must keep loading.

### UI

- **The menu bar item** is built in AppKit (`StatusItemController`), not SwiftUI's `MenuBarExtra`. That allows a custom SwiftUI header (`MenuHeaderView`) and two-line profile rows inside a native `NSMenu`.
- **The Settings window** is opened from AppKit by `SettingsWindowController`. While it's open, the app temporarily becomes a regular app (Dock icon, ⌘Tab) so the window can't get lost behind other apps.
- **The SwiftUI `App` scene** is a never-inserted `MenuBarExtra`. SwiftUI requires at least one scene, and an empty `Settings` scene would pop up as a blank window when the app is reactivated.

## Project structure

```
app/
├── Package.swift
├── Sources/
│   ├── MacRemapperCore/            Logic, with no SwiftUI dependency
│   │   ├── AppState/               AppState: wires the tap, engine, macro runs and permission together
│   │   └── Core/
│   │       ├── EventTap/           CGEventTap wrapper, key code names and modifier masks
│   │       ├── Engine/             MappingEngine + MappingPrecedence, MacroRunner, SystemMacroPerformer
│   │       ├── Models/             KeyCombo, Mapping (+ MacroOptions), MacroStep, Profile
│   │       ├── Persistence/        ProfileStore (JSON), ImportExport
│   │       ├── AppMonitor/         Frontmost-app tracking for app-scoped profiles
│   │       ├── Permissions/        Accessibility trust and polling
│   │       └── LaunchAtLogin/      SMAppService wrapper
│   ├── MacRemapper/                The app (SwiftUI and AppKit)
│   │   ├── MacRemapperApp.swift    Entry point and AppDelegate
│   │   ├── MenuBar/                Status item and menu, menu header view
│   │   ├── Settings/               Settings window, onboarding, profile/mapping/macro editors, key recorder
│   │   └── Shared/                 App name/icon lookup, on-screen point picker, Shortcuts list
│   └── CoreSmokeTest/              Dependency-free check runner
├── Tests/MacRemapperCoreTests/     swift-testing suite
├── Resources/                      Info.plist, AppIcon.icns (+ 1024 px preview)
├── build-app.sh                    Builds MacRemapper.app (release builds are universal: arm64 + x86_64)
├── make-dmg.sh                     Packages build/MacRemapper.app into build/MacRemapper.dmg
├── rebuild-and-run.sh              Dev loop: quit, rebuild, reset the Accessibility grant, relaunch
└── make-icon.swift                 Generates the app icon; edit and run `swift make-icon.swift`
```

## Releasing

1. Bump `CFBundleShortVersionString` (and `CFBundleVersion`) in `app/Resources/Info.plist`. The download page reads the latest release's version from the GitHub API, so it doesn't need editing. The number in its `data-latest-version` element is only a fallback.
2. Build the universal release app and the disk image:
   ```sh
   cd app
   ./build-app.sh release
   ./make-dmg.sh              # → build/MacRemapper.dmg
   ```
3. Commit, tag and push: `git tag vX.Y.Z && git push origin main vX.Y.Z`.
4. On GitHub, open **Releases → Draft a new release**, choose the tag, and attach `build/MacRemapper.dmg`. Keep the file named exactly **`MacRemapper.dmg`**: the website's download button uses GitHub's stable `releases/latest/download/MacRemapper.dmg` URL, so it always serves the newest release without editing the site.

**Signing:** releases are currently ad-hoc signed, not notarized, so users approve the app once via System Settings → Privacy & Security → **Open Anyway**. The download page explains this. To remove that step, enroll in the Apple Developer Program. Then build with `SIGN_IDENTITY="Developer ID Application: Name (TEAMID)" ./build-app.sh release` (which also enables the hardened runtime), and notarize the `.dmg` with `xcrun notarytool submit … --wait` followed by `xcrun stapler staple`.

## Website (`docs/`)

Plain HTML/CSS/JS with no build step, served by GitHub Pages from `main` → `/docs` (Settings → Pages → Deploy from a branch).

- `index.html` is the homepage and feature overview. `download.html` has the download button and install steps.
- `css/styles.css` and `js/main.js` hold the styles and scripts. When either changes, bump the `?v=` on its `<link>`/`<script>` tag in both pages, because GitHub Pages lets browsers cache them for 10 minutes. `assets/icons/` holds the favicon (SVG), the app icon, and the Apple touch icon.

To preview locally:

```sh
cd docs && python3 -m http.server 8000   # then open http://localhost:8000
```

## Known limitations

- **Caps Lock can't be remapped.** macOS toggles it inside the keyboard driver before any event tap sees it, so the key recorder rejects it. Users can remap it natively in System Settings → Keyboard → Keyboard Shortcuts → Modifier Keys.
- **Some games won't see remapped keys.** Remapping happens at the `CGEvent` level. Games that read the keyboard directly through IOKit/HID bypass it.
- **Macro clicks use global display coordinates** (origin at the top-left of the main display), so a saved x,y position may land elsewhere if the display arrangement changes.

## License

MIT, see [LICENSE](LICENSE).
