# .idx/modules/workspace.nix
{ extendedPkgs }:

{
  idx.workspace = {
    onCreate = {
      setup = ''
        echo "Setting up AGDK eframe Android environment..."

        # Determine base directory based on permissions
        BASE_DIR="/home/user/rust-android-examples"
        PROJECT_DIR="$BASE_DIR/agdk-eframe"

        if [ ! -w "/home/user" ]; then
          echo "Warning: /home/user not writable, falling back to /root/rust-android-examples"
          BASE_DIR="/root/rust-android-examples"
          PROJECT_DIR="$BASE_DIR/agdk-eframe"
          mkdir -p "$PROJECT_DIR"
          sudo chown -R $(whoami) "$PROJECT_DIR" 2>/dev/null || true
        else
          mkdir -p "$PROJECT_DIR"
          if [ ! -w "$PROJECT_DIR" ]; then
            echo "Fixing permissions for $PROJECT_DIR..."
            sudo chown -R $(whoami) "$PROJECT_DIR" 2>/dev/null || true
          fi
        fi

        # Setup Rust targets
        export PATH="${extendedPkgs.rustup}/bin:$PATH"
        rustup --version || { echo "Error: Rustup not available"; exit 1; }
        rustup target add aarch64-linux-android armv7-linux-androideabi x86_64-linux-android i686-linux-android

        # Install cargo tools
        which cargo-ndk > /dev/null || cargo install cargo-ndk
        which cargo-apk > /dev/null || cargo install cargo-apk

        # Accept Android licenses
        yes | ${extendedPkgs.androidSdk}/libexec/android-sdk/cmdline-tools/latest/bin/sdkmanager --licenses 2>/dev/null || true

        # Import the setup scripts with PROJECT_DIR
        ${import ./scripts/setup-openssl.nix { inherit extendedPkgs; }}
        ${import ./scripts/setup-gstreamer.nix { inherit extendedPkgs; }}
        ${import ./scripts/create-build-script.nix { inherit extendedPkgs; }}

        echo "Setup complete! Run '$PROJECT_DIR/build-apk' to build and deploy your app."
        echo "If license errors persist, run: export NIXPKGS_ACCEPT_ANDROID_SDK_LICENSE=1"
      '';
      default.openFiles = [ "agdk-eframe/src/main.rs" "agdk-eframe/app/build.gradle" ];
    };

    onStart = {
      welcome = ''
        echo "AGDK eframe Android environment ready!"
        echo "Run one of the following commands to build your app:"
        echo "  • /home/user/rust-android-examples/agdk-eframe/build-apk"
        echo "  • /root/rust-android-examples/agdk-eframe/build-apk"
        echo ""
        echo "Options:"
        echo "  • BUILD_MODE=debug ./agdk-eframe/build-apk    # Debug build"
        echo "  • INSTALL_AND_RUN=1 ./agdk-eframe/build-apk   # Install and run"
        echo ""
        echo "If license errors persist, run: export NIXPKGS_ACCEPT_ANDROID_SDK_LICENSE=1"
      '';
      default.openFiles = [ "agdk-eframe/src/main.rs" ];
    };
  };
}