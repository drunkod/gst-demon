# .idx/modules/gstreamer-daemon/gstd-android-libs.nix
# 
# Nix derivation for cross-compiling gstd and interpipe for Android
# This replaces the shell script approach with proper Nix builds

{ pkgs
, stdenv
, lib
, config
, gstreamerAndroid
, targetArch ? "arm64-v8a"
}:

let
  # Version configuration from centralized config
  interpipeVersion = config.interpipe.version;
  gstdVersion = config.gstd.version;
  androidApiLevel = config.android.apiLevel;
  
  # Map Android ABI to GStreamer architecture directory
  gstArchMap = {
    "arm64-v8a" = "arm64";
    "armeabi-v7a" = "armv7";
    "x86_64" = "x86_64";
    "x86" = "x86";
  };
  
  gstArch = gstArchMap.${targetArch} or (throw "Unknown target architecture: ${targetArch}");
  
  # Get dynamically generated cross-file
  crossFiles = import ./../../cross-files { inherit pkgs config; };
  crossFile = crossFiles.byAbi targetArch;
  
  # Extract GStreamer Android to a fixed location for this build
  gstreamerExtracted = stdenv.mkDerivation {
    name = "gstreamer-android-extracted-${gstArch}";
    src = gstreamerAndroid.source;
    
    dontBuild = true;
    dontConfigure = true;
    
    unpackPhase = ''
      runHook preUnpack
      mkdir -p $out
      tar -xJf $src -C $out
      runHook postUnpack
    '';
    
    installPhase = ''
      # Already extracted in unpackPhase
      # Verify the expected structure exists
      if [ ! -d "$out/${gstArch}/lib/pkgconfig" ]; then
        echo "ERROR: Expected GStreamer structure not found"
        echo "Looking for: $out/${gstArch}/lib/pkgconfig"
        echo "Available:"
        ls -la $out/
        exit 1
      fi
    '';
  };
  
  # Common build inputs for both interpipe and gstd
  commonBuildInputs = [
    pkgs.meson
    pkgs.ninja
    pkgs.pkg-config
    pkgs.python3
  ];
  
  # Build gst-interpipe
  interpipe = stdenv.mkDerivation {
    pname = "gst-interpipe-android";
    version = interpipeVersion;
    
    src = pkgs.fetchFromGitHub {
      owner = builtins.head (lib.splitString "/" config.interpipe.repo);
      repo = builtins.elemAt (lib.splitString "/" config.interpipe.repo) 1;
      rev = config.interpipe.rev;
      hash = config.interpipe.sha256;
    };
    
    nativeBuildInputs = commonBuildInputs;
    
    mesonFlags = [
      "--cross-file=${crossFile}"
      "-Dtests=disabled"
      "-Denable-gtk-doc=false"
      "-Ddefault_library=shared"
    ];
    
    # Set up environment for cross-compilation
    preConfigure = ''
      export PKG_CONFIG_PATH="${gstreamerExtracted}/${gstArch}/lib/pkgconfig"
      export PKG_CONFIG_LIBDIR="$PKG_CONFIG_PATH"
      
      echo "PKG_CONFIG_PATH: $PKG_CONFIG_PATH"
      
      # Verify pkg-config can find GStreamer
      if ! pkg-config --exists gstreamer-1.0; then
        echo "ERROR: pkg-config cannot find gstreamer-1.0"
        echo "PKG_CONFIG_PATH: $PKG_CONFIG_PATH"
        echo "Available .pc files:"
        ls -la "$PKG_CONFIG_PATH/"*.pc || true
        exit 1
      fi
    '';
    
    # Only install the plugin
    postInstall = ''
      # Move plugin to expected location
      if [ ! -f "$out/lib/gstreamer-1.0/libgstinterpipe.so" ]; then
        echo "ERROR: interpipe plugin not built"
        exit 1
      fi
      
      echo "✅ Interpipe plugin built for ${targetArch}"
    '';
    
    meta = with lib; {
      description = "GStreamer interpipe plugin for Android ${targetArch}";
      license = licenses.lgpl21Plus;
      platforms = platforms.linux;
    };
  };
  
  # Build gstd with patch applied
  gstd = stdenv.mkDerivation {
    pname = "gstd-android";
    version = gstdVersion;
    
    src = pkgs.fetchFromGitHub {
      owner = builtins.head (lib.splitString "/" config.gstd.repo);
      repo = builtins.elemAt (lib.splitString "/" config.gstd.repo) 1;
      rev = config.gstd.rev;
      sha256 = config.gstd.sha256;
    };
    
    nativeBuildInputs = commonBuildInputs;
    
    patches = [ ./../../patches/gstd-as-library.patch ];
    
    mesonFlags = [
      "--cross-file=${crossFile}"
      "-Denable-tests=disabled"
      "-Denable-examples=disabled"
      "-Denable-python=disabled"
      "-Denable-gtk-doc=false"
      "-Denable-systemd=disabled"
      "-Denable-initd=disabled"
      "-Ddefault_library=shared"
      "-Dc_args=-DGSTD_AS_LIBRARY -fvisibility=hidden"
      "-Dcpp_args=-DGSTD_AS_LIBRARY -fvisibility=hidden"
    ];
    
    preConfigure = ''
      # Include both GStreamer and interpipe in PKG_CONFIG_PATH
      export PKG_CONFIG_PATH="${gstreamerExtracted}/${gstArch}/lib/pkgconfig:${interpipe}/lib/pkgconfig"
      export PKG_CONFIG_LIBDIR="$PKG_CONFIG_PATH"
      
      echo "PKG_CONFIG_PATH: $PKG_CONFIG_PATH"
      
      # Verify dependencies
      pkg-config --exists gstreamer-1.0 || {
        echo "ERROR: gstreamer-1.0 not found"
        exit 1
      }
    '';
    
    postInstall = ''
      if [ ! -f "$out/lib/libgstd.so" ]; then
        echo "ERROR: gstd library not built"
        exit 1
      fi
      
      echo "✅ gstd library built for ${targetArch}"
    '';
    
    meta = with lib; {
      description = "GStreamer Daemon as library for Android ${targetArch}";
      license = licenses.lgpl21Plus;
      platforms = platforms.linux;
    };
  };

