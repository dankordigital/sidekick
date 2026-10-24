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

## The Nothing ad

42 seconds on "Funky Funky Music" (prettyjohn1), the app's Nothing look on a
silver iPhone 17 Pro (3D, CSS) and a MacBook Pro: **NothingVertical** (9:16)
and **NothingHorizontal** (16:9), 60 fps, every cut on the beat.

- `src/nothing/beat.ts`: the music's grid (`b(n)` = beat n, 112 BPM).
- `src/nothing/Ad.tsx`: titles, chips, platforms, end card, corners, sounds.
- `src/nothing/stage.tsx`: where the devices are and what their screens show
  (`poses`, `phoneContent`, `macContent`), taps, the pointer, flying files.
- `src/nothing/devices.tsx`: the iPhone, the MacBook, finger, pointer.
- `src/nothing/dots.tsx`: the app's dot font (`DotText`), the "sk." logo.
- `public/nothing/`: the music, the app's sounds, JetBrains Mono, sample
  photos and the app's screens (`app/`), rendered by
  `app/tool/ad_nothing_test.dart` (see its header) and saved as JPEGs.
