# .idx/modules/packages.nix
{ extendedPkgs, gstreamerDaemon }:

(with extendedPkgs; [
  # Rust Toolchain
  rustup
  cargo-watch
  cargo-edit
  cargo-outdated
  cargo-ndk
  cargo-apk

  # Android SDK/NDK
  androidSdk

  # Java/JDK
  jdk17
  gradle

  # Core Build Tools
  gcc
  pkg-config
  gnumake
  cmake
  perl

  # System Libraries
  glib
  glib.dev
  openssl
  openssl.dev
  libffi

  # GStreamer & Plugins
  gst_all_1.gstreamer
  gst_all_1.gstreamer.dev
  gst_all_1.gst-plugins-base
  gst_all_1.gst-plugins-base.dev
  gst_all_1.gst-plugins-good
  gst_all_1.gst-plugins-bad
  gst_all_1.gst-plugins-ugly
  gst_all_1.gst-libav
  gst_all_1.gst-devtools
  gst_all_1.gst-editing-services

  # Multimedia Libraries
  libva
  libvpx
  x264
  x265

  # GUI Dependencies (for eframe)
  libxkbcommon
  libGL
  wayland
  xorg.libXcursor
  xorg.libXrandr
  xorg.libXi
  xorg.libX11

  # Android Development Tools
  adb-sync
  scrcpy
]) ++ gstreamerDaemon.packages