in
# Final derivation that combines everything
stdenv.mkDerivation {
  name = "gstd-android-complete-${targetArch}";
  
  dontUnpack = true;
  dontBuild = true;
  
  installPhase = ''
    mkdir -p $out/lib/gstreamer-1.0
    
    # Copy gstd library
    cp ${gstd}/lib/libgstd.so $out/lib/
    
    # Copy interpipe plugin
    cp ${interpipe}/lib/gstreamer-1.0/libgstinterpipe.so $out/lib/gstreamer-1.0/
    
    # Copy essential GStreamer libraries
    cp ${gstreamerExtracted}/${gstArch}/lib/libgstreamer-1.0.so $out/lib/ || true
    cp ${gstreamerExtracted}/${gstArch}/lib/libgstbase-1.0.so $out/lib/ || true
    cp ${gstreamerExtracted}/${gstArch}/lib/libglib-2.0.so $out/lib/ || true
    cp ${gstreamerExtracted}/${gstArch}/lib/libgobject-2.0.so $out/lib/ || true
    cp ${gstreamerExtracted}/${gstArch}/lib/libgio-2.0.so $out/lib/ || true
    cp ${gstreamerExtracted}/${gstArch}/lib/libgmodule-2.0.so $out/lib/ || true
    cp ${gstreamerExtracted}/${gstArch}/lib/libjson-glib-1.0.so $out/lib/ || true
    cp ${gstreamerExtracted}/${gstArch}/lib/libffi.so $out/lib/ || true
    cp ${gstreamerExtracted}/${gstArch}/lib/libintl.so $out/lib/ || true
    cp ${gstreamerExtracted}/${gstArch}/lib/libiconv.so $out/lib/ || true
    
    # Copy core plugins
    if [ -d "${gstreamerExtracted}/${gstArch}/lib/gstreamer-1.0" ]; then
      cp ${gstreamerExtracted}/${gstArch}/lib/gstreamer-1.0/libgstcoreelements.so $out/lib/gstreamer-1.0/ || true
      cp ${gstreamerExtracted}/${gstArch}/lib/gstreamer-1.0/libgstcoretracers.so $out/lib/gstreamer-1.0/ || true
    fi
    
    # Create build info
    cat > $out/BUILD_INFO.txt << EOF
    GStreamer Daemon Android Libraries
    ===================================
    
    Target Architecture: ${targetArch}
    GStreamer Architecture: ${gstArch}
    Android API Level: ${androidApiLevel}
    
    Components:
      - gstd: ${gstdVersion}
      - gst-interpipe: ${interpipeVersion}
      - GStreamer Android: ${gstreamerAndroid.source}
    
    Built: $(date)
    
    Libraries:
    EOF
    
    find $out/lib -name "*.so" -exec basename {} \; | sort >> $out/BUILD_INFO.txt
    
    echo ""
    echo "═══════════════════════════════════════════════════════════"
    echo "  ✅ Android libraries built successfully"
    echo "═══════════════════════════════════════════════════════════"
    echo ""
    echo "Architecture: ${targetArch}"
    echo "Output: $out"
    echo ""
    echo "Libraries:"
    ls -lh $out/lib/*.so | awk '{print "  " $9 ": " $5}'
    echo ""
    echo "Plugins:"
    ls -lh $out/lib/gstreamer-1.0/*.so 2>/dev/null | awk '{print "  " $9 ": " $5}' || echo "  (none)"
  '';
  
  meta = with lib; {
    description = "Complete GStreamer Daemon library bundle for Android ${targetArch}";
    platforms = platforms.linux;
  };
}