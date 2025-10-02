# .idx/modules/scripts/setup-openssl.nix
{ extendedPkgs }:

''
  # Setup OpenSSL in project directory
  OPENSSL_DEST="$PROJECT_DIR/depend/openssl"
  if [ ! -d "$OPENSSL_DEST/android-arm64" ]; then
    echo "Setting up prebuilt OpenSSL 3.0.12 in $OPENSSL_DEST..."
    mkdir -p "$OPENSSL_DEST"
    curl -L https://www.openssl.org/source/openssl-3.0.12.tar.gz -o /tmp/openssl.tar.gz
    tar -xzf /tmp/openssl.tar.gz -C /tmp
    cd /tmp/openssl-3.0.12
    export ANDROID_NDK_ROOT="${extendedPkgs.androidSdk}/libexec/android-sdk/ndk/25.2.9519653"
    ./Configure android-arm64 --prefix="$OPENSSL_DEST/android-arm64" -D__ANDROID_API__=24 no-shared no-tests
    make -j$(nproc)
    make install_sw
    cd -
    rm -rf /tmp/openssl-3.0.12 /tmp/openssl.tar.gz
    if [ ! -d "$OPENSSL_DEST/android-arm64" ]; then
      echo "Error: Failed to setup OpenSSL at $OPENSSL_DEST/android-arm64"
      exit 1
    fi
  fi
''