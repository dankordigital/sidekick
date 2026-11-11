#!/bin/bash
# Checks the website's live demo (preview.html, and the home page's "Start
# the demo") in Chromium, Firefox and WebKit: both apps start, pair with the
# 6-digit code, and send files. Uses website/app/ as it is: run
# tool/build_preview.sh first after changing the app. Run from anywhere:
#
#   app/tool/check_preview.sh                    # every browser, every case
#   app/tool/check_preview.sh firefox page,phone # some of them
#
# Needs PHP (it serves the site, like the hosting), Node with Playwright and
# its browsers (npx playwright install --with-deps chromium firefox webkit).
# Xvfb, when there, gives Firefox a display, so it draws with WebGL like on
# a desktop. SIDEKICK_SHOTS=folder saves a screenshot of each run.
set -euo pipefail
cd "$(dirname "$0")/../.."

port=${SIDEKICK_PORT:-8765}
php -S "127.0.0.1:$port" >/dev/null 2>&1 &
server=$!
trap 'kill $server 2>/dev/null' EXIT
for _ in $(seq 50); do curl -s -o /dev/null "http://127.0.0.1:$port/preview.html" && break; sleep 0.1; done

run=(node app/tool/check_preview.js "$@")
if [ -z "${DISPLAY:-}" ] && command -v xvfb-run >/dev/null; then run=(xvfb-run -a "${run[@]}"); fi
SIDEKICK_SITE="http://127.0.0.1:$port" "${run[@]}"
