# .idx/modules/android-architectures.nix
# Single source of truth for Android architecture definitions
{ lib }:

{
  # ARM64 - Primary architecture (most modern Android devices)
  aarch64 = {
    androidAbi = "arm64-v8a";
    gccPrefix = "aarch64";
    cpuFamily = "aarch64";
    cpu = "armv8-a";
    # For 64-bit, use "-android"
    abiSuffix = "android";
    extraCFlags = [];
    extraLinkFlags = [];
  };

  # ARMv7a - Legacy 32-bit ARM (older devices)
  armv7a = {
    androidAbi = "armeabi-v7a";
    gccPrefix = "armv7a";
    cpuFamily = "arm";
    cpu = "armv7-a";
    # ✅ For 32-bit ARM, use "-androideabi" NOT "-android"
    abiSuffix = "androideabi";
    extraCFlags = [
      "-march=armv7-a"
      "-mfloat-abi=softfp"
      "-mfpu=neon"
      "-mthumb"
    ];
    extraLinkFlags = [
      "-Wl,--fix-cortex-a8"
    ];
  };

  # x86_64 - For Android emulator
  x86_64 = {
    androidAbi = "x86_64";
    gccPrefix = "x86_64";
    cpuFamily = "x86_64";
    cpu = "x86_64";
    # For x86_64, use "-android"
    abiSuffix = "android";
    extraCFlags = [
      "-msse4.2"
      "-mpopcnt"
    ];
    extraLinkFlags = [];
  };
}