{
  description = "A Nix-based development environment";

  inputs = {
    nixpkgs.url = "github.NixOS/nixpkgs/nixos-25.05";
  };

  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";
      
      # Allow unfree packages and accept Android SDK license
      pkgs = import nixpkgs {
        inherit system;
        config = {
          allowUnfree = true;
          android_sdk.accept_license = true;
        };
      };

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

      # Add a simple check to test the environment
      checks.${system}.default = pkgs.runCommand "hello-check" {} ''
        ${pkgs.hello}/bin/hello -n > $out
      '';
    };
}
