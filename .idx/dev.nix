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

  # Import GStreamer Daemon module
  gstreamerDaemon = import ./modules/gstreamer-daemon { inherit pkgs extendedPkgs; };

  # Import config
  config = import ./modules/config.nix;

  # Import GStreamer for Android module
  gstreamerAndroid = import ./modules/gstreamer-android { inherit pkgs config; };

  # Import scripts module
  scripts = import ./modules/scripts { inherit pkgs; };

  # Import modules
  package_list = import ./modules/packages.nix { inherit extendedPkgs gstreamerDaemon scripts; };
  environment = import ./modules/environment.nix { inherit lib extendedPkgs gstreamerDaemon; };
  previews = import ./modules/previews.nix { inherit extendedPkgs; };
  workspace = import ./modules/workspace.nix { inherit extendedPkgs; };
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

  # Expose packages for nix-build
  packages = {
    inherit gstreamerAndroid;
  };
}