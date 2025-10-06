{ pkgs }:

pkgs.stdenv.mkDerivation rec {
  pname = "gstd";
  version = "0.15.2";

  src = pkgs.fetchFromGitHub {
    owner = "RidgeRun";
    repo = "gstd-1.x";
    rev = "v${version}";
    sha256 = "sha256-capHgSurUSaBIUbKlPHv5hsfBZ11UwtgyuXRjQJJxuY=";
  };

  nativeBuildInputs = with pkgs; [
    meson
    ninja
    pkg-config
    python3
    python3.pkgs.pip
  ];

  buildInputs = with pkgs; [
    gst_all_1.gstreamer
    gst_all_1.gst-plugins-base
    glib
    json-glib
    libsoup
    jansson
    libedit
    ncurses
    readline
    libdaemon
  ];

  mesonFlags = [
    "-Denable-gtk-doc=false"
    "-Denable-tests=disabled"
    "-Denable-examples=disabled"
    "-Denable-python=enabled"
    "-Denable-systemd=disabled"
    "-Denable-initd=disabled"
    "-Dwith-gstd-runstatedir=/tmp/gstd"
    "-Dwith-gstd-logstatedir=/tmp/gstd/logs"
  ];

  doCheck = false;

  postInstall = ''
    if [ ! -x "$out/bin/gstd" ]; then
      echo "ERROR: gstd binary not found"
      exit 1
    fi
    
    echo "✅ GStreamer Daemon installed successfully"
    echo "   Daemon: $out/bin/gstd"
    
    if [ -x "$out/bin/gst-client" ]; then
      echo "   Client: $out/bin/gst-client"
    fi
    
    if [ -d "$out/lib/python"* ]; then
      echo "   Python client installed"
    fi
  '';

  meta = with pkgs.lib; {
    description = "GStreamer Daemon - GStreamer framework for controlling audio and video streaming";
    homepage = "https://github.com/RidgeRun/gstd-1.x";
    license = licenses.lgpl21Plus;
    platforms = platforms.linux;
  };
}