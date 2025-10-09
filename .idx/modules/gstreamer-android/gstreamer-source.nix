# GStreamer source download - cached independently
{ pkgs, config }:

pkgs.fetchurl {
  name = "gstreamer-android-${config.gstreamer.version}";
  url = "${config.gstreamer.url}/gstreamer-1.0-android-universal-${config.gstreamer.version}.tar.xz";
  sha256 = config.gstreamer.sha256;

  # Add metadata
  meta = {
    description = "GStreamer ${config.gstreamer.version} for Android";
    homepage = "https://gstreamer.freedesktop.org";
  };
}
