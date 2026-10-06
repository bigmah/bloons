#!/bin/bash
# Packages each SWF in bloons_flash/ into a standalone macOS .app powered by Ruffle.
# Usage: ./build_apps.sh   (clones, patches and builds Ruffle in ./ruffle first if needed)
# Requires: rustup toolchain 1.96, a JDK (Homebrew openjdk), gh/git.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
RUFFLE="$ROOT/ruffle"
OUT="$ROOT/apps"
BIN="$RUFFLE/target/release/ruffle_desktop"
RUFFLE_REV="a407c51ef5d1c95f0438fbdc8362513a385f20e2"

if [[ ! -d "$RUFFLE" ]]; then
  git init -q "$RUFFLE"
  git -C "$RUFFLE" fetch -q --depth 1 https://github.com/ruffle-rs/ruffle.git "$RUFFLE_REV"
  git -C "$RUFFLE" checkout -q FETCH_HEAD
  git -C "$RUFFLE" apply "$ROOT/patches/ruffle-bundled-swf.patch"
fi

if [[ ! -x "$BIN" ]]; then
  (cd "$RUFFLE" && JAVA_HOME=/opt/homebrew/opt/openjdk PATH="/opt/homebrew/opt/openjdk/bin:$PATH" CARGO_NET_GIT_FETCH_WITH_CLI=true cargo +1.96 build --release -p ruffle_desktop)
fi

mkdir -p "$OUT"
for swf in "$ROOT"/bloons_flash/*.swf; do
  name="$(basename "$swf" .swf)"
  slug="$(echo "$name" | tr 'A-Z ' 'a-z-')"
  app="$OUT/$name.app"
  echo "Building $app"
  rm -rf "$app"
  mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources/game"
  cp "$BIN" "$app/Contents/MacOS/$slug"
  cp "$swf" "$app/Contents/Resources/game/"
  cat > "$app/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key><string>en</string>
    <key>CFBundleDisplayName</key><string>$name</string>
    <key>CFBundleName</key><string>$name</string>
    <key>CFBundleExecutable</key><string>$slug</string>
    <key>CFBundleIdentifier</key><string>local.bloons.$slug</string>
    <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>1.0</string>
    <key>LSMinimumSystemVersion</key><string>11.0</string>
    <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
EOF
  codesign --force --deep --sign - "$app" >/dev/null
done
echo "Done: $OUT"
