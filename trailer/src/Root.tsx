import React from 'react';
import { Composition, staticFile } from 'remotion';
import { loadFont } from '@remotion/fonts';
import { Trailer } from './Composition';
import { END, FPS } from './beat';

for (const [family, file, weight] of [
  ['InterDisplay', 'InterDisplay-Black.ttf', '900'],
  ['InterDisplay', 'InterDisplay-ExtraBold.ttf', '800'],
  ['InterDisplay', 'InterDisplay-Bold.ttf', '700'],
  ['Inter', 'Inter-SemiBold.ttf', '600'],
  ['Inter', 'Inter-Medium.ttf', '500'],
  ['MaterialIcons', 'MaterialIcons-Regular.otf', '400'],
] as const) {
  loadFont({ family, url: staticFile(`fonts/${file}`), weight });
}

// One trailer, two shapes: every scene lays itself out for the frame it's in
// (useO / useVertical in ui.tsx).
export const Root: React.FC = () => (
  <>
    <Composition id="Horizontal" component={Trailer} durationInFrames={Math.round(END * FPS)} fps={FPS} width={1920} height={1080} />
    <Composition id="Vertical" component={Trailer} durationInFrames={Math.round(END * FPS)} fps={FPS} width={1080} height={1920} />
  </>
);
