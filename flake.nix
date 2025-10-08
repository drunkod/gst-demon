{
  description = "A Nix-based development environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-23.11";
  };

  outputs = { self, nixpkgs }:
    let
      system = "x88_64-linux";
      pkgs = import nixpkgs { inherit system; };

      # Import the existing dev.nix configuration
      devConfig = import ./.idx/dev.nix {
        inherit pkgs;
        lib = pkgs.lib;
      };

      # Extract the packages and environment setup from the dev.nix output
      # This is based on the structure of how .idx/dev.nix is built
      firstImport = builtins.elemAt devConfig.imports 0;
      envPackages = firstImport.packages;
      envSetup = firstImport.env;

    in
    {
      devShells.${system}.default = pkgs.mkShell {
        buildInputs = envPackages;
        inherit (envSetup) shellHook;
      };
    };
}
