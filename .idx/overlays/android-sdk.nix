# .idx/overlays/android-sdk.nix
self: super:

let
  config = import ../modules/config.nix;
in
{
  # Configure Android SDK with required components
  androidSdk = (super.androidenv.composeAndroidPackages {
    # Platform versions (API levels)
    platformVersions = [ "${toString config.android.apiLevel}" ];
    
    # Build tools version
    buildToolsVersions = [ "34.0.0" ];
    
    # Include NDK
    includeNDK = true;
    ndkVersions = [ config.android.ndkVersion ];
    
    # CMake (optional, but useful)
    cmakeVersions = [ "3.22.1" ];
    
    # Accept licenses
    includeSystemImages = false;
    includeEmulator = false;
    includeSources = false;
    
    # Additional settings
    extraLicenses = [
      "android-sdk-license"
      "android-sdk-preview-license"
    ];
  }).androidsdk;
  
  # Also set the config for the current pkgs
  config = (super.config or {}) // {
    android_sdk.accept_license = true;
  };
}