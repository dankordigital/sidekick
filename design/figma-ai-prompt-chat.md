# Follow-up prompt for Figma AI: fix the Chat tab

Paste this after the main prompt (`figma-ai-prompt.md`), once Figma AI has
built the screens. It corrects one misunderstanding: the Chat tab is not a
messaging app.

---

Rebuild the **Chat** tab (phone and computer). It was read as a messaging
app, and it isn't one.

**What it really is.** Sidekick only connects *your own* devices. Nobody is
on the other end: "Pixel 9" is my own phone, not a person. The Chat tab is
**one place per device for everything sent between it and this device**:
files, photos, links and short notes, in the order they were sent. It
borrows the familiar look of a chat (newest at the bottom, mine on the
right, the other device's on the left, a bar at the bottom to send) only
because everyone already knows how to read that. Think of Apple's "Notes to
self", Telegram's Saved Messages, or an AirDrop history, not WhatsApp.

**So take out everything that implies a person:**
- no "typing…" indicator, no read receipts, no "seen", no reactions, no
  emoji, no replies or quoting, no online/last-seen of a person, no
  profile pictures;
- no conversational sample text ("Yes! Sending the photos too", "Thanks!").
  Every item is something *sent*, written the way you'd note it for
  yourself: "Door code 4417", "Pick up the charger", a link, a file;
- the header names the device and how it's connected ("Pixel 9 · Same
  Wi-Fi · encrypted"), never a person's status.

**Each item is a thing, shown as a card, with what you can do with it:**
- **File**: icon or thumbnail, name, size, and its state (sending with a
  thin progress bar → "Delivered ✓"; received → "Saved to Files ›
  Sidekick"). Actions: Open, Show in folder (Files / Finder / Explorer).
- **Photos and videos**: real thumbnails in a small grid when several
  arrive together, "Saved to Photos". Tap to open.
- **Link**: the site big ("bbcgoodfood.com"), the path small; Open link,
  Copy link.
- **Note**: the text on a card (not a speech bubble), with Copy.
- **Waiting for you**: the amber card "MacBook Pro wants to send you 4 files
  · 128 MB" with Decline / Accept, which turns into a progress bar, then
  into the received files.
- Mine sit on the right (white cards), the other device's on the left
  (`#262626` cards), each with a small time underneath ("You sent · 9:14",
  "From Pixel 9 · 10:02"). Group them under day labels ("Today",
  "Tuesday").

**The bar at the bottom** stays exactly as designed (fully rounded, shaped
like the dock): a round **+** (Files, Photos & videos, Paste), the field
**"Write a note or paste a link"** (a pasted link becomes a link card), and
the white **Send files** pill. On the computer, files dropped anywhere on
this panel are sent too; there's still no drop box.

**Also add:**
- a row of filter chips under the header: **All · Files · Photos · Links ·
  Notes**, so you can find "that PDF from Tuesday" quickly;
- search (the magnifier) searches file names, links and notes;
- the empty state for a device with nothing sent yet: "Nothing here yet.
  Send Pixel 9 a file, a photo or a link and it'll show up here.", with
  the bar ready below;
- a long-press / right-click menu on an item: Open, Copy, Show in folder,
  Send again, Remove from this list (removing never deletes the file).

Keep the tab's name **Chat** and its place in the dock, and keep every other
rule from before (dark, flat, white pills, colour only for meaning, no
gradients, no glows, no badges or dots). Update the phone Chat screen, the
computer's Devices panel (each device's row shows its newest item, e.g.
"You sent Holiday.mov", not a message preview from a person), the
prototype links, and the components (replace the speech-bubble variants with
the item cards above).
