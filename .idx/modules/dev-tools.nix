{ pkgs }:

let
  vscodeWrapper = import ./vscode-wrapper.nix { inherit pkgs; };
  helpCommand = import ./help-command.nix { inherit pkgs; };
  chromiumWrapper = import ./chromium-wrapper.nix { inherit pkgs; };
in
{
  packages = with pkgs; [
    # Shell and completions
    bashInteractive
    bash-completion

    # Build tools
    gcc
    pkg-config
    cmake

    # Version control and IDE
    git
    vscodeWrapper.package # VS Code wrapper with code-dev command
    helpCommand.package # Help command

    # Browsers for development
    chromiumWrapper.chromiumDev # Chromium with dev profile
    chromiumWrapper.chromiumMobile # Chromium mobile emulation
    chromiumWrapper.chromiumClean # Clean chromium profiles

    # Nix tools for VS Code extensions
    # nix
    nil # Nix language server
    nixpkgs-fmt # Nix formatter

    # Language support
    python3
    nodejs
    jq

    # System libraries
    glib
    glib.dev
    openssl
    openssl.dev

    # Development tools
    gdb
    valgrind
    lldb

    # Android tools
    scrcpy # Android screen mirroring

    # Rust development tools
    cargo-watch # Auto-rebuild on file changes

    # Network tools for development
    netcat # For checking if ports are open

    xdg-utils # Important: include xdg-utils for open browser by default
  ];

  shellHook = ''
    # Source bash completion if available
    if [ -f ${pkgs.bash-completion}/etc/profile.d/bash_completion.sh ]; then
      source ${pkgs.bash-completion}/etc/profile.d/bash_completion.sh
    fi

    export PKG_CONFIG_PATH="${pkgs.glib.dev}/lib/pkgconfig:${pkgs.openssl.dev}/lib/pkgconfig:$PKG_CONFIG_PATH"

    # Ensure Nix tools are available for VS Code
    # export PATH="${pkgs.nix}/bin:$PATH"

    # Set VS Code workspace directory
    export VSCODE_WORKSPACE_DIR="$PWD"
    
    # Set Chromium development profile directory
    export CHROMIUM_DEV_PROFILE="$HOME/.chromium-dev"

    export BROWSER="${chromiumWrapper.chromiumDev}/bin/chromium-dev"
    export DEFAULT_BROWSER="${chromiumWrapper.chromiumDev}/bin/chromium-dev"
    
    # Ensure xdg-utils can find chromium-dev
    export PATH="${chromiumWrapper.chromiumDev}/bin:${pkgs.xdg-utils}/bin:$PATH"    

    # Show quick help on first entry
    if [ -z "$_DEV_HELP_SHOWN" ]; then
      export _DEV_HELP_SHOWN=1
      echo "💡 Type 'dev-help' for command reference"
      echo "🌐 Type 'chromium-dev' to launch Chromium with dev tools"
    fi
  '';
}
