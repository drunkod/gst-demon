{ pkgs }:

pkgs.stdenv.mkDerivation rec {
  pname = "gst-interpipe";
  version = "1.1.10";

  src = pkgs.fetchFromGitHub {
    owner = "RidgeRun";
    repo = "gst-interpipe";
    rev = "v${version}";
    hash = "sha256-Z7yeUxsTebKPynYzhtst2rlApoXzU1u/32ZqzBvQ6eY=";
  };

  nativeBuildInputs = with pkgs; [
    meson
    ninja
    pkg-config
  ];

  buildInputs = with pkgs; [
    gst_all_1.gstreamer
    gst_all_1.gst-plugins-base
    glib
  ];

  mesonFlags = [
    "-Denable-gtk-doc=false"
    "-Dtests=disabled"
  ];

  doCheck = false;

  postInstall = ''
    if ! [ -f "$out/lib/gstreamer-1.0/libgstinterpipe.so" ]; then
      echo "ERROR: Interpipe plugin not found at $out/lib/gstreamer-1.0/"
      exit 1
    fi
    echo "✅ Interpipe plugin installed at:"
    echo "   $out/lib/gstreamer-1.0/libgstinterpipe.so"
  '';

  meta = with pkgs.lib; {
    description = "GStreamer plug-in for interpipeline communication";
    homepage = "https://github.com/RidgeRun/gst-interpipe";
    license = licenses.lgpl21Plus;
    platforms = platforms.linux;
  };
}