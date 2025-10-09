# .idx/modules/gstreamer-daemon/interpipe-android.nix
# Cross-compiles gst-interpipe plugin for Android
{ pkgs
, pkgsAndroid
, mesonCrossFile
}:

pkgsAndroid.stdenv.mkDerivation rec {
  pname = "gst-interpipe-android";
  version = "1.1.10";

  src = pkgs.fetchFromGitHub {
    owner = "RidgeRun";
    repo = "gst-interpipe";
    rev = "v${version}";
    hash = "sha256-Z7yeUxsTebKPynYzhtst2rlApoXzU1u/32ZqzBvQ6eY=";
  };

  # Build tools run on host (x86_64-linux)
  nativeBuildInputs = with pkgs; [
    meson
    ninja
    pkg-config
    python3
  ];

  # Libraries to link against (Android target)
  buildInputs = with pkgsAndroid; [
    gst_all_1.gstreamer
    gst_all_1.gst-plugins-base
    glib
  ];

  mesonFlags = [
    "--cross-file=${mesonCrossFile}"
    "-Dtests=disabled"
    "-Dexamples=disabled"
    "-Denable-gtk-doc=false"
    "-Ddefault_library=shared"
  ];

  # Configure pkg-config to find Android dependencies
  preConfigure = ''
    export PKG_CONFIG_PATH="${pkgs.lib.makeSearchPath "lib/pkgconfig" buildInputs}"
    export PKG_CONFIG_LIBDIR="$PKG_CONFIG_PATH"
    
    echo "════════════════════════════════════════════════════════════"
    echo "  Building gst-interpipe for ${pkgsAndroid.stdenv.hostPlatform.config}"
    echo "════════════════════════════════════════════════════════════"
    echo ""
    echo "PKG_CONFIG_PATH:"
    echo "$PKG_CONFIG_PATH" | tr ':' '\n' | sed 's/^/  /'
    echo ""
    
    # Verify GStreamer is found
    if ! ${pkgs.pkg-config}/bin/pkg-config --exists gstreamer-1.0; then
      echo "❌ ERROR: GStreamer not found by pkg-config"
      echo ""
      echo "Available .pc files:"
      find $PKG_CONFIG_PATH -name "*.pc" 2>/dev/null || echo "  (none found)"
      exit 1
    fi
    
    echo "✅ GStreamer found: $(${pkgs.pkg-config}/bin/pkg-config --modversion gstreamer-1.0)"
    echo ""
  '';

  # Disable tests (can't run Android binaries on x86_64 build host)
  doCheck = false;

  # Verify the plugin was built
  postInstall = ''
    PLUGIN_PATH="$out/lib/gstreamer-1.0/libgstinterpipe.so"
    
    if [ ! -f "$PLUGIN_PATH" ]; then
      echo "❌ ERROR: Plugin not built!"
      echo ""
      echo "Expected: $PLUGIN_PATH"
      echo ""
      echo "Contents of $out:"
      find "$out" -type f
      exit 1
    fi
    
    echo "════════════════════════════════════════════════════════════"
    echo "  ✅ gst-interpipe built successfully"
    echo "════════════════════════════════════════════════════════════"
    echo ""
    echo "Plugin: $PLUGIN_PATH"
    ls -lh "$PLUGIN_PATH"
    echo ""
    echo "Architecture: ${pkgsAndroid.stdenv.hostPlatform.config}"
    echo "Size: $(du -h "$PLUGIN_PATH" | cut -f1)"
    echo ""
  '';

  meta = with pkgs.lib; {
    description = "GStreamer interpipe plugin for Android";
    homepage = "https://github.com/RidgeRun/gst-interpipe";
    license = licenses.lgpl21Plus;
    platforms = platforms.android;
  };
}