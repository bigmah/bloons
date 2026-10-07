# Bloons Flash

Play the original Bloons Tower Defense 1–4 Flash games without Flash, using
[Ruffle](https://github.com/ruffle-rs/ruffle), a Flash Player emulator written in Rust.

There are two ways to package the games:

- **Native macOS apps:** one double-clickable `.app` per game.
- **WebAssembly site:** a static website that runs the games in any modern browser.

> **Note:** neither option recompiles the games. The SWF files are kept as they are, and
> Ruffle's player (compiled natively for macOS, or to WebAssembly for the web) runs them.

## Layout

| Path | What it is |
| --- | --- |
| `bloons_flash/` | The original game SWFs (BTD 1–2 are SWF 8, BTD 3–4 are SWF 10) |
| `build_apps.sh` | Builds the macOS apps into `apps/` |
| `build_web.sh` | Builds the WebAssembly site into `web/` |
| `patches/ruffle-bundled-swf.patch` | Small patch to Ruffle's desktop player (see below) |

`ruffle/`, `apps/` and `web/` are generated and git-ignored.

## macOS apps

```sh
./build_apps.sh
open "apps/Bloons TD 4.app"
```

The script:

1. Clones Ruffle at a pinned commit into `ruffle/` and applies `patches/ruffle-bundled-swf.patch`.
2. Builds `ruffle_desktop` in release mode.
3. For each SWF, creates `apps/<Game>.app` with the player binary in `Contents/MacOS/` and the
   SWF in `Contents/Resources/game/`, then ad-hoc code-signs it.

The patch makes the player, when started without a file argument, auto-load the SWF found in
its bundle's `Contents/Resources/game/`, hide the menu bar, and use the game's name as the
window title.

**Requirements**

- Rust 1.96 (`rustup toolchain install 1.96`). The script calls `cargo +1.96`.
- A JDK, used to compile Ruffle's AS3 standard library. The script uses Homebrew's
  `openjdk` (`brew install openjdk`).
- `git`. The script sets `CARGO_NET_GIT_FETCH_WITH_CLI=true` so git dependencies are fetched
  with your git config (this matters if you rewrite GitHub URLs to SSH).

The apps are ad-hoc signed, so on another Mac you have to right-click → Open the first time,
or run `xattr -cr "Bloons TD.app"`.

## WebAssembly site

```sh
./build_web.sh                       # downloads the latest Ruffle nightly web build
./build_web.sh path/to/ruffle-*-web-selfhosted.zip   # or use a specific build
python3 -m http.server -d web 8000   # then open http://localhost:8000
```

This produces a static site: an `index.html` that links to each game, one page per game
(`bloons-td-1.html` … `bloons-td-4.html`), the SWFs in `web/games/`, and Ruffle's `ruffle.js`
and `.wasm` files in `web/ruffle/`. Browsers can't load WebAssembly from `file://`, so serve
it over HTTP. Any static host (GitHub Pages, Netlify, etc.) works.

Downloading the latest build requires the GitHub CLI (`gh`). Set `RUFFLE_TAG` to pin a
specific Ruffle release instead of the newest one.

### Embedding a game in another page

Each game page fills whatever box it is shown in, letterboxed on black, and `web/` only uses
relative paths. Copy the whole directory onto a site (say as `bloons/`) and drop a game in
with an iframe:

```html
<iframe src="bloons/bloons-td-2.html" allow="autoplay; fullscreen"
        style="width: 640px; aspect-ratio: 4 / 3; border: 0"></iframe>
```

BTD 1–3 have a 640×480 stage and BTD 4 a 640×640 one; any other box is letterboxed. Nothing is
downloaded until the iframe loads, and then it is about 14 MB of Ruffle (shared by all four
games and cached after the first) plus the game's SWF (0.5–2.9 MB). `allow="autoplay"` lets
sound start when the iframe is created from a click.

## Known quirks

- BTD 4 includes MochiAd code that tries to contact ad servers. The failed connections and
  "Security Sandbox Violation" messages in the logs are harmless.
- Ruffle's ActionScript 3 support is still incomplete, so the newer games (BTD 4 is AS3) may have occasional glitches
  that the older ones don't.
