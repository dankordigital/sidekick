# What we've done (session history)

A running record of the work on Sidekick, for picking up after `/clear` or in
a new session. Newest first. For how things work, read `CLAUDE.md` (the
detailed developer notes; every release is in `VERSIONS.md`) and
`ARCHITECTURE.md` (the big picture).

## Where we are and what's next (14 November 2026, before /clear)

**Done (13–14 Nov, design only; the Flutter app hasn't changed yet):**
- One look only: Nothing and Liquid Glass are being scrapped (CLAUDE.md).
- The new look, designed three ways: the Design canvas
  (https://claude.ai/artifact/N5YczZk3EXsqbULx56Qfxf), Claude's clickable
  prototype (https://claude.ai/artifact/PT9J7jBD417cBNMAwiBaQL), and, the
  one that counts, **the owner's Figma design** (`design/figma/`: the
  Prototype page, 183 screens, and Styles & Components: Foundations tokens,
  components, icons, photos) made clickable as the **Sidekick emulator**
  (https://claude.ai/artifact/Rbd3YL2REDeDKtCK5z3px5, `design/emulator/`).
- Decisions made along the way: the phone's floating dock (Devices · Chat ·
  Send · Remote · Settings; selected tab a white pill with its name); **no
  attention dots or badges**; **Chat is not a messaging app** but one place
  per device for files, photos, links and notes (filters, search, item
  cards with ⋯ menus); the message bar's Send files turns into a round Send
  button while typing; verification codes only from phone notifications
  (CLAUDE.md).
- Figma AI prompts (`design/figma-ai-prompt.md`, `figma-ai-prompt-chat.md`,
  screenshots in `design/reference/`).
- Logo: lots tried and dropped (letter marks; a split circle too close to
  SumUp's; overlapping squares too close to copyui's; planets; blobs).
  **Five candidates** in `design/logo-ideas/` (Hinge, Embrace, Lock, Bloom,
  Pair), each also with "Sidekick" beside it (`lockups/`). **The owner hasn't
  picked one.** Claude's pick: Pair (two colours, bigger step, so it isn't a
  pause icon).

**Next:**
1. The owner picks the logo (or a mix). Then: finish it, run a trademark
   check (Google Lens, WIPO Global Brand Database), and make every icon from
   it (`app/tool/make_icons.py`: app icons on all four platforms, tray icons,
   website favicon and touch icon) and the website's wordmark.
2. Build the Figma design into the Flutter app, screen by screen, using the
   emulator and `design/figma/` as the reference and the Foundations tokens
   as the theme: the dock, the Chat tab (it needs a stored per-device
   history of everything sent and received), Devices, Send, Remote,
   Settings, Connect, sheets and notices. Remove the Nothing and Liquid
   Glass looks while doing it (CLAUDE.md lists what to take out). Then
   rebuild the website's live demo (`app/tool/build_preview.sh`).
3. Verification codes only (CLAUDE.md, "Verification codes only"): change
   the phone-notification relay, the computer's notification, the setting
   and both privacy policies.
4. Release as usual once CI is green.

## 14 November 2026

- **4.0: swipe along the dock** to change tabs (haptic tick), tabs glide in from their side; plan: less bloated by Fitts's law (whole rows as targets, main action big and near the thumb, the rest behind a hold); `ui/kit.dart`, the design's building blocks for the rebuilt screens.
- **4.0 course change** (the owner: "this looks nothing like the promised design"): screens were being recoloured, not rebuilt. From now on each screen is rebuilt to match its Figma picture and the emulator, checked side by side with the design before it's ticked (`design/4.0-build-plan.md`, "How each screen is built"). Devices first.
- **4.0, step 4a:** a paired device's card shows the last thing shared and opens its Chat when tapped.
- **4.0, step 3b: the Chat tab** (`ui/chat_page.dart`): per-device cards (files, links, notes, 6-digit codes with Copy code), hold for actions (✕ to close), the message bar whose Send files turns into Send while typing. Dock has 5 tabs (Devices · Chat · Files · Remote · Settings). Analyze clean, tests and sizes_test pass.
- **4.0, step 3a: the Chat history** (`core/history.dart`): every file, photo, link and note sent or received is kept per device (500 each, `history.json`), with 6-digit code detection; AppState records it. 114 tests pass.
- **4.0, step 1b-ii: the Nothing and Liquid Glass looks are deleted** (3,000+ lines), with every branch that used them. Analyze clean, 109 tests, sizes_test, screenshots_test and transfer_shots_test pass. Also planned: home-screen widgets on Android and iPhone (step 9b) and the app-icon choice only in Settings.
- **4.0, step 1b-i: one look only.** Old looks can't come back (saved choices ignored, Settings and the welcome no longer offer them); Make theme deleted. Analyze clean, 111 tests, sizes_test passes.
- **4.0, step 2a: the floating dock on phones** (`ui/dock.dart`): the selected tab springs open into a white pill with its name. Analyze clean, 115 tests, sizes_test passes (no overflow at 360/430 wide, 100/150 % text).
- **4.0, step 1a: the app wears the 4.0 colours** (`sidekick4Scheme`: #121212 / #1c1c1c / #262626, white pill buttons with dark text, dark only). Analyze clean, 115 tests pass, renders checked. Next: 1b (remove Nothing, Liquid Glass, Make theme), then the dock (plan, phase 2).
- **4.0 is next, by plan** (`design/4.0-build-plan.md`): the owner asked for 4.0 (the app like the prototypes, smooth motion, released with screenshots). It starts when the usage limit resets (a scheduled check-in in this session), phase by phase, each phase green and pushed; the plan's boxes are the progress record.
- **The emails are in the 4.0 look** (`wishlist.php` `email_shell`, used by the welcome email and np7dpanel's announcements): dark card, the new header (Dusk "sk" + wordmark), "Got your **email!**", chips, a white "Try the demo" pill beside "Cancel my sign-up", the Dusk icon in the signature, "Made with ♥ in Poland". The plain-text part links the demo too. Checked with a real local sign-up (outbox) and a rendered announcement.
- **A new "sk" logo** (`design/logo-sk/`, the owner: same letters, new
  background and colours): eight icons from `3.png`'s letters (Ink, Paper,
  Sky, Amber, Mint, Signal, Chrome, Dusk; `board.png`). **Dusk** (white on
  blue → purple → coral) is now the website's and the demo's icon: tab icon,
  home-screen icon, beside the wordmark, the Mac's Dock and the Sidekick
  window. **4.0 will let people choose their app icon** from all eight
  (CLAUDE.md; not built yet).
- **Short addresses** (the owner: "redirect to getsidekick.app/preview"): every link goes to `/preview` and `/privacy`; `.htaccess` serves them and sends `/preview.html` and `/privacy.html` there (301). Checked on a real Apache: 200s, 301s with the query kept, 404 page, noindex header.
- **The demo's Mac looks like a Mac**: a MacBook with a notch and an aluminium base, a macOS-style wallpaper, a translucent menu bar (Apple logo, menus, Sidekick's menu-bar icon, battery, Wi-Fi, Control Center, date and time), a glass Dock (Finder, Safari, Music, Notes, the real Sidekick icon, running dots, hover lift), coloured window buttons; the iPhone got a Dynamic Island.
- **`preview.html` is the 4.0 design** (the owner: "make the newest design,
  not the old one"): rebuilt from the emulator's own CSS and icons
  (`design/preview/build.py`): a MacBook desktop with the 4.0 Sidekick window
  and an iPhone with the 4.0 screens; sending both ways with the amber
  request, the Sending ring and the chat's receiving card; Remote with the
  touchpad, clicks, scroll, keyboard and shortcuts. (Renders of the current
  app were tried first and dropped.)
- **The 4.0 website is live in the repo** (`index.html`, from the prototype):
  the real wordmark (`website/wordmark.png`, white, from `2.png`), no
  PROTOTYPE badge, wishlist / released looks (`only-wish` / `only-released`,
  index.php's `class="released"` and `SIDEKICK_RELEASE` fill the Devices
  tiles and the hero's Download), the form posts to `wishlist.php` (device
  chips, honeypot, 2-second minimum; checked with `php -S`: signed up, welcome
  email in the outbox), "Try the demo" → `/preview.html`, Privacy →
  `/privacy.html`; the panel's editor finds every text (165). **Phones get
  their own layout** (full-width buttons, Try it as a row of chips, one-column
  card stack, stacked form; the glow sits in a clipped box so the page is
  never wider than the phone) and things face your finger.
- **`preview.html` rebuilt** (the owner: the old one never worked; "just
  file sending and remote controlling"): a self-contained demo, a MacBook
  screen and an iPhone. Send files both ways with the real Accept flow;
  Remote: the phone's touchpad moves the Mac's pointer, tap clicks, scroll
  strip, play/volume keys, typing into Notes. Source
  `design/preview/preview.src.html`.
- **Canva AI logo prompt** (`design/canva-ai-logo-prompt.md`): what Sidekick is, who it's for, the app's look, the rules (abstract, two-together, rounded, 16 px, no letters / devices / SumUp- or copyui-like shapes), and 10 named directions.
- **Website prototype for 4.0** (https://claude.ai/artifact/KN5qtaJH4dWXy3JHoqPLnt,
  `design/website-4.0/`: `site.src.html` is the source, `index.html` the
  page with the emulator's icons put in): the wishlist page in the app's new
  look (#121212, #1c1c1c panels, white pills, Inter + JetBrains Mono labels),
  the 4.0 chat working in the hero (Copy code on 6-digit codes, hold a card
  for actions, ✕ / flick down, one notice at a time; "Try it" buttons play
  the MacBook), What Sidekick does, pairing in three steps, devices (coming
  soon), questions, the wishlist form (prototype: sends nothing). Not live:
  the real `index.html` is unchanged. **Next: the owner says when to build
  4.0** (the app in the new design, then this site for real).
  Then: "Two at once" (notices taking turns: "not a feature", the owner)
  became **Ring this phone** (the Ping screen with Found it!), and a **Free**
  section with the old site's holographic FREE (pastel chrome, moving shine,
  tilts toward the pointer) sits after What Sidekick does.
  Then **glossy headings**: every heading is chrome (white to grey, lit from
  above, per line) with a slow sheen passing through every 9 s, and each
  has one **keyword in an app colour**, glossy too: "as one." blue, "in one
  place." green, "three steps." amber, "every device" orange, "know." blue,
  "try it." green.
  Then **motion with the scroll and the pointer**: a thin line in the app
  colours under the top bar shows how far down you are; sections and cards
  rise in as they scroll into view (only what starts below the first
  screen); the hero phone leans toward the pointer and drifts with the
  scroll; cards get a soft light under the pointer and tilt slightly, their
  icon tile turns; the Send files card's bar fills as you scroll (Received ✓
  in green when full); the touchpad card's dot follows your pointer and
  ripples on click; the Ping chip's bell wobbles on hover; the pairing code
  types itself in, then "Paired" pops. Reduced motion turns it all off;
  pointer effects only with a mouse.
  Then (the owner: "I meant…"): **the features are a stack of cards**: each
  big card (text left, its picture right; one column on phones) sticks below
  the top bar and the next slides up over it; the one underneath shrinks and
  dims a little. **Things face the pointer** like the FREE: the headings,
  the hero phone, the pairing steps, the device tiles and each card's
  picture turn slightly toward the pointer wherever it is on the page (the
  per-card hover tilt is gone; the soft light under the pointer stays).
  Then **smooth motion everywhere** (one engine, `frame()`: every moving
  value eases toward its target each frame): pointer-facing with inertia; a
  soft colour glow follows the mouse; the hero rises in on load; the stack's
  cards come in tilted back and lower, straighten as they arrive, then sink,
  shrink and dim into the pile; buttons pull toward the pointer (magnetic),
  get a shine on hover and a springy press; every click ripples; nav and
  footer links underline; chips and rows lift; icons spring; questions open
  and close smoothly; joining the wishlist bursts the app's colours.
  Reduced motion and touch screens skip the pointer parts.
  Then: the owner saw only the progress line move (their device asks for
  reduced motion, which froze everything). Now reduced motion means **calm,
  not frozen**: hovers, fades, ripples, questions and the stack piling up
  still animate; only tilting, following the pointer, the glow and the
  magnetic pull stop. A **Motion** switch in the top bar turns full motion
  on or off (remembered, `sk-motion`).
  Then the owner ("THAT'S FIRE"): **full motion for everyone by default, no
  switch** (`CALM=false`; the calm styles stay in the CSS, unused).
- **Emulator: hold for actions, 6-digit codes, one notice at a time** (the
  owner): only a **6-digit code** gets the big **Copy code** button
  (`codeOf`: "482913", "482 913", "G-482913 is your Google code", "Kod BLIK
  123456"; not 4- or 8-digit numbers, not order numbers without "code").
  Every other card has no ⋯ any more: **hold it** (right-click or the Menu
  key on a computer) for all its actions (Open, Copy, Show in folder, Send
  again, Remove). That sheet closes with **✕** or a **flick down** (grab
  handle; no Cancel). Notices show **one at a time**: a new one waits, the
  one showing leaves 3 s later (its bar speeds up to match), at once on ✕ or
  swipe; hovering or touching it pauses it.
- **Emulator: quieter copying** (the owner: "just let people copy and don't
  tell them"): the "Copied" sheet is gone; copying says nothing. Notes and
  links have no Copy button any more: **long-press** (or right-click on a
  computer) the card to copy it (a small press-in, a tick of vibration).
  **Only a verification code gets the big button**: a note that is a code
  (`codeOf`: just 4–8 digits, or "verification / one-time / your code is…"
  with a number) shows the code big and a white **Copy code** that copies
  only the code (sim: "Pixel 9 gets a verification code"; no notice for it,
  it would cover the button). Notices can be **swiped down** to close
  (besides ✕ and the bar running out). Remote's shortcut keys and typing
  no longer show "Sent to …" notices. Carry all of this into the Flutter
  app when the new design is built (the old `ReceivedTextDialog` still
  says "Copied" on its button).
- **Sidekick emulator from the owner's Figma design**
  (https://claude.ai/artifact/Rbd3YL2REDeDKtCK5z3px5, source in
  `design/emulator/`): phone and computer, built from the Figma Foundations
  tokens, components, icons and photos. Every Prototype-page screen works:
  Devices (Needs you, favourites, paired, nearby, first launch), Chat (device
  picker, filters, search, item cards and their ⋯ menu, waiting / receiving /
  received / declined, not reachable, the message bar that turns into Send),
  Send and Sending, Remote, Settings, Connect (nearby / QR / code), Browse
  files, Ping, notices, error. A side panel plays the other devices.
  Checked end to end in Chromium (`check.js`).
- **The owner's Figma design, "Prototype" page** (`design/figma/prototype/`,
  183 PNGs at 2x: 102 phone 390×844, 81 computer 1280×800, plus
  `History overlay/Phone|Computer` sheets and menus) and its "Styles &
  Components" page (`design/figma/styles-and-components/`).
- **Logo ideas** (`design/logo-ideas/`, the owner: "these are amazing"; none
  picked yet): five abstract, symmetrical, round-edged marks with no letters,
  devices or dots: Hinge, Embrace, Lock, Bloom, Pair (board:
  `five-logos.png`). Claude's pick: Pair, as two colours with a bigger step
  so it isn't read as a pause icon. Rejected along the way: letter marks,
  a split circle (SumUp's), overlapping squares (copyui's), planets, blobs.
  Each also as a lockup with "Sidekick" (Inter Display Bold, outlined) in
  `design/logo-ideas/lockups/` (dark text and light text; board `lockups.png`).
- **Prototype: Send files becomes Send while typing**: typing in the
  message bar shrinks the white "Send files" pill into a round send button
  with an up arrow (it sends the text); sending or erasing brings "Send
  files" back. Also in both Figma prompts.
- **Chat isn't a messaging app** (follow-up Figma prompt,
  `design/figma-ai-prompt-chat.md`): Figma AI read the Chat tab as a chat
  with a person. It's one place per device for everything sent between
  your own devices (files, photos, links, notes), only borrowing a chat's
  familiar layout: no typing, receipts, reactions or chatty sample text;
  items are cards with actions; filter chips (All · Files · Photos · Links ·
  Notes), search, an empty state; the bar says "Write a note or paste a
  link".
- **No attention dots** (the owner's call): no badges, dots or counters
  on the dock or icons when something needs you; the amber "Needs you"
  card and the amber device already show it. Taken out of the prototype,
  the Figma prompt and its screenshots; written into CLAUDE.md.
- **A prompt for Figma AI** (`design/figma-ai-prompt.md`, one prompt):
  how the new look works (colours, colour only for meaning, white pills,
  the dock and the dock-shaped message bar, the logo), every phone and
  computer screen and state, how to build it in Figma (pages, styles,
  components with variants, auto layout, the clickable prototype), then
  improve it on a separate "Improved" page. Figma AI can't open our links,
  so `design/reference/` has screenshots of the prototype (11 phone, 4
  computer) to drag in with it.

## 13 November 2026

- **One look only** (the owner's call): Nothing and Liquid Glass will be
  scrapped; the regular dark look from the concept and prototype is the
  app's only look. Written into CLAUDE.md (not built yet).
- **A clickable prototype of the new look**
  (https://claude.ai/artifact/PT9J7jBD417cBNMAwiBaQL, private, not in the
  repo): a phone and a computer (switch at the top) where everything works
  for pretend. On the phone: the rounded dock (the selected tab grows into
  a white pill with its name), Chat (switch devices, type and press Enter,
  a pretend reply, + to add files, photos, a link or paste, Send files opens
  the real file picker), Accept/Decline in the chat or in the sheet with a
  progress bar, Send (pick, then Send to a device, with the progress ring,
  Stop), Remote (drag the touchpad, clicks, keyboard), Settings (switches,
  Quick save, Theme, Rename), browsing another device's files, Connect
  (pair with code 481705), and Ping. The computer has the same chat with
  drag and drop, Files, Remote and Settings. Buttons beside it play the
  other side (a link, files arriving, a note, a ping). A standalone page,
  separate from the Design canvas.
- **The app concept now covers every screen** (same Design canvas,
  https://claude.ai/artifact/N5YczZk3EXsqbULx56Qfxf, 13 artboards).
  Computer: Devices (chat), Remote, Settings. Phone: Devices, **Chat**
  (a new tab: device strip on top, the conversation, Accept/Decline in
  line), Files coming in, Send, Remote, Settings, browsing another
  device's files, Connect a device (QR code / 6 digits), Sending, Ping.
  The phone's tab bar is a floating rounded dock (Devices · Chat · Send ·
  Remote · Settings): the selected tab is a white pill with icon and name,
  the others just icons. The chat's drop zone is gone: a rounded message
  bar like the dock (+, "Message Pixel 9", white **Send files**), and
  dropping files on the computer's chat still works. Mock-ups only.
- **No sprites anywhere: regular icons** (the owner's call, end of the
  day). The website's felt "buddies" (too close to openbot.run's felt
  creatures: the owner worried about being sued) are gone: the "together"
  pair are pastel icon tiles (`.ico-tile`), the four on FREE, the two on
  the hero window and the footer parade are removed, icon tiles float
  around the wishlist, and the footer heart is a Material `favorite` icon.
  Along the way (both kept): the Boarding pass.pdf transfer bar fills as
  you scroll (with moving stripes), and FREE tilts as one piece. Tried and
  dropped the same day: a monochrome site (the owner meant the mockup) and
  8-bit pixel-art device sprites.
- **The app concept redone so it isn't openbot's look** (Design canvas
  https://claude.ai/artifact/N5YczZk3EXsqbULx56Qfxf, 4 artboards: computer
  window, phone Devices, phone "Files coming in" sheet, phone Remote). Now:
  dark like the website (#121212 page, #1c1c1c panels, #262626 raised),
  Figtree font, white pill buttons, colour only where it means something:
  each device has its own colour on a regular device icon (iPhone/PC
  blue, iPad green, Pixel/MacBook Pro amber, unreachable grey) with a
  green status dot; "Needs you" and file requests amber (Accept is the
  amber button); gold star for Favorites. Kept from before: the chat-style
  history per device (sent bubbles right, received link card, request
  card) and the "Needs you" card. The phone screens got a bottom tab bar
  (Devices · Send · Remote · Settings). The canvas is generated by a script
  in the session scratchpad (gone after the session); edit the artboards
  directly next time.
- **Interactive chat mockup** (a standalone .html sent to the owner, not in
  the repo): the computer screen where you can type a message (Enter
  sends, Shift+Enter new line, links clickable), add files with a paperclip
  or by dropping them (chips with ×), and Send: bubbles with a progress bar
  → "delivered ✓", a pretend "Pixel 9 is typing" reply; Accept / Decline on
  the request card work. Idea for the real app: a composer at the bottom
  of each device's history instead of only a drop zone.
- **Figma**: a zip of the site's screenshots and prompts for Figma AI
  (referencing the "Ideas" artboard) were made for the owner.
- **Sprites redrawn as "buddies"** (the owner sent openbot-style felt
  creatures: "not the kawaii ones", different but good): soft geometric
  bodies in our pastels with a felt grain, a glossy top light and white
  pill eyes in six moods, no mouths.

- **The site made our own** (the owner: same colors, more animation, less
  like openbot; keep the glossy FREE; "Made with love in Poland"; cute
  sprites instead of the sk tiles): a cast of sprites (phone, laptop,
  tablet, file, folder, bell, chat, heart) perched on the hero window,
  sitting on a holographic FREE, floating around the wishlist and walking
  in the footer; the looks deck fans out on scroll. Checked: sign-up, the
  embedded demo in Chromium and WebKit.

## 11 November 2026

- **New website look, after openbot.run** (the owner: "remake my site as
  openbot.run made"; its style only, Sidekick's own words and pictures):
  dark Inter pages with huge tight headings, pill buttons, a big app window
  in the hero (the live demo runs in it), cards holding real bits of the app
  (Accept card, touchpad, file list, link card, Ping, Live Activity),
  a giant "Free", pastel tiles for the four looks and for each platform,
  Questions, and the wishlist over a field of tiles. Light mode with the
  moon. preview.html, privacy.html and 404.html share the colors. Kept
  working: the wishlist form, released mode (tiles link to the files),
  sounds, the panel's Edit (old edits to texts that changed do nothing).
  The old drawn demo (Send files animation, file browser) is gone: the
  real app does it. Checked: wishlist sign-up, released mode, every
  browser's demo check. **Released 3.0.5.**
- **A concept of the app in the same look** (not built): a Design canvas,
  https://claude.ai/artifact/N5YczZk3EXsqbULx56Qfxf (computer window with
  devices as a list and each device's files and links as a conversation;
  phone Devices, files coming in, Remote).

- **The demo works in every browser** (Part 1 of the owner's four-part
  brief: every browser; plain wording; errors in a pop-up with Close and
  successes in a 5-second notice; better look on every screen).
  `app/tool/check_preview.sh` + `preview.yml` check Chromium (Chrome, Edge,
  Opera, Samsung Internet), Firefox and WebKit (Safari) end to end. Found
  and fixed: Chrome crashed on start where the system language is "C"
  (Linux); on iPhones both apps drew at 3× and text turned into blocks
  (now each draws at the size it's shown); the Mac's pairing code was
  invisible to screen readers; Paste did nothing when the browser refused
  the clipboard (now it says how to paste by hand). Old browsers get a
  picture and what to do; no graphics acceleration gets a "may be slow"
  note. `dart format` now reads the 120-column width from
  `analysis_options.yaml`.
- **Plain wording** (Part 2): jargon out of the screens (AES-256-GCM, TLS,
  certificate, Bluetooth LE, "adapter can't advertise", IP, a camera error
  code), "Grant" → "Allow", Unpair says files stop too, Remote says how to
  allow control on the other device, a dropped Remote says what to check,
  the waiting sender says "Waiting for an answer…". Messages that arrive
  from the other device ("Wrong code", "Not paired"…) stay as they are on
  the wire (older devices send them, and code matches some): Part 3 turns
  them into plain words where they're shown.
- **Errors are a pop-up, successes a 5-second notice** (Part 3).
  `explainError` knows ~20 kinds of problem (can't reach, different Wi-Fi,
  not paired / reset, wrong or expired code, declined, no answer, already
  ringing, no space, folder not allowed, file gone, each permission,
  Bluetooth off, firewall, connection dropped, older Sidekick, too big,
  damaged on the way, turned off on the other device, unknown), each with
  a title, why, numbered steps and a fix button where one helps. Notices
  replaced every snackbar. Found on the way: the notice's text was
  invisible to screen readers while it faded in (fixed and tested).
- **Every screen size** (Part 4). New `tool/sizes_test.dart`: every tab at
  6 sizes × 2 text scales × 2 looks, failing on overflow (none found).
  Looked at the pictures and fixed: a paired device's name was cut to
  "Pixel…" with big text on a phone (the button now goes under it); Quick
  save's choice squeezed its description to one word per line; the
  Nothing look's light grey text was 3.3:1 (now 5:1, #666661; a contrast
  test covers every built-in theme); tablets get dialogs like computers;
  phone tap areas ≥ 48 points; the Remote "send text" button had no name.
  Speed: the whole app rebuilt up to ten times a second during transfers;
  now only when its look changes. Not done: one spacing scale across the
  app (hundreds of hand-tuned values, some from the owner's approved
  Nothing mock-ups; too risky blind).
- The cloud environment is now **sidekick** (personal), which can download
  Playwright's Firefox and WebKit (cdn.playwright.dev).

## 8 November 2026

- **The live demo is the real thing, on the home page** (the owner: "make
  most of the app work … make users first connect the device and then they
  can use the app's preview however they like"). The two demo devices start
  unpaired and pair like real ones (6-digit code or QR code); then Files,
  Settings, Send, links, Ping, Remote and Unpair all work. The home page's
  "The app" section keeps its drawing with a new **Run the real Sidekick
  here** bar that loads the demo in its place. Also on the home page: a
  **Links and notes** card (NEW), notifications + screenshots merged into
  "Your phone, on your computer", and an "On every device" strip under
  Platforms. Clicked through in a headless browser.
- Fixed on the way (real app too): notices with a button ("Received … ·
  Show in folder") never went away (Flutter keeps such snackbars up; now
  6 s); Copy on a received link no longer hangs if the clipboard refuses.
  Demo only: Allow files / Allow control crashed, a link or ping arriving on
  the "Mac" threw, Show in folder threw.
- Noticed, not changed: a real iPhone's Settings shows the receive folder as
  a raw /var/mobile/… path.
- **To upload to `www`:** `index.html`, `preview.html`, and the whole
  `website/app/` folder.
- **Released 3.0.4** (the two app fixes above). On the way, Windows CI
  failed a test that opened a fixed port (53399, refused with errno 10013
  on that runner); the test now asks for a free port.

## 3 November 2026

- **The website follows new releases by itself** (the owner: "edit
  automatically its release version when released"). Released, the home
  page offers the newest GitHub release once all seven files are up
  (`offered_version`, `release_complete`); "Pin this version" in the
  panel's Website tab keeps one. Checked against the real 3.0.3 release.
- **The panel's Edit tab is visual** (the owner: "make the editor
  visual"): the home page itself, click a text and type, Wishlist /
  Released and Computer / Phone views, a list of changes with Undo, Save.
  The old list is "All texts as a list". Tested in a headless browser
  (log in, edit the headline, save, the live page shows it; links do
  nothing; Released view gets 3.0.3).
- **To upload to `www`:** `index.php`, `wishlist.php`, `np7dpanel.php`.

## 31 October 2026

- **Sidekick Pro preview** (the owner asked for screenshots of Pro features
  behind a paywall): a design canvas, not in the repo and not in the app:
  https://claude.ai/artifact/YanGDe2W5oPby8iH6w1MJf (private). Two
  computer-size screens: the free app's Devices tab (3 of 3 devices,
  "Send to all" and "Connect device" locked, a "See Sidekick Pro" banner,
  six greyed-out Pro tiles) and the paywall (what Pro unlocks; Monthly /
  Yearly switch with "Save 44%"; Start Pro; Lifetime paid once through a
  payment link sent by email; ✕ top right). The Pro features and the
  prices ($2.99 / month, $19.99 / year, $39.99 lifetime) are placeholders
  for the owner to decide; prices are tweakable on the canvas. Nothing
  decided yet: no payments in the app.
- **App 3.0.3: the link / note card redesigned** (the owner: make it good
  by UI/UX rules; then: no Close button, an ✕ top right, the icon on the
  left). See CLAUDE.md "Links and notes". Rendered at phone and computer
  size, default / dark / Nothing (`text_*.png`).
- **App 3.0.2: send a link or a note** (the owner picked it from Claude's
  ideas for a feature that surely works on all four platforms, and asked
  that the receiver always be asked Copy or Open, even from favourites,
  instead of getting a .txt file). `/v1/text`, `ui/text_messages.dart`;
  see CLAUDE.md "Links and notes". Other ideas offered and not built: a
  "Recent" history in the default look, and "Share to Sidekick" from other
  apps (needs a Swift share extension, which can't be built here).
  Released as v3.0.2 (CI green on all four). **Waiting on the owner:** try
  it between real devices (a link from the phone to the Mac in the menu
  bar: the window should open with Copy / Open), and upload `website/app/`.
- **Watch preview, then decided against** (the owner asked what Sidekick
  would look like on a watch): a design canvas, not in the repo:
  https://claude.ai/artifact/VLxqyk6VLdSaowDEC3w7S8 (private). Apple Watch:
  Devices, a device page (Ping, Slides, Last photo, Type), a slides remote
  (Next / Back / Blank), an incoming request, receiving with a ring; Wear OS:
  a round device list and a round request. Dark, Sidekick's lavender accent.
  **The owner's call: no watch app for now.** Why: the phone's Accept /
  Decline notifications should already reach a paired watch on their own
  (not checked on a real watch), an Apple Watch app can't be made in
  Flutter (Swift only, which can't be built in these sessions), and the
  launch matters more. If people ask after launch: a small Wear OS app with
  Ping and Accept / Decline first.
- **Waiting on the owner:** try 3.0.1's new Windows installer by hand (CI
  only ran it silently): the permission prompt after Install, and Open
  Sidekick at the end. Try a resumed transfer between real devices (switch
  Wi-Fi off and on mid-send). Upload `website/app/` (the 3.0 preview).

## 25 October 2026

- **App 3.0.1: Sidekick's own Windows installer** (the owner: "make your
  own installer for the .exe but keep .dmg's how they are"). Inno Setup is
  gone; `app/windows/installer/` is a C# WinForms program drawn by hand
  in Sidekick's look, which is also the uninstaller. CI installs, updates
  and uninstalls it on the runner and checks each step; its rendered pages
  go to the hidden ref `refs/ci/installer-pages` (`git fetch origin
  refs/ci/installer-pages`), since cloud sessions can't download artifacts.
- **App 3.0.0, "polished"** (the owner asked for a polished 3.0: design,
  connectivity, simplicity). Transfers resume after a dropped connection
  (Wi-Fi parts + downloads from an offset; Sidekick looks for the device
  and carries on), Stop while sending, time left, one calm "Can't reach"
  card in Files and Remote that retries by itself, Remote redials, device
  cards say how they're connected, plain-language errors everywhere, one
  card colour, Settings aligned, devices in even columns. See VERSIONS.md.
  The website preview (`website/app/`) is rebuilt with it: the website
  workflow uploads it, or upload `website/app/` by hand.

- **The Nothing ad's source, as a zip** (the owner asked for the code, not
  the MP4): `sidekick-nothing-ad.zip` (20 MB), a standalone Remotion
  project with only the Nothing ad: `src/nothing/` as in `trailer/`, its
  own `Root.tsx` (NothingVertical / NothingHorizontal only), `public/nothing/`
  and the two Inter fonts it uses, and a README (`npm install`,
  `npm run studio`, `npm run build`; what's in each file; headlines are
  `SCENES` in Ad.tsx, `^` makes a character red). Checked: it typechecks
  and renders. Made outside the repo (scratchpad); to make it again, copy
  those parts of `trailer/` into a fresh folder.
- **Waiting on the owner:** a listen to the ad. The app's sounds were
  boosted (+10 dB) and the music dips 40 % under them; the levels were only
  measured, not heard.

## 24 October 2026

- **The Nothing ad** (the owner's music, "Funky Funky Music", 42 s): the
  app's Nothing look on a 3D silver iPhone 17 Pro and a MacBook Pro, every
  cut on the beat. PHONE + COMPUTER = ONE, the "sk." logo, then 01 send
  iPhone → Mac (real Accept card and progress on both), 02 Mac → iPhone,
  03 screenshots land on the Mac, 04 browse the Mac's files, 05 touchpad
  and typing, 06 Ping, 07 no Wi-Fi (direct link), works on all four, end
  card "Join the wishlist · getsidekick.app"; the app's request / accept /
  ping sounds. 9:16 and 16:9 (`trailer/`, NothingVertical /
  NothingHorizontal; also rendered by `render.yml`). The screens come from
  `app/tool/ad_nothing_test.dart`.
- **App 2.19.0: Make theme** (the owner's plan from the day before):
  Settings → Theme → Make theme…, templates Default / Liquid Glass /
  Nothing, four colors with swatches and gradient sliders, a live preview,
  one saved theme with Edit / Delete.
- **Open, waiting on the owner:** a Nothing OS "widgets" direction (from a
  Nothing home-screen screenshot): round dark tiles and circles, dotted
  glyphs (15×15 icon set drawn), dot-matrix numbers ("2 READY",
  "47 MB SENT TODAY"), a red-dot "SEND FILES" pill, the tab bar as a long
  pill. Mock-ups only. To decide: plain paper/black background or a
  coloured blur, and whether it replaces the Nothing theme or becomes the
  default look. Also discussed (not done): renumbering to 1.0 for the
  public launch (old releases stay; Android build numbers must keep
  rising), store publishing, and a free launch with a later one-time
  "Plus" or tip jar.

- **App 2.18.0: the Nothing look redesigned** from the owner's approved
  "paper" mock-ups (light and dark): Devices · Send · Remote · Settings
  with dotted tab icons; Send works like LocalSend's (File / Folder /
  Media / Text / Paste, devices in reach with red send buttons, Browse
  files full screen with New folder, a new `/v1/fs/mkdir`); computers get
  a Receive column (this device, Quick save, recent). New for every look:
  "Always accept from …" (`AppState.alwaysAccept`) and Quick save
  (`QuickSave` off / favourites / on, replacing "Ask before receiving").
  A rebranded website was mocked up as an artifact (not uploaded).

## 23 October 2026

- **App 2.17.6: the Nothing look** (Settings → Theme → Nothing, a trial).
  Designed with the owner over several mock-ups (calm, a dark "glow" style,
  then Nothing's: black/white/red, dot-matrix titles; green only for
  "connected"; plain icons; logo "sk." with a red dot), then built 1:1 as
  its own screens. The app icon switches with it on every platform.
- **App 2.17.5:** fixed the iPhone freezing for good when the Liquid Glass
  tab bar area was tapped during the intro (the glass platform view now
  never holds touches). The intro plays only on the first launch; every
  other start shows a plain loading screen (logo + moving bar), and
  in-app waits use the same bar (`Loading`). Decorative gradients and
  glows removed everywhere (flat theme colors; tray panel solid).
- **App 2.17.3:** the Devices page no longer says "Pair over
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
- **Visits tab:** "Who visited" lists every IP address of the last 30
  days (bots marked, country / city / network from ipwho.is) and a
  countries chart (the owner suspected visits from Hong Kong). Both privacy
  policies say so.
- **preview.html:** "Try Sidekick, no download needed": the real app
  compiled for a browser (`app/lib/demo/`, `tool/build_preview.sh` →
  `website/app/`), running twice in the page as a Mac and an iPhone, paired:
  Send/Accept, Files, Remote, Ping, Settings all live. (A first version
  with screenshots was replaced the same day: the owner wanted the actual
  app.) `Platform.isX` → `Host.isX` everywhere for it.
- **iPhone Liquid Glass crash (released in 2.17.4):** tapping the tab bar crashed the
  app (Apple's UITabBar embedded as a platform view). It's now Sidekick's
  own tab bar on Apple's glass; and a crash right after starting with
  Liquid Glass turns it off next time, so the app always opens.
- **Connect a device** on computers is a centred dialog (it was a phone-style
  sheet from the bottom that a short window cut off); on phones the sheet
  scrolls.
- **preview.html checks itself:** if the app doesn't start in 15 s it says
  why (opened as a file, a `website/app/` file missing on the server, or
  `.wasm` sent with the wrong type: `.htaccess` not uploaded).
- **Owner to upload:** `index.html`, `index.php`, `wishlist.php`,
  `np7dpanel.php`, `privacy.html`, `preview.html`, `.htaccess` and
  `website/app/` (or let the website workflow do it). `website/preview/`
  on the hosting can be deleted.

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
    (iPhone: Sidekick's tab bar on Apple's glass since 2.17.4; the Mac draws its own glass,
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
