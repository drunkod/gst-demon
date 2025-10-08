# .idx/modules/workspace.nix
{ extendedPkgs, gstreamerAndroid }:

{
  idx.workspace = {
    onCreate = {
      setup = ''
        echo "════════════════════════════════════════════════════════════"
        echo "  Setting up AGDK eframe Android environment"
        echo "════════════════════════════════════════════════════════════"
        echo ""

        # Determine base directory based on permissions
        BASE_DIR="/home/user/rust-android-examples"
        PROJECT_DIR="$BASE_DIR/agdk-eframe"

        if [ ! -w "/home/user" ]; then
          echo "⚠️  /home/user not writable, using /root/rust-android-examples"
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

        echo "📂 Project directory: $PROJECT_DIR"
        echo ""

        # ============================================================
        # 1. Setup Rust targets
        # ============================================================
        echo "🦀 Setting up Rust toolchain..."
        export PATH="${extendedPkgs.rustup}/bin:$PATH"
        
        if ! rustup --version &> /dev/null; then
          echo "❌ Error: Rustup not available"
          exit 1
        fi
        
        echo "   Installing Android targets..."
        rustup target add aarch64-linux-android armv7-linux-androideabi \
                         x86_64-linux-android i686-linux-android

        # Install cargo tools
        echo "   Installing cargo-ndk..."
        which cargo-ndk > /dev/null || cargo install cargo-ndk
        
        echo "   Installing cargo-apk..."
        which cargo-apk > /dev/null || cargo install cargo-apk
        
        echo "   ✅ Rust toolchain ready"
        echo ""

        # ============================================================
        # 2. Accept Android licenses
        # ============================================================
        echo "📱 Configuring Android SDK..."
        export NIXPKGS_ACCEPT_ANDROID_SDK_LICENSE=1
        yes | ${extendedPkgs.androidSdk}/libexec/android-sdk/cmdline-tools/latest/bin/sdkmanager --licenses 2>/dev/null || true
        echo "   ✅ Android SDK configured"
        echo ""

        # ============================================================
        # 3. Setup GStreamer for Android (using Nix-managed source)
        # ============================================================
        echo "🎬 Setting up GStreamer for Android..."
        
        GSTREAMER_DEST="$PROJECT_DIR/gstreamer-android"
        GSTREAMER_TARBALL="${gstreamerAndroid.source}"
        
        if [ ! -f "$GSTREAMER_TARBALL" ]; then
          echo "❌ Error: GStreamer tarball not found at: $GSTREAMER_TARBALL"
          echo "   This should have been provided by Nix."
          exit 1
        fi
        
        echo "   Tarball: $GSTREAMER_TARBALL"
        echo "   Size: $(du -h "$GSTREAMER_TARBALL" | cut -f1)"
        
        if [ ! -d "$GSTREAMER_DEST/arm64/lib/pkgconfig" ]; then
          echo "   Extracting GStreamer binaries..."
          mkdir -p "$GSTREAMER_DEST"
          
          tar -xJf "$GSTREAMER_TARBALL" -C "$GSTREAMER_DEST"
          
          if [ ! -d "$GSTREAMER_DEST/arm64/lib/pkgconfig" ]; then
            echo "❌ Error: Failed to extract GStreamer properly"
            echo "   Expected: $GSTREAMER_DEST/arm64/lib/pkgconfig"
            exit 1
          fi
          
          echo "   ✅ GStreamer extracted successfully"
        else
          echo "   ✅ GStreamer already set up"
        fi
        
        # Show what we have
        echo ""
        echo "   Available architectures:"
        for arch in arm64 armv7 x86 x86_64; do
          if [ -d "$GSTREAMER_DEST/$arch" ]; then
            echo "     • $arch"
          fi
        done
        echo ""

        # ============================================================
        # 4. Setup OpenSSL (if not present)
        # ============================================================
        echo "🔐 Checking OpenSSL..."
        OPENSSL_DEST="$PROJECT_DIR/depend/openssl"
        
        if [ ! -d "$OPENSSL_DEST/android-arm64" ]; then
          echo "   Setting up OpenSSL 3.0.12..."
          mkdir -p "$OPENSSL_DEST"
          
          curl -L https://www.openssl.org/source/openssl-3.0.12.tar.gz -o /tmp/openssl.tar.gz
          tar -xzf /tmp/openssl.tar.gz -C /tmp
          
          cd /tmp/openssl-3.0.12
          export ANDROID_NDK_ROOT="${extendedPkgs.androidSdk}/libexec/android-sdk/ndk/25.2.9519653"
          ./Configure android-arm64 \
            --prefix="$OPENSSL_DEST/android-arm64" \
            -D__ANDROID_API__=24 \
            no-shared no-tests
          make -j$(nproc)
          make install_sw
          
          cd -
          rm -rf /tmp/openssl-3.0.12 /tmp/openssl.tar.gz
          
          echo "   ✅ OpenSSL set up"
        else
          echo "   ✅ OpenSSL already present"
        fi
        echo ""

        # ============================================================
        # 5. Create build script
        # ============================================================
        echo "📝 Creating build script..."
        
        cat > "$PROJECT_DIR/build-apk" << 'EOFSCRIPT'
#!/usr/bin/env bash
set -e

SCRIPT_DIR="$( cd "$( dirname "''${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

echo "════════════════════════════════════════════════════════════"
echo "  Building AGDK eframe APK"
echo "════════════════════════════════════════════════════════════"

BUILD_MODE="''${BUILD_MODE:-release}"
BUILD_FLAG=""

if [ "$BUILD_MODE" = "debug" ]; then
  BUILD_FLAG=""
  echo "Mode: DEBUG"
else
  BUILD_FLAG="--release"
  echo "Mode: RELEASE"
fi

echo ""
echo "Building Rust library..."
cargo ndk -t arm64-v8a -o app/src/main/jniLibs/ build $BUILD_FLAG

echo ""
echo "Building APK..."
./gradlew clean assemble$(echo "$BUILD_MODE" | sed 's/./\U&/')

echo ""
echo "✅ Build complete!"
echo ""
echo "APK location: app/build/outputs/apk/$BUILD_MODE/"
ls -lh app/build/outputs/apk/$BUILD_MODE/*.apk
EOFSCRIPT
        
        chmod +x "$PROJECT_DIR/build-apk"
        echo "   ✅ Build script created at: $PROJECT_DIR/build-apk"
        echo ""

        # ============================================================
        # Summary
        # ============================================================
        echo "════════════════════════════════════════════════════════════"
        echo "  ✅ Setup Complete!"
        echo "════════════════════════════════════════════════════════════"
        echo ""
        echo "Project directory: $PROJECT_DIR"
        echo ""
        echo "Build your app:"
        echo "  cd $PROJECT_DIR"
        echo "  ./build-apk"
        echo ""
        echo "Or use environment variable for debug build:"
        echo "  BUILD_MODE=debug ./build-apk"
        echo ""
        echo "Additional tools:"
        echo "  • setup-android-env        - Re-extract GStreamer"
        echo "  • verify-gstreamer-android - Verify GStreamer installation"
        echo "  • build-gstd-android       - Build GStreamer Daemon for Android"
        echo ""
      '';
      
      default.openFiles = [ 
        "agdk-eframe/src/main.rs" 
        "agdk-eframe/app/build.gradle" 
      ];
    };

    onStart = {
      welcome = ''
        echo "════════════════════════════════════════════════════════════"
        echo "  AGDK eframe Android Development Environment"
        echo "════════════════════════════════════════════════════════════"
        echo ""
        echo "🎬 GStreamer Status:"
        
        if [ -f "$GSTREAMER_ANDROID_TARBALL" ]; then
          echo "   ✅ GStreamer tarball available ($(du -h "$GSTREAMER_ANDROID_TARBALL" 2>/dev/null | cut -f1 || echo "unknown"))"
        else
          echo "   ⚠️  GStreamer tarball not found"
        fi
        
        if [ -d "/home/user/rust-android-examples/agdk-eframe/gstreamer-android/arm64" ]; then
          echo "   ✅ GStreamer extracted in project"
        elif [ -d "/root/rust-android-examples/agdk-eframe/gstreamer-android/arm64" ]; then
          echo "   ✅ GStreamer extracted in project"
        else
          echo "   ℹ️  Run setup-android-env to extract GStreamer"
        fi
        
        echo ""
        echo "🔧 Quick Commands:"
        echo "   • ./agdk-eframe/build-apk        - Build APK"
        echo "   • setup-android-env              - Setup/verify GStreamer"
        echo "   • build-gstd-android             - Build GStreamer Daemon"
        echo "   • gstd-start / gstd-stop         - Control host daemon"
        echo ""
        echo "📚 Documentation: .idx/README.md"
        echo "════════════════════════════════════════════════════════════"
        echo ""
      '';
      
      default.openFiles = [ "agdk-eframe/src/main.rs" ];
    };
  };
}