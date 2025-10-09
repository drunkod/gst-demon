#!/bin/bash
# Complete Android Cross-Compilation Test Suite

set -e

export NIXPKGS_ALLOW_UNFREE=1
export NIXPKGS_ACCEPT_ANDROID_SDK_LICENSE=1

echo "=== Building gst-interpipe for Android ARM64 ==="
echo "This is the first real build - will take 15-30 minutes"
echo ""
echo "Started at: $(date)"
echo ""

time nix-build -E '
  let
    pkgs = import <nixpkgs> {
      config.allowUnfree = true;
      overlays = import ./.idx/overlays/default.nix;
    };
  in
  import ./.idx/modules/gstreamer-daemon/interpipe-android.nix {
    inherit pkgs;
    pkgsAndroid = pkgs.pkgsAndroid_aarch64;
    mesonCrossFile = pkgs.mesonCrossFile_aarch64;
  }
' -o result-interpipe 2>&1 | tee build-interpipe.log

echo ""
echo "Finished at: $(date)"
echo ""

if [ -L result-interpipe ]; then
  echo "✅ Build successful!"
  echo ""
  echo "Plugin location:"
  ls -lh result-interpipe/lib/gstreamer-1.0/libgstinterpipe.so
  
  echo ""
  echo "Verifying it's an Android binary:"
  file result-interpipe/lib/gstreamer-1.0/libgstinterpipe.so
  
  echo ""
  echo "Checking dependencies (should use Bionic):"
  readelf -d result-interpipe/lib/gstreamer-1.0/libgstinterpipe.so | grep NEEDED
else
  echo "❌ Build failed! Check build-interpipe.log"
fi