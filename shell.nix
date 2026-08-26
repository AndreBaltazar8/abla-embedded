{ pkgs ? import <nixpkgs> {} }:

pkgs.mkShell {
  packages = with pkgs; [
    bison
    ccache
    cmake
    dfu-util
    flex
    gperf
    libusb1
    ninja
    platformio
  ];

  shellHook = ''
    export PLATFORMIO_CORE_DIR="$PWD/.platformio"
    echo "Abla Embedded development shell"
  '';
}
