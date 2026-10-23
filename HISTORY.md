# What we've done (session history)

A running record of the work on Sidekick, for picking up after `/clear` or in
a new session. Newest first. For how things work, read `CLAUDE.md` (the
detailed developer notes; every release is in `VERSIONS.md`) and
`ARCHITECTURE.md` (the big picture).

## 23 October 2026

- **App (unreleased):** the Devices page no longer says "Pair over
  Bluetooth": a "Connect" link opens every way to connect (Wi-Fi, QR code,
  IP, Bluetooth last). The welcome screen says "Works over Wi-Fi". When
  Wi-Fi reaches a device, Sidekick hangs up its own Bluetooth link to it
  (other Bluetooth devices stay connected).
- **Website:** features updated to what 2.17 does (direct Wi-Fi, Ping,
  notifications and screenshots on computers, tray / menu bar, Live
  Activities); Bluetooth only as a last resort.
- **np7dpanel.php:** Website shows the latest GitHub release with
  **Release latest**; new **Edit** tab changes the home page's texts on the
  hosting (`edits.json`, applied by index.php).
- **Owner to upload:** `index.html`, `index.php`, `wishlist.php`,
  `np7dpanel.php` (or let the website workflow do it).

## Where things stand (15 October 2026)

- **App:** latest release **2.17.2** (same app as 2.17.1), published on GitHub (Windows .exe,
  Apple-silicon and Intel .dmg/.pkg, Android .apk, iPhone .ipa,
  altstore.json) and on TestFlight. Branch:
  `claude/sidekick-app-architecture-main` (until 15 Oct 2026
  `claude/sidekick-app-architecture-8ilytw`; `sync.sh` renames the Mac's
  copy by itself).
  - Features now: files both ways, browse the other device, remote control,
    Ping, direct Wi-Fi / Bluetooth, QR pairing, Live Activities, phone
    notifications on computers (Android), screenshots to computers.
  - **Removed (2.15.0, don't bring back):** shared clipboard, Screen
    Mirroring.
  - Look: minimal Material by default; Liquid Glass option on iOS/macOS 26
    (since 2.17.0 buttons, switches, fields and menus are glass too)
    (iPhone uses Apple's own swipeable tab bar; the Mac draws its own glass,
    never a transparent window: that killed the M1 app in 2.16.0).
- **Mac:** separate Apple-silicon and Intel builds since 2.16.0. The owner
  confirmed 2.16.1 works on the M1.
- **Website:** **getsidekick.app** (OVHcloud free hosting), uploaded by the
  owner with FileZilla into `www`. A **wishlist page, not a download page**.
- **Wishlist:** works, emails arrive (SMTP via ssl0.ovh.net). Admin panel
  **`np7dpanel.php`**: overview, people (add/remove/resend/CSV), email
  everyone, past sends, mail log, health. Its password is the mailbox
  password from `wishlist-config.php` (never in git).
- **Ads:** three finished videos, made outside the repo (scratchpad).

## Waiting on the owner

1. ~~Test 2.16.1 on the M1~~: done, it works.
2. **Upload to `www`:** `np7dpanel.php`, `wishlist.php` (welcome email no
   longer mentions clipboard/mirroring), `privacy.html` (2.15 features).
   Delete `wishlist-check.php` from the hosting.
3. **Change the info@getsidekick.app password** (it was shared in chat),
   then update `wishlist-config.php` on the hosting. The panel uses it too.
4. **Profile picture for info@:** `website/profile.png` (white "sk" on
   black). Google needs a phone number that isn't over its limit;
   Gravatar works without one.
5. **Terms of Service:** country in section 9, a real name in the
   copyright line. **Privacy policy:** still mentions the Microsoft Store.
6. **Launch, when ready:** bring back the download section (git history,
   2.12.0), make the site findable on Google, email the list from
   `np7dpanel.php`. Decide what iPhone users are told (AltStore/TestFlight).

## History

### One branch, lighter CLAUDE.md (15 Oct)
- The main branch is now `claude/sidekick-app-architecture-main` (renamed
  on GitHub from `-8ilytw`; no other branches left). `sync.sh` renames the
  Mac's copy by itself; `website.yml` uploads from both names.
- "Versions" moved out of `CLAUDE.md` into `VERSIONS.md` (the owner's call,
  to save tokens: `CLAUDE.md` is loaded into every session, 53 KB → 33 KB).
- Every GitHub link pointed at the son's old account
  (`michaldaniszewski03-hash/sidekick`): the site, privacy policies, README,
  Windows installer and `wishlist.php`'s `REPO` (where the released site gets
  its downloads). All now `dankordigital/sidekick`.

