# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

HexGL is a static HTML5/WebGL racing game (Three.js). There is **no build step, no package.json, no bundler**. The browser loads `.js` files directly via `<script>` tags in `index.html`. Assets are loaded by relative path, so the project must be served over HTTP (not opened via `file://`).

## Run locally

From the project root:

```bash
python3 -m http.server 8000
# then open http://localhost:8000
```

Any static server works (`npx serve`, nginx, etc.).

URL flags (handled in `launch.js`) override the menu defaults: `?controlType=0|1|2|3`, `?quality=0|1|2|3`, `?hud=0|1`, `?godmode=0|1`.

There are CoffeeScript unit tests at `bkcore.coffee/tests.html` — open it through the same local server.

## CoffeeScript / JavaScript dual sources

This is the **only non-obvious thing about the codebase**. Several files exist as both `.coffee` source and a hand-checked-in compiled `.js`:

- `launch.coffee` ↔ `launch.js`
- `bkcore.coffee/Timer.coffee` ↔ `Timer.js`
- `bkcore.coffee/Utils.coffee` ↔ `Utils.js`
- `bkcore.coffee/ImageData.coffee` ↔ `ImageData.js`

The browser only loads the `.js`. The `.coffee` is the original source. **If you edit the `.coffee`, you must recompile** (`coffee -c file.coffee`) or the change won't take effect. The pragmatic shortcut for small fixes is to edit the `.js` directly and either also patch the `.coffee` or leave a comment noting the divergence. Files under `bkcore/` (no `.coffee` suffix in the dir name) are hand-written JavaScript with no CoffeeScript twin.

## Architecture

**Entry path:** `index.html` loads libs and game scripts in a specific order, then `launch.js` runs. `launch.js` wires up the menu DOM, constructs `bkcore.hexgl.HexGL`, and drives `hexGL.load(...)` → `hexGL.init()` → `hexGL.start()`.

**Core class — `bkcore/hexgl/HexGL.js`:** Owns the WebGL renderer, the `RenderManager`, the postprocessing `EffectComposer`, the HUD, and the `Gameplay` instance. Quality (0–3) drives renderer flags here: `quality > 2` turns on PBR/gamma/shadows/bloom; `quality === 0` halves width/height. Difficulty settings are hard-coded in `tweakShipControls()`.

**Per-frame loop:** `HexGL.update()` → `gameplay.update()` → `manager.renderCurrent()`. The `requestAnimationFrame` loop lives in `HexGL.start()`.

**Gameplay layer (`bkcore/hexgl/`):**
- `Gameplay.js` — race state machine, checkpoints, lap timing, finish/destroy outcomes.
- `ShipControls.js` — physics + input integration; values per difficulty are set externally by `HexGL.tweakShipControls()`.
- `CameraChase.js`, `ShipEffects.js`, `HUD.js` — camera follow, particle/booster effects, canvas-based HUD overlay.
- `RaceData.js`, `Ladder.js` — recording/replay and leaderboard.

**Tracks (`bkcore/hexgl/tracks/`):** A track is a plain object (e.g. `Cityscape`) declaring spawn, checkpoints, an asset manifest (textures + geometries by quality tier), and `buildMaterials` / `buildScenes` methods called from `HexGL.init()`. Adding a track means creating a sibling file and registering it on `bkcore.hexgl.tracks`. Asset paths inside the track file are **quality-gated** — fewer textures/lower-res variants are listed under `quality < 2` branches.

**Three.js layer (`bkcore/threejs/`):**
- `RenderManager.js` — registers named scene+camera pairs; `setCurrent` / `renderCurrent` swap which one renders.
- `Loader.js` — manifest-driven async loader (textures, geometries, images) with the `onLoad`/`onProgress`/`onError` callbacks that `launch.js` uses for the progress bar.
- `Shaders.js` — custom shader passes (notably `hexvignette`, which is wired into the postprocessing chain in `initGameComposer`).

**Three.js itself is bundled** as `libs/Three.dev.js` / `libs/Three.r53.js` — this is a **legacy r53-era build**. APIs like `geometry.computeTangents()`, `renderer.physicallyBasedShading`, `renderer.shadowMapEnabled`, and `THREE.RGBFormat` are used throughout. Do **not** drop in a modern Three.js; the game uses removed/renamed APIs and the postprocessing files in `libs/postprocessing/` are matched to this version.

## Assets

- `textures/` is the low-res default. `textures.full/` is full-resolution. To use full-size, swap the two directories (rename — `index.html` always references `textures/`). Noted in the README.
- `geometries/` holds Three.js JSON model exports (r53 format). Same legacy-version caveat as Three.js itself.
- `audio/` is OGG Vorbis; played via `bkcore/Audio.js`.

## Deployment (chief-sys/HexGL → hexgl.blockchanger.io)

The site is deployed on a DigitalOcean droplet, served by nginx, fronted by Cloudflare.

- Origin: `/home/anthony/HexGL` on `144.126.207.28` (SSH: `ssh -i ~/.ssh/deploy_key anthony@144.126.207.28`).
- nginx site config: `/etc/nginx/sites-available/hexgl.blockchanger.io` (root → `/home/anthony/HexGL`, Cloudflare real-IP ranges, long cache for static assets, `no-store` for `index.html` / `cache.appcache` / `manifest.webapp`).
- Public URL: `https://hexgl.blockchanger.io/` (Cloudflare proxy, orange-cloud).

Redeploy after a push to `chief-sys/HexGL`:

```bash
ssh -i ~/.ssh/deploy_key anthony@144.126.207.28 'cd ~/HexGL && git pull --ff-only'
```

If you change response headers or MIME mapping, **purge Cloudflare's cache** afterwards or test with a cache-bypass query string — stale responses (e.g. an old `Content-Type: application/octet-stream`) will otherwise persist for the visitor.

## Known gotchas

- `HexGL.js:228` calls `JSON.Stringify` (capital S) — that's a real bug in the upstream code; the replay save path silently throws.
- `manifest.webapp` points to `/index-mobile.html` which **does not exist** in this repo — it's a leftover from the Firefox OS package. Safe to ignore unless you're rebuilding the FFOS bundle.
- `cache.appcache` is an HTML5 AppCache manifest (deprecated by browsers). Listed assets must stay in sync if you keep using it; otherwise the safest move is to stop linking it.
- `package.zip` (~3 MB) is the prebuilt Firefox OS package, not a source artifact. Don't depend on it from code.
