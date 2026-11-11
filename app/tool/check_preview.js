// Checks the website's live demo (preview.html) in Chromium (Chrome, Edge,
// Opera, Samsung Internet), Firefox and WebKit (Safari): both copies of the
// app start, pair with the 6-digit code, and the iPhone sends files that the
// Mac accepts. Run through tool/check_preview.sh (it serves the site).
//
//   node tool/check_preview.js [chromium,firefox,webkit] [page,embed,phone]
//
// page: /preview.html on a computer. embed: the home page's "Start the
// demo" (preview.html?embed=1 in the page). phone: /preview.html on a
// phone-sized screen (an iPhone in WebKit, a Pixel in Chromium).
//
// The app draws on a canvas, so this turns on Flutter's accessibility tree
// in each frame and finds buttons and text there, like a screen reader.
const pw = require('playwright');

const site = process.env.SIDEKICK_SITE || 'http://localhost:8000';
const args = process.argv.slice(2);
const names = (args[0] || 'chromium,firefox,webkit').split(',');
const scenarios = (args[1] || 'page,embed,phone').split(',');
const shots = process.env.SIDEKICK_SHOTS;

async function semantics(frame) {
  await frame.evaluate(() => document.querySelector('flt-semantics-placeholder')?.click());
}

/// Everything the app shows, as text (for finding the code, and for errors).
async function text(frame) {
  return frame.evaluate(() =>
    [...document.querySelectorAll('flt-semantics *')]
      .map((e) => e.getAttribute('aria-label') || (e.children.length ? '' : e.textContent))
      .filter(Boolean)
      .join(' | '),
  );
}

/// Scrolls the device into view, like a person would: browsers stop drawing
/// frames that are off screen (on a phone, the Mac is above the iPhone).
async function show(frame) {
  const el = await frame.frameElement();
  await el.evaluate((e) => (e.closest('.device') || e).scrollIntoView({ block: 'center' }));
}

async function waitFor(frame, what, re, timeout = 15000) {
  await show(frame);
  const end = Date.now() + timeout;
  while (Date.now() < end) {
    const t = await text(frame);
    const m = t.match(re);
    if (m) return m;
    await frame.page().waitForTimeout(250);
  }
  throw new Error(`${what}: never showed ${re}. On screen: ${(await text(frame)).slice(0, 600)}`);
}

/// Taps like a screen reader does: a click on the accessibility node (the
/// devices are drawn scaled down in frames, where pointer taps can miss on
/// an emulated phone).
async function tap(frame, role, name) {
  await show(frame);
  const target = (typeof role === 'string' ? frame.getByRole(role, { name }) : role).last();
  await target.waitFor({ timeout: 15000 });
  await target.evaluate((e) => e.click());
}

