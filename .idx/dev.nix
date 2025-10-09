# .idx/dev.nix
{ pkgs, lib, ... }:
let
  # ========================================================================
  # 1. Import centralized configuration u 
  # ========================================================================
  config = import ./modules/config.nix;

  # ========================================================================
  # 2. Apply overlays to pkgs
  # ========================================================================
  overlays = import ./overlays/default.nix { inherit pkgs; };
  extendedPkgs = pkgs.extend (
    self: super:
      builtins.foldl' (acc: overlay: acc // overlay self super) {} overlays
  );

  # ========================================================================
  # 3. Import GStreamer for Android module (pre-built binaries)
  # ========================================================================
  gstreamerAndroid = import ./modules/gstreamer-android { 
    inherit pkgs config; 
  };

  # ========================================================================
  # 4. Import GStreamer Daemon module (host development)
  # ========================================================================
  gstreamerDaemon = import ./modules/gstreamer-daemon { 
    inherit pkgs extendedPkgs; 
  };

  # ========================================================================
  # 5. Import Android libraries module (Nix-built Android libs)
  # ========================================================================
  androidLibs = import ./modules/gstreamer-daemon/android-libs.nix {
    inherit pkgs config gstreamerAndroid;
  };

  # ========================================================================
  # 6. Import scripts module
  # ========================================================================
  scripts = import ./modules/scripts { 
    inherit pkgs; 
  };

  # ========================================================================
  # 7. Assemble all packages
  # ========================================================================
  package_list = import ./modules/packages.nix { 
    inherit extendedPkgs gstreamerDaemon scripts gstreamerAndroid config;
  } ++ androidLibs.packages;
  
  # ========================================================================
  # 8. Setup environment
  environment = import ./modules/environment.nix { 
    inherit lib extendedPkgs gstreamerDaemon gstreamerAndroid config; 
  };
  
  # ========================================================================
  # 9. Configure previews
  # ========================================================================
  previews = import ./modules/previews.nix { 
    inherit extendedPkgs; 
  };
  
  # ========================================================================
  # 10. Configure workspace automation
  # ========================================================================
  workspace = import ./modules/workspace.nix { 
    inherit extendedPkgs gstreamerAndroid config; 
  };

in
{
  imports = [
    {
      channel = "stable-25.05";
      packages = package_list;
      env = environment;
    }
    previews
    workspace
  ];
}
