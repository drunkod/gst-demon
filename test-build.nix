let
  # Fetch nixpkgs directly (no channels needed)
  nixpkgsSrc = builtins.fetchTarball {
    url = "https://github.com/NixOS/nixpkgs/archive/nixos-25.05.tar.gz";
    sha256 = "0000000000000000000000000000000000000000000000000000"; # Nix will fix
  };
  
  pkgs = import nixpkgsSrc {
    config = {
      allowUnfree = true;
      android_sdk.accept_license = true;
    };
  };
  
  # Test overlay loading
  overlaysList = import ./.idx/overlays/default.nix { inherit pkgs; };
  
in
{
  # Simple derivation to test
  test = pkgs.runCommand "overlay-test" {} ''
    echo "Overlays loaded: ${toString (builtins.length overlaysList)}"
    echo "Success!" > $out
  '';
}
