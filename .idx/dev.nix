# .idx/dev.nix
{ pkgs, lib, ... }:
let
  # Import all overlays 
  overlays = import ./overlays/default.nix { inherit pkgs; };

  # Apply overlays to pkgs
  extendedPkgs = pkgs.extend (
    self: super:
      builtins.foldl' (acc: overlay: acc // overlay self super) {} overlays
  );

  # Import config (centralized configuration)
  config = import ./modules/config.nix;

  # Import GStreamer for Android module (must be before gstreamerDaemon)
  gstreamerAndroid = import ./modules/gstreamer-android { 
    inherit pkgs config; 
  };

  # Import GStreamer Daemon module
  gstreamerDaemon = import ./modules/gstreamer-daemon { 
    inherit pkgs extendedPkgs; 
  };

  # Import scripts module
  scripts = import ./modules/scripts { 
    inherit pkgs; 
  };

  # Import modules with all dependencies
  package_list = import ./modules/packages.nix { 
    inherit extendedPkgs gstreamerDaemon scripts gstreamerAndroid; 
  };
  
  environment = import ./modules/environment.nix { 
    inherit lib extendedPkgs gstreamerDaemon gstreamerAndroid; 
  };
  
  previews = import ./modules/previews.nix { 
    inherit extendedPkgs; 
  };
  
  workspace = import ./modules/workspace.nix { 
    inherit extendedPkgs gstreamerAndroid; 
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