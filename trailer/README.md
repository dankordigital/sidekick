# Sidekick trailer (Remotion)

62 seconds on the first 1:02 of the hitslab track, in two shapes:
**Horizontal** (16:9, 1920×1080) and **Vertical** (9:16, 1080×1920), 60 fps.

- `src/index.tsx`: entry point. `src/Root.tsx`: the two compositions.
- `src/Composition.tsx`: the timeline (which scene plays when), backdrop, flashes, music.
- `src/scenes.tsx`: every scene. `src/ui.tsx`: phone, Mac, headlines, pills.
  Scenes lay themselves out for either shape with `useO(horizontal, vertical)`.
- `src/beat.ts`: the music's grid (`B(n)` = bar n; the drop is `DROP`).
- `public/`: music, fonts, app screenshots (`shots/`) and animation frames (`seq/`).

**Rendering:** every push that changes `trailer/` runs `.github/workflows/render.yml`:
both MP4s appear under the run's **Artifacts** (Actions tab). It can also be started
by hand: Actions → Render trailer → Run workflow.

On a computer: `npm ci`, then `npm run studio` (preview) or `npm run build`.
