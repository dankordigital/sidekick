# Prompt for Figma AI: the Sidekick app design

Paste everything under the line into Figma Make (or First Draft) as one
prompt, and drag in the screenshots from `design/reference/` with it
(Figma AI can't open links to the Design canvas or the prototype, but it
can look at pictures): 11 phone screens (`phone-01-devices.png` …
`phone-11-add-to-chat.png`) and 4 computer screens (`computer-01…04`).

---

Design and build the app **Sidekick** in this file (the attached
screenshots show the look; match them, then build it properly): a complete, clickable
design for a phone (390×844) and a computer window (1280×800), built from
proper styles and components.

## What Sidekick is

One app for iPhone, Android, Mac and Windows that makes your phone and
computer work as one. You send files both ways, chat with your own devices
(links, notes, files), browse another device's files, use the phone as a
touchpad and keyboard for the computer, and ping a lost device. Everything
is encrypted; there is no account and no cloud: devices talk directly over
Wi-Fi.

## How it looks

Dark, calm and flat, like a well-made Apple app. Not futuristic, not
"AI-made".

- **Colours.** Page `#121212`. Panels and cards `#1c1c1c`. Raised items and
  inputs `#262626`. Secondary buttons `#2e2e2e`. Hairlines: white at 8%.
  Text `#f2f2f2`, secondary `#a1a1a6`, faint `#8a8a8f`.
