# .idx/modules/scripts/setup-gstreamer.nix
{ extendedPkgs }:

''
  # Setup GStreamer in project directory
  GSTREAMER_DEST="$PROJECT_DIR/gstreamer-android"
  if [ ! -d "$GSTREAMER_DEST/arm64/lib/pkgconfig" ]; then
    echo "Setting up prebuilt GStreamer 1.22.12 in $GSTREAMER_DEST..."
    mkdir -p "$GSTREAMER_DEST"
    curl -L https://gstreamer.freedesktop.org/data/pkg/android/1.22.12/gstreamer-1.0-android-universal-1.22.12.tar.xz -o /tmp/gstreamer.tar.xz
    tar -xf /tmp/gstreamer.tar.xz -C "$GSTREAMER_DEST"
    mv "$GSTREAMER_DEST/arm64" "$GSTREAMER_DEST/arm64-tmp" 2>/dev/null || true
    mv "$GSTREAMER_DEST/arm64-tmp" "$GSTREAMER_DEST/arm64" 2>/dev/null || true
    rm -rf /tmp/gstreamer.tar.xz
    if [ ! -d "$GSTREAMER_DEST/arm64/lib/pkgconfig" ]; then
      echo "Error: Failed to setup GStreamer at $GSTREAMER_DEST/arm64"
      exit 1
    fi
  fi
''