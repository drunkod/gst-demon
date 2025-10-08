# .idx/modules/scripts/default.nix
{ pkgs }:
let
  # Package the setup-android-env.sh script
  setup-android-env = pkgs.writeShellScriptBin "setup-android-env" ''
    exec ${pkgs.bash}/bin/bash ${./../../scripts/setup-android-env.sh} "$@"
  '';
in
{
  # List of script packages to be added to the environment
  packages = [
    setup-android-env
  ];
}