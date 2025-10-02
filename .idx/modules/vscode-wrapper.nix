{ pkgs }:

let
  vscodeWrapper = pkgs.writeShellScriptBin "code-dev" ''
    # Set environment to skip shell environment checks
    export VSCODE_SKIP_SHELL_ENV=1

    # Ensure VS Code has access to Nix tools
    # export PATH="${pkgs.nix}/bin:$PATH"

    # Pass through browser settings to VS Code
    export BROWSER="''${BROWSER:-chromium-dev}"
    export DEFAULT_BROWSER="''${DEFAULT_BROWSER:-chromium-dev}"
    export PATH="${pkgs.lib.makeBinPath [ pkgs.xdg-utils pkgs.chromium ]}:$PATH"
    # Create VS Code settings if needed
    ws_dir="''${VSCODE_WORKSPACE_DIR:-$PWD}"
    cfg_dir="$ws_dir/.vscode"
    settings="$cfg_dir/settings.json"

    mkdir -p "$cfg_dir"

    # Create settings only if missing
    if [ ! -f "$settings" ]; then
      cat > "$settings" <<'ENDJSON'
    {
      "terminal.integrated.defaultProfile.linux": "bash",
      "terminal.integrated.profiles.linux": {
        "bash": {
          "path": "bash",
          "args": ["-l"]
        }
      },
        # "terminal.integrated.env.linux": {
        #   "BROWSER": "chromium-dev",
        #   "DEFAULT_BROWSER": "chromium-dev"
        # },
        # "workbench.externalBrowser": "chromium-dev",
      "nix.enableLanguageServer": true,
      "nix.serverPath": "${pkgs.nil}/bin/nil"
    }
    ENDJSON
    fi

    # Launch VS Code with proper environment
    exec ${pkgs.vscode}/bin/code --no-sandbox "$@"
  '';
in
{
  package = vscodeWrapper;
}
