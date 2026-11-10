#!/bin/sh
# Packages the exported Linux build as an AppImage: one file that runs on most
# x86-64 Linux desktops without installing anything.
#
#   tools/make_appimage.sh <exported binary> <godot> <appimagetool> <out.AppImage>
#
# Run from the repository root. The exported binary normally has the game
# embedded (embed_pck); a .pck beside it is packed too if there is one.
set -eu

BIN="$1"
GODOT="$2"
TOOL="$3"
OUT="$4"

WORK="$(mktemp -d)"
APPDIR="$WORK/SilentBearing2.AppDir"
mkdir -p "$APPDIR/usr/bin" "$APPDIR/usr/share/applications" "$APPDIR/usr/share/icons/hicolor/256x256/apps"

cp "$BIN" "$APPDIR/usr/bin/SilentBearing2"
chmod +x "$APPDIR/usr/bin/SilentBearing2"
PCK="${BIN%.*}.pck"
if [ -f "$PCK" ]; then
	cp "$PCK" "$APPDIR/usr/bin/SilentBearing2.pck"
fi

"$GODOT" --headless --path . -s tools/make_icon.gd -- 256 "$APPDIR/silentbearing2.png"
cp "$APPDIR/silentbearing2.png" "$APPDIR/usr/share/icons/hicolor/256x256/apps/silentbearing2.png"

cat > "$APPDIR/silentbearing2.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=Silent Bearing 2
GenericName=Naval warfare game
Comment=The Cold War has gone hot: command American or Soviet warships, from frigate to battleship
Exec=SilentBearing2
Icon=silentbearing2
Categories=Game;Simulation;
Terminal=false
EOF
cp "$APPDIR/silentbearing2.desktop" "$APPDIR/usr/share/applications/silentbearing2.desktop"

cat > "$APPDIR/AppRun" <<'EOF'
#!/bin/sh
HERE="$(dirname "$(readlink -f "$0")")"
exec "$HERE/usr/bin/SilentBearing2" "$@"
EOF
chmod +x "$APPDIR/AppRun"

# Extract-and-run: build machines often have no FUSE.
ARCH=x86_64 APPIMAGE_EXTRACT_AND_RUN=1 "$TOOL" "$APPDIR" "$OUT"
chmod +x "$OUT"
rm -rf "$WORK"
echo "APPIMAGE $OUT"
