{
  description = "A Nix-based development environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
  };

  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";
      
      pkgs = import nixpkgs {
        inherit system;
        config = {
          allowUnfree = true;
          android_sdk.accept_license = true;
        };
      };

      devConfig = import ./.idx/dev.nix {
        inherit pkgs;
        lib = pkgs.lib;
        config = pkgs.config;
      };

      firstImport = builtins.elemAt devConfig.imports 0;
      envPackages = firstImport.packages;
      envSetup = firstImport.env;

    in
    {
      devShells.${system}.default = pkgs.mkShell {
        buildInputs = envPackages;
        shellHook = ''
          export NIXPKGS_ACCEPT_ANDROID_SDK_LICENSE=1
          ${envSetup.shellHook}
        '';
      };

      checks.${system}.default = pkgs.runCommand "hello-check" {} ''
        ${pkgs.hello}/bin/hello -n > $out
      '';
    };
}
