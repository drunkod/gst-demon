# GStreamer Android - Quick Reference

## Environment Variables

| Variable | Description | Example Value |
|----------|-------------|---------------|
| `GSTREAMER_ANDROID_TARBALL` | Path to GStreamer tarball in Nix store | `/nix/store/xxx-gstreamer-1.0-android-universal-1.26.6.tar.xz` |
| `ANDROID_HOME` | Android SDK root | `/nix/store/yyy-android-sdk/libexec/android-sdk` |
| `ANDROID_NDK_HOME` | Android NDK root | `$ANDROID_HOME/ndk/25.2.9519653` |

## Commands

### Setup Commands

```bash
# Extract GStreamer for Android (first time)
setup-android-env

# Force re-extraction (if corrupted)
setup-android-env --force

# Verify installation
verify-gstreamer-android

# Get tarball path
gstreamer-android-path
```

### Build Commands

```bash
# Build GStreamer Daemon for Android
build-gstd-android

# Build only for specific architectures
ARCHITECTURES="arm64-v8a armeabi-v7a" build-gstd-android

# Clean build artifacts
build-gstd-android clean

# Build APK
cd agdk-eframe
./build-apk

# Debug build
BUILD_MODE=debug ./build-apk
```

### Host Development (Testing)

```bash
# Start GStreamer Daemon on host
gstd-start

# Check status
gstd-status

# Stop daemon
gstd-stop

# Use client
gst-client pipeline_create test "videotestsrc ! fakesink"
gst-client pipeline_play test
```

## Directory Structure

```
project-root/
├── .idx/
│   ├── modules/
│   │   ├── config.nix                    # ← GStreamer version config
│   │   ├── gstreamer-android/           # ← Download module
│   │   │   ├── default.nix
│   │   │   └── gstreamer-source.nix
│   │   ├── packages.nix                 # ← Uses gstreamerAndroid
│   │   ├── environment.nix              # ← Exposes $GSTREAMER_ANDROID_TARBALL
│   │   └── workspace.nix                # ← Auto-extracts on onCreate
│   └── scripts/
│       ├── setup-android-env.sh         # ← Extraction script
│       └── build-gstd-android.sh        # ← Build script
│
├── gstreamer-android/                   # ← Extracted here
│   ├── arm64/
│   │   ├── lib/
│   │   │   ├── pkgconfig/              # ← Used by pkg-config
│   │   │   ├── gstreamer-1.0/          # ← GStreamer plugins
│   │   │   └── *.so                    # ← Shared libraries
│   │   └── include/
│   ├── armv7/
│   ├── x86_64/
│   └── GSTREAMER_INFO.txt
│
└── agdk-eframe/
    ├── app/src/main/jniLibs/           # ← Copied here by build-gstd-android
    │   └── arm64-v8a/
    │       ├── libgstd.so
    │       ├── libgstinterpipe.so
    │       └── libgstreamer-1.0.so
    └── build-apk                        # ← Build script
```

## Workflow

### Initial Setup (Automatic)

```bash
# Enter development environment
nix develop

# Workspace onCreate runs automatically:
# 1. Downloads GStreamer tarball (cached in Nix store)
# 2. Extracts to ./agdk-eframe/gstreamer-android/
# 3. Sets up OpenSSL
# 4. Creates build-apk script
```

### Manual Setup (If Needed)

```bash
# If extraction failed or you want to refresh
setup-android-env --force

# Verify everything is ready
verify-gstreamer-android
```

### Building GStreamer Daemon

```bash
# Build for default architecture (arm64-v8a)
build-gstd-android

# Build for multiple architectures
ARCHITECTURES="arm64-v8a armeabi-v7a x86_64" build-gstd-android

# Output will be in:
# - android-libs/arm64-v8a/lib/libgstd.so
# - agdk-eframe/app/src/main/jniLibs/arm64-v8a/libgstd.so
```

### Building APK

```bash
cd agdk-eframe

# Release build (default)
./build-apk

# Debug build
BUILD_MODE=debug ./build-apk

# Install and run immediately
INSTALL_AND_RUN=1 ./build-apk
```

## Common Issues

### Issue: "GStreamer for Android not found"

