# Prompt for Figma AI: the Sidekick app design

Paste **Prompt 1** into Figma Make (or First Draft) on its own. When it's
done, send the follow-ups one at a time. The follow-ups are short on
purpose: Figma AI does better with one job at a time.

Reference to show it (screenshots, or drag the pictures in):
- Design canvas: https://claude.ai/artifact/N5YczZk3EXsqbULx56Qfxf
- Clickable prototype: https://claude.ai/artifact/PT9J7jBD417cBNMAwiBaQL

---

## Prompt 1 (the foundation)

Design the app **Sidekick**: one app for iPhone, Android, Mac and Windows
that makes your phone and computer work as one. You can send files both
ways, chat with your own devices (links, notes, files), browse another
device's files, use the phone as a touchpad and keyboard for the computer,
and ping a lost device. Everything is encrypted, there is no account and no
cloud: devices talk directly over Wi-Fi.

Build a **phone design (390×844)** and a **computer window (1280×800)**,
plus a small set of components and color/type styles.

**The look.** Dark, calm and flat, like a well-made Apple app. Not
futuristic, not "AI-made".
- Page `#121212`, panels and cards `#1c1c1c`, raised items and inputs
  `#262626`, secondary buttons `#2e2e2e`, hairlines white at 8% opacity.
- Text `#f2f2f2`, secondary text `#a1a1a6`, faint text `#8a8a8f`.
- Main buttons are **white pills** (`#f0f0f0` with `#141414` text). Second
  buttons are dark pills or outlined pills. Everything a person taps is
  fully rounded.
