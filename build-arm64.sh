#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK="${GITHUB_WORKSPACE:-$ROOT}/_arm64_build"
PREFIX="$WORK/sr"
APPDIR="$WORK/AppDir"
TOOLS="$WORK/tools"
OUT="${GITHUB_WORKSPACE:-$ROOT}/dist"
mkdir -p "$WORK" "$OUT" "$TOOLS"

sudo apt-get update
sudo apt-get install -y --no-install-recommends \
  build-essential git cmake pkg-config autoconf automake libtool sdcc \
  python3 python3-dev python3-setuptools python3-numpy python3-gi swig doxygen \
  libglib2.0-dev libglibmm-2.4-dev libzip-dev libserialport-dev libusb-1.0-0-dev \
  libftdi1-dev libhidapi-dev libbluetooth-dev libieee1284-3-dev \
  libboost-dev qtbase5-dev qttools5-dev qttools5-dev-tools libqt5svg5-dev \
  libqt5serialport5-dev libqt5opengl5-dev libqwt-qt5-dev zsync file patchelf

# Build all upstream components in their documented dependency order.
git clone --depth=1 https://github.com/sigrokproject/sigrok-util.git "$WORK/sigrok-util"
export TGT="$PREFIX"
export INSTALL_DIR="$PREFIX"
export PATH="$PREFIX/bin:$PATH"
export PKG_CONFIG_PATH="$PREFIX/lib/pkgconfig:$PREFIX/lib/aarch64-linux-gnu/pkgconfig"
export LD_LIBRARY_PATH="$PREFIX/lib:$PREFIX/lib/aarch64-linux-gnu:${LD_LIBRARY_PATH:-}"
export PARALLEL="-j$(nproc)"
cd "$WORK"
bash "$WORK/sigrok-util/cross-compile/linux/sigrok-cross-linux"

test -x "$PREFIX/bin/pulseview"
test -x "$PREFIX/bin/sigrok-cli"
test -d "$PREFIX/share/libsigrokdecode/decoders"

download_tool() {
  local name="$1" url="$2"
  curl --fail --location --retry 3 "$url" --output "$TOOLS/$name"
  chmod +x "$TOOLS/$name"
}
download_tool linuxdeploy-aarch64.AppImage \
  https://github.com/linuxdeploy/linuxdeploy/releases/download/continuous/linuxdeploy-aarch64.AppImage
download_tool linuxdeploy-plugin-qt-aarch64.AppImage \
  https://github.com/linuxdeploy/linuxdeploy-plugin-qt/releases/download/continuous/linuxdeploy-plugin-qt-aarch64.AppImage

make_appdir() {
  local app="$1" bin="$2" title="$3"
  rm -rf "$APPDIR"
  mkdir -p "$APPDIR/usr"
  cp -a "$PREFIX/." "$APPDIR/usr/"
  mkdir -p "$APPDIR/usr/share/applications" "$APPDIR/usr/share/icons/hicolor/256x256/apps"
  cat > "$APPDIR/$bin.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=$title
Exec=$bin
Icon=$bin
Categories=Development;Electronics;
Terminal=$( [[ "$bin" == "sigrok-cli" ]] && echo true || echo false )
EOF
  cp "$APPDIR/$bin.desktop" "$APPDIR/usr/share/applications/"
  # Keep Python protocol decoders and firmware discoverable inside the image.
  local pyver
  pyver="$(python3 -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')"
  mkdir -p "$APPDIR/usr/share/pyshared/lib"
  cp -a "/usr/lib/python$pyver" "$APPDIR/usr/share/pyshared/lib/"
  mkdir -p "$APPDIR/usr/share/pyshared/lib/python$pyver/site-packages"
  cp -a /usr/lib/python3/dist-packages/. "$APPDIR/usr/share/pyshared/lib/python$pyver/site-packages/" 2>/dev/null || true
  cat > "$APPDIR/AppRun" <<EOF
#!/bin/sh
HERE="\$(dirname "\$(readlink -f "\$0")")"
export PYTHONHOME="\$HERE/usr/share/pyshared"
export PYTHONPATH="\$PYTHONHOME/lib/python$pyver/site-packages:\${PYTHONPATH:-}"
export SIGROK_FIRMWARE_PATH="\$HERE/usr/share/sigrok-firmware:\${SIGROK_FIRMWARE_PATH:-}"
export SIGROKDECODE_PATH="\$HERE/usr/share/libsigrokdecode/decoders:\${SIGROKDECODE_PATH:-}"
export LD_LIBRARY_PATH="\$HERE/usr/lib:\$HERE/usr/lib/aarch64-linux-gnu:\${LD_LIBRARY_PATH:-}"
exec "\$HERE/usr/bin/$bin" "\$@"
EOF
  chmod +x "$APPDIR/AppRun"
  APPIMAGE_EXTRACT_AND_RUN=1 ARCH=aarch64 "$TOOLS/linuxdeploy-aarch64.AppImage" \
    --appdir "$APPDIR" --executable "$APPDIR/usr/bin/$bin" --output appimage \
    $( [[ "$bin" == "pulseview" ]] && printf '%s' '--plugin qt' )
  local generated
  generated="$(find "$WORK" -maxdepth 2 -type f -name '*.AppImage' -printf '%T@ %p\n' | sort -nr | head -1 | cut -d' ' -f2-)"
  test -n "$generated"
  install -m 755 "$generated" "$OUT/$app"
  rm -f "$generated"
}

cd "$WORK"
make_appdir pulseview-NIGHTLY-aarch64.AppImage pulseview PulseView
make_appdir sigrok-cli-NIGHTLY-aarch64.AppImage sigrok-cli sigrok-cli
file "$OUT"/*.AppImage
sha256sum "$OUT"/*.AppImage > "$OUT/SHA256SUMS"
