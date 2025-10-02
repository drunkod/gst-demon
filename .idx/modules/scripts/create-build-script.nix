# .idx/modules/scripts/create-build-script.nix
{ extendedPkgs }:

''
    # Create build-apk script in project directory
    echo "Creating build script at: $PROJECT_DIR/build-apk"
    cat > "$PROJECT_DIR/build-apk" << 'EOFSCRIPT'
  #!/usr/bin/env bash
  set -e

  # Get script directory (should be agdk-eframe)
  SCRIPT_DIR="$( cd "$( dirname "''${BASH_SOURCE[0]}" )" && pwd )"
  PROJECT_DIR="$SCRIPT_DIR"

  echo "════════════════════════════════════════════════════════════"
  echo "  AGDK eframe Android Build Script"
  echo "════════════════════════════════════════════════════════════"
  echo ""
  echo "Building in: $PROJECT_DIR"
  cd "$PROJECT_DIR"

  # Check if running in Nix shell or IDX environment
  if [ -z "$ANDROID_HOME" ] || [ -z "$ANDROID_SDK_ROOT" ]; then
    # Try to detect from common locations
    if [ -d "${extendedPkgs.androidSdk}/share/android-sdk" ]; then
      export ANDROID_HOME="${extendedPkgs.androidSdk}/share/android-sdk"
      export ANDROID_SDK_ROOT="${extendedPkgs.androidSdk}/share/android-sdk"
      export ANDROID_NDK_HOME="$ANDROID_HOME/ndk/25.2.9519653"
      export ANDROID_NDK_ROOT="$ANDROID_NDK_HOME"
    elif [ -d "${extendedPkgs.androidSdk}/libexec/android-sdk" ]; then
      export ANDROID_HOME="${extendedPkgs.androidSdk}/libexec/android-sdk"
      export ANDROID_SDK_ROOT="${extendedPkgs.androidSdk}/libexec/android-sdk"
      export ANDROID_NDK_HOME="$ANDROID_HOME/ndk/25.2.9519653"
      export ANDROID_NDK_ROOT="$ANDROID_NDK_HOME"
    else
      echo "Error: Android SDK environment variables not set."
      echo "Please run this script from within the Nix development shell:"
      echo "  nix develop"
      echo "  cd agdk-eframe"
      echo "  ./build-apk"
      echo ""
      echo "Or if using IDX:"
      echo "  Ensure the environment is properly loaded"
      exit 1
    fi
  fi

  # Set Java home if not set
  if [ -z "$JAVA_HOME" ]; then
    if [ -d "${extendedPkgs.jdk17}" ]; then
      export JAVA_HOME="${extendedPkgs.jdk17}"
    else
      echo "Warning: JAVA_HOME not set and couldn't detect Java installation"
    fi
  fi

  # Ensure PATH includes necessary tools
  export PATH="${extendedPkgs.rustup}/bin:$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/linux-x86_64/bin:$ANDROID_HOME/cmdline-tools/latest/bin:$PATH"

  # Verify required tools are available
  echo "Checking required tools..."
  command -v rustup >/dev/null 2>&1 || { 
    echo "Error: rustup not found."
    echo "Please ensure Rust is installed and available in PATH"
    exit 1
  }
  command -v cargo >/dev/null 2>&1 || { 
    echo "Error: cargo not found."
    echo "Installing Rust toolchain..."
    rustup default stable || rustup install stable
  }
  command -v gradle >/dev/null 2>&1 || { 
    echo "Warning: gradle not found in PATH"
    echo "Will use ./gradlew wrapper instead"
  }

  # Ensure cargo-ndk is installed
  if ! command -v cargo-ndk >/dev/null 2>&1; then
    echo "Installing cargo-ndk..."
    cargo install cargo-ndk
  fi

  # Export all necessary environment variables
  export NIXPKGS_ACCEPT_ANDROID_SDK_LICENSE=1
  export PKG_CONFIG_ALLOW_CROSS=1
  export RUSTFLAGS="-lffi"
  export RUST_BACKTRACE=1

  # Use project-local dependencies
  export OPENSSL_DIR="$PROJECT_DIR/depend/openssl"
  export OPENSSL_LIB_DIR="$OPENSSL_DIR/android-arm64/lib"
  export AARCH64_LINUX_ANDROID_OPENSSL_LIB_DIR="$OPENSSL_DIR/android-arm64/lib"
  export OPENSSL_INCLUDE_DIR="$OPENSSL_DIR/android-arm64/include"
  export OPENSSL_STATIC=1

  # GStreamer configuration
  export PKG_CONFIG_PATH="$PROJECT_DIR/gstreamer-android/arm64/lib/pkgconfig"
  export GST_PLUGIN_PATH="$PROJECT_DIR/gstreamer-android/arm64/lib/gstreamer-1.0"

  # Print build environment
  echo ""
  echo "Build environment:"
  echo "  PROJECT_DIR:      $PROJECT_DIR"
  echo "  ANDROID_HOME:     $ANDROID_HOME"
  echo "  ANDROID_NDK_HOME: $ANDROID_NDK_HOME"
  echo "  JAVA_HOME:        $JAVA_HOME"
  echo "  Rust version:     $(rustc --version 2>/dev/null || echo 'Not available')"
  echo "  Cargo NDK:        $(cargo ndk --version 2>/dev/null || echo 'Not installed')"
  echo ""

  # Check for dependencies
  if [ ! -d "$OPENSSL_DIR/android-arm64" ]; then
    echo "Warning: OpenSSL not found at $OPENSSL_DIR"
    echo "Some features may not work. Run setup-android-env to install dependencies."
  fi

  if [ ! -d "$PROJECT_DIR/gstreamer-android/arm64" ]; then
    echo "Warning: GStreamer not found at $PROJECT_DIR/gstreamer-android"
    echo "Some features may not work. Run setup-android-env to install dependencies."
  fi

  # Clean previous builds
  echo "Cleaning previous builds..."
  rm -f app/src/main/jniLibs/arm64-v8a/*.so
  rm -rf target/debug/apk/lib/arm64-v8a/* 2>/dev/null || true
  rm -rf target/release/apk/lib/arm64-v8a/* 2>/dev/null || true

  # Determine build mode
  BUILD_MODE="''${BUILD_MODE:-release}"
  BUILD_FLAG=""
  TARGET_DIR="release"
  GRADLE_BUILD_TYPE="Release"

  if [ "$BUILD_MODE" = "debug" ]; then
    BUILD_FLAG=""
    TARGET_DIR="debug"
    GRADLE_BUILD_TYPE="Debug"
    echo "════════════════════════════════════════════════════════════"
    echo "  Building in DEBUG mode"
    echo "════════════════════════════════════════════════════════════"
  else
    BUILD_FLAG="--release"
    echo "════════════════════════════════════════════════════════════"
    echo "  Building in RELEASE mode"
    echo "════════════════════════════════════════════════════════════"
  fi

  # Ensure we have the Android targets
  echo ""
  echo "Checking Rust Android targets..."
  for target in aarch64-linux-android armv7-linux-androideabi x86_64-linux-android i686-linux-android; do
    if ! rustup target list --installed | grep -q "$target"; then
      echo "Installing $target..."
      rustup target add "$target"
    else
      echo "  ✓ $target installed"
    fi
  done

  # Build Rust library for Android
  echo ""
  echo "Building Rust library for Android (arm64-v8a)..."
  echo "Running: cargo ndk -t arm64-v8a -o app/src/main/jniLibs/ build $BUILD_FLAG"

  if ! cargo ndk -t arm64-v8a -o app/src/main/jniLibs/ build $BUILD_FLAG; then
    echo ""
    echo "Error: Rust build failed!"
    echo "Check the error messages above for details."
    echo ""
    echo "Common issues:"
    echo "  • Missing Android targets - run: rustup target add aarch64-linux-android"
    echo "  • Missing cargo-ndk - run: cargo install cargo-ndk"
    echo "  • Missing dependencies - run: setup-android-env"
    exit 1
  fi

  # Handle library naming
  JNI_LIBS="app/src/main/jniLibs/arm64-v8a"
  mkdir -p "$JNI_LIBS"

  echo ""
  echo "Processing native libraries..."

  # Find and rename the main library
  FOUND_LIB=0
  for lib in libagdk_eframe.so lib$(basename "$PROJECT_DIR").so; do
    if [ -f "$JNI_LIBS/$lib" ]; then
      if [ "$lib" != "libmain.so" ]; then
        echo "  Renaming $lib to libmain.so..."
        mv "$JNI_LIBS/$lib" "$JNI_LIBS/libmain.so"
      fi
      FOUND_LIB=1
      break
    fi
  done

  if [ "$FOUND_LIB" -eq 0 ] && [ ! -f "$JNI_LIBS/libmain.so" ]; then
    echo "Warning: Expected library not found in $JNI_LIBS"
    echo "Available libraries:"
    ls -la "$JNI_LIBS" 2>/dev/null || echo "  No libraries found"
    echo ""
    echo "The build may have failed or the library name is unexpected."
  fi

  # Copy libc++_shared.so if needed
  LIBCXX_SHARED="$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/lib/aarch64-linux-android/24/libc++_shared.so"
  if [ -f "$LIBCXX_SHARED" ]; then
    if [ ! -f "$JNI_LIBS/libc++_shared.so" ]; then
      echo "  Copying libc++_shared.so..."
      cp "$LIBCXX_SHARED" "$JNI_LIBS/"
    else
      echo "  ✓ libc++_shared.so already present"
    fi
  else
    echo "Warning: libc++_shared.so not found at expected location"
  fi

  # List all native libraries
  echo ""
  echo "Native libraries in $JNI_LIBS:"
  ls -lh "$JNI_LIBS"/*.so 2>/dev/null || echo "  No .so files found"

  # Build APK
  echo ""
  echo "════════════════════════════════════════════════════════════"
  echo "  Building Android APK ($GRADLE_BUILD_TYPE)"
  echo "════════════════════════════════════════════════════════════"

  # Check if gradlew exists
  if [ -f "./gradlew" ]; then
    GRADLE_CMD="./gradlew"
    # Make sure gradlew is executable
    chmod +x ./gradlew
  else
    GRADLE_CMD="gradle"
  fi

  # Run gradle build
  echo "Running: $GRADLE_CMD clean assemble$GRADLE_BUILD_TYPE"
  if ! $GRADLE_CMD clean assemble$GRADLE_BUILD_TYPE; then
    echo ""
    echo "Error: Gradle build failed!"
    echo "Check the error messages above for details."
    echo ""
    echo "Common issues:"
    echo "  • Missing JAVA_HOME - ensure Java is installed"
    echo "  • Missing Android SDK - check ANDROID_HOME"
    echo "  • Gradle wrapper issues - try: gradle wrapper"
    exit 1
  fi

  # Check APK location based on build type
  if [ "$BUILD_MODE" = "release" ]; then
    APK_LOCATION="app/build/outputs/apk/release"
  else
    APK_LOCATION="app/build/outputs/apk/debug"
  fi

  # Check if APK was built successfully
  echo ""
  if [ -d "$APK_LOCATION" ]; then
    echo "════════════════════════════════════════════════════════════"
    echo "  ✅ APK BUILD SUCCESSFUL!"
    echo "════════════════════════════════════════════════════════════"
    echo ""
    echo "APK location: $APK_LOCATION"
    echo "Available APKs:"
    for apk in "$APK_LOCATION"/*.apk; do
      if [ -f "$apk" ]; then
        SIZE=$(ls -lh "$apk" | awk '{print $5}')
        echo "  • $(basename "$apk") ($SIZE)"
      fi
    done
  else
    echo "════════════════════════════════════════════════════════════"
    echo "  ❌ APK BUILD FAILED"
    echo "════════════════════════════════════════════════════════════"
    echo ""
    echo "Error: APK directory not found at $APK_LOCATION"
    echo "Check the Gradle output above for errors."
    exit 1
  fi

  # Optional: Install and run
  if [ "''${INSTALL_AND_RUN:-0}" = "1" ]; then
    echo ""
    echo "════════════════════════════════════════════════════════════"
    echo "  Installing and Running APK"
    echo "════════════════════════════════════════════════════════════"
  
    # Check if device is connected
    if ! adb devices | grep -q "device$"; then
      echo "Error: No Android device connected!"
      echo "Please connect a device with USB debugging enabled."
      exit 1
    fi
  
    echo "Installing APK to device..."
    if [ "$BUILD_MODE" = "release" ]; then
      $GRADLE_CMD installRelease
    else
      $GRADLE_CMD installDebug
    fi
  
    echo ""
    echo "Starting application..."
    adb shell am start -n co.realfit.agdkeframe/.MainActivity
  
    echo ""
    echo "Showing logs (Ctrl+C to stop)..."
    adb logcat -s main RustStdoutStderr agdk_eframe
  fi

  # Final instructions
  echo ""
  echo "════════════════════════════════════════════════════════════"
  echo "  Build Complete!"
  echo "════════════════════════════════════════════════════════════"
  echo ""
  echo "Next steps:"
  echo "  • Install on device:  adb install $APK_LOCATION/*.apk"
  echo "  • Install and run:    INSTALL_AND_RUN=1 ./build-apk"
  echo "  • View logs:          adb logcat -s main RustStdoutStderr"
  echo "  • Debug build:        BUILD_MODE=debug ./build-apk"
  echo ""
  EOFSCRIPT
    chmod +x "$PROJECT_DIR/build-apk"
  
    # Also create a convenience symlink in the base directory
    if [ -w "$BASE_DIR" ]; then
      ln -sf "$PROJECT_DIR/build-apk" "$BASE_DIR/build-agdk-eframe" 2>/dev/null || true
      echo "Created convenience symlink: $BASE_DIR/build-agdk-eframe -> $PROJECT_DIR/build-apk"
    fi
  
    echo "Build script created successfully at: $PROJECT_DIR/build-apk"
''
