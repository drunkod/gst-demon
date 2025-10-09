# .idx/modules/environment.nix
{ lib, extendedPkgs, gstreamerDaemon, gstreamerAndroid, config }:

let
  # Detect the actual Android SDK path dynamically
  androidSdkPath =
    if builtins.pathExists "${extendedPkgs.androidSdk}/share/android-sdk" then
      "${extendedPkgs.androidSdk}/share/android-sdk"
    else
      "${extendedPkgs.androidSdk}/libexec/android-sdk";
  
  # Build NDK path dynamically from config
  androidNdkPath = "${androidSdkPath}/ndk/${config.android.ndkVersion}";
  
  # GStreamer Android source path (from Nix store)
  gstAndroidSource = gstreamerAndroid.source;
  
  # Toolchain path
  ndkToolchainPath = "${androidNdkPath}/toolchains/llvm/prebuilt/linux-x86_64/bin";
  
in
{
  # ========================================================================
  # Android Environment
  # ========================================================================
  
  ANDROID_HOME = lib.mkForce androidSdkPath;
  ANDROID_SDK_ROOT = lib.mkForce androidSdkPath;
  ANDROID_NDK_HOME = androidNdkPath;
  ANDROID_NDK_ROOT = androidNdkPath;
  
  # Android API Level
  ANDROID_API_LEVEL = config.android.apiLevel;
  
  # ========================================================================
  # Java Environment
  # ========================================================================
  
  JAVA_HOME = "${extendedPkgs.jdk17}";
  
  # ========================================================================
  # Rust Environment
  # ========================================================================
  
  RUST_BACKTRACE = "1";
  PKG_CONFIG_ALLOW_CROSS = "1";
  RUSTFLAGS = "-lffi";
  
  # ========================================================================
  # Android SDK License
  # ========================================================================
  
  NIXPKGS_ACCEPT_ANDROID_SDK_LICENSE = "1";
  
  # ========================================================================
  # GStreamer Environment (Host development)
  # ========================================================================
  
  GST_PLUGIN_PATH = gstreamerDaemon.env.GST_PLUGIN_PATH;
  GST_PLUGIN_PATH_1_0 = gstreamerDaemon.env.GST_PLUGIN_PATH_1_0;
  GST_PLUGIN_SYSTEM_PATH_1_0 = gstreamerDaemon.env.GST_PLUGIN_SYSTEM_PATH_1_0;
  
  # ========================================================================
  # GStreamer for Android (Nix store path to tarball)
  # ========================================================================
  
  GSTREAMER_ANDROID_TARBALL = gstAndroidSource;
  GSTREAMER_ANDROID_VERSION = config.gstreamer.version;
  
  # ========================================================================
  # Combined PATH
  # ========================================================================
  
  PATH = [
    # Android SDK tools
    "${androidSdkPath}/cmdline-tools/latest/bin"
    "${androidSdkPath}/platform-tools"
    
    # Android NDK toolchain
    ndkToolchainPath
    
    # Rust toolchain
    "${extendedPkgs.rustup}/bin"
    
    # GStreamer Daemon tools
  ] ++ gstreamerDaemon.pathAdditions;
  
  # ========================================================================
  # Shell Hook
  # ========================================================================
  
  shellHook = lib.mkAfter ''
    ${gstreamerDaemon.shellHook}
    
    # Display environment info on first shell entry
    if [ -z "$_ENV_INFO_SHOWN" ]; then
      export _ENV_INFO_SHOWN=1
      
      echo ""
      echo "════════════════════════════════════════════════════════════"
      echo "  Development Environment Ready"
      echo "════════════════════════════════════════════════════════════"
      echo ""
      
      # Android info
      echo "📱 Android:"
      echo "   SDK:     ${androidSdkPath}"
      echo "   NDK:     ${androidNdkPath}"
      echo "   API:     ${config.android.apiLevel}"
      
      # Verify NDK exists
      if [ -d "${androidNdkPath}" ]; then
        echo "   Status:  ✅ Ready"
      else
        echo "   Status:  ⚠️  NDK not found at expected location"
      fi
      
      echo ""
      
      # GStreamer info
      echo "🎬 GStreamer:"
      if [ -f "$GSTREAMER_ANDROID_TARBALL" ]; then
        TARBALL_SIZE=$(du -h "$GSTREAMER_ANDROID_TARBALL" 2>/dev/null | cut -f1 || echo "unknown")
        echo "   Version: ${config.gstreamer.version}"
        echo "   Tarball: $TARBALL_SIZE"
        echo "   Status:  ✅ Available"
      else
        echo "   Status:  ⚠️  Tarball not found"
      fi
      
      echo ""
      
      # Rust info
      if command -v rustc &> /dev/null; then
        RUST_VERSION=$(rustc --version | cut -d' ' -f2)
        echo "🦀 Rust:    $RUST_VERSION"
      fi
      
      echo ""
      echo "════════════════════════════════════════════════════════════"
      echo ""
      echo "Quick Start:"
      echo "  1. Setup GStreamer:        setup-android-env"
      echo "  2. Build Android libs:     deploy-gstd-android"
      echo "  3. Build APK:              cd agdk-eframe && ./build-apk"
      echo ""
      echo "Verification:"
      echo "  • verify-gstreamer-android      - Check GStreamer tarball"
      echo "  • verify-gstd-android-libs      - Check built libraries"
      echo ""
      echo "Host Development:"
      echo "  • gstd-start / gstd-stop        - Control GStreamer Daemon"
      echo "  • gst-client                    - Daemon client"
      echo ""
    fi
  '';
}