### 2.17.2 and syncing with GitHub (14 Oct)
- `sync.sh` (pull, commit everything, push; never uploads to the hosting)
  for the copy on the family Mac; CLAUDE.md says Claude pulls before work
  and pushes each finished change itself.
- Released **2.17.2**: no app changes since 2.17.1, just a rebuild. All
  files are on the GitHub release (.exe, Apple-silicon and Intel .dmg/.pkg,
  .apk, .ipa, altstore.json).

### 2.17.1: tray Open fix, smoother, Apple-like motion (14 Oct)
- Tray panel's Open Sidekick opened and closed the window: the hide's focus
  loss started a second close (`_closingPanel` now shared).
- Lag: no BackdropFilter per glass button or on the computer's content
  panel; tab switch shows only the new tab (fade-in, 180 ms).
- Cupertino page transitions everywhere; `Entrance` slides up 2 % with
  easeOutQuint.
- Trailer (`trailer/`, Remotion): Apple style, rendered by
  `.github/workflows/render.yml` (Artifacts).

### 2.17.0: Liquid Glass everywhere it fits (14 Oct)
- Liquid Glass theme now covers buttons, selections, switches, fields,
  menus, snackbars and tooltips (`ui/glass.dart`: `GlassFill`,
  `glassTheme`), all keeping the theme's colors.

### Admin panel: Visits and Release / wishlist switch (13 Oct)
- `np7dpanel.php` → **Visits**: home-page visits and visitors per day,
  30-day chart, referring sites (counted by the new `index.php`).
- → **Website**: "Release Sidekick" (with a version) turns the site into
  the download page (Apple-silicon/Intel Mac links too); "Make it a
  wishlist again" undoes it. `.htaccess` routes the home page through
  `index.php`. Privacy policies mention the visit count.

### Email signature, M1 confirmed (13 Oct)
- Every email (welcome and Email everyone) ends with a signature: the "sk"
  logo (inline `cid:logo`, `logo_image()` in `wishlist.php`), "Sidekick",
  getsidekick.app and info@getsidekick.app (`email_footer()`). The plain
  text ends the same way. Upload `wishlist.php` and `np7dpanel.php`.
- The owner confirmed 2.16.1 works on the M1.

### Admin panel grows up (13 Oct)
- `np7dpanel.php` became a full admin panel: Overview (counts, 30-day
  sign-up chart, devices, newest), People (search, add, remove, resend
  welcome, send to everyone who never got it, CSV export), Email everyone
  (test first, batches of 8, resumable, draft kept), Past sends, Mail log,
  Health. Tested with 37 fake sign-ups against a fake SMTP server.

### 2.16.1, admin panel, Mac icon looks (13 Oct)
- M1 app was dead in 2.16.0 (no background, buttons dead): the see-through
  glass window was removed; the Mac draws its own glass.
- `np7dpanel.php`: password-protected panel that emails the whole list in
  batches (tested against a fake SMTP server). Password comes from
  wishlist-config.php, never git.
- `website/mac-icons/sidekick-mac-{default,dark,clear,tinted}.png`.

### Sidekick 2.16.0: Mac per chip, real glass (13 Oct)
- Owner: M1 Mac showed no pairing code/QR; Liquid Glass "doesn't make
  anything liquid glass"; wanted separate ARM and Intel Mac versions.
- Mac builds split (Apple-silicon / Intel .dmg and .pkg). The Mac's glass
  is now the window (NSGlassEffectView behind a clear Flutter view); the
  AppKitView glass that likely hid the pairing code is gone.

### Sidekick 2.15.0: simpler, and two new features (13 Oct)
- The owner tried Liquid Glass and wanted the real thing: the iPhone tab
  bar is now Apple's own UITabBar (swipeable) on iOS 26.
- "More minimalist, not vibecoded": no gradient hero, no tinted icon
  squares or status pills, plain section titles, Send + ⋯ menu per device.
- Removed the shared clipboard and Screen Mirroring (too laggy), including
  the iPhone broadcast extension target.
- New: Android notifications on computers; screenshots to computers.

### Liquid Glass theme, 2.14.0 (13 Oct)
- iOS/macOS 26+ get Settings → Theme → "Theme: Default / Liquid Glass";
  Material stays the default everywhere (`ui/glass.dart`, pref `look`).

### Website fits phones (12 Oct)
- `index.html`: on phones the top bar fits (smaller logo, "Join" button),
  hero buttons are full width, the email field no longer collapses, bigger
  color swatches, tighter spacing; tablets get a centered hero picture.
  Checked at 360, 390, 820 and 1440 px wide: no sideways scrolling.

### Wishlist email: second route (12 Oct)
- `wishlist.php` now tries `ssl0.ovh.net` on **465 (SSL)**, then **587
  (STARTTLS)**, then PHP `mail()`, logging each failure. Port 993 (what the
  owner had) is IMAP, for reading mail: it can't send. The header image
  stays attached inline (`cid:header`). Tested both ports against fake
  servers.

