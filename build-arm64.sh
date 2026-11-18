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
  libboost-dev libboost-filesystem-dev libboost-system-dev libboost-serialization-dev libboost-test-dev \
  qtbase5-dev qttools5-dev qttools5-dev-tools libqt5svg5-dev qtwayland5 \
  libqt5serialport5-dev libqt5opengl5-dev libqwt-qt5-dev zsync file patchelf curl

# Build all upstream components in their documented dependency order.
git clone --depth=1 https://github.com/sigrokproject/sigrok-util.git "$WORK/sigrok-util"
export TGT="$PREFIX"
export INSTALL_DIR="$PREFIX"
sed -i 's|^PREFIX=\$HOME/sr$|PREFIX=$TGT|' \
  "$WORK/sigrok-util/cross-compile/linux/sigrok-cross-linux"
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
  cat > "$APPDIR/$bin.svg" <<'SVG'
<svg xmlns="http://www.w3.org/2000/svg" width="256" height="256" viewBox="0 0 256 256">
  <rect x="16" y="16" width="224" height="224" rx="32" fill="#183153"/>
  <path d="M32 132h48l22-56 38 104 25-64 18 16h41" fill="none" stroke="#63d9e8" stroke-linecap="round" stroke-linejoin="round" stroke-width="14"/>
</svg>
SVG
  cp "$APPDIR/$bin.svg" "$APPDIR/usr/share/icons/hicolor/256x256/apps/$bin.svg"
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
export PYTHONPATH="\$PYTHONHOME/lib/python$pyver/site-packages"
export SIGROK_FIRMWARE_PATH="\$HERE/usr/share/sigrok-firmware:\${SIGROK_FIRMWARE_PATH:-}"
export SIGROKDECODE_PATH="\$HERE/usr/share/libsigrokdecode/decoders:\${SIGROKDECODE_PATH:-}"
export LD_LIBRARY_PATH="\$HERE/usr/lib:\$HERE/usr/lib/aarch64-linux-gnu:\${LD_LIBRARY_PATH:-}"
exec "\$HERE/usr/bin/$bin" "\$@"
EOF
  chmod +x "$APPDIR/AppRun"
  rm -f "$WORK/$app"
  local -a deploy_args=(--appdir "$APPDIR" --executable "$APPDIR/usr/bin/$bin" --output appimage --custom-apprun "$APPDIR/AppRun")
  if [[ "$bin" == "pulseview" ]]; then
    deploy_args+=(--plugin qt)
    EXTRA_PLATFORM_PLUGINS='libqwayland-egl.so;libqwayland-generic.so' \
      OUTPUT="$WORK/$app" APPIMAGE_EXTRACT_AND_RUN=1 ARCH=aarch64 \
      "$TOOLS/linuxdeploy-aarch64.AppImage" "${deploy_args[@]}"
  else
    OUTPUT="$WORK/$app" APPIMAGE_EXTRACT_AND_RUN=1 ARCH=aarch64 \
      "$TOOLS/linuxdeploy-aarch64.AppImage" "${deploy_args[@]}"
  fi
  test -s "$WORK/$app"
  install -m 755 "$WORK/$app" "$OUT/$app"
  rm -f "$WORK/$app"
}

cd "$WORK"
make_appdir pulseview-NIGHTLY-aarch64.AppImage pulseview PulseView
make_appdir sigrok-cli-NIGHTLY-aarch64.AppImage sigrok-cli sigrok-cli
file "$OUT"/*.AppImage
sha256sum "$OUT"/*.AppImage > "$OUT/SHA256SUMS"

