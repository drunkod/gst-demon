{ pkgs, extendedPkgs }:

let
  # Import sub-modules
  rustSetup = import ./setup/rust.nix { inherit pkgs extendedPkgs; };
  opensslSetup = import ./setup/openssl.nix { inherit pkgs; };
  gstreamerSetup = import ./setup/gstreamer.nix { inherit pkgs; };
  buildScriptGenerator = import ./setup/build-script.nix { inherit pkgs; };

  # Main setup script that orchestrates everything
  setupScript = pkgs.writeShellScriptBin "setup-android-env" ''
    #!/usr/bin/env bash
    set -e

    echo "Setting up AGDK eframe Android environment..."

    # Determine base directory
    BASE_DIR="$(pwd)"
    PROJECT_DIR="$BASE_DIR/agdk-eframe"
    
    mkdir -p "$PROJECT_DIR"
    
    # Detect Android SDK path from environment
    ANDROID_SDK_PATH="$ANDROID_HOME"
    if [ -z "$ANDROID_SDK_PATH" ]; then
      if [ -d "${extendedPkgs.androidSdk}/share/android-sdk" ]; then
        ANDROID_SDK_PATH="${extendedPkgs.androidSdk}/share/android-sdk"
      else
        ANDROID_SDK_PATH="${extendedPkgs.androidSdk}/libexec/android-sdk"
      fi
    fi
    
    echo "Android SDK detected at: $ANDROID_SDK_PATH"
    
    # Setup Rust
    ${rustSetup}/bin/setup-rust
    
    # Accept Android licenses
    echo "Accepting Android licenses..."
    yes | $ANDROID_SDK_PATH/cmdline-tools/latest/bin/sdkmanager --licenses 2>/dev/null || true
    
    # Setup OpenSSL
    OPENSSL_DEST="$PROJECT_DIR/depend/openssl"
    ${opensslSetup}/bin/setup-openssl "$OPENSSL_DEST" "$ANDROID_SDK_PATH"
    
    # Setup GStreamer
    GSTREAMER_DEST="$PROJECT_DIR/gstreamer-android"
    ${gstreamerSetup}/bin/setup-gstreamer "$GSTREAMER_DEST"
    
    # Generate build script
    ${buildScriptGenerator}/bin/generate-build-script "$PROJECT_DIR"
    
    # Create convenience symlink in base directory
    if [ -w "$BASE_DIR" ]; then
      ln -sf "$PROJECT_DIR/build-apk" "$BASE_DIR/build-agdk-eframe" 2>/dev/null || true
    fi

    echo ""
    echo "✅ Setup complete!"
    echo ""
    echo "Next steps:"
    echo "  1. cd agdk-eframe"
    echo "  2. ./build-apk"
    echo ""
    echo "Build options:"
    echo "  BUILD_MODE=debug ./build-apk    # Debug build"
    echo "  INSTALL_AND_RUN=1 ./build-apk   # Install and run on device"
  '';
in
{
  package = setupScript;
}
