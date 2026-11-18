# Language spike: decided GDScript (2026-11-18)

The port plan lives outside this repo. Fernando chose **statically typed GDScript**
after a three-way spike (Go via graphics.gd, C#, GDScript). The Go and C# spikes and their
toolchains (.NET SDK, Godot .NET editor/templates, `gd`) were deleted. `gdspike/` remains as the
reference scene.

## What the spike proved
- Same scene in all three: neon code-drawn fighter, fixed 60 Hz tick, keyboard/gamepad/touch,
  level JSON from `res://`, headless parity run.
- **Bit-exact across languages:** 600 scripted ticks → `a2f1c08d29652a82` in Go, C# and GDScript.
  Swift ActionCore uses `Double` everywhere and GDScript `float` is 64-bit, so the port can be
  diffed frame by frame against the Swift `lastlight-sim`.
- Hash = first 8 bytes of SHA-256 over LE float64 `x, y, vx, vy, facing` + LE int32 `attack_t`
  (`gdspike/sim.gd:state_hash`). Use the same layout on the Swift side.
- GDScript needed no extra toolchain and no workarounds. iOS export → Xcode archive → TestFlight
  upload all succeeded first time.
- Why not the others: Go needed 3 iOS workarounds, has a single maintainer, and builds device-only.
  C# was clean but adds the .NET SDK, NativeAOT ("experimental") and 1.2 GB templates.

## Rules carried into the port
- Keep the game's own deterministic `World` sim in plain `RefCounted` GDScript. **Don't** use
  `CharacterBody2D`/`move_and_slide()` for gameplay: it changes the feel and breaks Swift parity.
  Godot only renders and reads input.
- Fixed tick in `_physics_process`; ignore `delta` in the sim (`DT = 1.0/60.0`).
- Game-logic tests run under Godot headless (gdUnit4 or `-s` scripts). Unlike Go/C#, there is no
  engine-free test runner.
- Typed GDScript: `project.godot` sets `untyped_declaration` as an error.
- Never compare doubles through a decimal parser. Godot's `JSON.parse_string` and
  `String.to_float()` are not correctly rounded for long decimals; goldens carry bit patterns.
- No reliance on int64 overflow wrapping: `sim/seeded_random.gd` does u64 math in 16-bit limbs.

## Headless parity run
```
cd gdspike
godot --headless --path . -- --sim-ticks=600
# → SPIKE sim: ticks=600 hash=a2f1c08d29652a82
```

## iOS / TestFlight (2026-11-18)
- App Store Connect record **LastLight GdSpike** (`com.fernandocorreia.lastlight.gdspike`, SKU
  `lastlight-gdspike`); build 1 uploaded with `ITSAppUsesNonExemptEncryption=false`.
- Records **LastLight GoSpike / CsSpike** were removed from App Store Connect on 2026-11-18 (Fernando's
  call). Their names are released; their explicit App IDs are still registered in the Developer portal.
- Flow: `--export-release "iOS"` (preset `export_project_only=true`) → `xcodebuild archive`
  (team 84X9WYBF36, automatic signing) → `-exportArchive` with `destination=upload`.
  Archives and logs are kept outside the repo.
- ⚠️ **Xcode 27 required:** Apple warns that from April 2027 uploads need the iOS 27 SDK, and
  Xcode 26.2 cannot install directly onto the iOS 27.2 phone (CoreDevice tunnel unavailable).
  App Store Connect already warned on the 2026-11-18 upload (ITMS-90725). For CI, GitHub's
  `xcode-27` runner label (public preview, Xcode 27.1) has the SDK; `macos-26` stops at Xcode 26.6.
- Device verdict (launch, feel, touch): pending, Fernando via TestFlight.

## iOS Simulator
- Official Godot 4.7.2 iOS templates ship an **x86_64-only** simulator `libgodot.a`; the iOS 26
  simulator on Apple Silicon refuses x86_64 apps. Fix: build the arm64 simulator template once from
  source (godotengine/godot tag `4.7.2-stable` = `ed1daf0`):
  ```
  scons platform=ios target=template_release arch=arm64 ios_simulator=yes generate_bundle=no
  ```
  Not yet run (auto mode blocked it; Fernando's call).

## Deferred until the game is fully ported (Fernando, 2026-11-18)
- **Steam:** GodotSteam is only on codeberg.org, which doesn't resolve on this network (DNS filter
  NXDOMAIN). Steam isn't installed on the Mac. Verify `steamInit` + one achievement on a Steamworks
  test branch.
- **Windows run:** GitHub repo for thelast-light-godot + Actions `windows-latest` job running the
  exported exe headless with `--sim-ticks=600`, checking the parity hash.
