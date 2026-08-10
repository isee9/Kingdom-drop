# docs/ — the playable browser build

This folder is a **pre-built copy of the game**, committed so it can be served
by GitHub Pages and played from a link, with nothing to install.

Enable it: repository **Settings → Pages → Source: Deploy from a branch →
Branch: `claude/kingdom-drop-mvp-sfeoa4`, folder `/docs` → Save.**
The site appears at `https://isee9.github.io/Kingdom-drop/` after a minute or
two.

## This is build output, not source

Nothing here is hand-written and nothing else in the project depends on it.
Regenerate it with:

```bash
flutter build web --release --no-web-resources-cdn --base-href /Kingdom-drop/
rm -rf docs && cp -r build/web docs
find docs -name "*.symbols" -delete
rm -rf docs/canvaskit/skwasm* docs/canvaskit/wimp* docs/canvaskit/experimental_webparagraph
touch docs/.nojekyll
```

The flags matter:

- `--no-web-resources-cdn` bundles CanvasKit instead of fetching it from
  Google's CDN at run time.
- `--base-href /Kingdom-drop/` matches the Pages subpath. Without it every
  asset 404s.
- `.nojekyll` stops Pages running Jekyll over the output.
- The deletions drop debug symbol maps and the unused renderer variants,
  taking the folder from 41 MB to 17 MB.

**Delete this folder whenever you like** — it is a convenience for trying the
game, not part of the app. The real targets are Android and iOS.
