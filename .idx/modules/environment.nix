# .idx/modules/environment.nix
{ extendedPkgs, config }:

{
    # ═══════════════════════════════════════════════════════════════════
  # Android SDK License Acceptance
  # ═══════════════════════════════════════════════════════════════════
  NIXPKGS_ACCEPT_ANDROID_SDK_LICENSE = "1";
  # Android paths (no build, just references)
  ANDROID_SDK_ROOT = "${extendedPkgs.androidSdk}/libexec/android-sdk";
  ANDROID_NDK_ROOT = "${extendedPkgs.androidSdk}/libexec/android-sdk/ndk-bundle";
  
  # Config
  ANDROID_API_LEVEL = config.android.apiLevel;
  GSTREAMER_VERSION = config.gstreamer.version;
  
  shellHook = ''
    echo ""
    echo "════════════════════════════════════════════════════════════"
    echo "  Android Cross-Compilation Environment"
    echo "════════════════════════════════════════════════════════════"
    echo ""
    echo "✅ Overlays loaded (no packages built yet)"
    echo ""
    echo "Available in extendedPkgs:"
    echo "  • androidSdk"
    echo "  • androidArchitectures"
    echo "  • pkgsAndroid_aarch64"
    echo "  • pkgsAndroid_armv7a"
    echo "  • pkgsAndroid_x86_64"
    echo "  • mesonCrossFile_aarch64"
    echo "  • gstdPatches"
    echo ""
    echo "Configuration:"
    echo "  Android API: ${config.android.apiLevel}"
    echo "  GStreamer:   ${config.gstreamer.version}"
    echo ""
    echo "Build manually with nix-build:"
    echo ""
    echo ""
    echo "Or use helper scripts in .idx/scripts/"
    echo ""
  '';
}