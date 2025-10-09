# .idx/modules/previews.nix
{ extendedPkgs }:

{
  idx.previews = {
    enable = true;
    previews = {
      android = {
        command = [ "./gradlew" ":app:installDebug" ];
        cwd = ".";
        manager = "android";
        activity = "co.realfit.agdkeframe/.MainActivity";
        env = {
          ANDROID_HOME = "${extendedPkgs.androidSdk}/libexec/android-sdk";
          JAVA_HOME = "${extendedPkgs.jdk17}";
          NIXPKGS_ACCEPT_ANDROID_SDK_LICENSE = "1";
        };
      };
    };
  };
}