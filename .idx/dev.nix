# .idx/dev.nix
# Project IDX development environment with Android cross-compilation
{ pkgs, lib, ... }:

let
  # ═══════════════════════════════════════════════════════════════════
  # Import all overlays
  # ═══════════════════════════════════════════════════════════════════
  overlays = import ./overlays/default.nix { inherit pkgs; };

  # ═══════════════════════════════════════════════════════════════════
  # Apply overlays to pkgs
  # ═══════════════════════════════════════════════════════════════════
  extendedPkgs = pkgs.extend (
    self: super:
      builtins.foldl' (acc: overlay: acc // overlay self super) {} overlays
  );

  # ═══════════════════════════════════════════════════════════════════
  # Android Cross-Compilation Bundles
  # ═══════════════════════════════════════════════════════════════════
  mkAndroidBundle = import ./modules/gstreamer-daemon/android-libs-bundle.nix {
    pkgs = extendedPkgs;
  };

  # androidLibs = {
  #   aarch64 = mkAndroidBundle "aarch64";
  #   armv7a = mkAndroidBundle "armv7a";
  #   x86_64 = mkAndroidBundle "x86_64";
  # };

  # ═══════════════════════════════════════════════════════════════════
  # Import GStreamer Android module
  # ═══════════════════════════════════════════════════════════════════
  gstreamerAndroid = import ./modules/gstreamer-android {
    inherit pkgs extendedPkgs;
  };

  # ═══════════════════════════════════════════════════════════════════
  # Import other modules (with Android libs support)
  # ═══════════════════════════════════════════════════════════════════
  packages = import ./modules/packages.nix {
    inherit extendedPkgs gstreamerAndroid;
  };

  environment = import ./modules/environment.nix {
    inherit lib extendedPkgs gstreamerAndroid;
  };

  previews = import ./modules/previews.nix {
    inherit extendedPkgs;
  };

  workspace = import ./modules/workspace.nix {
    inherit extendedPkgs;
  };

in
{
  # ═══════════════════════════════════════════════════════════════════
  # Project IDX Configuration
  # ═══════════════════════════════════════════════════════════════════
  imports = [
    {
      channel = "stable-25.05";  # Updated to match nixpkgs version
      packages = packages;
      env = environment;
    }
    previews
    workspace
  ];

  # ═══════════════════════════════════════════════════════════════════
  # IDX Hooks (for build automation)
  # ═══════════════════════════════════════════════════════════════════
  idx = {
    # Extensions for the IDE
    extensions = [
      "llvm-vs-code-extensions.vscode-clangd"
      "ms-vscode.cmake-tools"
      "twxs.cmake"
      "ms-vscode.cpptools"
    ];

    # Workspace lifecycle hooks
    workspace = {
      # Runs when workspace is first created
      onCreate = {
        setup-info = ''
          echo "════════════════════════════════════════════════════════════"
          echo "  GStreamer Daemon - Android Development Environment"
          echo "════════════════════════════════════════════════════════════"
          echo ""
          echo "Android cross-compilation is configured!"
          echo ""
          echo "To build Android libraries, use the build script:"
          echo "  ./build-android.sh aarch64"
          echo ""
          echo "Or build manually with nix-build (see README)"
          echo ""
        '';
      };

      # Runs every time workspace starts
      onStart = {
        android-env = ''
          echo "Setting up Android environment..."
          export ANDROID_SDK_ROOT="${extendedPkgs.androidSdk}/libexec/android-sdk"
          export ANDROID_NDK_ROOT="${extendedPkgs.androidSdk}/libexec/android-sdk/ndk-bundle"
          echo "✅ Android SDK/NDK configured"
        '';
      };
    };

    # Preview configurations
    previews = {
      enable = true;
      previews = {
        web = {
          command = ["echo" "No web preview for this project"];
          manager = "web";
        };
      };
    };
  };

  # ═══════════════════════════════════════════════════════════════════
  # Make Android bundles accessible for debugging/inspection
  # ═══════════════════════════════════════════════════════════════════
  # passthru = {
  #   inherit androidLibs extendedPkgs;
    
  #   # Helper to access bundles
  #   getAndroidBundle = arch: androidLibs.${arch} or (throw "Unknown architecture: ${arch}");
    
  #   # Available architectures
  #   supportedArchitectures = [ "aarch64" "armv7a" "x86_64" ];
  # };
}