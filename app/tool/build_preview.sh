#!/bin/bash
# Builds the website's live preview: Sidekick itself, compiled for a browser
# (lib/demo/preview_main.dart), into ../website/app/. preview.html shows it
# twice, as a Mac and as an iPhone. Run from anywhere:
#
#   app/tool/build_preview.sh
#
# Everything is served from getsidekick.app (no Google CDN). Inter stands in
# for Apple's system font (which can't be shipped), cut down to the
# characters the app uses.
set -euo pipefail
cd "$(dirname "$0")/.."

fonts=build/fonts/x/extras/ttf
if [ ! -f "$fonts/Inter-Regular.ttf" ]; then
  mkdir -p build/fonts
  curl -sSfL -o build/fonts/inter.zip https://github.com/rsms/inter/releases/download/v4.1/Inter-4.1.zip
  unzip -q -o build/fonts/inter.zip -d build/fonts/x
fi

out=build/preview_web
flutter build web -t lib/demo/preview_main.dart --release --no-web-resources-cdn \
  --base-href /website/app/ -o "$out"

mkdir -p "$out/fonts"
for family in Inter InterDisplay; do
  for weight in Regular Medium SemiBold Bold; do
    pyftsubset "$fonts/$family-$weight.ttf" --output-file="$out/fonts/$family-$weight.ttf" \
      --unicodes="U+0020-007E,U+00A0-00FF,U+0100-017F,U+2010-2027,U+2030-203A,U+2190-2199,U+2022,U+2122,U+2713,U+2715,U+00D7" \
      --layout-features='*' --no-hinting
  done
done
cp build/fonts/x/LICENSE.txt "$out/fonts/Inter-LICENSE.txt"

# Not needed on the site: debug symbols, and the renderers for WebAssembly
# builds (this is a JavaScript build: it uses canvaskit/ and, in Chrome,
# canvaskit/chromium/).
rm -f "$out/.last_build_id"
find "$out" -name '*.js.symbols' -delete
rm -rf "$out"/canvaskit/skwasm* "$out"/canvaskit/wimp* "$out"/canvaskit/webparagraph
rm -rf ../website/app
cp -r "$out" ../website/app
du -sh ../website/app
