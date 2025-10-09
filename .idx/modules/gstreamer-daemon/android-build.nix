{ pkgs, extendedPkgs }:

let
  # Скрипт сборки как пакет
  buildScript = pkgs.writeShellScriptBin "build-gstd-android" ''
    exec ${pkgs.bash}/bin/bash ${./../../scripts/build-gstd-android.sh} "$@"
  '';

in
{
  # Пакет для добавления в окружение
  package = buildScript;

  # Shell hook для информации
  shellHook = ''
    if [ -z "$_GSTD_ANDROID_HELP_SHOWN" ]; then
      export _GSTD_ANDROID_HELP_SHOWN=1
      echo ""
      echo "📱 GStreamer Daemon Android build available!"
      echo ""
      echo "Commands:"
      echo "  • build-gstd-android        - Build gstd for Android"
      echo "  • build-gstd-android clean  - Clean build artifacts"
      echo ""
      echo "Environment variables:"
      echo "  • ARCHITECTURES - Target architectures (default: arm64-v8a)"
      echo "    Example: ARCHITECTURES=\"arm64-v8a armeabi-v7a\" build-gstd-android"
      echo ""
    fi
  '';
}