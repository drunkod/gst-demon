
{
  description = "GStreamer Daemon (gstd) cross-compilation environment for Android ARM64";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        # Overlay to fix openssl infinite recursion
        openssl-overlay = self: super: {
          openssl = super.openssl.overrideAttrs (oldAttrs: {
            separateDebugInfo = false;
          });
        };

        pkgs = import nixpkgs {
          inherit system;
          config = {
            allowUnfree = true;
            android_sdk.accept_license = true;
          };
          overlays = [ openssl-overlay ];
        };

        # Cross compilation for aarch64-linux (Android ARM64)
        pkgsCross = import nixpkgs {
          inherit system;
          crossSystem = {
            config = "aarch64-unknown-linux-android";
          };
          overlays = [ openssl-overlay ];
        };

        # Android NDK
        androidNdk = pkgs.androidenv.androidPkgs_9_0.ndk-bundle;
        
        # GStreamer version
        gstreamerVersion = "1.22.5";
        
        # Custom derivation for GStreamer Android binaries
        gstreamerAndroid = pkgs.stdenv.mkDerivation rec {
          pname = "gstreamer-android";
          version = gstreamerVersion;
          
          src = pkgs.fetchurl {
            url = "https://gstreamer.freedesktop.org/data/pkg/android/${version}/gstreamer-1.0-android-universal-${version}.tar.xz";
            sha256 = "sha256-PLACEHOLDER"; # Replace with actual hash
          };
          
          installPhase = \'\'
            mkdir -p $out
            cp -r * $out/
          \'\';
        };

        # Jansson for ARM64
        janssonAarch64 = pkgsCross.jansson.overrideAttrs (oldAttrs: {
          configureFlags = (oldAttrs.configureFlags or []) ++ [
            "--host=aarch64-linux-android"
          ];
        });

        # libdaemon for ARM64
        libdaemonAarch64 = pkgsCross.libdaemon.overrideAttrs (oldAttrs: {
          configureFlags = (oldAttrs.configureFlags or []) ++ [
            "--host=aarch64-linux-android"
          ];
          # Disable SETPGRP as mentioned in the build instructions
          preConfigure = \'\'
            sed -i 's/^AC_FUNC_SETPGRP/# AC_FUNC_SETPGRP/' configure.ac
            autoconf
          \'\';
        });

        # Build script for gstd
        buildGstdScript = pkgs.writeScriptBin "build-gstd" \'\'
          #!${pkgs.bash}/bin/bash
          set -e
          
          echo "Building GStreamer Daemon for Android ARM64..."
          
          # Set up environment variables
          export ANDROID_NDK_HOME=${androidNdk}
          export TOOLCHAIN=$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/linux-x86_64
          export TARGET=aarch64-linux-android
          export API=28
          export AR=$TOOLCHAIN/bin/llvm-ar
          export CC=$TOOLCHAIN/bin/$TARGET$API-clang
          export CXX=$TOOLCHAIN/bin/$TARGET$API-clang++
          export AS=$CC
          export LD=$TOOLCHAIN/bin/ld
          export RANLIB=$TOOLCHAIN/bin/llvm-ranlib
          export STRIP=$TOOLCHAIN/bin/llvm-strip
          
          # Create build directory
          mkdir -p build
          cd build
          
          # Clone gstd if not present
          if [ ! -d "gstd-1.x" ]; then
            git clone https://github.com/RidgeRun/gstd-1.x.git
          fi
          
          cd gstd-1.x
          
          # Run autogen
          ./autogen.sh
          
          # Configure with cross-compilation
          PKG_CONFIG_PATH="${gstreamerAndroid}/lib/pkgconfig:${janssonAarch64}/lib/pkgconfig:${libdaemonAarch64}/lib/pkgconfig" \
          ./configure \
            --host=aarch64-linux-android \
            --prefix=$PWD/output \
            --with-gstreamer-dir=${gstreamerAndroid} \
            --enable-gtk-doc=no \
            --enable-tests=no
          
          # Build
          make -j$(nproc)
          make install
          
          ecBuilduild complete! Output in: $PWD/output"
        \'\';

        # Meson cross file for Android ARM64
        mesonCrossFile = pkgs.writeText "android_arm64_cross.txt" \'\'
          [binaries]
          c = \'${androidNdk}/toolchains/llvm/prebuilt/linux-x86_64/bin/aarch64-linux-android28-clang\'
          cpp = \'${androidNdk}/toolchains/llvm/prebuilt/linux-x86_64/bin/aarch64-linux-android28-clang++\'
          ar = \'${androidNdk}/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-ar\'
          strip = \'${androidNdk}/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-strip\'
          pkgconfig = \'${pkgs.pkg-config}/bin/pkg-config\'
          
          [host_machine]
          system = \'android\'
          cpu_family = \'aarch64\'
          cpu = \'aarch64\'
          endian = \'little\'
          
          [properties]
          sys_root = \'${androidNdk}/toolchains/llvm/prebuilt/linux-x86_64/sysroot\'
        \'\';

        # Alternative Meson build script
        buildGstdMesonScript = pkgs.writeScriptBin "build-gstd-meson" \'\'
          #!${pkgs.bash}/bin/bash
          set -e
          
          echo "Building GStreamer Daemon with Meson for Android ARM64..."
          
          mkdir -p build-meson
          cd build-meson
          
          # Clone gstd if not present
          if [ ! -d "gstd-1.x" ]; then
            git clone https://github.com/RidgeRun/gstd-1.x.git
          fi
          
          cd gstd-1.x
          
          # Setup Meson build
          PKG_CONFIG_PATH="${gstreamerAndroid}/lib/pkgconfig:${janssonAarch64}/lib/pkgconfig:${libdaemonAarch64}/lib/pkgconfig" \
          meson setup builddir \
            --cross-file ${mesonCrossFile} \
            --prefix=$PWD/output \
            -Dgtk_doc=disabled \
            -Dtests=disabled
          
          # Build with Ninja
          ninja -C builddir
          ninja -C builddir install
          
          echo "Meson build complete! Output in: $PWD/output"
        \'\';

        buildInputs = with pkgs; [
          # Build tools
          automake
          autoconf
          libtool
          pkg-config
          meson
          ninja
          cmake
          
          # Cross-compilation tools
          pkgsCross.stdenv.cc
          
          # Version control
          git
          wget
          curl
          
          # Development dependencies
          glib
          glib.dev
          json-glib
          
          # GStreamer development packages
          gst_all_1.gstreamer
          gst_all_1.gstreamer.dev
          gst_all_1.gst-plugins-base
          gst_all_1.gst-plugins-good
          gst_all_1.gst-plugins-bad
          
          # Additional libraries
          jansson
          libdaemon
          libedit
          libsoup
          ncurses
          
          # Python for build scripts
          python3
          python3Packages.pip
          
          # Documentation tools (optional)
          gtk-doc
          
          # Android specific
          androidNdk
        ];

        shellHook = \'\'
          echo "🚀 GStreamer Daemon Cross-Compilation Environment for Android ARM64"
          echo "=================================================================="
          echo ""
          echo "Android NDK Path: ${androidNdk}"
          echo "Target Architecture: aarch64-linux-android"
          echo "API Level: 28"
          echo ""
          echo "Available commands:"
          echo "  build-gstd         - Build gstd using autotools"
          echo "  build-gstd-meson   - Build gstd using Meson/Ninja"
          echo ""
          echo "Environment variables:"
          echo "  ANDROID_NDK_HOME   - Android NDK location"
          echo "  PKG_CONFIG_PATH    - Package config search path"
          echo ""
          echo "Manual build steps:"
          echo "  1. Clone gstd: git clone https://github.com/RidgeRun/gstd-1.x.git"
          echo "  2. Enter directory: cd gstd-1.x"
          echo "  3. Run autogen: ./autogen.sh"
          echo "  4. Configure for cross-compilation"
          echo "  5. Build with make"
          echo "=================================================================="
          
          # Set up environment variables
          export ANDROID_NDK_HOME=${androidNdk}
          export TOOLCHAIN=$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/linux-x86_64
          export TARGET=aarch64-linux-android
          export API=28
          
          # Set up cross-compilation tools
          export AR=$TOOLCHAIN/bin/llvm-ar
          export CC=$TOOLCHAIN/bin/$TARGET$API-clang
          export CXX=$TOOLCHAIN/bin/$TARGET$API-clang++
          export AS=$CC
          export LD=$TOOLCHAIN/bin/ld
          export RANLIB=$TOOLCHAIN/bin/llvm-ranlib
          export STRIP=$TOOLCHAIN/bin/llvm-strip
          
          # Set up pkg-config path for cross-compiled libraries
          export PKG_CONFIG_PATH="${gstreamerAndroid}/lib/pkgconfig:${janssonAarch64}/lib/pkgconfig:${libdaemonAarch64}/lib/pkgconfig:$PKG_CONFIG_PATH"
          
          # Create working directory
          mkdir -p gstd-build
          cd gstd-build
        \'\';

      in
      {
        devShells.default = pkgs.mkShell {
          inherit buildInputs shellHook;
          
          packages = [
            buildGstdScript
            buildGstdMesonScript
          ];
        };

        # Package outputs for the cross-compiled libraries
        packages = {
          jansson-aarch64 = janssonAarch64;
          libdaemon-aarch64 = libdaemonAarch64;
          gstreamer-android = gstreamerAndroid;
          
          # Complete gstd build
          gstd-android = pkgs.stdenv.mkDerivation {
            pname = "gstd-android";
            version = "1.0";
            
            src = pkgs.fetchFromGitHub {
              owner = "RidgeRun";
              repo = "gstd-1.x";
              rev = "master";
              sha256 = "sha256-PLACEHOLDER"; # Replace with actual hash
            };
            
            nativeBuildInputs = buildInputs;
            
            configureFlags = [
              "--host=aarch64-linux-android"
              "--with-gstreamer-dir=${gstreamerAndroid}"
            ];
            
            preConfigure = \'\'
              export CC=${androidNdk}/toolchains/llvm/prebuilt/linux-x86_64/bin/aarch64-linux-android28-clang
              export CXX=${androidNdk}/toolchains/llvm/prebuilt/linux-x86_64/bin/aarch64-linux-android28-clang++
              ./autogen.sh
            \'\';
          };
        };
      });
}
