# .idx/modules/packages.nix
{ extendedPkgs, gstreamerDaemon, scripts, gstreamerAndroid }:

let
  # Import Android build module
  androidBuild = import ./gstreamer-daemon/android-build.nix {
    inherit (extendedPkgs) pkgs;
    inherit extendedPkgs;
  };

  # Create a package that provides the GStreamer Android binaries
  gstreamerAndroidPackage = extendedPkgs.stdenv.mkDerivation {
    name = "gstreamer-android-setup";
    version = "1.0.0";
    
    # No source needed - this is a setup helper
    src = extendedPkgs.writeText "dummy" "";
    
    buildInputs = [ gstreamerAndroid.source ];
    
    # Create a script that can extract/setup GStreamer
    installPhase = ''
      mkdir -p $out/bin
      
      cat > $out/bin/gstreamer-android-path << 'EOF'
#!/usr/bin/env bash
# Returns the path to the GStreamer Android tarball
echo "${gstreamerAndroid.source}"
EOF
      
      chmod +x $out/bin/gstreamer-android-path
      
      # Also create a verification script
      cat > $out/bin/verify-gstreamer-android << 'EOF'
#!/usr/bin/env bash
TARBALL="${gstreamerAndroid.source}"
if [ -f "$TARBALL" ]; then
  echo "✅ GStreamer for Android found at: $TARBALL"
  echo "   Size: $(du -h "$TARBALL" | cut -f1)"
  echo ""
  echo "To extract:"
  echo "  tar -xJf \"$TARBALL\" -C ./gstreamer-android"
  exit 0
else
  echo "❌ GStreamer for Android not found!"
  exit 1
fi
EOF
      
      chmod +x $out/bin/verify-gstreamer-android
    '';
    
    meta = {
      description = "Helper scripts for GStreamer Android setup";
    };
  };

in

(with extendedPkgs; [
  python311
  
  # Rust Toolchain
  rustup
  cargo-watch
  cargo-edit
  cargo-outdated
  cargo-ndk
  cargo-apk

  # Android SDK/NDK
  androidSdk

  # Java/JDK
  jdk17
  gradle

  # Core Build Tools
  gcc
  pkg-config
  gnumake
  cmake
  perl

  # System Libraries
  glib
  glib.dev
  openssl
  openssl.dev
  libffi

  # GStreamer & Plugins (for host development)
  gst_all_1.gstreamer
  gst_all_1.gstreamer.dev
  gst_all_1.gst-plugins-base
  gst_all_1.gst-plugins-base.dev
  gst_all_1.gst-plugins-good
  gst_all_1.gst-plugins-bad
  gst_all_1.gst-plugins-ugly
  gst_all_1.gst-libav
  gst_all_1.gst-devtools
  gst_all_1.gst-editing-services

  # Multimedia Libraries
  libva
  libvpx
  x264
  x265

  # GUI Dependencies (for eframe)
  libxkbcommon
  libGL
  wayland
  xorg.libXcursor
  xorg.libXrandr
  xorg.libXi
  xorg.libX11

  # Android Development Tools
  adb-sync
  scrcpy
  
  # Archive tools (for extracting GStreamer)
  xz
  gnutar
  
  # Git for cloning sources
  git
]) ++ gstreamerDaemon.packages 
   ++ [ androidBuild.package gstreamerAndroidPackage ] 
   ++ scripts.packages