```bash
# Check if tarball is available
echo $GSTREAMER_ANDROID_TARBALL
verify-gstreamer-android

# If missing, rebuild environment
exit  # Exit nix develop
nix develop --rebuild
```

### Issue: "Extraction failed"

```bash
# Try manual extraction
mkdir -p ./gstreamer-android
tar -xJf "$GSTREAMER_ANDROID_TARBALL" -C ./gstreamer-android

# Or use force flag
setup-android-env --force
```

### Issue: "pkgconfig files not found during build"

```bash
# Check extraction
ls -la ./gstreamer-android/arm64/lib/pkgconfig/

# If empty, re-extract
setup-android-env --force

# Verify pkg-config can find GStreamer
export PKG_CONFIG_PATH="$PWD/gstreamer-android/arm64/lib/pkgconfig"
pkg-config --modversion gstreamer-1.0
```

### Issue: "Library loading failed on Android"

Check library order in `GstdNative.kt`:

```kotlin
// Must be in dependency order!
private val LIBRARIES = arrayOf(
    "glib-2.0",        // 1. Base
    "gobject-2.0",
    "gstreamer-1.0",   // 2. Core
    "gstd"             // 3. Our libraries
)
```

### Issue: "Missing symbols when linking"

```bash
# Check what libraries are actually needed
cd android-libs/arm64-v8a/lib
readelf -d libgstd.so | grep NEEDED

# Make sure all dependencies are copied to jniLibs
```

## Configuration Changes

### Update GStreamer Version

Edit `.idx/modules/config.nix`:

```nix
{
  gstreamerVersion = "1.28.0";  # Change this
  gstreamerUrl = "https://gstreamer.freedesktop.org/data/pkg/android/1.28.0/";
  gstreamerSha256 = "...";  # Get new hash with nix-prefetch-url
}
```

Then:
```bash
nix develop --rebuild
setup-android-env --force
build-gstd-android clean
build-gstd-android
```

### Change Android API Level

Edit `.idx/cross-files/android-aarch64.ini`:

```ini
[binaries]
c = 'aarch64-linux-android26-clang'  # Change 24 → 26
cpp = 'aarch64-linux-android26-clang++'

[properties]
c_args = [
  '-D__ANDROID_API__=26',  # Change 24 → 26
  # ...
]
```

## Debugging

### Check What's in the Tarball

```bash
tar -tJf "$GSTREAMER_ANDROID_TARBALL" | head -20
```

### Verify Library Dependencies

```bash
# On Android device
adb shell "readelf -d /data/app/.../lib/arm64/libgstd.so | grep NEEDED"
```

### Monitor Logs

```bash
# Watch GStreamer logs
adb logcat -s GStreamer:V GstdNative:V

# Watch all logs
adb logcat | grep -E "(GStreamer|gstd|MainActivity)"
```

## Performance Tips

1. **Use Release Builds**: `BUILD_MODE=release ./build-apk`
2. **Strip Symbols**: Add `-Wl,--strip-all` to link flags
3. **Exclude Unused Plugins**: Only copy needed `.so` files to jniLibs
4. **Use ProGuard**: Enable code shrinking in `build.gradle`

## Security Considerations

1. **Bind to localhost only**: In `GstdNative.kt`, ensure:
   ```kotlin
   "--http-address=127.0.0.1",  // Not 0.0.0.0!
   "--tcp-address=127.0.0.1",
   ```

2. **No public network access**: GStreamer Daemon should not be exposed to external networks

3. **Validate inputs**: Always validate pipeline descriptions before passing to gstd

## Resources

- [GStreamer Documentation](https://gstreamer.freedesktop.org/documentation/)
- [GStreamer Daemon Wiki](https://developer.ridgerun.com/wiki/index.php/GStreamer_Daemon)
- [Android NDK Documentation](https://developer.android.com/ndk)
- [Nix Package Manager](https://nixos.org/manual/nix/stable/)

## Support

For issues specific to this integration:
1. Check `.idx/README.md` for architecture details
2. Run `verify-gstreamer-android` for diagnostics
3. Check build logs in `/tmp/gstd-android-build/`
4. Review environment with `env | grep -E "(GST|ANDROID)"`