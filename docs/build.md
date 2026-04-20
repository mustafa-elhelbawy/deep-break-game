# Deep Break — Android Build Guide

> **Build machine**: Windows (PowerShell) is primary. Mac/Linux commands shown in parallel.  
> **Edit machine**: Mac (Godot editor + VS Code). Never run the headless export from the edit machine unless your keystore is set up there.

---

## Overview

```
git clone → set env vars → godot --headless --export-release → adb install
```

The Godot editor is NOT needed on the build machine after the one-time export template installation. All subsequent builds run headlessly.

---

## One-Time Machine Setup

### 1 — Install Godot 4.3 CLI

**Windows (PowerShell)**
```powershell
# Download Godot_v4.3-stable_win64.exe from https://godotengine.org/download
# Rename to godot.exe and place it in C:\tools\godot\
$env:PATH += ";C:\tools\godot"
# Add to system PATH permanently via System Properties → Environment Variables
```

**Mac**
```bash
# Option A: Homebrew
brew install godot

# Option B: Manual — download Godot_v4.3-stable_macos.universal
# Rename to Godot.app, move to /Applications/
# Add to PATH:
export PATH="/Applications/Godot.app/Contents/MacOS:$PATH"
```

Verify:
```bash
godot --version   # should print: 4.3.stable
```

---

### 2 — Install Android Export Templates

Run once per Godot version. Templates are stored in the Godot user data directory.

```bash
# Download Godot_v4.3-stable_export_templates.tpz from godotengine.org
# Then install headlessly:
godot --headless --install-export-templates Godot_v4.3-stable_export_templates.tpz
```

Verify (check for android_release.apk in templates dir):

**Windows**: `%APPDATA%\Godot\export_templates\4.3.stable\`  
**Mac**: `~/.local/share/godot/export_templates/4.3.stable/`

---

### 3 — Install JDK 17

Godot's Android Gradle build requires JDK 17. `keytool` (for keystore generation) ships with the JDK.

**Windows**
```powershell
# Download Adoptium Temurin 17 from https://adoptium.net/
# Install and verify:
java -version    # openjdk 17...
keytool -help    # should show keytool usage
```

**Mac**
```bash
brew install openjdk@17
# Add to PATH (add to ~/.zshrc):
export PATH="/opt/homebrew/opt/openjdk@17/bin:$PATH"
java -version
```

---

### 4 — Install Android SDK

**Windows**
```powershell
# Option A: Install Android Studio from https://developer.android.com/studio
# Then use SDK Manager inside Android Studio.

# Option B: Command-line tools only (recommended for CI)
# Download cmdline-tools from https://developer.android.com/studio#command-tools
# Extract to C:\Android\cmdline-tools\latest\
$env:ANDROID_HOME = "C:\Android"
$env:PATH += ";C:\Android\cmdline-tools\latest\bin;C:\Android\platform-tools"

sdkmanager "platform-tools" "platforms;android-33" "build-tools;33.0.2"
sdkmanager --licenses   # accept all licences (type 'y' for each)
```

**Mac**
```bash
brew install android-commandlinetools
export ANDROID_HOME="$HOME/Library/Android/sdk"
sdkmanager "platform-tools" "platforms;android-33" "build-tools;33.0.2"
sdkmanager --licenses
```

> **Point Godot at the SDK**: In the Godot editor on the build machine (first time only), go to  
> Editor → Editor Settings → Export → Android and set the Android SDK path to `$ANDROID_HOME`.

---

### 5 — Generate the Release Keystore

Run **once** and store the `.keystore` file in a **safe location outside the repo** (e.g. a password manager or a secure network share). Losing the keystore means you cannot update the app on Google Play.

```bash
keytool -genkey -v \
  -keystore deep-break.keystore \
  -alias deep-break-key \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000
