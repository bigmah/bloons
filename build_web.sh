#!/bin/bash
# Builds a static website in ./web that plays each SWF in bloons_flash/ using Ruffle's WebAssembly player.
# Usage: ./build_web.sh [path/to/ruffle-web-selfhosted.zip]
#   Without an argument, downloads the latest Ruffle nightly self-hosted web build
#   (or the release named by $RUFFLE_TAG).
# Serve with: python3 -m http.server -d web 8000   (browsers can't load .wasm from file://)
#
# Every game is its own page, bloons-td-<n>.html, that fills whatever box it is
# shown in, letterboxed. web/ is self-contained and uses relative paths only,
# so it can be copied anywhere on a site and each game embedded with an iframe:
#   <iframe src="bloons/bloons-td-1.html" allow="autoplay; fullscreen"></iframe>
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
OUT="$ROOT/web"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

ZIP="${1:-}"
if [[ -z "$ZIP" ]]; then
  tag="${RUFFLE_TAG:-$(gh release list -R ruffle-rs/ruffle -L 1 --json tagName -q '.[0].tagName')}"
  gh release download "$tag" -R ruffle-rs/ruffle -p '*web-selfhosted.zip' -D "$TMP"
  ZIP="$(ls "$TMP"/*.zip)"
fi

rm -rf "$OUT"
mkdir -p "$OUT/ruffle" "$OUT/games"
unzip -q "$ZIP" -d "$OUT/ruffle"
# Source maps are most of the build's weight besides the wasm, and nothing loads them.
rm -f "$OUT"/ruffle/*.map

links=""
while IFS= read -r swf; do
  name="$(basename "$swf" .swf)"
  slug="$(echo "$name" | tr 'A-Z ' 'a-z-')"
  # The first game has no number in its name; give it one so the four line up.
  if [[ ! "$slug" =~ -[0-9]+$ ]]; then slug="$slug-1"; name="$name 1"; fi
  cp "$swf" "$OUT/games/$slug.swf"
  links+="$slug"$'\t'"$name"$'\n'
  cat > "$OUT/$slug.html" <<EOF
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>$name</title>
  <style>
    html, body { margin: 0; height: 100%; overflow: hidden; background: #000; }
    #game, #game ruffle-player { display: block; width: 100%; height: 100%; }
  </style>
</head>
<body>
  <div id="game"></div>
  <script>
    window.RufflePlayer = window.RufflePlayer || {};
    window.RufflePlayer.config = {
      publicPath: "ruffle/",
      autoplay: "on",
      unmuteOverlay: "hidden",
      splashScreen: false,
      letterbox: "on",
      backgroundColor: "#000000",
      allowScriptAccess: false,
      warnOnUnsupportedContent: false,
    };
  </script>
  <script src="ruffle/ruffle.js"></script>
  <script>
    const player = window.RufflePlayer.newest().createPlayer();
    document.getElementById("game").appendChild(player);
    player.ruffle().load("games/$slug.swf");
  </script>
</body>
</html>
EOF
done < <(ls "$ROOT"/bloons_flash/*.swf)

items=""
while IFS=$'\t' read -r slug name; do
  [[ -n "$slug" ]] && items+="    <li><a href=\"$slug.html\">$name</a></li>"$'\n'
done < <(printf '%s' "$links" | sort)

cat > "$OUT/index.html" <<EOF
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Bloons Flash</title>
  <style>
    body { font: 18px system-ui, sans-serif; max-width: 480px; margin: 48px auto; padding: 0 16px; }
    li { margin: 8px 0; }
  </style>
</head>
<body>
  <h1>Bloons Flash</h1>
  <ul>
$items  </ul>
</body>
</html>
EOF

echo "Done: $OUT"
