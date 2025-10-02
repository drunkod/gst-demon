{ pkgs, extendedPkgs }:

let
  # Import sub-modules
  gstdPackage = import ./gstd.nix { inherit pkgs; };
  interpipePackage = import ./interpipe.nix { inherit pkgs; };
  gstdService = import ./service.nix {
    inherit pkgs;
    gstd = gstdPackage;
  };

in
{
  packages = [
    gstdPackage
    interpipePackage
    gstdService.wrapper
    gstdService.client
  ] ++ (with pkgs; [
    # GStreamer packages
    gstreamer
    gst-plugins-base
    gst-plugins-good
    gst-plugins-bad
    gst-plugins-ugly
    gst-libav
    gst-vaapi

    # Development tools
    pkg-config
    automake
    autoconf
    libtool
    gtk-doc

    # Runtime dependencies
    glib
    json-glib
    libsoup
    jansson
    libedit
    ncurses
    readline
    libdaemon

    # Utilities
    curl
    iputils
    dumb-init
  ]);

  shellHook = ''
    # Create recording directory
    mkdir -p $PWD/recording

    # Export GStreamer plugin paths
    export GST_PLUGIN_PATH="${interpipePackage}/lib/gstreamer-1.0:$GST_PLUGIN_PATH"

    # Add gstd to PATH
    export PATH="${gstdPackage}/bin:${gstdService.wrapper}/bin:$PATH"

    # Show available commands
    if [ -z "$_GSTD_HELP_SHOWN" ]; then
      export _GSTD_HELP_SHOWN=1
      echo "🎬 GStreamer Daemon environment ready!"
      echo "Commands:"
      echo "  • gstd-start    - Start GStreamer Daemon"
      echo "  • gstd-stop     - Stop GStreamer Daemon"
      echo "  • gstd-status   - Check daemon status"
      echo "  • gst-client    - GStreamer Daemon client"
      echo "  • gst-inspect-1.0 interpipe - Verify interpipe plugin"
    fi
  '';
}