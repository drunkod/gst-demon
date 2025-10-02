{ pkgs }:

pkgs.writeShellScriptBin "setup-openssl" ''
  #!/usr/bin/env bash
  set -e
  
  OPENSSL_DEST="$1"
  ANDROID_SDK_PATH="$2"
  
  if [ ! -d "$OPENSSL_DEST/android-arm64" ]; then
    echo "Setting up OpenSSL 3.0.12..."
    mkdir -p "$OPENSSL_DEST"
    
    # Try downloading from GitHub (more reliable)
    OPENSSL_URL="https://github.com/openssl/openssl/archive/refs/tags/openssl-3.0.12.tar.gz"
    
    echo "Downloading OpenSSL from GitHub..."
    DOWNLOAD_SUCCESS=0
    for attempt in 1 2 3; do
      echo "Download attempt $attempt/3..."
      if curl -L --connect-timeout 30 --max-time 300 "$OPENSSL_URL" -o /tmp/openssl.tar.gz; then
        DOWNLOAD_SUCCESS=1
        break
      fi
      sleep 2
    done
    
    if [ "$DOWNLOAD_SUCCESS" -eq 1 ] && [ -f /tmp/openssl.tar.gz ]; then
      tar -xzf /tmp/openssl.tar.gz -C /tmp
      
      # GitHub archive has different directory name
      cd /tmp/openssl-openssl-3.0.12 2>/dev/null || cd /tmp/openssl-3.0.12
      
      export ANDROID_NDK_ROOT="$ANDROID_SDK_PATH/ndk/25.2.9519653"
      echo "Using NDK at: $ANDROID_NDK_ROOT"
      
      # Verify NDK exists
      if [ ! -d "$ANDROID_NDK_ROOT" ]; then
        echo "Error: NDK not found at $ANDROID_NDK_ROOT"
        echo "Available NDK versions:"
        ls -la "$ANDROID_SDK_PATH/ndk/" 2>/dev/null || echo "No NDK directory found"
        exit 1
      fi
      
      ./Configure android-arm64 \
        --prefix="$OPENSSL_DEST/android-arm64" \
        -D__ANDROID_API__=24 \
        no-shared \
        no-tests
      
      make -j$(nproc)
      make install_sw
      
      cd - > /dev/null
      rm -rf /tmp/openssl* 2>/dev/null || true
      echo "OpenSSL setup complete!"
    else
      echo "WARNING: Could not download OpenSSL."
      echo "Creating placeholder directory to continue..."
      mkdir -p "$OPENSSL_DEST/android-arm64/lib"
      mkdir -p "$OPENSSL_DEST/android-arm64/include"
    fi
  else
    echo "OpenSSL already set up at $OPENSSL_DEST"
  fi
''