### Wishlist emails fixed and designed (12 Oct)
- Emails weren't arriving: PHP `mail()` doesn't deliver on OVHcloud. Now
  `wishlist.php` sends over **SMTP to `ssl0.ovh.net:465`**, logged in as
  `info@getsidekick.app`; the password is in `wishlist-config.php` on the
  hosting only (git-ignored). Failures go to `sidekick-wishlist/mail.log`
  (never the password). Tested against a fake SMTP server.
- "Got your email!" is now a **designed HTML email**: a header image
  (`website/email-header.png`: the glass "sk" logo, "Sidekick", "Your
  devices, together." on the purple gradient), the message, a **"Cancel my sign-up"
  button** (the remove link; the header image links to the site); plain text inside
  too for apps that don't show HTML. The image is attached inline, so it
  shows even when web images are blocked.
- `wishlist-check.php` sends a real test email the same way and shows the
  reason if it fails.

### A new ad made with Remotion (6 Oct)
- 62 s, 1080p 60 fps, 16:9 and 9:16, the trailer music, bold text on
  screen (no voice), every feature fast; the app's real screenshots in CSS
  device frames; Screen Mirroring on the music's drop. Error screenshots
  were swapped for working ones.
- Project: `scratchpad/remotion-ad` (React; `render.mjs` renders in
  10-second chunks; `stills.mjs` for checks). Remotion needs the headless
  shell browser: `/opt/pw-browsers/chromium_headless_shell-1194/...`.
  Sent compressed to ~28 MB (upload limit 30 MB).

### Documents (5–6 Oct)
- `ARCHITECTURE.md`: one Flutter app, no backend (each device runs its own
  HTTPS server on 53318, the `/v1` API), where data is stored, the
  wishlist script, **no sign-in, no payments**.
- Terms of Service corrected to match reality (sent as a file, not in the
  repo).

### Website: real wishlist, new domain (5 Oct)
- The site moved to **getsidekick.app** (official domain).
- The wishlist form became real: `wishlist.php` (PHP, no database; list in
  `sidekick-wishlist/list.csv` outside `www`), "Got your email!" with a
  remove link, a note to info@ per sign-up, anti-bot trap, 2-second
  minimum, 5 tries an hour per hashed IP. Both privacy policies updated.
- Earlier (5 Oct): the site became a wishlist instead of downloads (the
  owner's call), with a placeholder form at first.

### The trailer (5 Oct)
- 1:02, every feature, on the "hitslab technology tech presentation"
  track, cut at 1:02; buttons build up with the music, Screen Mirroring on
  the drop. Python/PIL 3D renderer (`scratchpad/video/trailer.py`, on top
  of `ad8.py`, `dev3d.py`, `models3d.py`).
- Versions: music-only and with the owner's **ElevenLabs voiceover**
  (`vo_mix.py`: phrases placed on their scenes, no ducking, music -2 dB);
  end card says getsidekick.app.

### Sidekick 2.13.0 (5 Oct)
- **Screen Mirroring:** Mac/Windows watch a paired iPhone/Android screen,
  lossless (changed 64 px tiles, zlib), Fast/Sharp. Android:
  MediaProjection (`ScreenMirror.kt`); iPhone: a ReplayKit broadcast
  extension (`ios/SidekickMirror`). The phone asks first.
- **Phones stay on:** Android keeps its engine and service running (even
  swiped away, from boot); the iPhone's silent keep-alive repairs itself.
- Android notifications and sounds work with the app closed.

### Earlier ads (before 5 Oct)
- **ad8**: 3D iPhone 17 Pro (Cosmic Orange) and MacBook, synced to the
  music, highlight words in a pink-to-gold gradient (no cursive), 9:16
  TikTok-safe; the clipboard scene pastes getsidekick.app.
- Voiceover scripts for fish.audio and ElevenLabs (tags in `[]`, one
  emotion each; ElevenLabs reads any timestamps aloud, so none in the text).

### Before this history starts
- Releases 1.1.3 to 2.12.0: see `VERSIONS.md`.

## How to work here (quick reminders)
- Flutter: `/home/user/tools/flutter/bin`; `dart format -l 120`,
  `flutter analyze` clean and `flutter test` passing before any push.
- Release when done and CI is green: run the `Build` workflow with
  `release_tag: vX.Y.Z`, then add an entry to `VERSIONS.md`.
- Commit messages end with the Co-Authored-By and Claude-Session lines.
- The owner uploads the website with FileZilla; send them the changed
  files. Never put the FTP login or the mailbox password in git.
- Update this file when something notable is done.
