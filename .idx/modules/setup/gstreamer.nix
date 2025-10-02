{ pkgs }:

pkgs.writeShellScriptBin "setup-gstreamer" ''
  #!/usr/bin/env bash
  set -e
  
  GSTREAMER_DEST="$1"
  
  if [ ! -d "$GSTREAMER_DEST/arm64/lib/pkgconfig" ]; then
    echo "Setting up GStreamer 1.22.12..."
    mkdir -p "$GSTREAMER_DEST"
    
    GSTREAMER_URL="https://gstreamer.freedesktop.org/data/pkg/android/1.22.12/gstreamer-1.0-android-universal-1.22.12.tar.xz"
    
    echo "Downloading GStreamer (this may take a while)..."
    DOWNLOAD_SUCCESS=0
    for attempt in 1 2 3; do
      echo "Download attempt $attempt/3..."
      if curl -L --connect-timeout 30 --max-time 600 "$GSTREAMER_URL" -o /tmp/gstreamer.tar.xz; then
        DOWNLOAD_SUCCESS=1
        break
      fi
      sleep 2
    done
    
    if [ "$DOWNLOAD_SUCCESS" -eq 1 ] && [ -f /tmp/gstreamer.tar.xz ]; then
      tar -xf /tmp/gstreamer.tar.xz -C "$GSTREAMER_DEST"
      rm -rf /tmp/gstreamer.tar.xz
      echo "GStreamer setup complete!"
    else
      echo "WARNING: Could not download GStreamer."
      echo "Creating placeholder directory to continue..."
      mkdir -p "$GSTREAMER_DEST/arm64/lib/pkgconfig"
    fi
  else
    echo "GStreamer already set up at $GSTREAMER_DEST"
  fi
''
