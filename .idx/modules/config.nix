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
    
    # NDK version (for nixpkgs or validation)
    ndkVersion = "21.4.7075529";
    
    # ✅ NEW: Optional local NDK path
    # If set, will use this instead of downloading/building NDK
    # 
    # Options:
    # 1. Set to null to use nixpkgs NDK (automatic but slow)
    # 2. Set to local path like "/home/user/android-ndk-r26b"
    # 3. Set to "~/.local/android-ndk" (will expand ~)
    # 
    # To download NDK manually:
    #   wget https://dl.google.com/android/repository/android-ndk-r26c-linux.zip
    #   unzip android-ndk-r26c-linux.zip -d ~/.local/
    ndkPath = null;  # Change to your NDK path, e.g., "/home/user/.local/android-ndk-r26c"
    
    # Alternative: Use environment variable
    # Set ANDROID_NDK_HOME in your shell
    useEnvNdk = true;  # If true, checks $ANDROID_NDK_HOME first
    
    # Supported architectures
    architectures = [ "arm64-v8a" "armeabi-v7a" "x86_64" ];
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