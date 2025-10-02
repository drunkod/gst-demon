# .idx/overlays/android.nix
{ pkgs }:

self: super: {
  androidSdk =
    let
      android-nixpkgs = import (fetchTarball {
        url = "https://github.com/tadfisher/android-nixpkgs/archive/main.tar.gz";
        sha256 = "sha256:0sff0igz587wbaszcq0mm0ldr9nb65srf40if55nlj1ba1jz3wdd"; 
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