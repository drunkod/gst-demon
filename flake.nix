{
  description = "A Nix-based development environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
  };

  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";
      
      # Configure pkgs once with all necessary options
      configuredPkgs = import nixpkgs {
        inherit system;
        config = {
          allowUnfree = true;
          android_sdk.accept_license = true;
        };
      };

      # Import the existing dev.nix configuration, passing the configuredPkgs
      devConfig = import ./.idx/dev.nix {
        pkgs = configuredPkgs; # Pass the fully configured pkgs
        lib = configuredPkgs.lib;
        config = configuredPkgs.config; # Also pass the config for modules that expect it
      };

      # Extract the packages and environment setup from the dev.nix output
      # This is based on the structure of how .idx/dev.nix is built
      firstImport = builtins.elemAt devConfig.imports 0;
      envPackages = firstImport.packages;
      envSetup = firstImport.env;

    in
    {
      devShells.${system}.default = configuredPkgs.mkShell {
        buildInputs = envPackages;
        inherit (envSetup) shellHook;
      };

      # Add a simple check to test the environment
      checks.${system}.default = configuredPkgs.runCommand "hello-check" {} ''
        ${configuredPkgs.hello}/bin/hello -n > $out
      '';
    };
}
