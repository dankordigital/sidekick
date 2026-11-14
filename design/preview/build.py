"""Builds /preview.html from preview.src.html: the 4.0 design's CSS and icons come from design/emulator."""
import pathlib
here = pathlib.Path(__file__).parent
emu = (here.parent / 'emulator' / 'emulator.src.html').read_text()
css = emu[emu.index('<style>') + 7:emu.index('</style>')]
lines = css.split('\n')
# the tokens (top) and the components (from "shared pieces"); not the emulator's own page layout
top = '\n'.join(lines[:15])
comp = css[css.index('/* ---------- shared pieces'):]
i = emu.index('const I={'); j = emu.index('\n', emu.index('const esc=', i))
src = (here / 'preview.src.html').read_text()
out = src.replace('/*EMU_CSS*/', top + '\n' + comp, 1).replace('/*ICONS*/', emu[i:j], 1)
(here.parent.parent / 'preview.html').write_text(out)
print('preview.html', len(out))
