# .idx/modules/config.nix
# Centralized configuration for all version numbers and paths
{
  # GStreamer for Android configuration
  gstreamer = {
    version = "1.26.6";
    url = "https://gstreamer.freedesktop.org/data/pkg/android/1.26.6/";
    sha256 = "1a889589a1cb1c98a7055375437894a46aab855a8286a9390a88079e1418f099";
  };
  
  # GStreamer Daemon configuration
  gstd = {
    version = "0.15.2";
    repo = "RidgeRun/gstd-1.x";
    rev = "v0.15.2";
    sha256 = "sha256-capHgSurUSaBIUbKlPHv5hsfBZ11UwtgyuXRjQJJxuY=";
  };
  
  # GStreamer Interpipe configuration
  interpipe = {
    version = "1.1.10";
    repo = "RidgeRun/gst-interpipe";
    rev = "v1.1.10";
    sha256 = "sha256-Z7yeUxsTebKPynYzhtst2rlApoXzU1u/32ZqzBvQ6eY=";
  };
  
  # Android configuration
  android = {
    # API level for compilation
    apiLevel = "24";
    
    # NDK version (should match what android-nixpkgs provides)
    ndkVersion = "25.2.9519653";
    
    # Supported architectures
    architectures = [ "arm64-v8a" "armeabi-v7a" "x86_64" ];
    
    # Default architecture for single builds
    defaultArch = "arm64-v8a";
  };
  
  # Build configuration
  build = {
    # Build types
    defaultBuildType = "release";
    
    # Optimization flags
    releaseFlags = [ "-O2" "-DNDEBUG" ];
    debugFlags = [ "-g" "-O0" ];
  };
}