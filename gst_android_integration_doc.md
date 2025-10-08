# GStreamer Android Integration

This document describes how `gstreamerAndroid` is integrated throughout the Nix module system.

## Overview

The `gstreamerAndroid` module provides pre-compiled GStreamer binaries for Android. It is now properly integrated throughout the build system and exposed to users through environment variables, helper scripts, and automation.

## Architecture

```
dev.nix
  ├─→ config.nix (centralized configuration)
  ├─→ gstreamerAndroid (downloads tarball via Nix)
  │     └─→ gstreamer-source.nix (fetchurl derivation)
  ├─→ packages.nix (uses gstreamerAndroid)
  │     └─→ Creates helper scripts
  ├─→ environment.nix (exposes gstreamerAndroid)
  │     └─→ Sets GSTREAMER_ANDROID_TARBALL
  └─→ workspace.nix (uses gstreamerAndroid in setup)
        └─→ Extracts tarball during onCreate
```

## Module Details

### 1. `config.nix` - Centralized Configuration

```nix
{
  gstreamerVersion = "1.26.6";
  gstreamerUrl = "https://gstreamer.freedesktop.org/data/pkg/android/1.26.6/";
  gstreamerSha256 = "1a889589a1cb1c98a7055375437894a46aab855a8286a9390a88079e1418f099";
}
```

**Purpose**: Single source of truth for GStreamer version and download URL.

### 2. `gstreamer-android/default.nix` - Module Entry Point

```nix
{ pkgs, config }:
{
  source = import ./gstreamer-source.nix {
    inherit pkgs config;
  };
}
```

**Exports**:
- `source` - Path to the downloaded tarball in Nix store

### 3. `gstreamer-android/gstreamer-source.nix` - Download Logic

```nix
pkgs.fetchurl {
  url = config.gstreamerUrl + "/gstreamer-1.0-android-universal-" + config.gstreamerVersion + ".tar.xz";
  sha256 = config.gstreamerSha256;
}
```

**Purpose**: Downloads and caches the GStreamer tarball using Nix's content-addressable store.

### 4. `packages.nix` - Helper Scripts

Creates a package with helper scripts:

```nix
gstreamerAndroidPackage = extendedPkgs.stdenv.mkDerivation {
  name = "gstreamer-android-setup";
  
  installPhase = ''
    # Script to get tarball path
    cat > $out/bin/gstreamer-android-path << 'EOF'
#!/usr/bin/env bash
echo "${gstreamerAndroid.source}"
EOF
    
    # Script to verify installation
    cat > $out/bin/verify-gstreamer-android << 'EOF'
#!/usr/bin/env bash
TARBALL="${gstreamerAndroid.source}"
if [ -f "$TARBALL" ]; then
  echo "✅ GStreamer for Android found at: $TARBALL"
  echo "   Size: $(du -h "$TARBALL" | cut -f1)"
  exit 0
else
  echo "❌ GStreamer for Android not found!"
  exit 1
fi
EOF
  '';
}
```

**Provides**:
- `gstreamer-android-path` - Returns Nix store path to tarball
- `verify-gstreamer-android` - Verifies tarball availability

### 5. `environment.nix` - Environment Variables

```nix
{
  # GStreamer for Android (Nix store path to tarball)
  GSTREAMER_ANDROID_TARBALL = gstreamerAndroid.source;
  
  shellHook = lib.mkAfter ''
    if [ -f "$GSTREAMER_ANDROID_TARBALL" ]; then
      TARBALL_SIZE=$(du -h "$GSTREAMER_ANDROID_TARBALL" | cut -f1)
      echo ""
      echo "📦 GStreamer for Android available"
      echo "   Tarball: $GSTREAMER_ANDROID_TARBALL"
      echo "   Size: $TARBALL_SIZE"
      echo ""
      echo "Setup:"
      echo "  • setup-android-env        - Extract GStreamer binaries"
      echo "  • verify-gstreamer-android - Verify installation"
    fi
  '';
}
```

**Exports**:
- `$GSTREAMER_ANDROID_TARBALL` - Environment variable pointing to tarball

### 6. `workspace.nix` - Automated Setup

```nix
onCreate = {
  setup = ''
    # Extract GStreamer during workspace creation
    GSTREAMER_TARBALL="${gstreamerAndroid.source}"
    
    if [ ! -d "$GSTREAMER_DEST/arm64/lib/pkgconfig" ]; then
      echo "   Extracting GStreamer binaries..."
      tar -xJf "$GSTREAMER_TARBALL" -C "$GSTREAMER_DEST"
    fi
  '';
}
```

**Purpose**: Automatically extracts GStreamer when workspace is created.

## User Workflow

### Initial Setup

When entering the development environment:

```bash
$ nix develop
📦 GStreamer for Android available
   Tarball: /nix/store/xxx-gstreamer-1.0-android-universal-1.26.6.tar.xz
   Size: 245M

Setup:
  • setup-android-env        - Extract GStreamer binaries
  • verify-gstreamer-android - Verify installation
```

