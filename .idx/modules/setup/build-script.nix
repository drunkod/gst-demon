{ pkgs }:

pkgs.writeShellScriptBin "generate-build-script" ''
    #!/usr/bin/env bash
    set -e
  
    PROJECT_DIR="$1"
  
    echo "Creating build script at: $PROJECT_DIR/build-apk"
  
    cat > "$PROJECT_DIR/build-apk" << 'EOFSCRIPT'
  #!/usr/bin/env bash
  set -e

  # Get script directory
  SCRIPT_DIR="$( cd "$( dirname "''${BASH_SOURCE[0]}" )" && pwd )"
  PROJECT_DIR="$SCRIPT_DIR"

  echo "Building in: $PROJECT_DIR"
  cd "$PROJECT_DIR"

  # Check if running in Nix shell
  if [ -z "$ANDROID_HOME" ] || [ -z "$ANDROID_SDK_ROOT" ]; then
    echo "Error: Android SDK environment variables not set."
    echo "Please run this script from within the Nix development shell:"
    echo "  nix develop"
    echo "  ./build-apk"
    exit 1
  fi

  # Verify required tools are available
  command -v rustup >/dev/null 2>&1 || { echo "Error: rustup not found. Please run from Nix shell."; exit 1; }
  command -v cargo >/dev/null 2>&1 || { echo "Error: cargo not found. Please run from Nix shell."; exit 1; }
  command -v gradle >/dev/null 2>&1 || { echo "Error: gradle not found. Please run from Nix shell."; exit 1; }

  # Export all necessary environment variables
  export NIXPKGS_ACCEPT_ANDROID_SDK_LICENSE=1

  # Use project-local dependencies
  export OPENSSL_DIR="$PROJECT_DIR/depend/openssl"
  export OPENSSL_LIB_DIR="$OPENSSL_DIR/android-arm64/lib"
  export AARCH64_LINUX_ANDROID_OPENSSL_LIB_DIR="$OPENSSL_DIR/android-arm64/lib"
  export OPENSSL_INCLUDE_DIR="$OPENSSL_DIR/android-arm64/include"
  export OPENSSL_STATIC=1
  export PKG_CONFIG_PATH="$PROJECT_DIR/gstreamer-android/arm64/lib/pkgconfig"

  echo "Build environment:"
  echo "  PROJECT_DIR=$PROJECT_DIR"
  echo "  ANDROID_HOME=$ANDROID_HOME"
  echo "  ANDROID_NDK_HOME=$ANDROID_NDK_HOME"
  echo "  JAVA_HOME=$JAVA_HOME"
  echo "  Rust version: $(rustc --version)"

  # Clean previous builds
  echo "Cleaning previous builds..."
  rm -f app/src/main/jniLibs/arm64-v8a/*.so
  rm -rf target/debug/apk/lib/arm64-v8a/* 2>/dev/null || true
  rm -rf target/release/apk/lib/arm64-v8a/* 2>/dev/null || true

  # Determine build mode
  BUILD_MODE="''${BUILD_MODE:-release}"
  BUILD_FLAG=""
  TARGET_DIR="release"

  if [ "$BUILD_MODE" = "debug" ]; then
    BUILD_FLAG=""
    TARGET_DIR="debug"
    echo "Building in DEBUG mode..."
  else
    BUILD_FLAG="--release"
    echo "Building in RELEASE mode..."
  fi

  # Ensure we have the Android target
  echo "Checking Rust Android targets..."
  rustup target list --installed | grep -q aarch64-linux-android || {
    echo "Installing aarch64-linux-android target..."
    rustup target add aarch64-linux-android
  }

  # Build Rust library for Android
  echo "Building Rust library for Android..."
  PKG_CONFIG_ALLOW_CROSS=1 \
  RUSTFLAGS="-lffi" \
  RUST_BACKTRACE=1 \
  cargo ndk -t arm64-v8a -o app/src/main/jniLibs/ build $BUILD_FLAG

  # Handle library naming
  JNI_LIBS="app/src/main/jniLibs/arm64-v8a"
  mkdir -p "$JNI_LIBS"

  # Rename library if needed
  if [ -f "$JNI_LIBS/libagdk_eframe.so" ]; then
    echo "Renaming libagdk_eframe.so to libmain.so..."
    mv "$JNI_LIBS/libagdk_eframe.so" "$JNI_LIBS/libmain.so"
  elif [ ! -f "$JNI_LIBS/libmain.so" ]; then
    echo "Warning: Neither libagdk_eframe.so nor libmain.so found in $JNI_LIBS"
    echo "Available libraries:"
    ls -la "$JNI_LIBS"
  fi

  # Copy libc++_shared.so if needed
  LIBCXX_SHARED="$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/lib/aarch64-linux-android/24/libc++_shared.so"
  if [ -f "$LIBCXX_SHARED" ] && [ ! -f "$JNI_LIBS/libc++_shared.so" ]; then
    echo "Copying libc++_shared.so..."
    cp "$LIBCXX_SHARED" "$JNI_LIBS/"
  fi

  # Build APK
  echo "Building Android APK..."
  if [ "$BUILD_MODE" = "release" ]; then
    ./gradlew clean assembleRelease
    APK_LOCATION="app/build/outputs/apk/release"
  else
    ./gradlew clean assembleDebug
    APK_LOCATION="app/build/outputs/apk/debug"
  fi

  # Check if APK was built successfully
  if [ -d "$APK_LOCATION" ]; then
    echo ""
    echo "✅ APK built successfully!"
    echo "APK location: $APK_LOCATION"
    echo "Available APKs:"
    ls -lh "$APK_LOCATION"/*.apk 2>/dev/null || echo "No APK files found"
  else
    echo "❌ Error: APK directory not found at $APK_LOCATION"
    exit 1
  fi

  # Optional: Install and run
  if [ "''${INSTALL_AND_RUN:-0}" = "1" ]; then
    echo ""
    echo "Installing APK to device..."
    if [ "$BUILD_MODE" = "release" ]; then
      ./gradlew installRelease
    else
      ./gradlew installDebug
    fi
  
    echo "Starting application..."
    adb shell am start -n co.realfit.agdkeframe/.MainActivity
  
    echo "Showing logs..."
    adb logcat -s main RustStdoutStderr
  fi

  echo ""
  echo "Done! To install and run:"
  echo "  INSTALL_AND_RUN=1 ./build-apk"
  EOFSCRIPT
  
    chmod +x "$PROJECT_DIR/build-apk"
    echo "Build script created successfully!"
''