```

You will be prompted for:
- Keystore password (save it — you will need it every build)
- Key alias password (can be the same as keystore password)
- Organisation details (name, org, city, country — anything is fine for self-signing)

> **Keep the keystore secret.** Never commit it to git. Add `*.keystore` to `.gitignore`.

---

## Per-Build Steps

### Step 1 — Pull latest main

```bash
git checkout main
git pull origin main
```

---

### Step 2 — Set environment variables

**Windows (PowerShell)**
```powershell
$env:DEEP_BREAK_KEYSTORE_PATH = "C:\keys\deep-break.keystore"
$env:DEEP_BREAK_KEY_ALIAS      = "deep-break-key"
$env:DEEP_BREAK_KEY_PASSWORD   = "yourpassword"
```

**Mac / Linux (bash/zsh)**
```bash
export DEEP_BREAK_KEYSTORE_PATH="/Users/yourname/keys/deep-break.keystore"
export DEEP_BREAK_KEY_ALIAS="deep-break-key"
export DEEP_BREAK_KEY_PASSWORD="yourpassword"
```

> These are session-only. They are **not** persisted between terminal sessions, which is intentional — secrets should not live permanently in shell profiles.

---

### Step 3 — Run the headless export

```bash
# Create the output directory if it doesn't exist
mkdir -p build/android

# Export
godot --headless --export-release "Android Release" build/android/DeepBreak.apk
```

**Windows (PowerShell)**
```powershell
New-Item -ItemType Directory -Force -Path build\android
godot.exe --headless --export-release "Android Release" build\android\DeepBreak.apk
```

Expected output:
```
Godot Engine v4.3.stable - https://godotengine.org
OpenGL ES 3.0 Renderer: Disabled
...
Exporting for Android...
```

No errors = success. Warnings about missing `.import` files for resources not used in the export are normal.

---

### Step 4 — Install on device

Connect an Android device via USB with Developer Options and USB Debugging enabled.

```bash
adb devices        # device should appear as "device" (not "unauthorized")
adb install -r build/android/DeepBreak.apk
```

`-r` = replace existing installation. On first install omit `-r` or it still works.

---

### Step 5 — Verify on device

1. Find "Deep Break" in the app drawer
2. Tap to launch — should open directly to the game in under 3 seconds
3. Play through: ball launches, bricks break, screen shakes, lives decrement, game over shows
4. No ANR (App Not Responding) dialog within the first 60 seconds

---

## Troubleshooting

### "Export template not found"
```
ERROR: No export template found for platform "Android"
```
→ Re-run the export template installation (Step 2 in One-Time Setup).

---

### "keytool not found on Windows"
→ Ensure JDK 17 `bin/` directory is in `PATH`. Check: `where keytool`

---

### "SDK not found" / Gradle build fails
```
ERROR: Android SDK path is invalid
```
→ Open Godot editor on the build machine, go to Editor → Editor Settings → Export → Android, and set the SDK path to the value of `$ANDROID_HOME`.

---

### "adb: device not found" or "unauthorized"
→ On the phone: pull down notification tray → tap "USB Debugging" notification → Allow.  
→ Revoke and re-allow USB debugging in Developer Options if still stuck.

---

### APK installs but crashes immediately
→ Check `adb logcat -s GodotEngine` for the crash log.  
→ Common cause: missing `.import` files — run the Godot editor once on the project to re-import all assets.

---

### "INSTALL_FAILED_UPDATE_INCOMPATIBLE"
→ Different signing key from a previous build. Uninstall first:
```bash
adb uninstall com.deepbreak.game
adb install build/android/DeepBreak.apk
```

---

## Build Artefact Naming

| Version | Tag | APK filename |
|---------|-----|-------------|
| Phase 5 | v0.5.0-phase5 | DeepBreak-v0.5.0.apk |

Archive the versioned copy before overwriting:
```bash
cp build/android/DeepBreak.apk build/android/DeepBreak-v0.5.0.apk
```

---

## What is NOT in the repo

| Item | Why |
|------|-----|
| `deep-break.keystore` | Secret — losing/exposing it is unrecoverable |
| `build/` directory | Generated artefact — gitignored |
| Keystore passwords | Set via env vars only, never in files |
