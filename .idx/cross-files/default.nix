# .idx/modules/cross-files/default.nix
# 
# Dynamically generate Meson cross-compilation files for Android
# This eliminates hardcoded paths and makes the configuration more maintainable

{ pkgs, config }:

let
  # Re-import nixpkgs with the necessary config for androidsdk
  # This ensures the license is accepted at the point of consumption
  configuredPkgs = import pkgs.path {
    system = pkgs.system;
    config = pkgs.config // {
      android_sdk.accept_license = true;
    };
  };

  # Get Android SDK path dynamically using the configuredPkgs
  androidSdkPath =
    if builtins.pathExists "${configuredPkgs.androidsdk}/share/android-sdk" then
      "${configuredPkgs.androidsdk}/share/android-sdk"
    else
      "${configuredPkgs.androidsdk}/libexec/android-sdk";
  
  # Build NDK paths
  ndkPath = "${androidSdkPath}/ndk/${config.android.ndkVersion}";
  ndkToolchainPath = "${ndkPath}/toolchains/llvm/prebuilt/linux-x86_64";
  ndkSysroot = "${ndkToolchainPath}/sysroot";
  
  # API level from config
  apiLevel = config.android.apiLevel;
  
  # Generate cross-file for a specific architecture
  mkCrossFile = { arch, cpuFamily, cpu, extraCArgs ? [], extraLinkArgs ? [] }: pkgs.writeText "android-${arch}.ini" ''
    # Meson cross-compilation file for Android ${arch}
    # Generated dynamically from Nix configuration
    # API Level ${apiLevel}
    
    [binaries]
    c = '${ndkToolchainPath}/bin/${arch}-linux-android${if cpuFamily == "arm" then "eabi" else ""}${apiLevel}-clang'
    cpp = '${ndkToolchainPath}/bin/${arch}-linux-android${if cpuFamily == "arm" then "eabi" else ""}${apiLevel}-clang++'
    ar = '${ndkToolchainPath}/bin/llvm-ar'
    strip = '${ndkToolchainPath}/bin/llvm-strip'
    ranlib = '${ndkToolchainPath}/bin/llvm-ranlib'
    ld = '${ndkToolchainPath}/bin/ld.lld'
    pkgconfig = '${pkgs.pkg-config}/bin/pkg-config'
    
    [properties]
    needs_exe_wrapper = true
    sys_root = '${ndkSysroot}'
    
    c_args = [
      '-DANDROID',
      '-D__ANDROID_API__=${apiLevel}',
      '-fPIC',
      '-ffunction-sections',
      '-fdata-sections',
      ${pkgs.lib.concatMapStringsSep ",\n      " (x: "'${x}'") extraCArgs}
    ]
    
    cpp_args = [
      '-DANDROID',
      '-D__ANDROID_API__=${apiLevel}',
      '-fPIC',
      '-ffunction-sections',
      '-fdata-sections',
      ${pkgs.lib.concatMapStringsSep ",\n      " (x: "'${x}'") extraCArgs}
    ]
    
    c_link_args = [
      '-Wl,--gc-sections',
      '-Wl,--as-needed',
      ${pkgs.lib.concatMapStringsSep ",\n      " (x: "'${x}'") extraLinkArgs}
    ]
    
    cpp_link_args = [
      '-Wl,--gc-sections',
      '-Wl,--as-needed',
      ${pkgs.lib.concatMapStringsSep ",\n      " (x: "'${x}'") extraLinkArgs}
    ]
    
    [host_machine]
    system = 'android'
    cpu_family = '${cpuFamily}'
    cpu = '${cpu}'
    endian = 'little'
  '';

in
rec {
  # ARM64 (aarch64)
  aarch64 = mkCrossFile {
    arch = "aarch64";
    cpuFamily = "aarch64";
    cpu = "armv8-a";
  };
  
  # ARMv7a
  armv7a = mkCrossFile {
    arch = "armv7a";
    cpuFamily = "arm";
    cpu = "armv7-a";
    extraCArgs = [
      "-march=armv7-a"
      "-mfloat-abi=softfp"
      "-mfpu=neon"
    ];
    extraLinkArgs = [
      "-Wl,--fix-cortex-a8"
    ];
  };
  
  # x86_64
  x86_64 = mkCrossFile {
    arch = "x86_64";
    cpuFamily = "x86_64";
    cpu = "x86_64";
  };
  
  # x86 (i686)
  x86 = mkCrossFile {
    arch = "i686";
    cpuFamily = "x86";
    cpu = "i686";
  };
  
  # Helper function to get cross-file by Android ABI name
  byAbi = abi:
    if abi == "arm64-v8a" then aarch64
    else if abi == "armeabi-v7a" then armv7a
    else if abi == "x86_64" then x86_64
    else if abi == "x86" then x86
    else throw "Unknown Android ABI: ${abi}";
}
