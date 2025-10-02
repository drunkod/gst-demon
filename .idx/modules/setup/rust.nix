{ pkgs, extendedPkgs }:

pkgs.writeShellScriptBin "setup-rust" ''
  #!/usr/bin/env bash
  set -e
  
  echo "Setting up Rust toolchain..."
  
  # Setup Rust - First set default toolchain
  export PATH="${extendedPkgs.rustup}/bin:$PATH"
  
  rustup default stable || {
    echo "Installing stable Rust toolchain..."
    rustup install stable
    rustup default stable
  }
  
  # Add Android targets
  echo "Adding Android targets..."
  rustup target add \
    aarch64-linux-android \
    armv7-linux-androideabi \
    x86_64-linux-android \
    i686-linux-android

  # Install cargo tools
  echo "Installing cargo tools..."
  which cargo-ndk > /dev/null 2>&1 || {
    echo "Installing cargo-ndk..."
    cargo install cargo-ndk
  }
  which cargo-apk > /dev/null 2>&1 || {
    echo "Installing cargo-apk..."
    cargo install cargo-apk
  }
  
  echo "Rust setup complete!"
''
  