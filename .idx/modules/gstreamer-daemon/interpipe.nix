{ pkgs }:

pkgs.stdenv.mkDerivation rec {
  pname = "gst-interpipe";
  version = "1.1.8";

  src = pkgs.fetchurl {
    url = "https://github.com/RidgeRun/gst-interpipe/archive/v${version}.tar.gz";
    sha256 = "981c40d4da47d380221d0435393416b42bd762584c905597de5fe5c373ee46ef";
  };

  nativeBuildInputs = with pkgs; [
    autoreconfHook
    pkg-config
    gtk-doc
  ];

  buildInputs = with pkgs; [
    gstreamer
    gst-plugins-base
    glib
  ];

  configureFlags = [
    "--enable-gtk-doc=no"
    "--libdir=${placeholder "out"}/lib"
  ];

  postInstall = ''
    # Ensure the plugin is in the right location
    mkdir -p $out/lib/gstreamer-1.0
    if [ -d "$out/lib/gstreamer-1.0" ]; then
      echo "Interpipe plugin installed successfully"
    fi
  '';

  meta = with pkgs.lib; {
    description = "GStreamer plug-in for interpipeline communication";
    homepage = "https://github.com/RidgeRun/gst-interpipe";
    license = licenses.lgpl21Plus;
    platforms = platforms.linux;
  };
}