# .idx/overlays/android.nix
{ pkgs }:

self: super: {
  androidSdk =
    let
      android-nixpkgs = import (fetchTarball {
        url = "https://github.com/tadfisher/android-nixpkgs/archive/refs/tags/2025-10-03-stable.tar.gz";
        sha256 = "sha256:0la5jbisgw57d8hdh6grsxjwyp9d7s8p7ss1j60r3ij10y84263a"; 
      }) { inherit pkgs; };
      sdk = android-nixpkgs.sdk (sdkPkgs: with sdkPkgs; [
        cmdline-tools-latest
        build-tools-34-0-0
        build-tools-33-0-2
        platform-tools
        platforms-android-34
        platforms-android-33
        cmake-3-22-1
        ndk-25-2-9519653
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
      '';
    });
}