
# Testing Manual: GStreamer Daemon Android Cross-Compilation

This guide walks you through testing your Nix-based Android cross-compilation setup from basic validation to full builds.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Phase 1: Syntax & Configuration Validation](#phase-1-syntax--configuration-validation)
3. [Phase 2: Platform Verification](#phase-2-platform-verification)
4. [Phase 3: Incremental Component Builds](#phase-3-incremental-component-builds)
5. [Phase 4: Full Bundle Build](#phase-4-full-bundle-build)
6. [Phase 5: Binary Verification](#phase-5-binary-verification)
7. [Phase 6: Android Deployment](#phase-6-android-deployment)
8. [Troubleshooting](#troubleshooting)
9. [Performance Tips](#performance-tips)

---

## Prerequisites

### Required Tools

```bash
# Verify Nix is installed
nix --version
# Should output: nix (Nix) 2.x.x or higher

# Verify file command (for binary inspection)
which file

# Verify readelf (for ELF inspection)
which readelf
```

### Environment Setup

```bash
# Accept Android SDK license
export NIXPKGS_ACCEPT_ANDROID_SDK_LICENSE=1

# Optional: Enable Nix flakes (if using flakes)
export NIX_CONFIG="experimental-features = nix-command flakes"

# Set this in your shell profile (~/.bashrc or ~/.zshrc) for permanence
echo 'export NIXPKGS_ACCEPT_ANDROID_SDK_LICENSE=1' >> ~/.bashrc
```

### File Checklist

Ensure all required files exist:

```bash
#!/bin/bash
# Run this from project root

echo "=== File Existence Check ==="
files=(
  ".idx/overlays/default.nix"
  ".idx/overlays/android-sdk.nix"
  ".idx/overlays/cross-android.nix"
  ".idx/modules/config.nix"
  ".idx/modules/android-architectures.nix"
  ".idx/modules/gstreamer-daemon/android-libs-bundle.nix"
  ".idx/modules/gstreamer-daemon/interpipe-android.nix"
  ".idx/modules/gstreamer-daemon/gstd-android.nix"
  ".idx/patches/gstd-as-library.patch"
)

missing=0
for file in "${files[@]}"; do
  if [ -f "$file" ]; then
    lines=$(wc -l < "$file")
    printf "✓ %-60s (%3d lines)\n" "$file" "$lines"
  else
    printf "✗ %-60s (MISSING)\n" "$file"
    ((missing++))
  fi
done

echo ""
if [ $missing -eq 0 ]; then
  echo "✅ All files present!"
else
  echo "❌ $missing file(s) missing!"
  exit 1
fi
```

---

## Phase 1: Syntax & Configuration Validation

### Test 1.1: Parse Nix Files

Verify all Nix files have correct syntax:

```bash
echo "=== Parsing Nix Files ==="

# Parse each overlay
for file in .idx/overlays/*.nix; do
  echo "Parsing $file..."
  if nix-instantiate --parse "$file" > /dev/null 2>&1; then
    echo "  ✓ Valid syntax"
  else
    echo "  ✗ Syntax error!"
    nix-instantiate --parse "$file"
    exit 1
  fi
done

# Parse module files
for file in .idx/modules/**/*.nix; do
  echo "Parsing $file..."
  if nix-instantiate --parse "$file" > /dev/null 2>&1; then
    echo "  ✓ Valid syntax"
  else
    echo "  ✗ Syntax error!"
    nix-instantiate --parse "$file"
    exit 1
  fi
done

echo "✅ All files have valid syntax"
```

**Expected:** All files parse without errors.

### Test 1.2: Overlay Loading

Verify overlays load correctly:

```bash
echo "=== Testing Overlay Loading ==="

nix-instantiate --eval --strict --expr '
  let
    pkgs = import <nixpkgs> {
      config.android_sdk.accept_license = true;
      overlays = import ./.idx/overlays/default.nix;
    };
  in
  {
    hasAndroidSdk = pkgs ? androidSdk;
    hasArchitectures = pkgs ? androidArchitectures;
    hasPkgsAarch64 = pkgs ? pkgsAndroid_aarch64;
    hasCrossFile = pkgs ? mesonCrossFile_aarch64;
    hasPatches = pkgs ? patches;
  }
'
```

**Expected output:**
```nix
{
  hasAndroidSdk = true;
  hasArchitectures = true;
  hasPkgsAarch64 = true;
  hasCrossFile = true;
  hasPatches = true;
}
```

### Test 1.3: Configuration Values

Verify config.nix values:

```bash
echo "=== Configuration Check ==="

nix-instantiate --eval --strict .idx/modules/config.nix
```

**Expected output:**
```nix
{
  android = {
    apiLevel = 34;
    ndkVersion = "26.1.10909125";
  };
}
```

### Test 1.4: Architecture Definitions

```bash
echo "=== Architecture Definitions ==="

nix-instantiate --eval --strict --expr '
  let
    pkgs = import <nixpkgs> {
      config.android_sdk.accept_license = true;
      overlays = import ./.idx/overlays/default.nix;
    };
  in
  builtins.attrNames pkgs.androidArchitectures
'
```

**Expected output:**
```
[ "aarch64" "armv7a" "x86_64" ]
```

---

## Phase 2: Platform Verification

### Test 2.1: Target Platform Configuration

**THIS IS THE MOST CRITICAL TEST** - it verifies you're targeting Android (Bionic) not generic Linux (glibc):

```bash
echo "=== Platform Verification (CRITICAL) ==="

nix-instantiate --eval --strict --expr '
  let
    pkgs = import <nixpkgs> {
      config.android_sdk.accept_license = true;
      overlays = import ./.idx/overlays/default.nix;
    };
    p = pkgs.pkgsAndroid_aarch64.stdenv.hostPlatform;
  in
  {
    config = p.config;
    libc = p.libc or "unknown";
    isAndroid = p.isAndroid or false;
  }
'
```

**✅ CORRECT output (Android with Bionic):**
```nix
{
  config = "aarch64-linux-android";  # ← Must end in "-android"
  libc = "bionic";                   # ← Must be "bionic" (NOT "glibc"!)
  isAndroid = true;                  # ← Must be true
}
```

**❌ WRONG output (Generic Linux):**
```nix
{
  config = "aarch64-linux-gnu";      # ← Ends in "-gnu" (WRONG!)
  libc = "glibc";                    # ← glibc (WRONG!)
  isAndroid = false;                 # ← false (WRONG!)
}
```

If you get the WRONG output, **STOP** - your libraries will not work on Android!

### Test 2.2: All Architectures

Verify all three architectures are configured correctly:

```bash
echo "=== Testing All Architectures ==="

for arch in aarch64 armv7a x86_64; do
  echo ""
  echo "Testing $arch..."
  result=$(nix-instantiate --eval --strict --expr "
    let
      pkgs = import <nixpkgs> {
        config.android_sdk.accept_license = true;
        overlays = import ./.idx/overlays/default.nix;
      };
      p = pkgs.pkgsAndroid_${arch}.stdenv.hostPlatform;
    in
    {
      config = p.config;
      libc = p.libc or \"unknown\";
      isAndroid = p.isAndroid or false;
    }
  ")
  
  echo "$result"
  
  # Check for Bionic
  if echo "$result" | grep -q '"bionic"'; then
    echo "  ✓ Using Bionic libc"
  else
    echo "  ✗ NOT using Bionic!"
    exit 1
  fi
  
  # Check for Android
  if echo "$result" | grep -q 'isAndroid = true'; then
    echo "  ✓ Marked as Android"
  else
    echo "  ✗ NOT marked as Android!"
    exit 1
  fi
done

echo ""
echo "✅ All architectures correctly configured"
```

### Test 2.3: Meson Cross-File Generation

Verify the Meson cross-file is generated correctly:

```bash
echo "=== Meson Cross-File Generation ==="

nix-build --no-out-link -E '
  (import <nixpkgs> {
    config.android_sdk.accept_license = true;
    overlays = import ./.idx/overlays/default.nix;
  }).mesonCrossFile_aarch64
'

echo ""
echo "Generated cross-file:"
cat result
```

**Expected content (verify these lines exist):**
```ini
[binaries]
c = '/nix/store/.../bin/aarch64-linux-android34-clang'
cpp = '/nix/store/.../bin/aarch64-linux-android34-clang++'
pkgconfig = '/nix/store/.../bin/pkg-config'

[properties]
sys_root = '/nix/store/.../sysroot'

[host_machine]
system = 'android'
cpu_family = 'aarch64'
```

---

## Phase 3: Incremental Component Builds

Build individual components to catch errors early.

### Test 3.1: Build gst-interpipe (ARM64)

This builds just the interpipe plugin:

```bash
echo "=== Building gst-interpipe for Android ARM64 ==="

nix-build -E '
  let
    pkgs = import <nixpkgs> {
      config.android_sdk.accept_license = true;
      overlays = import ./.idx/overlays/default.nix;
    };
  in
  import ./.idx/modules/gstreamer-daemon/interpipe-android.nix {
    inherit pkgs;
    pkgsAndroid = pkgs.pkgsAndroid_aarch64;
    mesonCrossFile = pkgs.mesonCrossFile_aarch64;
  }
' -o result-interpipe-arm64

echo ""
echo "✅ Build complete! Checking output..."
ls -lh result-interpipe-arm64/lib/gstreamer-1.0/
```

**Expected output:**
```
lrwxrwxrwx 1 user user XX result-interpipe-arm64 -> /nix/store/...
-r-xr-xr-x 1 user user XXXK libgstinterpipe.so
```

**Time estimate:** 10-30 minutes (first build)

### Test 3.2: Verify interpipe Binary

```bash
echo "=== Verifying interpipe Binary ==="

file result-interpipe-arm64/lib/gstreamer-1.0/libgstinterpipe.so
readelf -h result-interpipe-arm64/lib/gstreamer-1.0/libgstinterpipe.so | grep -E "Class|Machine|OS/ABI"
```

**Expected output:**
```
libgstinterpipe.so: ELF 64-bit LSB shared object, ARM aarch64, version 1 (SYSV), dynamically linked, ...
  Class:                             ELF64
  Machine:                           AArch64
  OS/ABI:                            UNIX - System V
```

### Test 3.3: Build gstd (ARM64)

**Note:** This requires a valid `gstd-as-library.patch` file.

```bash
echo "=== Building gstd for Android ARM64 ==="

# First, verify the patch exists
if [ ! -f .idx/patches/gstd-as-library.patch ]; then
  echo "❌ ERROR: gstd-as-library.patch not found!"
  echo "You must create this patch first. See TESTING.md Phase 3.4"
  exit 1
fi

nix-build -E '
  let
    pkgs = import <nixpkgs> {
      config.android_sdk.accept_license = true;
      overlays = import ./.idx/overlays/default.nix;
    };
    interpipe = import ./.idx/modules/gstreamer-daemon/interpipe-android.nix {
      inherit pkgs;
      pkgsAndroid = pkgs.pkgsAndroid_aarch64;
      mesonCrossFile = pkgs.mesonCrossFile_aarch64;
    };
  in
  import ./.idx/modules/gstreamer-daemon/gstd-android.nix {
    inherit pkgs;
    pkgsAndroid = pkgs.pkgsAndroid_aarch64;
    mesonCrossFile = pkgs.mesonCrossFile_aarch64;
    gst-interpipe-android = interpipe;
    gstd-as-library-patch = pkgs.patches.gstd-as-library;
  }
' -o result-gstd-arm64

echo ""
echo "✅ Build complete! Checking output..."
ls -lh result-gstd-arm64/lib/
```

**Expected output:**
```
-r-xr-xr-x 1 user user XXXK libgstd.so
```

**Time estimate:** 15-45 minutes

### Test 3.4: Creating gstd-as-library.patch

If you don't have the patch yet, create it:

```bash
#!/bin/bash
echo "=== Creating gstd-as-library.patch ==="

cd /tmp
git clone https://github.com/RidgeRun/gstd-1.x.git
cd gstd-1.x
git checkout v0.15.2

# Backup original
cp gstd/meson.build gstd/meson.build.orig

# Edit the file (you need to do this manually)
echo "Now edit gstd/meson.build:"
echo "  1. Find: executable('gstd',"
echo "  2. Change to: shared_library('gstd',"
echo "  3. Remove: 'main.c' from sources (if present)"
echo "  4. Save and exit"
echo ""
read -p "Press Enter after editing..."

# Generate patch
git diff gstd/meson.build > gstd-as-library.patch

echo "Patch created. Copy it to your project:"
echo "  cp /tmp/gstd-1.x/gstd-as-library.patch ~/your-project/.idx/patches/"
```

---

## Phase 4: Full Bundle Build

### Test 4.1: Build Complete Bundle (ARM64)

```bash
echo "=== Building Complete Android Bundle (ARM64) ==="

export NIXPKGS_ACCEPT_ANDROID_SDK_LICENSE=1

nix-build .idx/dev.nix -A packages.androidLibs-aarch64 -o result-bundle-arm64

echo ""
echo "✅ Bundle built! Contents:"
ls -lh result-bundle-arm64/lib/
```

**Expected output:**
```
drwxr-xr-x 2 user user 4.0K gstreamer-1.0/
-r-xr-xr-x 1 user user XXXK libgstd.so
-r-xr-xr-x 1 user user XXXK libgstreamer-1.0.so
-r-xr-xr-x 1 user user XXXK libglib-2.0.so
... (many more .so files)
```

**Time estimate:** 1-3 hours (first build, includes GStreamer)

### Test 4.2: View Build Info

```bash
cat result-bundle-arm64/BUILD_INFO.txt
```

**Verify this output shows:**
```
TARGET SYSTEM VERIFICATION:
  Platform Config:     aarch64-linux-android   ✓
  C Library:           bionic                  ✓
  Is Android:          YES ✓                   ✓
```

### Test 4.3: Build All Architectures

```bash
echo "=== Building for All Architectures ==="

export NIXPKGS_ACCEPT_ANDROID_SDK_LICENSE=1

nix-build .idx/dev.nix -A packages.all -o result-all-archs

echo ""
echo "✅ All architectures built!"
du -sh result-all-archs/lib/
```

**Time estimate:** 3-8 hours (first build)

---

## Phase 5: Binary Verification

### Test 5.1: Check Binary Architecture

```bash
echo "=== Binary Architecture Check ==="

for lib in result-bundle-arm64/lib/*.so; do
  echo ""
  echo "$(basename $lib):"
  file "$lib" | grep -o "ELF.*"
done
```

**Expected:** All show `ELF 64-bit LSB shared object, ARM aarch64`

### Test 5.2: Check Dependencies (Critical!)

```bash
echo "=== Dependency Check (Bionic vs glibc) ==="

readelf -d result-bundle-arm64/lib/libgstd.so | grep NEEDED
```

**✅ CORRECT output (Android/Bionic):**
```
0x0000000000000001 (NEEDED)   Shared library: [libc.so]
0x0000000000000001 (NEEDED)   Shared library: [libm.so]
0x0000000000000001 (NEEDED)   Shared library: [libdl.so]
```

**❌ WRONG output (Linux/glibc):**
```
0x0000000000000001 (NEEDED)   Shared library: [libc.so.6]     ← .6 = glibc!
0x0000000000000001 (NEEDED)   Shared library: [libm.so.6]
```

If you see `.so.6`, you're linking against glibc! **Your libraries won't work on Android!**

### Test 5.3: Check for glibc Symbols

```bash
echo "=== Checking for glibc Contamination ==="

if readelf -s result-bundle-arm64/lib/*.so 2>/dev/null | grep -i "GLIBC"; then
  echo "❌ ERROR: glibc symbols found!"
  echo "These libraries will NOT work on Android!"
  exit 1
else
  echo "✅ No glibc symbols found - clean Android build"
fi
```

### Test 5.4: Size Check

```bash
echo "=== Library Sizes ==="

du -h result-bundle-arm64/lib/*.so | sort -h
echo ""
echo "Total size:"
du -sh result-bundle-arm64/lib/
```

**Typical sizes:**
- `libgstd.so`: 500KB - 2MB
- `libgstinterpipe.so`: 50KB - 200KB
- `libgstreamer-1.0.so`: 1MB - 3MB

---

## Phase 6: Android Deployment

### Test 6.1: Copy to Android Project

```bash
#!/bin/bash
echo "=== Deploying to Android Project ==="

# Configuration
PROJECT_ROOT="$(pwd)"
ANDROID_PROJECT="$PROJECT_ROOT/agdk-eframe"  # Adjust path
JNI_DIR="$ANDROID_PROJECT/app/src/main/jniLibs/arm64-v8a"

# Create directory
mkdir -p "$JNI_DIR"

# Copy libraries
echo "Copying libraries to $JNI_DIR..."
cp -v result-bundle-arm64/lib/*.so "$JNI_DIR/"
cp -v result-bundle-arm64/lib/gstreamer-1.0/*.so "$JNI_DIR/"

echo ""
echo "✅ Libraries deployed!"
ls -lh "$JNI_DIR/"*.so | wc -l
echo "libraries copied."
```

### Test 6.2: Verify Android Project Structure

```bash
echo "=== Android Project Structure ==="

tree agdk-eframe/app/src/main/jniLibs/ -L 2

# Or without tree:
find agdk-eframe/app/src/main/jniLibs/ -name "*.so" | sort
```

**Expected structure:**
```
jniLibs/
├── arm64-v8a/
│   ├── libgstd.so
│   ├── libgstinterpipe.so
│   ├── libgstreamer-1.0.so
│   └── ... (other .so files)
├── armeabi-v7a/  (optional)
└── x86_64/       (optional, for emulator)
```

### Test 6.3: Android Build Test

```bash
echo "=== Android Gradle Build Test ==="

cd agdk-eframe

# Clean build
./gradlew clean

# Build APK
./gradlew assembleDebug

echo ""
echo "✅ APK built! Check for .so files in APK:"
unzip -l app/build/outputs/apk/debug/app-debug.apk | grep "\.so$"
```

**Expected:** Your .so files should appear in the APK under `lib/arm64-v8a/`

---

## Troubleshooting

### Issue 1: "syntax error, unexpected end of file"

**Symptom:**
```
error: syntax error, unexpected end of file
at /home/user/project/.idx/overlays/cross-android.nix:86:3
```

**Cause:** File is incomplete or has mismatched braces.

**Fix:**
```bash
# Check file completeness
wc -l .idx/overlays/cross-android.nix
# Should be ~162 lines

# Validate syntax
nix-instantiate --parse .idx/overlays/cross-android.nix
```

### Issue 2: "attribute 'families' missing"

**Symptom:**
```
error: attribute 'families' missing
at .../lib/systems/parse.nix:501:13
```

**Cause:** Incorrectly constructed `parsed` platform attribute.

**Fix:** Remove manual `parsed` structure, let Nix parse automatically:
```nix
crossSystem = {
  config = "aarch64-linux-android";
  # Don't manually set 'parsed'!
};
```

### Issue 3: Libraries link against glibc instead of Bionic

**Symptom:**
```bash
readelf -d libgstd.so | grep NEEDED
# Shows: libc.so.6 (wrong!)
```

**Diagnosis:**
```bash
# Check platform config
nix-instantiate --eval --strict --expr '...'  # See Test 2.1

# If libc != "bionic", you're building for wrong target
```

**Fix:** Verify `cross-android.nix` has:
```nix
crossSystem = {
  config = "${archConfig.gccPrefix}-linux-android";  # Must end in "-android"
  libc = "bionic";
  isAndroid = true;
};
```

### Issue 4: NDK not found

**Symptom:**
```
Android NDK not found at: /nix/store/.../ndk/26.1.10909125
```

**Fix:**
```bash
# Check NDK version in config
cat .idx/modules/config.nix

# List available NDK versions
nix-instantiate --eval --expr '
  (import <nixpkgs> {}).androidenv.androidPkgs_9_0.ndk-bundle.version
'

# Update config.nix with correct version
```

### Issue 5: Out of disk space during build

**Symptom:**
```
error: while copying to store: No space left on device
```

**Fix:**
```bash
# Check Nix store size
du -sh /nix/store

# Clean old generations
nix-collect-garbage -d

# Clean build artifacts
rm -rf result*
```

---

## Performance Tips

### Tip 1: Use Binary Caches

```bash
# Add to ~/.config/nix/nix.conf
substituters = https://cache.nixos.org https://nix-community.cachix.org
trusted-public-keys = cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY=
```

### Tip 2: Parallel Builds

```bash
# Add to ~/.config/nix/nix.conf
max-jobs = auto
cores = 0  # Use all available cores
```

### Tip 3: Keep Build Outputs

```bash
# Don't delete result symlinks - Nix uses them as GC roots
# Keep them to avoid rebuilding:
nix-build ... -o result-keep
```

### Tip 4: Incremental Testing

```bash
# Test individual components first (faster iteration)
# 1. Test interpipe (~15 min)
# 2. Test gstd (~30 min)
# 3. Full bundle (~2 hours)
```

### Tip 5: Use `nix-shell` for Development

```bash
# Enter development environment without building
nix-shell .idx/dev.nix -A shell

# Now you have all tools available
which pkg-config
echo $ANDROID_NDK_ROOT
```

---

## Quick Reference

### Essential Commands

```bash
# 1. Validate syntax
nix-instantiate --parse .idx/overlays/cross-android.nix

# 2. Check platform (CRITICAL)
nix-instantiate --eval --strict --expr '...' # See Test 2.1

# 3. Build interpipe only
nix-build -E '...' # See Test 3.1

# 4. Build full bundle
nix-build .idx/dev.nix -A packages.androidLibs-aarch64 -o result

# 5. Verify binary
file result/lib/libgstd.so
readelf -d result/lib/libgstd.so | grep NEEDED

# 6. Deploy to Android
cp result/lib/*.so agdk-eframe/app/src/main/jniLibs/arm64-v8a/
```

### Expected Build Times (First Build)

| Component | Time | Size |
|-----------|------|------|
| interpipe | 10-30 min | ~50-200 KB |
| gstd | 15-45 min | ~500 KB - 2 MB |
| Full bundle (ARM64) | 1-3 hours | ~20-50 MB |
| All architectures | 3-8 hours | ~60-150 MB |

**Subsequent builds:** 1-5 minutes (Nix caching!)

---

## Success Criteria

Your setup is working correctly if:

- ✅ Test 2.1 shows `libc = "bionic"` and `isAndroid = true`
- ✅ Test 5.2 shows `libc.so` without version suffix (no `.so.6`)
- ✅ Test 5.3 shows no glibc symbols
- ✅ Libraries load correctly in Android app (runtime test)

---

## Next Steps

1. Run Phase 1-2 tests first (quick validation)
2. Create the `gstd-as-library.patch` if needed
3. Build interpipe (Test 3.1) to verify cross-compilation works
4. Build full bundle (Test 4.1)
5. Deploy to Android project
6. Test on actual Android device

**Time Investment:**
- Setup & Testing: 30-60 minutes
- First Full Build: 2-4 hours
- Subsequent Builds: 1-5 minutes

Good luck! 🚀
