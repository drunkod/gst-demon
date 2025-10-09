# .idx/dev.nix
# Minimal configuration - loads overlays without building packages
{ pkgs, lib, ... }:

let
  # ═══════════════════════════════════════════════════════════════════
  # Configuration upd
  # ═══════════════════════════════════════════════════════════════════
  config = import ./modules/config.nix;

  # ═══════════════════════════════════════════════════════════════════
  # Apply overlays
  # ═══════════════════════════════════════════════════════════════════
  overlays = import ./overlays/default.nix;

  # Apply overlays to a pkgs instance with Android SDK license accepted
  extendedPkgs = (pkgs.extend (self: super: {
    # Override nixpkgs config to accept Android SDK license
    config = (super.config or {}) // {
      android_sdk.accept_license = true;
      allowUnfree = true;
    };
  })).extend (
    self: super:
      builtins.foldl' (acc: overlay: acc // overlay self super) {} overlays
  );

  # ═══════════════════════════════════════════════════════════════════
  # Import modules
  # ═══════════════════════════════════════════════════════════════════
  packages = import ./modules/packages.nix {
    inherit extendedPkgs;
  };

  environment = import ./modules/environment.nix {
    inherit extendedPkgs config;
  };

in
{
  # ═══════════════════════════════════════════════════════════════════
  # IDX Configuration
  # ═══════════════════════════════════════════════════════════════════
  imports = [
    {
      channel = "stable-25.05";
      packages = packages;
      env = environment;
    }
  ];

  # ═══════════════════════════════════════════════════════════════════
  # Extensions
  # ═══════════════════════════════════════════════════════════════════
  idx.extensions = [
    "rust-lang.rust-analyzer"
    "vadimcn.vscode-lldb"
  ];
}