- **Colour only where it means something.** Green `#45d07e` = connected
  (small status dots, "Same Wi-Fi · encrypted"). Amber `#ffc56b` on a dark
  amber card `#2f2410` (border amber at 25%) = something needs you: a file
  request and its Accept button. A gold star = favourites. Each device has
  its own icon colour (blue `#5b9dff`, green `#4fcf86`, amber `#ffb84d`;
  grey `#8a8a8f` when it can't be reached).
- **Buttons.** The main button is a **white pill** (`#f0f0f0`, text
  `#141414`). Second buttons are dark pills (`#2e2e2e`) or outlined pills
  (white at 15%). Everything a person taps is fully rounded. Cards have a
  20 pt radius; device icons sit in rounded squares (30% radius) with a
  12 pt status dot at the bottom-right corner.
- **No gradients, no glows, no glass or blur, no emoji, no illustrations or
  characters.** Shadows only on things that float (the dock, the message
  bar, sheets, notices): soft, black at 50%, 10 pt down, 30 pt blur.
- **Type.** Figtree (or SF Pro). Page titles 30 bold, tight. Section labels
  12.5 semibold in secondary grey. Body 14–15 regular; names semibold.
  Big confident titles; everything else quiet.
- **Words.** Plain and friendly, never technical: "Pixel 9 wants to send
  you 3 files", "Not reachable · seen 2 h ago", "Try again", "Found it!".
- **Accessibility.** Touch targets at least 44 pt; text contrast at least
  4.5:1.
- **Icons.** Simple 2 pt outline icons (Lucide or SF Symbols style).

## The signature pieces

- **The dock** (phone): floats 16 pt from the sides and 24 pt from the
  bottom; fully rounded (radius 32), `#1c1c1c`, a faint border, the float
  shadow, 8 pt padding. Five tabs: **Devices · Chat · Send · Remote ·
  Settings**. The selected tab is a **white pill (48 pt tall) with its icon
  and its name**; every other tab is **only its icon** in grey, in a 48 pt
  circle. A small amber badge on Devices counts requests waiting.
- **The message bar**: shaped exactly like the dock (same radius, colour,
  border and shadow). Inside: a round "+" button (files, photos, a link,
  paste), the field "Message Pixel 9", and a white **"Send files"** pill
  with an upload icon. There is no drag-and-drop box anywhere.
- **The logo**: a bold lowercase "sk" in an Apple-like typeface; the s sits
  slightly over the k's stem with a thin gap cut around the s. White on
  `#121212`.

## The screens

**Phone**
1. **Devices**: title "Devices" with a "+ Connect" pill. An amber "Needs
   you" card when a device wants to send something (device icon, "MacBook
   Pro · Wants to send you 4 files", amber "View" pill). Then groups
   ★ Favorites, Paired, Nearby (Nearby rows have a dashed outline and a
   "Pair" pill). Each row: device icon with status dot, name, how it's
   reached ("Same Wi-Fi · ready"), and one pill on the right: Send, Try
   again (outlined, for a device that can't be reached) or Pair.
2. **Chat**: like Messages, one conversation per device. At the top a row
   of device avatars to switch conversations (the current one ringed in
   white). Under it a bar with the device's name, green status and three
   round icon buttons (Files, Ping, More). Then the history: my messages
   and files on the right in white bubbles, theirs on the left in
   `#262626` (20 pt radius, 6 pt on the corner nearest the sender). A file
   bubble: icon, name, size, "delivered ✓" or a thin progress bar. A link:
   "Pixel 9 sent a link", the site big ("bbcgoodfood.com"), the path small,
   Copy link / Open link. A file request: an amber card in the chat with
   the file names and Decline / Accept. The message bar sits just above the
   dock.
3. **Files coming in**: a bottom sheet over the dimmed screen: amber header
   card ("MacBook Pro wants to send you 4 files · 128 MB"), the file list,
   "Photos and videos go straight to Photos. The rest goes to Files ›
   Sidekick.", an "Always accept from MacBook Pro" tick, and big Accept
   (amber) / Decline (outlined) buttons.
4. **Send**: four big tiles (Files, Photos & videos, Text or link, Paste),
   the selection as removable chips with sizes and a Clear pill, then "Send
   to" with each reachable device and a white Send pill.
5. **Sending**: full screen: the device, a large progress ring with the
   percentage and time left, "30.5 of 47.7 MB · 12 MB/s", each file with
   its own thin bar, and a Stop button.
6. **Remote**: the device to control as a pill with a chevron, a big
   rounded touchpad with a faint dot grid and the pointer as a white dot,
   Left click / Right click / Keyboard buttons, and shortcut chips (Start,
   Alt+Tab, Desktop, Lock). Picking an iPhone says plainly that iPhones
   can't be controlled.
7. **Browse files** (another device's files): back button, the device as a
   chip, breadcrumbs, a rounded search field, folders and files in a card
   with download buttons, and a floating bar shaped like the dock with
   "Download all" and a white "Upload here".
8. **Settings**: this device's card (name, "Visible to nearby devices",
   Rename), then grouped cards: Receiving (Quick save: Everyone asks /
   Favorites / No one asks; Save to), Connections (Bluetooth, Keep running
   in the background, Send screenshots to computers: switches, green when
   on), Sound, Privacy. One look only: no theme picker.
9. **Connect a device**: a segmented control shaped like the dock (Nearby /
   QR code / Code; the chosen one a white pill), a QR code on a white
   rounded card with "Scan a code instead", and six big boxes for the
   6-digit code.
10. **Ping**: full screen, amber rings around the device that is looking
    for this phone, "MacBook Pro is looking for this phone", and a big white
    "Found it!" button.

**States** (phone): Chat with a device that can't be reached (a calm card:
"Can't reach MacBook Air · last seen 2 h ago", what to check, Try again), an
empty chat ("Send Pixel 9 its first file or link"), Devices with nothing
paired yet (one clear "Connect a device" pill), an error pop-up (title, why,
one to three steps, Close), and a **notice**: a small dark rounded card that
slides up above the dock ("Received 3 files from Pixel 9 · Saved to Files ›
Sidekick") with a thin bar along its bottom that empties over 5 seconds and
an ✕; show two stacked.

**Computer window (1280×800).** Same colours. A thin title bar, then three
columns with 12 pt gaps:
- a narrow rail (80 pt) with the "sk" logo and four sections (Devices,
  Files, Remote, Settings; the current one has a white pill behind its
  icon);
- a 300 pt rounded panel with the device list: each row shows the last
  message and its time, like a messages app, with the amber "Needs you"
  card at the top;
- a big rounded panel with the chosen device's conversation: header with
  the device, green status and Browse files / Ping / Remote pills; the same
  bubbles as the phone; and at the bottom the same dock-shaped message bar
  ("Message Pixel 9, or drop files anywhere here" + Send files). Dropping
  files on the conversation works, but there is no drop box.
Also make the computer's **Remote** (device list on the left, a big touchpad,
click buttons, and a dock-shaped typing bar with shortcut chips) and
**Settings** (sections on the left, two columns of grouped cards).

## How to build it

1. **Pages:** "Styles & components", "Phone", "Computer", "Prototype",
   "Improved".
2. **Styles first:** a colour style for every colour above (named by role:
   bg/page, bg/panel, bg/raised, text/primary, text/secondary,
   accent/connected, accent/needs-you…), text styles (Title 30, Heading 20,
   Body 15, Body 14, Label 12.5, Caption 11.5), the float shadow as an
   effect style, and spacing in steps of 4 (8, 12, 16, 24).
3. **Components with variants**, all in auto layout, layers named properly:
   Dock (5 variants, one per selected tab), Device row (ready / not
   reachable / nearby), Device icon (phone, tablet, laptop, monitor ×
   reachable / not), Bubble (text mine / theirs, file sending / delivered,
   link, request waiting / receiving / done / declined), Message bar, Pill
   button (white / dark / outlined / amber × normal / small), Round icon
   button, Switch (on / off), Section card with rows, Sheet, Notice,
   Segmented control.
4. **Build every screen from those components only**, in auto layout, so
   one change updates everything. Content scrolls behind the floating dock;
   leave 112 pt at the bottom of each phone screen.
5. **Make it clickable** on the Prototype page: the dock switches tabs (the
   white pill moves to the tapped tab and grows to show its name; smart
   animate, ~300 ms, ease out). A device in Devices opens its Chat. "View"
   on Needs you opens the Files coming in sheet; Accept turns the request
   into a progress bar, then "Received". "+" and "Send files" open a sheet
   of choices. Send → Sending → back to Chat with the new file bubble.
   Files in the chat header opens Browse files; back returns. "+ Connect"
   opens Connect a device. Pages push in from the right like iOS; sheets
   slide up; nothing bounces.

## Then improve it

When everything above is done, review the whole design as a senior Apple
designer would: spacing and alignment, the type scale, how the eye moves on
each screen, anything that looks generic or crowded. Keep the rules (dark,
flat, white pills, colour only for meaning, the dock and the dock-shaped
message bar, no gradients or glows). Put your improved versions on the
"Improved" page next to the originals, with a short note on each frame
saying what you changed and why, so I can choose. Don't change the originals.
