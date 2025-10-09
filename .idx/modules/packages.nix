# .idx/modules/packages.nix
{ extendedPkgs }:

with extendedPkgs; [
  # Essential CLI tools only
  git
  curl
  jq
  
  # Nix tools
  nix
]