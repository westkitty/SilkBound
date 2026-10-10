# Build and validation

## Pinned toolchain

- **Godot:** 4.7.2 stable, Compatibility renderer (`gl_compatibility`).
- **Language:** GDScript only.
- **Android:** Java 17, Android SDK platform 36 and build-tools 36.0.0.
- **Export:** Godot's standard Android debug template; ARM64 (`arm64-v8a`) only.
- **Package:** `com.westkitty.silkbound`.
- **Signing:** Godot's local debug signing. No signing key or password is stored in this repository.

## Desktop/editor validation

From a fresh checkout, open the project once in Godot 4.7.2 or run:

```sh
godot --headless --editor --path . --import --quit
godot --headless --path . --script res://tests/run_all.gd
godot --headless --path . --quit-after 120
```

`tests/run_all.gd` is a `SceneTree` test runner; it prints each assertion and exits nonzero if any assertion fails. The final command is a bounded main-scene startup smoke test, **not** a touchscreen or device test.

The repository helper runs those same checks and rejects critical Godot log errors:

```sh
GODOT_BIN=/absolute/path/to/Godot_v4.7.2-stable_linux.x86_64 \
  tools/validate_project.sh
```

## Android export

1. Install the Godot 4.7.2 Android export templates in Godot's normal user export-template directory.
2. Install Android SDK platform 36 and build-tools 36.0.0; install/configure Java 17.
3. In Godot Editor Settings, set `export/android/android_sdk_path` and `export/android/java_sdk_path` to those installations.
4. Run validation, then:

```sh
mkdir -p build
godot --headless --path . --export-debug "Android" build/SilkBound-debug.apk
unzip -tq build/SilkBound-debug.apk
sha256sum build/SilkBound-debug.apk
```

The APK path is ignored by Git. The debug preset has no custom permissions enabled; it does not request Internet access. Android orientation is set to landscape in `project.godot`.

## GitHub Actions APK

`.github/workflows/android.yml` downloads the official 4.7.2 editor and matching export templates, verifies their pinned SHA-256 digests, sets Java 17, installs SDK 36/build-tools 36.0.0, sets Godot's local Android editor paths in the ephemeral runner profile, and then runs import, regression tests, smoke startup and export. Before uploading, it checks ZIP integrity, package ID and the presence of ARM64 native libraries, rejects a 32-bit ARM payload, and writes a SHA-256 sidecar. The binary is available only as an Actions artifact after a successful run; it is not committed or published as a release.

## Local runtime testing

A headless editor or test run does not prove Android touch feel, device thermals, tablet safe areas, gamepad support or real-device performance. Those remain device-level checks. No measured FPS or physical-device result is claimed here.
