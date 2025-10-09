#!/bin/bash
# Complete Android Cross-Compilation Test Suite

set -e

export NIXPKGS_ALLOW_UNFREE=1
export NIXPKGS_ACCEPT_ANDROID_SDK_LICENSE=1


echo "════════════════════════════════════════════════════════════"
echo "  Final Nix Android Setup Validation"
echo "════════════════════════════════════════════════════════════"
echo ""

# Test 1: Overlays
echo "✓ Test 1: Overlays"
nix-instantiate --eval --strict --expr '
  let
    pkgs = import <nixpkgs> {
      config.allowUnfree = true;
      overlays = import ./.idx/overlays/default.nix;
    };
  in
  {
    hasAndroidSdk = pkgs ? androidSdk;
    hasAndroidNdk = pkgs ? androidNdk;
    hasArchitectures = pkgs ? androidArchitectures;
    hasPatches = pkgs ? gstdPatches;
  }
' > /dev/null && echo "  ✅ Pass" || (echo "  ❌ Fail" && exit 1)

# Test 2: SDK with NDK
echo "✓ Test 2: SDK with NDK"
nix-build --no-out-link -E '
  (import <nixpkgs> {
    config.allowUnfree = true;
    overlays = import ./.idx/overlays/default.nix;
  }).androidSdk
' > /dev/null && echo "  ✅ Pass" || (echo "  ❌ Fail" && exit 1)

# Test 3: Platform configurations
echo "✓ Test 3: Platform Configurations"
for arch in aarch64 armv7a x86_64; do
  printf "  Checking $arch... "
  
  result=$(nix-instantiate --eval --strict --expr "
    let
      pkgs = import <nixpkgs> {
        config.allowUnfree = true;
        overlays = import ./.idx/overlays/default.nix;
      };
      p = pkgs.pkgsAndroid_${arch}.stdenv.hostPlatform;
    in
    {
      config = p.config;
      libc = p.libc;
      isAndroid = p.isAndroid or false;
    }
  " 2>&1)
  
  if echo "$result" | grep -q '"bionic"' && echo "$result" | grep -q 'isAndroid = true'; then
    echo "✅"
  else
    echo "❌"
    echo "$result"
    exit 1
  fi
done

# Test 4: Cross-files generation
echo "✓ Test 4: Meson Cross-Files"
for arch in aarch64 armv7a x86_64; do
  printf "  Generating $arch cross-file... "
  
  nix-build --no-out-link -E "
    (import <nixpkgs> {
      config.allowUnfree = true;
      overlays = import ./.idx/overlays/default.nix;
    }).mesonCrossFile_${arch}
  " > /dev/null 2>&1 && echo "✅" || (echo "❌" && exit 1)
  
  if [ -f result ]; then
    rm result
  fi
done

echo ""
echo "════════════════════════════════════════════════════════════"
echo "  ✅ ALL TESTS PASSED!"
echo "════════════════════════════════════════════════════════════"
echo ""
echo "Your Nix Android cross-compilation setup is ready! 🎉"
echo ""
echo "Next steps:"
echo "  1. Build interpipe plugin (15-30 min):"
echo "     nix-build -E '...' (see TESTING.md Phase 3.1)"
echo ""
echo "  2. Build complete bundle (1-3 hours first time):"
echo "     nix-build .idx/dev.nix -A packages.androidLibs-aarch64 -o result"
echo ""
echo "  3. Deploy to Android project:"
echo "     cp -r result/lib/*.so agdk-eframe/app/src/main/jniLibs/arm64-v8a/"
echo ""