- **Colour only where it means something:** green `#45d07e` = connected
  (small status dots, "Same Wi-Fi · encrypted"); amber `#ffc56b` on a dark
  amber card `#2f2410` = something needs you (a file request, Accept);
  gold star = favourites. Each device has its own icon colour (blue
  `#5b9dff`, green `#4fcf86`, amber `#ffb84d`; grey `#8a8a8f` when it
  can't be reached).
- **No gradients, no glows, no glass, no emoji, no illustrations or
  characters.** Shadows only on things that float (the dock, sheets,
  notices).
- Font **Figtree** (or SF Pro): page titles 30 bold, section labels 12.5
  semibold grey, body 14–15. Big, tight, confident titles; everything else
  quiet.
- Plain, friendly words ("Pixel 9 wants to send you 3 files", "Not
  reachable · seen 2 h ago", "Try again"). Never technical.
- Touch targets at least 44 pt. Text contrast at least 4.5:1.

**Phone: the dock.** A floating, fully rounded dock 16 pt from the sides
and 24 pt from the bottom (dark `#1c1c1c`, faint border, soft shadow), with
five tabs: **Devices · Chat · Send · Remote · Settings**. The selected tab is
a **white pill with its icon and its name**; the other tabs are **only an
icon**, grey. A small amber badge on Devices counts requests waiting.

**Phone screens:**
1. **Devices**: title "Devices" with a "+ Connect" pill. An amber
   "Needs you" card when a device wants to send something (device icon,
   "MacBook Pro · Wants to send you 4 files", amber "View" pill). Then
   groups: ★ Favorites, Paired, Nearby (dashed outline, "Pair" button).
   Each row: a rounded-square device icon with a status dot, name, how
   it's reached ("Same Wi-Fi · ready"), and one pill on the right (Send /
   Try again / Pair).
2. **Chat**: a conversation with one device, like Messages. At the top a
   row of round-cornered device avatars to switch conversations (the
   current one ringed in white). Under it a bar with the device's name,
   green status, and three round icon buttons (Files, Ping, More). Then
   the history: my messages and files on the right in white bubbles, theirs
   on the left in `#262626`; a file bubble shows an icon, the name, size and
   "delivered ✓" or a progress bar; a link shows the site big
   ("bbcgoodfood.com"), the path small, and Copy link / Open link; a file
   request is an amber card with Decline / Accept inside the chat. At the
   bottom, just above the dock, **a message bar shaped exactly like the
   dock** (fully rounded, same colours): a round "+" button (files, photos,
   a link, paste), the field "Message Pixel 9", and a white **"Send files"**
   pill. No drag-and-drop box anywhere.
3. **Files coming in**: a bottom sheet over the dimmed screen: amber header
   card ("MacBook Pro wants to send you 4 files · 128 MB"), the file list,
   "Photos and videos go straight to Photos", an "Always accept from
   MacBook Pro" tick, and big Accept (amber) / Decline (outlined) buttons.
4. **Send**: four big tiles (Files, Photos & videos, Text or link, Paste),
   the selection as removable chips with sizes and a Clear pill, then
   "Send to" with each reachable device and a white Send pill.
5. **Sending**: full screen: the device, a large progress ring with the
   percentage and time left, "30.5 of 47.7 MB · 12 MB/s", each file with
   its own thin bar, and a Stop button.
6. **Remote**: the device to control as a pill with a chevron, a big
   rounded touchpad with a faint dot grid and the pointer as a white dot,
   Left click / Right click / Keyboard, and shortcut chips (Start, Alt+Tab,
   Desktop, Lock). iPhones can't be controlled; say so plainly if one is
   picked.
7. **Browse files** (another device's files): back button, the device as a
   chip, breadcrumbs, a rounded search field, folders and files in a card
   with download buttons, and a floating rounded bar with "Download all"
   and a white "Upload here".
8. **Settings**: this device's card (name, "Visible to nearby devices",
   Rename), then grouped cards: Receiving (Quick save: Everyone asks /
   Favorites / No one asks; Save to), Connections (Bluetooth, Keep running
   in the background, Send screenshots to computers, as switches), Sound,
   Privacy. One look only: there is no theme picker.
9. **Connect a device**: a three-part segmented control shaped like the
   dock (Nearby / QR code / Code), a QR code on a white rounded card, and six
   big boxes for the 6-digit code.
10. **Ping**: full screen, amber rings around the device that is looking
    for this phone, "MacBook Pro is looking for this phone", and a big white
    "Found it!" button.

Also a **notice**: a small dark rounded card that slides up above the dock
("Received 3 files from Pixel 9 · Saved to Files › Sidekick") with a thin
bar along its bottom that empties over 5 seconds, and an ✕.

**Computer window (1280×800).** Same colours. A thin title bar, then three
columns: a narrow rail on the left with the "sk" logo and four sections
(Devices, Files, Remote, Settings; the current one a white pill behind its
icon); a 300 px panel with the device list (each row shows the last message
and time, like a messages app, plus the amber "Needs you" card); and a big
rounded panel with the chosen device's conversation: header with the
device, green status and Browse files / Ping / Remote pills; the same
bubbles as the phone; and at the bottom the same dock-shaped message bar
("Message Pixel 9, or drop files anywhere here" + Send files). Dropping
files anywhere on the conversation works, but there is no drop box. Make
the Remote (touchpad + typing bar) and Settings (two columns of grouped
cards) screens for the computer too.

**Logo:** a lowercase "sk", bold and Apple-like: the s sits slightly over the
k's stem with a thin gap cut around it. White on `#121212` in the app; it
appears in the computer rail.

Make components for: dock (5 states), device row (ready / not reachable /
nearby), message bubbles (text, file sending, file delivered, link, request
waiting / receiving / done / declined), message bar, pill buttons (white,
dark, outlined, amber), switch, sheet, notice. Use auto layout everywhere
and name the layers properly.

---

## Prompt 2 (make it clickable)

Wire the phone screens into a prototype: the dock switches tabs (the white
pill grows into the tapped tab with its name; smart animate, about 300 ms,
ease out). Tapping a device in Devices opens its Chat. "View" on Needs you
opens the Files coming in sheet; Accept turns the request card into a
progress bar, then "Received". "Send files" and "+" open a sheet of choices.
Send → Sending → back to Chat with the new file bubble. Files in the chat
header opens Browse files; back returns. "+ Connect" opens Connect a device.
Pages push in from the right like iOS; sheets slide up; nothing bounces.

## Prompt 3 (states)

Add the states a real app needs, in the same style: Chat with a device that
can't be reached (calm card: "Can't reach MacBook Air · last seen 2 h ago",
what to check, Try again), an empty chat ("Send Pixel 9 its first file or
link"), Devices with nothing paired yet (one clear "Connect a device" pill),
an error pop-up (title, why, one to three steps, Close), and the notice
stacked two high.

## Prompt 4 (your turn to improve it)

Now review the whole design as a senior Apple designer would and improve
it: spacing and alignment, the type scale, how the eye moves on each screen,
anything that looks generic or crowded. Keep the rules (dark, flat, white
pills, colour only for meaning, the dock and the dock-shaped message bar,
no gradients or glows). Put your improved versions on a new page called
"Improved" next to the originals, and add a short note on each frame saying
what you changed and why, so I can pick.
