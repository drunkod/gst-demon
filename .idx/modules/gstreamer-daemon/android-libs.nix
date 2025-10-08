# .idx/modules/gstreamer-daemon/android-libs.nix
# 
# Module that provides pre-built Android libraries for all architectures
# This replaces the shell script approach with cacheable Nix builds

{ pkgs, config, gstreamerAndroid }:

let
  # Build libraries for a specific architecture
  buildForArch = arch: pkgs.callPackage ./gstd-android-libs.nix {
    inherit config gstreamerAndroid;
    targetArch = arch;
  };
  
  # Build for all supported architectures
  allArchs = builtins.listToAttrs (
    map (arch: {
      name = arch;
      value = buildForArch arch;
    }) config.android.architectures
  );
  
  # Create a deployment script that copies to Android project
  deployScript = pkgs.writeShellScriptBin "deploy-gstd-android" ''
    #!/usr/bin/env bash
    set -euo pipefail
    
    PROJECT_ROOT="$(pwd)"
    JNI_LIBS_BASE="$PROJECT_ROOT/agdk-eframe/app/src/main/jniLibs"
    
    echo "════════════════════════════════════════════════════════════"
    echo "  Deploying GStreamer Daemon Android Libraries"
    echo "════════════════════════════════════════════════════════════"
    echo ""
    
    # Architectures to deploy
    ARCHITECTURES="''${ARCHITECTURES:-${config.android.defaultArch}}"
    
    echo "Target architectures: $ARCHITECTURES"
    echo "Destination: $JNI_LIBS_BASE"
    echo ""
    
    for arch in $ARCHITECTURES; do
      echo "Deploying $arch..."
      
      # Determine source path
      case "$arch" in
        arm64-v8a)
          SRC="${allArchs.arm64-v8a}/lib"
          ;;
        armeabi-v7a)
          SRC="${allArchs.armeabi-v7a}/lib"
          ;;
        x86_64)
          SRC="${allArchs.x86_64}/lib"
          ;;
        *)
          echo "  ⚠️  Unknown architecture: $arch"
          continue
          ;;
      esac
      
      # Create destination
      DEST="$JNI_LIBS_BASE/$arch"
      mkdir -p "$DEST"
      
      # Copy libraries
      if [ -d "$SRC" ]; then
        cp -v "$SRC"/*.so "$DEST/" 2>/dev/null || true
        
        # Copy plugins if they exist
        if [ -d "$SRC/gstreamer-1.0" ]; then
          cp -v "$SRC/gstreamer-1.0"/*.so "$DEST/" 2>/dev/null || true
        fi
        
        # Show what was copied
        COUNT=$(find "$DEST" -name "*.so" | wc -l)
        SIZE=$(du -sh "$DEST" | cut -f1)
        echo "  ✅ Copied $COUNT libraries ($SIZE)"
      else
        echo "  ❌ Source not found: $SRC"
        exit 1
      fi
      
      echo ""
    done
    
    echo "════════════════════════════════════════════════════════════"
    echo "  ✅ Deployment Complete"
    echo "════════════════════════════════════════════════════════════"
    echo ""
    echo "Libraries are now in: $JNI_LIBS_BASE"
    echo ""
    echo "Next step: Build your APK"
    echo "  cd agdk-eframe && ./build-apk"
    echo ""
  '';
  
  # Create a verification script
  verifyScript = pkgs.writeShellScriptBin "verify-gstd-android-libs" ''
    #!/usr/bin/env bash
    set -euo pipefail
    
    echo "════════════════════════════════════════════════════════════"
    echo "  GStreamer Daemon Android Libraries - Verification"
    echo "════════════════════════════════════════════════════════════"
    echo ""
    
    ${pkgs.lib.concatMapStringsSep "\n" (arch: ''
      echo "Architecture: ${arch}"
      echo "  Path: ${allArchs.${arch}}"
      
      if [ -d "${allArchs.${arch}}/lib" ]; then
        LIB_COUNT=$(find "${allArchs.${arch}}/lib" -name "*.so" | wc -l)
        TOTAL_SIZE=$(du -sh "${allArchs.${arch}}" | cut -f1)
        
        echo "  Status: ✅ Available"
        echo "  Libraries: $LIB_COUNT"
        echo "  Total size: $TOTAL_SIZE"
        
        # Check for key libraries
        if [ -f "${allArchs.${arch}}/lib/libgstd.so" ]; then
          echo "  • libgstd.so: ✅"
        else
          echo "  • libgstd.so: ❌"
        fi
        
        if [ -f "${allArchs.${arch}}/lib/gstreamer-1.0/libgstinterpipe.so" ]; then
          echo "  • libgstinterpipe.so: ✅"
        else
          echo "  • libgstinterpipe.so: ❌"
        fi
      else
        echo "  Status: ❌ Not found"
      fi
      
      echo ""
    '') config.android.architectures}
    
    echo "════════════════════════════════════════════════════════════"
    echo ""
    echo "To deploy these libraries to your Android project:"
    echo "  deploy-gstd-android"
    echo ""
    echo "To deploy all architectures:"
    echo "  ARCHITECTURES=\"${toString config.android.architectures}\" deploy-gstd-android"
    echo ""
  '';

in
{
  # Expose libraries for each architecture
  libs = allArchs;
  
  # Expose deployment tools
  scripts = {
    deploy = deployScript;
    verify = verifyScript;
  };
  
  # List of packages to add to environment
  packages = [
    deployScript
    verifyScript
  ];
}