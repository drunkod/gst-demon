{ pkgs }:

let
  helpScript = pkgs.writeShellScriptBin "dev-help" ''
        cat << 'EOF'
    ╔══════════════════════════════════════════════════════════════╗
    ║          Development Environment Quick Reference             ║
    ╚══════════════════════════════════════════════════════════════╝

    🚀 Quick Start:
      dev-help          - Show this help
      code-dev .        - Open VS Code
      chromium-dev      - Launch Chromium (dev profile)
      cargo run         - Run Rust project
      scrcpy -Sw -K     - Mirror Android device

    🌐 Web Development:
      chromium-dev      - Chromium with dev tools auto-open
      chromium-mobile   - Chromium with mobile emulation
      chromium-clean    - Clean all dev browser profiles
  
      Common URLs:
      • http://localhost:3000  - React/Next.js default
      • http://localhost:8000  - Python/Django default
      • http://localhost:8080  - Alternative port
      • http://10.0.2.2:8080   - Android emulator host

    📱 Android:
      adb devices       - List devices
      adb shell         - Device shell
      scrcpy            - Screen mirror

    🦀 Rust:
      cargo build       - Build project
      cargo test        - Run tests
      cargo watch       - Auto-rebuild

    🎬 GStreamer:
      gst-launch-1.0    - Test pipelines
      gst-inspect-1.0   - Inspect elements

    💡 Browser Tips:
      • Chromium dev profile is isolated from your main browser
      • DevTools auto-open with chromium-dev
      • F12 - Toggle DevTools
      • Ctrl+Shift+M - Toggle device emulation
      • Ctrl+Shift+I - Inspect element

    Current Environment:
      Rust: $(rustc --version 2>/dev/null | cut -d' ' -f2 || echo "not available")
      Android SDK: $([ -n "$ANDROID_SDK_ROOT" ] && echo "✓ configured" || echo "✗ not set")
      Devices: $(adb devices 2>/dev/null | tail -n +2 | grep -c device || echo "0") connected
      Dev servers: $(for port in 3000 8000 8080; do nc -z localhost $port 2>/dev/null && echo "localhost:$port ✓"; done | paste -sd " " - || echo "none running")

    EOF
  '';
in
{
  package = helpScript;
}
