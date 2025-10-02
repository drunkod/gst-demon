{ pkgs }:

pkgs.stdenv.mkDerivation rec {
  pname = "gstd";
  version = "0.15.0";

  src = pkgs.fetchurl {
    url = "https://github.com/RidgeRun/gstd-1.x/archive/v${version}.tar.gz";
    sha256 = "f4a83765d2cf2948c38abc5107ab07d49a01b4101047f188fed7204f1d4e49c7";
  };

  nativeBuildInputs = with pkgs; [
    autoreconfHook
    pkg-config
    gtk-doc
    docbook-xsl-nons
    docbook_xml_dtd_43
    python3
  ];

  buildInputs = with pkgs; [
    gstreamer
    gst-plugins-base
    glib
    json-glib
    libsoup
    jansson
    libedit
    ncurses
    readline
    libdaemon
  ];

  configureFlags = [
    "--enable-gtk-doc=no"  # Skip gtk-doc to speed up build
    "--with-gstd-runstatedir=/tmp/gstd"
    "--with-gstd-logstatedir=/tmp/gstd/logs"
  ];

  preConfigure = ''
    # Fix paths for NixOS
    substituteInPlace configure.ac \
      --replace "/var/run" "/tmp" \
      --replace "/var/log" "/tmp/logs"
  '';

  postInstall = ''
    # Create wrapper scripts
    mkdir -p $out/bin

    # Create Python client wrapper
    cat > $out/bin/gst-client << EOF
    #!${pkgs.python3}/bin/python3
    import sys
    sys.path.insert(0, '$out/${pkgs.python3.sitePackages}')
    from pygstc import gstc
    # Add client implementation here
    EOF
    chmod +x $out/bin/gst-client
  '';

  meta = with pkgs.lib; {
    description = "GStreamer Daemon - GStreamer framework for controlling audio and video streaming";
    homepage = "https://github.com/RidgeRun/gstd-1.x";
    license = licenses.lgpl21Plus;
    platforms = platforms.linux;
  };
}