{
  description = "Development environment for e2ee-notes";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { nixpkgs, ... }:
    let
      supportedSystems = [ "x86_64-linux" "aarch64-linux" ];
      forEachSystem = nixpkgs.lib.genAttrs supportedSystems;
    in {
      devShells = forEachSystem (system:
        let
          pkgs = import nixpkgs {
            inherit system;
            config = {
              allowUnfree = true;
              android_sdk.accept_license = true;
            };
          };
          androidSdk = (pkgs.androidenv.composeAndroidPackages {
            platformVersions = [ "35" "36" ];
            buildToolsVersions = [ "36.0.0" ];
            cmakeVersions = [ "3.22.1" ];
            includeNDK = true;
            ndkVersions = [ "28.2.13676358" ];
          }).androidsdk;
        in {
          default = pkgs.mkShell {
            packages = [
              pkgs.android-tools
              androidSdk
              pkgs.flutter
              pkgs.jdk17
            ];

            ANDROID_HOME = "${androidSdk}/libexec/android-sdk";
            ANDROID_SDK_ROOT = "${androidSdk}/libexec/android-sdk";
            JAVA_HOME = "${pkgs.jdk17}";
          };
        });
    };
}
