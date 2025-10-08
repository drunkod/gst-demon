# .idx/modules/environment.nix
{ lib, extendedPkgs, gstreamerDaemon, gstreamerAndroid }:

let
  # Detect the actual Android SDK path
  androidSdkPath =
    if builtins.pathExists "${extendedPkgs.androidSdk}/share/android-sdk" then
      "${extendedPkgs.androidSdk}/share/android-sdk"
    else
      "${extendedPkgs.androidSdk}/libexec/android-sdk";
  
  # GStreamer Android source path (from Nix store)
  gstAndroidSource = gstreamerAndroid.source;
in
{
  # Android Environment
  ANDROID_HOME = lib.mkForce androidSdkPath;
  ANDROID_SDK_ROOT = lib.mkForce androidSdkPath;
  ANDROID_NDK_HOME = "${androidSdkPath}/ndk/25.2.9519653";
  ANDROID_NDK_ROOT = "${androidSdkPath}/ndk/25.2.9519653";
  
  # Java Environment
  JAVA_HOME = "${extendedPkgs.jdk17}";
  
  # Rust Environment
  RUST_BACKTRACE = "1";
  PKG_CONFIG_ALLOW_CROSS = "1";
  RUSTFLAGS = "-lffi";
  
  # Android SDK License
  NIXPKGS_ACCEPT_ANDROID_SDK_LICENSE = "1";
  
  # GStreamer Environment (from gstreamerDaemon module)
  GST_PLUGIN_PATH = gstreamerDaemon.env.GST_PLUGIN_PATH;
  GST_PLUGIN_PATH_1_0 = gstreamerDaemon.env.GST_PLUGIN_PATH_1_0;
  GST_PLUGIN_SYSTEM_PATH_1_0 = gstreamerDaemon.env.GST_PLUGIN_SYSTEM_PATH_1_0;
  
  # GStreamer for Android (Nix store path to tarball)
  GSTREAMER_ANDROID_TARBALL = gstAndroidSource;
  
  # Combined PATH
  PATH = [
    # Android paths
    "${androidSdkPath}/cmdline-tools/latest/bin"
    "${androidSdkPath}/ndk/25.2.9519653/toolchains/llvm/prebuilt/linux-x86_64/bin"
    
    # Rust path
    "${extendedPkgs.rustup}/bin"
  ] ++ gstreamerDaemon.pathAdditions;  # Add GStreamer daemon bins to PATH
  
  # Shell hook (keep your existing pattern)
  shellHook = lib.mkAfter ''
    ${gstreamerDaemon.shellHook}
    
    # GStreamer for Android info
    if [ -z "$_GST_ANDROID_INFO_SHOWN" ]; then
      export _GST_ANDROID_INFO_SHOWN=1
      
      if [ -f "$GSTREAMER_ANDROID_TARBALL" ]; then
        TARBALL_SIZE=$(du -h "$GSTREAMER_ANDROID_TARBALL" 2>/dev/null | cut -f1 || echo "unknown")
        echo ""
        echo "📦 GStreamer for Android available"
        echo "   Tarball: $GSTREAMER_ANDROID_TARBALL"
        echo "   Size: $TARBALL_SIZE"
        echo ""
        echo "Setup:"
        echo "  • setup-android-env        - Extract GStreamer binaries"
        echo "  • verify-gstreamer-android - Verify installation"
        echo ""
      fi
    fi
  '';
}