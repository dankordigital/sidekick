# Sidekick emulator

The owner's Figma design (`../figma/`) made clickable: a phone and a computer
in one page. Published at https://claude.ai/artifact/Rbd3YL2REDeDKtCK5z3px5.

- `sidekick-emulator.html`: the page (open it in a browser).
- `emulator.src.html` + `media.js`: the source; the page is the source with
  `/*MEDIA*/` replaced by `media.js` (the three sample photos, from the Figma
  screens).
- `check.js`: clicks through every flow in Chromium (Playwright) and saves
  screenshots to `shots/`; run `node check.js` next to the page.

Colours and type sizes are the Figma "Foundations" tokens; icons are Lucide,
like the Figma icon set.
