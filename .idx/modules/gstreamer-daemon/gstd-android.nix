# .idx/modules/gstreamer-daemon/gstd-android.nix
# Cross-compiles GStreamer Daemon as a library for Android
{ pkgs
, pkgsAndroid
, mesonCrossFile
, gst-interpipe-android
, gstd-as-library-patch
}:

pkgsAndroid.stdenv.mkDerivation rec {
  pname = "gstd-android";
  version = "0.15.2";

  src = pkgs.fetchFromGitHub {
    owner = "RidgeRun";
    repo = "gstd-1.x";
    rev = "v${version}";
    sha256 = "sha256-capHgSurUSaBIUbKlPHv5hsfBZ11UwtgyuXRjQJJxuY=";
  };

  # Apply patch to build as library instead of executable
  patches = [ gstd-as-library-patch ];

  nativeBuildInputs = with pkgs; [
    meson
    ninja
    pkg-config
    python3
  ];

  buildInputs = with pkgsAndroid; [
    # Our cross-compiled interpipe plugin
    gst-interpipe-android
    
    # GStreamer components
    gst_all_1.gstreamer
    gst_all_1.gst-plugins-base
    
    # Other dependencies
    glib
    json-glib
    jansson
    libdaemon
    readline
    ncurses
    
    # libsoup - try version 3 first (modern nixpkgs default)
    # If build fails, you may need to use libsoup_2_4
    libsoup
  ];

  mesonFlags = [
    "--cross-file=${mesonCrossFile}"
    "-Denable-tests=disabled"
    "-Denable-examples=disabled"
    "-Denable-python=disabled"
    "-Denable-gtk-doc=false"
    "-Denable-systemd=disabled"
    "-Denable-initd=disabled"
    "-Ddefault_library=shared"
    
    # Add flags for library build
    "-Dc_args=-DGSTD_AS_LIBRARY -fvisibility=default"
    "-Dcpp_args=-DGSTD_AS_LIBRARY -fvisibility=default"
  ];

  preConfigure = ''
    export PKG_CONFIG_PATH="${pkgs.lib.makeSearchPath "lib/pkgconfig" buildInputs}"
    export PKG_CONFIG_LIBDIR="$PKG_CONFIG_PATH"
    
    echo "════════════════════════════════════════════════════════════"
    echo "  Building gstd for ${pkgsAndroid.stdenv.hostPlatform.config}"
    echo "════════════════════════════════════════════════════════════"
    echo ""
    
    # Verify all dependencies
    for dep in gstreamer-1.0 glib-2.0 json-glib-1.0; do
      if ${pkgs.pkg-config}/bin/pkg-config --exists $dep; then
        echo "✅ $dep: $(${pkgs.pkg-config}/bin/pkg-config --modversion $dep)"
      else
        echo "❌ $dep: NOT FOUND"
        exit 1
      fi
    done
    
    echo ""
    echo "Patch applied: gstd-as-library.patch"
    echo ""
  '';

  doCheck = false;

  postInstall = ''
    LIB_PATH="$out/lib/libgstd.so"
    
    if [ ! -f "$LIB_PATH" ]; then
      echo "❌ ERROR: libgstd.so not built!"
      echo ""
      echo "Contents of $out:"
      find "$out" -type f
      exit 1
    fi
    
    echo "════════════════════════════════════════════════════════════"
    echo "  ✅ gstd library built successfully"
    echo "════════════════════════════════════════════════════════════"
    echo ""
    echo "Library: $LIB_PATH"
    ls -lh "$LIB_PATH"
    echo ""
    echo "Size: $(du -h "$LIB_PATH" | cut -f1)"
    echo ""
    echo "Dependencies:"
    ${pkgsAndroid.stdenv.cc.bintools}/bin/${pkgsAndroid.stdenv.cc.targetPrefix}readelf -d "$LIB_PATH" | grep NEEDED | sed 's/^/  /' || true
    echo ""
  '';

  meta = with pkgs.lib; {
    description = "GStreamer Daemon as a library for Android";
    homepage = "https://github.com/RidgeRun/gstd-1.x";
    license = licenses.lgpl21Plus;
    platforms = platforms.linux;
  };
}