async function check(name, scenario) {
  // Headless Firefox has no WebGL here and draws on the CPU, far slower than
  // any real Firefox: with a display (check_preview.sh starts Xvfb) it runs
  // in a window, with WebGL, like on a desktop.
  const browser = await pw[name].launch({ headless: name !== 'firefox' || !process.env.DISPLAY });
  const phoneLike = { webkit: 'iPhone 15', chromium: 'Pixel 7' }[name];
  const options =
    scenario === 'phone'
      ? phoneLike
        ? pw.devices[phoneLike]
        : { viewport: { width: 393, height: 852 } }
      : { viewport: { width: 1440, height: 1000 } };
  const context = await browser.newContext(options);
  const page = await context.newPage();
  const errors = [];
  page.on('pageerror', (e) => errors.push(e.message.split('\n')[0]));
  await page.addInitScript(() => {
    window.__sk = { ready: [], failed: null };
    addEventListener('message', (e) => {
      try {
        const m = JSON.parse(e.data);
        if (m.t === 'ready') window.__sk.ready.push(m.from);
      } catch (_) {}
    });
  });
  const started = Date.now();
  const steps = [];
  const step = async (label, fn) => {
    const t = Date.now();
    try {
      await fn();
      steps.push(`  ✓ ${label} (${((Date.now() - t) / 1000).toFixed(1)} s)`);
    } catch (e) {
      steps.push(`  ✗ ${label}: ${process.env.SIDEKICK_VERBOSE ? e.message : e.message.split('\n')[0]}`);
      throw e;
    }
  };
  let ok = true;
  try {
    if (scenario === 'embed') {
      await step('home page loads, Start the demo', async () => {
        await page.goto(`${site}/index.html`);
        // Smooth scrolling keeps things moving while Playwright clicks.
        await page.addStyleTag({ content: 'html { scroll-behavior: auto !important; }' });
        await page.locator('#liveStart').click();
      });
    } else {
      await step('loads', () => page.goto(`${site}/preview.html?semantics=1`));
    }
    await step('both apps start', async () => {
      // preview.html: the page itself, or (embed) a frame in the home page.
      let host;
      for (let i = 0; i < 100 && !host; i++) {
        host = page.frames().find((f) => /preview\.html/.test(f.url()));
        if (!host) await page.waitForTimeout(100);
      }
      if (!host) throw new Error('preview.html never loaded');
      await host.waitForFunction(() => window.__sk?.ready.length >= 2, null, { timeout: 45000 });
    });
    const mac = page.frame({ url: /device=mac/ });
    const phone = page.frame({ url: /device=iphone/ });
    await semantics(mac);
    await semantics(phone);
    let code;
    await step('iPhone asks to pair, Mac shows a code', async () => {
      await tap(phone, 'button', /^Pair$/);
      code = (await waitFor(mac, 'Mac', /Pairing code: ((?:\d ?){6})/))[1].replace(/ /g, '');
    });
    await step('the code is typed on the iPhone and they pair', async () => {
      const box = phone.getByRole('textbox').last();
      await box.waitFor({ timeout: 10000 });
      // A real click gives Flutter's own text box the keyboard (in Firefox a
      // scripted one doesn't reach a nested frame). Keys typed before Flutter
      // has hooked the box up are lost, faster than any person types: then
      // clear it and type again.
      for (let attempt = 1; ; attempt++) {
        await show(phone);
        await box.click({ timeout: 3000 }).catch(() => tap(phone, box));
        await page.waitForTimeout(700);
        await page.keyboard.type(code, { delay: 60 });
        await page.waitForTimeout(1500);
        // Six digits pair by themselves; press Pair only if it's still there.
        const pair = phone.getByRole('button', { name: /^Pair$/ });
        if (await pair.count()) await tap(phone, pair).catch(() => {});
        try {
          await waitFor(phone, 'iPhone', /Paired/, attempt < 3 ? 4000 : 15000);
          break;
        } catch (e) {
          if (attempt >= 3) throw e;
          for (let i = 0; i < 8; i++) await page.keyboard.press('Backspace');
        }
      }
    });
    await step('iPhone sends files, Mac accepts, they arrive', async () => {
      await tap(phone, 'button', /^Send$/);
      await tap(phone, phone.getByText(/^Files$/));
      await waitFor(mac, 'Mac', /Accept/);
      await tap(mac, 'button', /^Accept/);
      await waitFor(phone, 'iPhone', /Sent|Done/i, 30000);
    });
    if (scenario === 'embed') {
      await step('the home page shows it running', () =>
        page.waitForFunction(() => document.querySelector('#live')?.dataset.state === 'running', null, {
          timeout: 5000,
        }),
      );
    }
  } catch (e) {
    ok = false;
  }
  if (shots) await page.screenshot({ path: `${shots}/preview-${name}-${scenario}.png` });
  console.log(`${ok ? 'PASS' : 'FAIL'} ${name}, ${scenario} (${((Date.now() - started) / 1000).toFixed(0)} s)`);
  console.log(steps.join('\n'));
  if (errors.length) console.log('  page errors:\n    ' + [...new Set(errors)].slice(0, 5).join('\n    '));
  await browser.close();
  return ok;
}

(async () => {
  let failed = 0;
  for (const n of names) for (const sc of scenarios) if (!(await check(n, sc))) failed++;
  process.exit(failed ? 1 : 0);
})();
