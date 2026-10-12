# What we've done (session history)

A running record of the work on Sidekick, for picking up after `/clear` or in
a new session. Newest first. For how things work, read `CLAUDE.md` (the
detailed developer notes, including every release in "Versions") and
`ARCHITECTURE.md` (the big picture).

## Where things stand (12 October 2026)

- **App:** latest release **2.13.0** (Screen Mirroring, phones that stay on
  in the background), published on GitHub with all six files and on
  TestFlight. Branch: `claude/sidekick-app-architecture-8ilytw`.
- **Website:** **getsidekick.app** (OVHcloud, free 100 MB hosting with
  email), uploaded by the owner with FileZilla into `www`. It's a
  **wishlist page, not a download page** (Sidekick isn't out yet).
- **Wishlist:** works, emails confirmed arriving (12 Oct, the check page's
  test email reached info@getsidekick.app).
- **Ads:** three finished videos (below), all made outside the repo, in the
  session's scratchpad.

## Waiting on the owner

1. **Wishlist:** delete `wishlist-check.php` from the hosting. People who
   signed up before the fix never got their email: offered a one-time resend.
2. **Terms of Service:** fill in the country in section 9; the copyright
   line should name a real person or business. Not on the site yet
   (offered as `terms.html`).
3. **Privacy policy:** still mentions the Microsoft Store as an install
   source, which isn't true (offered to fix).
4. **Launch, when ready:** bring back the download section (in git history,
   2.12.0), make the site findable on Google, and build the "email everyone"
   page for the wishlist (password-protected, sends in small batches).
   Decide what iPhone users are told (no App Store; AltStore/TestFlight).

## History

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
- Releases 1.1.3 to 2.12.0: see "Versions" in `CLAUDE.md`.

## How to work here (quick reminders)
- Flutter: `/home/user/tools/flutter/bin`; `dart format -l 120`,
  `flutter analyze` clean and `flutter test` passing before any push.
- Release when done and CI is green: run the `Build` workflow with
  `release_tag: vX.Y.Z`, then add a "Versions" entry in `CLAUDE.md`.
- Commit messages end with the Co-Authored-By and Claude-Session lines.
- The owner uploads the website with FileZilla; send them the changed
  files. Never put the FTP login or the mailbox password in git.
- Update this file when something notable is done.