### Manual Extraction (Optional)

If needed, users can manually extract:

```bash
$ setup-android-env
[INFO] GStreamer for Android not found. Starting setup...
[SUCCESS] GStreamer tarball found at: /nix/store/...
[INFO] Extracting GStreamer binaries...

✅ arm64
   • pkg-config files: 67
   • GStreamer plugins: 203

[SUCCESS] Successfully extracted GStreamer for Android
```

### Verification

```bash
$ verify-gstreamer-android
✅ GStreamer for Android found at: /nix/store/...
   Size: 245M

To extract:
  tar -xJf "/nix/store/..." -C ./gstreamer-android
```

### Building for Android

```bash
$ build-gstd-android
[INFO] GStreamer for Android found in ./gstreamer-android
[INFO] Building gst-interpipe for arm64-v8a...
[INFO] Building gstd for arm64-v8a...
[SUCCESS] Libraries copied to agdk-eframe/app/src/main/jniLibs/
```

## Benefits of This Integration

### 1. **Reproducibility**
- GStreamer version pinned in `config.nix`
- Nix ensures identical downloads across machines
- SHA256 hash verification prevents tampering

### 2. **Caching**
- Tarball downloaded once per machine
- Stored in `/nix/store`
- Shared across all workspaces

### 3. **Convenience**
- Helper scripts abstract Nix store paths
- Environment variables provide easy access
- Automated extraction in workspace setup

### 4. **Flexibility**
- Users can manually re-extract if needed
- Force flag available: `setup-android-env --force`
- Multiple architectures supported automatically

## File Locations

### Nix Store (Read-only)
```
/nix/store/xxx-gstreamer-1.0-android-universal-1.26.6.tar.xz
  └─→ Downloaded once, cached permanently
```

### Project Directory (Extracted)
```
agdk-eframe/
  └── gstreamer-android/
      ├── arm64/
      │   ├── lib/
      │   │   ├── pkgconfig/
      │   │   └── gstreamer-1.0/
      │   └── include/
      ├── armv7/
      ├── x86/
      ├── x86_64/
      └── GSTREAMER_INFO.txt
```

### JNI Libraries (Build Output)
```
agdk-eframe/app/src/main/jniLibs/
  └── arm64-v8a/
      ├── libgstd.so
      ├── libgstinterpipe.so
      ├── libgstreamer-1.0.so
      ├── libgstbase-1.0.so
      └── ... (other GStreamer libraries)
```

## Configuration Updates

### Changing GStreamer Version

Edit `.idx/modules/config.nix`:

```nix
{
  gstreamerVersion = "1.28.0";  # New version
  gstreamerUrl = "https://gstreamer.freedesktop.org/data/pkg/android/1.28.0/";
  gstreamerSha256 = "new-sha256-hash-here";
}
```

Then:
```bash
$ nix develop  # Downloads new version
$ setup-android-env --force  # Re-extract
```

### Getting SHA256 Hash

```bash
$ nix-prefetch-url https://gstreamer.freedesktop.org/.../gstreamer-1.0-android-universal-1.28.0.tar.xz
```

## Troubleshooting

### Tarball Not Found

```bash
$ verify-gstreamer-android
❌ GStreamer for Android not found!

# Solution: Rebuild the Nix environment
$ nix develop --rebuild
```

### Extraction Failed

```bash
$ setup-android-env --force
[WARNING] Installation appears corrupted. Reinstalling...
```

### Missing Architectures

Some GStreamer packages may not include all architectures. Check:

```bash
$ ls agdk-eframe/gstreamer-android/
arm64  armv7  x86_64  # x86 might be missing in some versions
```

## Integration with Build Scripts

### `build-gstd-android.sh`

Automatically uses extracted GStreamer:

```bash
# Configures PKG_CONFIG_PATH
export PKG_CONFIG_PATH="$PROJECT_ROOT/gstreamer-android/$gst_arch/lib/pkgconfig"

# Builds against GStreamer libraries
meson setup "$build_dir" --cross-file="$cross_file" ...
```

### `build-apk` Script

References GStreamer in environment:

```bash
# GStreamer configuration
export PKG_CONFIG_PATH="$PROJECT_DIR/gstreamer-android/arm64/lib/pkgconfig"
export GST_PLUGIN_PATH="$PROJECT_DIR/gstreamer-android/arm64/lib/gstreamer-1.0"
```

## Summary

The `gstreamerAndroid` module is now fully integrated:

✅ **Declared** in `dev.nix`  
✅ **Passed** to all relevant modules  
✅ **Exposed** via environment variables  
✅ **Accessible** through helper scripts  
✅ **Automated** in workspace setup  
✅ **Documented** for users  

This provides a seamless, reproducible, and user-friendly way to work with GStreamer on Android in the Nix environment.