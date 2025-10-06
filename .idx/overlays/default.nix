# .idx/overlays/default.nix
{ pkgs }:

[
    (import ./android.nix { inherit pkgs; })
  # Add more overlays here as needed
  # (import ./rust.nix { inherit pkgs; })
  # (import ./gstreamer.nix { inherit pkgs; })
]