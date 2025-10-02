# .idx/modules/environment.nix
{ lib, extendedPkgs }:

let
  # Detect the actual Android SDK path
  androidSdkPath =
    if builtins.pathExists "${extendedPkgs.androidSdk}/share/android-sdk" then
      "${extendedPkgs.androidSdk}/share/android-sdk"
    else
      "${extendedPkgs.androidSdk}/libexec/android-sdk";
in
{
  ANDROID_HOME = lib.mkForce androidSdkPath;
  ANDROID_SDK_ROOT = lib.mkForce androidSdkPath;
  ANDROID_NDK_HOME = "${androidSdkPath}/ndk/25.2.9519653";
  ANDROID_NDK_ROOT = "${androidSdkPath}/ndk/25.2.9519653";
  JAVA_HOME = "${extendedPkgs.jdk17}";
  PATH = [
    "${androidSdkPath}/cmdline-tools/latest/bin"
    "${androidSdkPath}/ndk/25.2.9519653/toolchains/llvm/prebuilt/linux-x86_64/bin"
    "${extendedPkgs.rustup}/bin"
  ];
  RUST_BACKTRACE = "1";
  PKG_CONFIG_ALLOW_CROSS = "1";
  RUSTFLAGS = "-lffi";
  NIXPKGS_ACCEPT_ANDROID_SDK_LICENSE = "1";
}
