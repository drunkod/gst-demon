# .idx/overlays/android.nix
# Minimal Android SDK/NDK configuration - saves ~80GB
{ pkgs }:

self: super: {
  androidSdk =
    let
      # Create a pkgs instance with android license acceptance
      pkgsWithAndroidConfig = import pkgs.path {
        inherit (pkgs) system;
        config = {
          android_sdk.accept_license = true;
          allowUnfree = true;
        };
      };
      
      android-nixpkgs = import (fetchTarball {
        url = "https://github.com/tadfisher/android-nixpkgs/archive/refs/tags/2025-10-03-stable.tar.gz";
        sha256 = "sha256:0la5jbisgw57d8hdh6grsxjwyp9d7s8p7ss1j60r3ij10y84263a"; 
      }) { 
        pkgs = pkgsWithAndroidConfig;
      };
      
      # MINIMAL SDK - only what's absolutely necessary
      sdk = android-nixpkgs.sdk (sdkPkgs: with sdkPkgs; [
        # Command line tools (required)
        cmdline-tools-latest
        
        # Build tools - ONLY the version you need
        build-tools-34-0-0
        
        # Platform tools (adb, fastboot)
        platform-tools
        
        # Platform - ONLY the version you need
        platforms-android-34
        
        # NDK - ONLY one version
        ndk-25-2-9519653
        
        # ❌ REMOVED to save space:
        # - build-tools-33-0-2 (~500MB saved)
        # - platforms-android-33 (~200MB saved)
        # - cmake-3-22-1 (~300MB saved - use system cmake instead)
        # - emulator images (~10GB+ saved)
        # - system images (~20GB+ saved)
      ]);
    in
    sdk.overrideAttrs (oldAttrs: {
      # Create symlinks for compatibility
      postInstall = (oldAttrs.postInstall or "") + ''
        # Create libexec symlink for compatibility
        if [ -d "$out/share/android-sdk" ] && [ ! -e "$out/libexec/android-sdk" ]; then
          mkdir -p "$out/libexec"
          ln -s "$out/share/android-sdk" "$out/libexec/android-sdk"
        fi
        
        # Clean up unnecessary files
        cd "$out/share/android-sdk" 2>/dev/null || cd "$out/libexec/android-sdk"
        
        # Remove docs and samples to save space
        rm -rf docs/ samples/ || true
        
        # Remove emulator if present
        rm -rf emulator/ || true
        
        # Remove system images
        rm -rf system-images/ || true
        
        # Keep only essential NDK files
        if [ -d "ndk/25.2.9519653" ]; then
          cd "ndk/25.2.9519653"
          
          # Remove documentation
          rm -rf CHANGELOG.md README.md NOTICE || true
          
          # Remove prebuilt binaries for other platforms (keep only linux-x86_64)
          cd toolchains/llvm/prebuilt || true
          ls | grep -v "linux-x86_64" | xargs rm -rf || true
          
          # Remove renderscript (if you don't use it)
          cd ../../../
          rm -rf toolchains/renderscript || true
        fi
        
        echo "✅ Minimal Android SDK configured"
        echo "   Size optimized - removed docs, samples, emulator, system images"
      '';
    });
}