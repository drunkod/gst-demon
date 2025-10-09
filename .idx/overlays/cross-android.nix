# .idx/overlays/cross-android.nix
# Cross-compilation setup for Android (Bionic libc)
self: super:

let
  config = import ../modules/config.nix;
  architectures = import ../modules/android-architectures.nix { lib = super.lib; };

  androidSdk = self.androidSdk or (throw ''
    Android SDK not found!
    Ensure android-sdk.nix overlay is loaded first.
  '');

  ndkPath = "${androidSdk}/libexec/android-sdk/ndk/${config.android.ndkVersion}";
  toolchainPath = "${ndkPath}/toolchains/llvm/prebuilt/linux-x86_64";

  # Create Android package set for an architecture
  mkAndroidPkgs = archConfig:
    let
      nixpkgsSrc = super.path or (builtins.fetchTarball {
        url = "https://github.com/NixOS/nixpkgs/archive/nixos-24.05.tar.gz";
        sha256 = "";  # Will auto-fill on first run
      });
      
    in
    import nixpkgsSrc {
      # Build system (your x86_64-linux PC)
      localSystem = builtins.currentSystem;
      
      # Target system (Android device with Bionic libc)
      crossSystem = {
        # Let Nix parse this automatically - don't manually construct 'parsed'
        config = "${archConfig.gccPrefix}-linux-android";
        
        # Android-specific settings
        isAndroid = true;
        useLLVM = true;
        libc = "bionic";
        
        # Versions
        sdkVer = toString config.android.apiLevel;
        ndkVer = config.android.ndkVersion;
      };

      config = {
        android_sdk.accept_license = true;
        allowUnfree = true;
      };

      overlays = [
        # Android-specific package overrides
        (selfAndroid: superAndroid: {
          # Disable desktop features in GStreamer
          gst_all_1 = superAndroid.gst_all_1 // {
            gstreamer = superAndroid.gst_all_1.gstreamer.overrideAttrs (old: {
              mesonFlags = (old.mesonFlags or []) ++ [
                "-Dtests=disabled"
                "-Dexamples=disabled"
                "-Dintrospection=disabled"
                "-Dnls=disabled"
                "-Dtools=disabled"
                "-Dlibunwind=disabled"
                "-Dlibdw=disabled"
              ];
            });
            
            gst-plugins-base = superAndroid.gst_all_1.gst-plugins-base.overrideAttrs (old: {
              mesonFlags = (old.mesonFlags or []) ++ [
                "-Dgl=disabled"
                "-Dx11=disabled"
                "-Dxvideo=disabled"
                "-Dalsa=disabled"
                "-Dcdparanoia=disabled"
                "-Dogg=disabled"
                "-Dvorbis=disabled"
                "-Dexamples=disabled"
                "-Dtests=disabled"
                "-Dintrospection=disabled"
              ];
            });
          };
        })
      ];
    };

  # Generate Meson cross-file
  mkMesonCrossFile = archConfig:
    let
      apiLevel = toString config.android.apiLevel;
      
      # Android NDK compiler naming
      compilerPrefix =
        if archConfig.cpuFamily == "arm"
        then "${archConfig.gccPrefix}-linux-androideabi${apiLevel}"
        else "${archConfig.gccPrefix}-linux-android${apiLevel}";
      
      # Bionic sysroot
      bionicSysroot = "${toolchainPath}/sysroot";
      
      # Android-specific flags
      androidFlags = [
        "-DANDROID"
        "-D__ANDROID_API__=${apiLevel}"
        "-fPIC"
        "-ffunction-sections"
        "-fdata-sections"
      ];
      
      baseCFlags = androidFlags ++ (archConfig.extraCFlags or []);
      
      baseLinkFlags = [
        "-Wl,--gc-sections"
        "-Wl,--as-needed"
        "-Wl,--no-undefined"
        "-Wl,--hash-style=gnu"
        "-Wl,--build-id"
      ] ++ (archConfig.extraLinkFlags or []);
      
      formatFlags = flags: super.lib.concatMapStringsSep ", " (f: "'${f}'") flags;
      
    in
    self.writeText "meson-cross-${archConfig.androidAbi}.ini" ''
      # Meson cross-file for Android ${archConfig.androidAbi}
      # Target: ${archConfig.gccPrefix}-linux-android (Bionic libc)
      
      [binaries]
      c = '${toolchainPath}/bin/${compilerPrefix}-clang'
      cpp = '${toolchainPath}/bin/${compilerPrefix}-clang++'
      ar = '${toolchainPath}/bin/llvm-ar'
      strip = '${toolchainPath}/bin/llvm-strip'
      ranlib = '${toolchainPath}/bin/llvm-ranlib'
      ld = '${toolchainPath}/bin/ld.lld'
      pkgconfig = '${self.pkg-config}/bin/pkg-config'

      [properties]
      needs_exe_wrapper = true
      sys_root = '${bionicSysroot}'
      pkg_config_libdir = []
      
      c_args = [${formatFlags baseCFlags}]
      cpp_args = [${formatFlags baseCFlags}]
      c_link_args = [${formatFlags baseLinkFlags}]
      cpp_link_args = [${formatFlags baseLinkFlags}]

      [host_machine]
      system = 'android'
      cpu_family = '${archConfig.cpuFamily}'
      cpu = '${archConfig.cpu}'
      endian = 'little'
    '';

in
{
  # Expose architecture definitions
  androidArchitectures = architectures;

  # Create Android package sets
  pkgsAndroid_aarch64 = mkAndroidPkgs architectures.aarch64;
  pkgsAndroid_armv7a = mkAndroidPkgs architectures.armv7a;
  pkgsAndroid_x86_64 = mkAndroidPkgs architectures.x86_64;

  # Create Meson cross-files
  mesonCrossFile_aarch64 = mkMesonCrossFile architectures.aarch64;
  mesonCrossFile_armv7a = mkMesonCrossFile architectures.armv7a;
  mesonCrossFile_x86_64 = mkMesonCrossFile architectures.x86_64;
}