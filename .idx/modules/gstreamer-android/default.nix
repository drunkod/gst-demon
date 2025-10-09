# .idx/modules/gstreamer-android/default.nix
{ pkgs, config }:
{
  # The GStreamer for Android source derivation
  source = import ./gstreamer-source.nix {
    inherit pkgs;
    inherit config;
  };
}