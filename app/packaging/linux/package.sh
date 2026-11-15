#!/usr/bin/env bash
# Packages the Linux build for (almost) every distribution, from app/:
#   packaging/linux/package.sh 4.0.1
# Needs `flutter build linux --release` first. Writes build/dist/:
#   Sidekick-V-linux-ARCH.tar.gz   any distribution: unpack, run ./sidekick
#   Sidekick-V-linux-ARCH.AppImage any distribution: chmod +x, run
#   Sidekick-V-linux-ARCH.deb      Debian, Ubuntu, Mint, Pop!_OS, elementary…
#   Sidekick-V-linux-ARCH.rpm      Fedora, openSUSE, RHEL, Rocky, Alma…
#   PKGBUILD                       Arch, Manjaro, EndeavourOS (makepkg -si)
# ARCH is x64 or arm64, from the machine it runs on.
set -euo pipefail

V="$1"
case "$(uname -m)" in
  x86_64) ARCH=x64 DEB=amd64 RPM=x86_64 AI=x86_64 BUNDLE=build/linux/x64/release/bundle ;;
  aarch64 | arm64) ARCH=arm64 DEB=arm64 RPM=aarch64 AI=aarch64 BUNDLE=build/linux/arm64/release/bundle ;;
  *) echo "Unsupported machine: $(uname -m)" >&2; exit 1 ;;
esac
HERE=packaging/linux
NAME="Sidekick-$V-linux-$ARCH"
OUT=build/dist
mkdir -p "$OUT"

# The app folder every package is made from.
APP=build/pkg/sidekick
rm -rf build/pkg && mkdir -p build/pkg
cp -r "$BUNDLE" "$APP"
cp "$HERE/dev.sidekick.sidekick.desktop" "$HERE/dev.sidekick.sidekick.png" "$APP/"

# .tar.gz
tar -C build/pkg -czf "$OUT/$NAME.tar.gz" sidekick

# A root with /opt/sidekick, a launcher and the icon (the .deb and .rpm).
ROOT=build/pkg/root
mkdir -p "$ROOT/opt" "$ROOT/usr/bin" "$ROOT/usr/share/applications" "$ROOT/usr/share/icons/hicolor/512x512/apps"
cp -r "$BUNDLE" "$ROOT/opt/sidekick"
ln -s /opt/sidekick/sidekick "$ROOT/usr/bin/sidekick"
sed 's|^Exec=.*|Exec=/opt/sidekick/sidekick|' "$HERE/dev.sidekick.sidekick.desktop" \
  > "$ROOT/usr/share/applications/dev.sidekick.sidekick.desktop"
cp "$HERE/dev.sidekick.sidekick.png" "$ROOT/usr/share/icons/hicolor/512x512/apps/"

# .deb
DEBROOT=build/pkg/deb
cp -a "$ROOT" "$DEBROOT"
mkdir -p "$DEBROOT/DEBIAN"
sed "s/@VERSION@/$V/; s/@ARCH@/$DEB/" "$HERE/control" > "$DEBROOT/DEBIAN/control"
dpkg-deb --root-owner-group --build "$DEBROOT" "$OUT/$NAME.deb"

# .rpm (rpmbuild, from the same root)
if command -v rpmbuild > /dev/null; then
  TOP="$PWD/build/pkg/rpm"
  mkdir -p "$TOP/SPECS"
  sed "s/@VERSION@/$V/" "$HERE/sidekick.spec" > "$TOP/SPECS/sidekick.spec"
  rpmbuild -bb --target "$RPM" --define "_topdir $TOP" --define "_sidekick_root $PWD/$ROOT" "$TOP/SPECS/sidekick.spec"
  cp "$TOP"/RPMS/*/*.rpm "$OUT/$NAME.rpm"
else
  echo "No rpmbuild: skipping the .rpm" >&2
fi

# AppImage (appimagetool, downloaded once; runs without FUSE here).
# SKIP_APPIMAGE=1 leaves it out (a quick local check).
if [ -z "${SKIP_APPIMAGE:-}" ]; then
DIR=build/pkg/Sidekick.AppDir
cp -a "$APP" "$DIR"
cat > "$DIR/AppRun" << 'EOF'
#!/bin/sh
HERE="$(dirname "$(readlink -f "$0")")"
exec "$HERE/sidekick" "$@"
EOF
chmod +x "$DIR/AppRun"
cp "$HERE/dev.sidekick.sidekick.png" "$DIR/.DirIcon"
TOOL="build/appimagetool-$AI.AppImage"
if [ ! -x "$TOOL" ]; then
  curl -fsSL -o "$TOOL" "https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-$AI.AppImage"
  chmod +x "$TOOL"
fi
ARCH="$AI" APPIMAGE_EXTRACT_AND_RUN=1 "$TOOL" --no-appstream "$DIR" "$OUT/$NAME.AppImage"
fi

# Arch: a PKGBUILD that installs this release's .tar.gz (both machines).
sed "s/@VERSION@/$V/g" "$HERE/PKGBUILD" > "$OUT/PKGBUILD"

ls -l "$OUT"
