{ pkgs, extendedPkgs ? pkgs }:

let
  # Import sub-modules
  gstdPackage = import ./gstd.nix { inherit pkgs; };
  interpipePackage = import ./interpipe.nix { inherit pkgs; };
  gstdService = import ./service.nix {
    inherit pkgs;
    gstd = gstdPackage;
    interpipe = interpipePackage;  # ✅ Pass interpipe to service
  };
  
  # Build the GStreamer plugin path
  # ✅ Explicitly use .out to get plugins, not binaries
  gstPluginPath = pkgs.lib.strings.concatStringsSep ":" [
    "${interpipePackage}/lib/gstreamer-1.0"
    "${pkgs.gst_all_1.gstreamer.out}/lib/gstreamer-1.0"  
    "${pkgs.gst_all_1.gst-plugins-base}/lib/gstreamer-1.0"
    "${pkgs.gst_all_1.gst-plugins-good}/lib/gstreamer-1.0"
    "${pkgs.gst_all_1.gst-plugins-bad}/lib/gstreamer-1.0"
    "${pkgs.gst_all_1.gst-plugins-ugly}/lib/gstreamer-1.0"
    "${pkgs.gst_all_1.gst-libav}/lib/gstreamer-1.0"
    "${pkgs.gst_all_1.gst-vaapi}/lib/gstreamer-1.0"
  ];

in
{
  packages = [
    gstdPackage
    interpipePackage
    gstdService.wrapper
    gstdService.client
  ] ++ (with pkgs; [
    # GStreamer packages
    gst_all_1.gstreamer
    gst_all_1.gstreamer.dev
    gst_all_1.gst-plugins-base
    gst_all_1.gst-plugins-base.dev
    gst_all_1.gst-plugins-good
    gst_all_1.gst-plugins-bad
    gst_all_1.gst-plugins-ugly
    gst_all_1.gst-libav
    gst_all_1.gst-vaapi

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

  # Export environment variables
  env = {
    GST_PLUGIN_PATH = gstPluginPath;
    GST_PLUGIN_PATH_1_0 = gstPluginPath;
    GST_PLUGIN_SYSTEM_PATH_1_0 = gstPluginPath;
  };

  # Export PATH additions
  pathAdditions = [
    "${gstdPackage}/bin"
    "${gstdService.wrapper}/bin"
  ];

  shellHook = ''
    # Create recording directory
    mkdir -p $PWD/recording

    # Show available commands (only once)
    if [ -z "$_GSTD_HELP_SHOWN" ]; then
      export _GSTD_HELP_SHOWN=1
      echo ""
      echo "🎬 GStreamer Daemon environment ready!"
      echo ""
      echo "Commands:"
      echo "  • gstd-start    - Start GStreamer Daemon"
      echo "  • gstd-stop     - Stop GStreamer Daemon"
      echo "  • gstd-status   - Check daemon status"
      echo "  • gst-client    - GStreamer Daemon client"
      echo ""
      echo "Verify plugins:"
      echo "  • gst-inspect-1.0 videotestsrc"
      echo "  • gst-inspect-1.0 fakesink"
      echo "  • gst-inspect-1.0 interpipe"
      echo ""
    fi
  '';
}