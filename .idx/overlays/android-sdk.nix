# .idx/overlays/android-sdk.nix
# Flexible Android SDK with support for local NDK
self: super:

let
  appConfig = import ../modules/config.nix;
  
  # Helper to expand ~ in paths
  expandHome = path:
    if path == null then null
    else if super.lib.hasPrefix "~/" path then
      builtins.getEnv "HOME" + builtins.substring 1 (builtins.stringLength path - 1) path
    else path;
  
  # Check environment variable for NDK
  envNdkPath = 
    let env = builtins.getEnv "ANDROID_NDK_HOME";
    in if env == "" then null else env;
  
  # Determine NDK source priority:
  # 1. Config file path (highest priority)
  # 2. Environment variable (if useEnvNdk = true)
  # 3. Nixpkgs (fallback)
  configNdkPath = expandHome (appConfig.android.ndkPath or null);
  useEnvNdk = appConfig.android.useEnvNdk or false;
  
  localNdkPath =
    if configNdkPath != null then configNdkPath
    else if useEnvNdk && envNdkPath != null then envNdkPath
    else null;
  
  useLocalNdk = localNdkPath != null;
  
  # Validate local NDK path
  validateNdkPath = path:
    let
      pathExists = builtins.pathExists path;
      toolchainExists = builtins.pathExists "${path}/toolchains/llvm/prebuilt";
      
      # Detect NDK version from source.properties if it exists
      sourceProps = "${path}/source.properties";
      hasSourceProps = builtins.pathExists sourceProps;
      
    in
    if !pathExists then throw ''
      ❌ NDK path does not exist: ${path}
      
      Please either:
      1. Download NDK from: https://developer.android.com/ndk/downloads
         Example for NDK r26c:
         wget https://dl.google.com/android/repository/android-ndk-r26c-linux.zip
         unzip android-ndk-r26c-linux.zip -d ~/.local/
      
      2. Update .idx/modules/config.nix:
         android.ndkPath = "/path/to/your/ndk";
      
      3. Set environment variable:
         export ANDROID_NDK_HOME=/path/to/your/ndk
      
      4. Use nixpkgs NDK (automatic):
         android.ndkPath = null;
    ''
    else if !toolchainExists then throw ''
      ❌ Invalid NDK structure at: ${path}
      
      Expected to find: ${path}/toolchains/llvm/prebuilt/linux-x86_64
      
      The directory exists but doesn't look like a valid NDK.
      Make sure you extracted the full NDK archive.
      
      Directory contents:
      ${builtins.toString (builtins.attrNames (builtins.readDir path))}
    ''
    else 
      builtins.trace "✅ Using local NDK: ${path}" true;
  
  # Validate if using local NDK
  _ = if useLocalNdk then validateNdkPath localNdkPath else true;
  
  # Import local NDK into Nix store (makes it available during build)
  importLocalNdk = path:
    builtins.trace "Importing NDK from ${path} into Nix store..." (
      super.runCommand "android-ndk-local" {
        preferLocalBuild = true;
      } ''
        echo "Importing NDK from: ${path}"
        mkdir -p $out
        
        # Use rsync if available for faster copying, otherwise cp
        if command -v rsync >/dev/null 2>&1; then
          rsync -a --copy-links "${path}/" $out/
        else
          cp -rL "${path}"/* $out/
        fi
        
        # Make writable
        chmod -R +w $out
        
        # Verify toolchain
        if [ ! -d "$out/toolchains/llvm/prebuilt/linux-x86_64" ]; then
          echo "ERROR: Toolchain not found after import!"
          exit 1
        fi
        
        echo "✅ NDK imported successfully"
        echo "   Toolchains: $(ls $out/toolchains/)"
      ''
    );
  
  # Build base Android SDK (may or may not include NDK)
  baseSdk = 
    if useLocalNdk then
      # Don't include NDK in SDK - we'll add it separately
      (super.androidenv.composeAndroidPackages {
        platformVersions = [ "34" ];
        buildToolsVersions = [ "34.0.0" ];
        includeNDK = false;  # We're using local NDK
        cmakeVersions = [ "3.22.1" ];
        includeSystemImages = false;
        includeEmulator = false;
        includeSources = false;
      }).androidsdk
    else
      # Try to include NDK from nixpkgs
      (super.androidenv.composeAndroidPackages {
        platformVersions = [ "34" ];
        buildToolsVersions = [ "34.0.0" ];
        includeNDK = true;
        ndkVersions = [ appConfig.android.ndkVersion ];
        cmakeVersions = [ "3.22.1" ];
        includeSystemImages = false;
        includeEmulator = false;
        includeSources = false;
        extraLicenses = [
          "android-sdk-license"
          "android-sdk-preview-license"
        ];
      }).androidsdk;

in
{
  # Expose NDK separately for easy access
  androidNdk = 
    if useLocalNdk then
      importLocalNdk localNdkPath
    else
      # Try to extract from baseSdk or use standalone
      super.androidenv.androidPkgs_9_0.ndk-bundle or baseSdk;
  
  # Base SDK (might not include NDK if using local)
  androidSdkBase = baseSdk;
  
  # Full SDK with NDK at standard location
  androidSdk = super.symlinkJoin {
    name = "android-sdk-with-ndk";
    paths = [ baseSdk ];
    
    postBuild = ''
      # Create standard NDK location
      mkdir -p $out/libexec/android-sdk
      
      ${if useLocalNdk then ''
        echo "Linking local NDK to SDK..."
        ln -sf ${self.androidNdk} $out/libexec/android-sdk/ndk-bundle
        ln -sf ${self.androidNdk} $out/libexec/android-sdk/ndk/${appConfig.android.ndkVersion}
        
        echo "NDK Info:"
        echo "  Source: ${localNdkPath}"
        echo "  Link: $out/libexec/android-sdk/ndk-bundle"
      '' else ''
        echo "Using nixpkgs NDK (if included in SDK)"
      ''}
      
      # Create a marker file with NDK info
      cat > $out/NDK_INFO.txt << EOF
      NDK Source: ${if useLocalNdk then "Local: ${localNdkPath}" else "Nixpkgs"}
      NDK Version: ${appConfig.android.ndkVersion}
      SDK Path: $out
      NDK Path: $out/libexec/android-sdk/ndk-bundle
      EOF
      
      echo "SDK prepared at: $out"
      cat $out/NDK_INFO.txt
    '';
  };
}