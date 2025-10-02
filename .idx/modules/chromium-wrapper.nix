{ pkgs }:

let
  chromiumWrapper = pkgs.writeShellScriptBin "chromium-dev" ''
    # Set up development environment for Chromium
    export NIXOS_OZONE_WL=1  # Enable Wayland support if available
    
    # Create a dedicated profile directory for development
    DEV_PROFILE_DIR="''${CHROMIUM_DEV_PROFILE:-$HOME/.chromium-dev}"
    mkdir -p "$DEV_PROFILE_DIR"
    
    # Create initial preferences if needed
    PREFS_FILE="$DEV_PROFILE_DIR/Default/Preferences"
    if [ ! -f "$PREFS_FILE" ]; then
      mkdir -p "$DEV_PROFILE_DIR/Default"
      cat > "$PREFS_FILE" <<'ENDPREFS'
    {
      "devtools": {
        "preferences": {
          "currentDockState": "\"right\"",
          "Inspector.drawerSplitViewState": "{\"horizontal\":{\"size\":0,\"showMode\":\"OnlyMain\"}}",
          "InspectorView.splitViewState": "{\"vertical\":{\"size\":400}}",
          "console.showSettingsToolbar": "true",
          "network.requestHeaders": "[{\"name\":\"User-Agent\",\"value\":\"\"},{\"name\":\"Accept\",\"value\":\"*/*\"},{\"name\":\"Accept-Language\",\"value\":\"\"}]"
        }
      },
      "webkit": {
        "webprefs": {
          "javascript_enabled": true,
          "loads_images_automatically": true,
          "plugins_enabled": true
        }
      }
    }
    ENDPREFS
    fi
    
    # Create bookmarks for development resources
    BOOKMARKS_FILE="$DEV_PROFILE_DIR/Default/Bookmarks"
    if [ ! -f "$BOOKMARKS_FILE" ]; then
      cat > "$BOOKMARKS_FILE" <<'ENDBOOKMARKS'
    {
      "version": 1,
      "roots": {
        "bookmark_bar": {
          "name": "Bookmarks Bar",
          "children": [
            {
              "name": "Dev Tools",
              "type": "folder",
              "children": [
                {"name": "localhost:3000", "type": "url", "url": "http://localhost:3000"},
                {"name": "localhost:8000", "type": "url", "url": "http://localhost:8000"},
                {"name": "localhost:8080", "type": "url", "url": "http://localhost:8080"},
                {"name": "Android Emulator", "type": "url", "url": "http://10.0.2.2:8080"}
              ]
            },
            {
              "name": "Documentation",
              "type": "folder",
              "children": [
                {"name": "Android Developers", "type": "url", "url": "https://developer.android.com"},
                {"name": "Rust Docs", "type": "url", "url": "https://doc.rust-lang.org"},
                {"name": "MDN Web Docs", "type": "url", "url": "https://developer.mozilla.org"},
                {"name": "Nix Manual", "type": "url", "url": "https://nixos.org/manual/nix/stable"}
              ]
            }
          ]
        }
      }
    }
    ENDBOOKMARKS
    fi
    
    # Default URLs to open if none specified
    DEFAULT_URLS=""
    if [ $# -eq 0 ]; then
      # Check if common development servers are running
      if nc -z localhost 3000 2>/dev/null; then
        DEFAULT_URLS="http://localhost:3000"
      elif nc -z localhost 8000 2>/dev/null; then
        DEFAULT_URLS="http://localhost:8000"
      elif nc -z localhost 8080 2>/dev/null; then
        DEFAULT_URLS="http://localhost:8080"
      fi
    fi
    
    # Launch Chromium with development-friendly flags
    exec ${pkgs.chromium}/bin/chromium \
      --user-data-dir="$DEV_PROFILE_DIR" \
      --disable-background-timer-throttling \
      --disable-backgrounding-occluded-windows \
      --disable-renderer-backgrounding \
      --disable-features=TranslateUI \
      --disable-ipc-flooding-protection \
      --enable-features=NetworkService,NetworkServiceInProcess \
      --force-color-profile=srgb \
      --metrics-recording-only \
      --no-default-browser-check \
      --no-first-run \
      --password-store=basic \
      --use-mock-keychain \
      --enable-logging=stderr \
      --v=0 \
      --auto-open-devtools-for-tabs \
      $DEFAULT_URLS \
      "$@"
  '';

  # Additional helper script for mobile testing
  chromiumMobile = pkgs.writeShellScriptBin "chromium-mobile" ''
    # Launch Chromium with mobile device emulation
    DEV_PROFILE_DIR="''${CHROMIUM_DEV_PROFILE:-$HOME/.chromium-dev-mobile}"
    mkdir -p "$DEV_PROFILE_DIR"
    
    echo "Launching Chromium in mobile device emulation mode..."
    echo "Use DevTools (F12) > Device Toggle (Ctrl+Shift+M) to switch devices"
    
    exec ${pkgs.chromium}/bin/chromium \
      --user-data-dir="$DEV_PROFILE_DIR" \
      --window-size=412,915 \
      --user-agent="Mozilla/5.0 (Linux; Android 11; Pixel 5) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/90.0.4430.91 Mobile Safari/537.36" \
      --use-mobile-user-agent \
      --enable-viewport \
      --enable-features=OverlayScrollbar \
      --force-device-scale-factor=2.625 \
      --auto-open-devtools-for-tabs \
      "$@"
  '';

  # Script to clean development profiles
  chromiumClean = pkgs.writeShellScriptBin "chromium-clean" ''
    echo "Cleaning Chromium development profiles..."
    
    # Clean desktop profile
    if [ -d "$HOME/.chromium-dev" ]; then
      echo "Removing desktop profile..."
      rm -rf "$HOME/.chromium-dev"
    fi
    
    # Clean mobile profile
    if [ -d "$HOME/.chromium-dev-mobile" ]; then
      echo "Removing mobile profile..."
      rm -rf "$HOME/.chromium-dev-mobile"
    fi
    
    echo "✅ Chromium development profiles cleaned"
  '';
in
{
  packages = [ chromiumWrapper chromiumMobile chromiumClean ];

  # Export individual packages for flexibility
  chromiumDev = chromiumWrapper;
  chromiumMobile = chromiumMobile;
  chromiumClean = chromiumClean;
}
