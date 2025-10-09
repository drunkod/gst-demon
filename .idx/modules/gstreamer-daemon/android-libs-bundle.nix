# .idx/modules/gstreamer-daemon/android-libs-bundle.nix
# Bundles all Android libraries for a specific architecture
{ pkgs }:

# This is a function that takes an architecture name
archName:

let
  # Supported architectures
  supportedArchs = [ "aarch64" "armv7a" "x86_64" ];
  
  # Get architecture config
  archConfig = pkgs.androidArchitectures.${archName} or (throw ''
    Unsupported architecture: ${archName}
    Supported: ${pkgs.lib.concatStringsSep ", " supportedArchs}
  '');

  # Get architecture-specific pkgs and cross-file
  pkgsAndroid = pkgs."pkgsAndroid_${archName}" or (throw ''
    pkgsAndroid_${archName} not found in pkgs.
    Make sure cross-android.nix overlay is loaded.
  '');
  
  mesonCrossFile = pkgs."mesonCrossFile_${archName}" or (throw ''
    mesonCrossFile_${archName} not found in pkgs.
    Make sure cross-android.nix overlay is loaded.
  '');

  # Get the patch
  gstd-as-library-patch = pkgs.patches.gstd-as-library or (throw ''
    gstd-as-library patch not found.
    Make sure patches overlay is loaded and .idx/patches/gstd-as-library.patch exists.
  '');

  # Platform information for verification
  platform = pkgsAndroid.stdenv.hostPlatform;
  libc = platform.libc or "unknown";
  isAndroid = platform.isAndroid or false;
  platformConfig = platform.config;
  
  # VERIFICATION: Check we're targeting Android with Bionic
  # Correct Nix syntax for assertions in let bindings
  checkLibc = 
    if libc != "bionic" then throw ''
      FATAL ERROR: Expected Bionic libc, got: ${libc}
      
      Platform config: ${platformConfig}
      
      This means we're building for GNU/Linux (${archName}-linux) instead of
      Android (${archName}-linux-android). The resulting .so files will link
      against glibc and will NOT work on Android devices!
      
      Check your cross-android.nix overlay configuration.
    '' else true;
  
  checkIsAndroid = 
    if !isAndroid then throw ''
      FATAL ERROR: Platform is not marked as Android!
      
      Platform config: ${platformConfig}
      isAndroid: ${builtins.toString isAndroid}
      
      The platform must have isAndroid = true.
    '' else true;
  
  checkPlatformConfig = 
    if (builtins.match ".*-linux-android$" platformConfig) == null then throw ''
      FATAL ERROR: Platform config doesn't end with "-android"!
      
      Got: ${platformConfig}
      Expected: ${archConfig.gccPrefix}-linux-android
      
      This is the most reliable indicator that we're targeting the wrong system.
    '' else true;
  
  # Run all checks (will throw if any fail)
  allChecks = checkLibc && checkIsAndroid && checkPlatformConfig;

  # Build components (only if checks pass)
  interpipe = 
    assert allChecks;
    import ./interpipe-android.nix {
      inherit pkgs pkgsAndroid mesonCrossFile;
    };

  gstd = 
    assert allChecks;
    import ./gstd-android.nix {
      inherit pkgs pkgsAndroid mesonCrossFile gstd-as-library-patch;
      gst-interpipe-android = interpipe;
    };

in
pkgs.symlinkJoin {
  name = "gstreamer-daemon-bundle-${archConfig.androidAbi}";
  
  paths = [
    gstd
    interpipe
    pkgsAndroid.gst_all_1.gstreamer
    pkgsAndroid.gst_all_1.gst-plugins-base
  ];
  
  postBuild = ''
    cat > "$out/BUILD_INFO.txt" << EOF
════════════════════════════════════════════════════════════
  GStreamer Daemon Android Bundle - BUILD VERIFICATION
════════════════════════════════════════════════════════════

TARGET SYSTEM VERIFICATION:
  Platform Config:     ${platformConfig}
  C Library:           ${libc}
  Is Android:          ${if isAndroid then "YES ✓" else "NO ✗"}
  Android ABI:         ${archConfig.androidAbi}
  
BUILD SYSTEM:
  Build Platform:      ${pkgs.stdenv.hostPlatform.config}
  Build Date:          $(date -u +"%Y-%m-%d %H:%M:%S UTC")

COMPONENTS:
  - gstd:              ${gstd.version}
  - gst-interpipe:     ${interpipe.version}

LIBRARIES:
EOF
    
    echo "" >> "$out/BUILD_INFO.txt"
    
    # List all .so files
    find "$out/lib" -name "*.so" -type f | sort | while read lib; do
      size=$(du -h "$lib" | cut -f1)
      name=$(basename "$lib")
      echo "  $name ($size)" >> "$out/BUILD_INFO.txt"
    done
    
    echo "" >> "$out/BUILD_INFO.txt"
    echo "Total size: $(du -sh "$out/lib" | cut -f1)" >> "$out/BUILD_INFO.txt"
    echo "" >> "$out/BUILD_INFO.txt"
    echo "VERIFICATION COMMANDS:" >> "$out/BUILD_INFO.txt"
    echo "  file $out/lib/*.so" >> "$out/BUILD_INFO.txt"
    echo "  readelf -h $out/lib/libgstd.so | grep 'OS/ABI'" >> "$out/BUILD_INFO.txt"
    echo "  readelf -d $out/lib/libgstd.so | grep NEEDED" >> "$out/BUILD_INFO.txt"
    
    cat "$out/BUILD_INFO.txt"
  '';
  
  passthru = {
    inherit archConfig pkgsAndroid interpipe gstd;
    architecture = archName;
    abi = archConfig.androidAbi;
    targetSystem = platformConfig;
    targetLibc = libc;
  };

  meta = with pkgs.lib; {
    description = "GStreamer Daemon bundle for Android ${archConfig.androidAbi} (Bionic libc)";
    platforms = platforms.linux;  # Generic "linux" is fine for metadata
  };
}