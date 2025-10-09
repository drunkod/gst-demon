# .idx/dev.nix
# Main entry point for the development environment
{ pkgs ? import <nixpkgs> {} }:

let
  # Load all overlays
  overlays = import ./overlays/default.nix;
  
  # Apply overlays to pkgs
  extendedPkgs = pkgs.extend (self: super:
    builtins.foldl' (acc: overlay: acc // (overlay self super)) {} overlays
  );

  # Bundle builder function
  mkAndroidBundle = import ./modules/gstreamer-daemon/android-libs-bundle.nix {
    pkgs = extendedPkgs;
  };

  # Build bundles for all architectures
  androidLibs-aarch64 = mkAndroidBundle "aarch64";
  androidLibs-armv7a = mkAndroidBundle "armv7a";
  androidLibs-x86_64 = mkAndroidBundle "x86_64";

in
{
  # Packages that can be built with `nix-build`
  packages = {
    # Build with: nix-build .idx/dev.nix -A packages.androidLibs-aarch64
    inherit androidLibs-aarch64 androidLibs-armv7a androidLibs-x86_64;
    
    # Default build target (ARM64)
    default = androidLibs-aarch64;
    
    # Convenience: all architectures
    all = extendedPkgs.symlinkJoin {
      name = "gstreamer-daemon-all-archs";
      paths = [ androidLibs-aarch64 androidLibs-armv7a androidLibs-x86_64 ];
    };
  };

  # Development shell
  shell = extendedPkgs.mkShell {
    name = "gstreamer-daemon-android-dev";
    
    buildInputs = with extendedPkgs; [
      # Android development tools
      androidSdk
      
      # Build tools
      pkg-config
      meson
      ninja
      cmake
      
      # GStreamer tools (for host testing)
      gst_all_1.gstreamer
      gst_all_1.gst-plugins-base
      gst_all_1.gst-devtools
      
      # Utilities
      git
      curl
      jq
      
      # Make the ARM64 bundle available in shell
      androidLibs-aarch64
    ];

    shellHook = ''
      echo "════════════════════════════════════════════════════════════"
      echo "  GStreamer Daemon - Android Cross-Compilation Environment"
      echo "════════════════════════════════════════════════════════════"
      echo ""
      echo "📱 Target Android API Level: ${(import ./modules/config.nix).android.apiLevel}"
      echo "🔧 NDK Version: ${(import ./modules/config.nix).android.ndkVersion}"
      echo ""
      echo "Available commands:"
      echo ""
      echo "  Build for specific architecture:"
      echo "    nix-build .idx/dev.nix -A packages.androidLibs-aarch64 -o result-arm64"
      echo "    nix-build .idx/dev.nix -A packages.androidLibs-armv7a -o result-armv7"
      echo "    nix-build .idx/dev.nix -A packages.androidLibs-x86_64 -o result-x86_64"
      echo ""
      echo "  Build all architectures:"
      echo "    nix-build .idx/dev.nix -A packages.all -o result-all"
      echo ""
      echo "  Enter development shell:"
      echo "    nix-shell .idx/dev.nix -A shell"
      echo ""
      echo "════════════════════════════════════════════════════════════"
    '';
    
    # Set environment variables
    ANDROID_SDK_ROOT = "${extendedPkgs.androidSdk}/libexec/android-sdk";
    ANDROID_NDK_ROOT = "${extendedPkgs.androidSdk}/libexec/android-sdk/ndk/${(import ./modules/config.nix).android.ndkVersion}";
  };
}