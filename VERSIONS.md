# Sidekick versions

Every release, newest first, with its biggest features and fixes. Add an
entry here with each release (see "Releasing" in `CLAUDE.md`). The history
starts at 1.1.3.

## 3.0.0
- **Transfers survive a dropped connection.** If Wi-Fi blinks, the other
  device sleeps for a moment or moves to another network, Sidekick finds it
  again and carries on from where it stopped, instead of failing and
  starting over. Both ways: sending, and downloading from the other
  device's files. (Both devices need 3.0.)
- **Stop a transfer part-way:** the sending screen has Stop, and the other
  device stops waiting and drops the half-sent file.
- **Time left** while sending ("2 min left").
- **One clear "can't reach" screen:** Files and Remote no longer show a red
  paragraph and a technical error. They say "Looking for …", when the
  device was last seen and what to check, with Try again, and open by
  themselves as soon as the device answers.
- **Remote reconnects by itself** when the connection drops.
- **Device cards say how a device is connected:** Same Wi-Fi, Direct Wi-Fi
  or Bluetooth, or "Not reachable · seen 4 min ago" with Try again
  (instead of a greyed-out Send).
- **Errors in plain words** everywhere (no more "SocketException" or
  "No host specified in URI").
- **Tidier look:** one card colour everywhere, Settings lined up with its
  title, device cards in even columns, clearer first-run steps.

## 2.19.0
- **Make your own theme** (Settings → Theme → Make theme…): start from
  Default, Liquid Glass (on Apple devices that have it) or Nothing, pick
  light or dark, then change the accent, background, card and text colors
  with ready-made swatches or Hue / Saturation / Brightness sliders. A
  live preview shows the app changing as you go. Save it with a name;
  it's in the Theme list from then on, with Edit theme and Delete.
- A theme made from Nothing keeps the Nothing screens and app icon, with
  your accent in place of the red.

## 2.18.0
- **The Nothing theme, redesigned** (Settings → Theme → Nothing): ink on
  paper in light mode, paper on ink in dark, lines instead of cards, dotted
  tab icons with their names, and one red button per screen. Green dots
  still mean "connected".
- **Send tab** (in the Nothing theme, where Files used to be), like
  LocalSend: pick files, photos, text or the clipboard (a folder on
  computers), then tap the red button on any device in reach. What's picked
  stays until Clear, so it can go to several devices. **Browse files**
  opens another device's folders full screen (X to close), with **New
  folder** and **Upload here**.
- **Always accept from a device:** tick it on the Accept card, or switch it
  on the device's page, and that device's files come straight in.
  **Quick save** (Settings, and on computers beside Send) picks who skips
  the question: nobody, those favourites, or every paired device.
- **No more "timer" rings** in the Nothing theme.
- Mac and Windows no longer touch the window, Dock or tray icon at start
  unless the Nothing theme is on.

## 2.17.6
- **New look to try: Nothing** (Settings → Theme → Nothing, on every
  device): black and white like Nothing's phones, titles and numbers in
  dots, a floating tab bar, red progress, green dots for connected devices,
  and a device page with Send, Files, Remote and Ping.
- **The app icon changes with it** ("sk." in dots, with a red full stop),
  and back when you pick another theme: on iPhone and Android the home
  screen icon; on Mac the Dock icon; on Windows the taskbar icon; and the
  menu-bar / tray icon on both.

## 2.17.5
- **Fixed: the iPhone froze for good** when the Liquid Glass bar's area was
  tapped during the intro. The glass never holds a touch now.
- **The intro plays once,** the first time Sidekick opens. Every other
  start shows a plain loading screen (logo and a moving bar); waits inside
  the app (opening a folder) use the same bar.
- **A cleaner, flatter look:** no decorative gradients or glows on the send
  and receive screens, welcome, QR code, Accept buttons or the tray panel.

## 2.17.4
- **Fixed: the iPhone crashed when the Liquid Glass tab bar was tapped**
  (iOS 26). The tab bar is now Sidekick's own, on Apple's Liquid Glass.
- **Sidekick always opens:** if it closes right after starting with Liquid
  Glass on, the next start turns Liquid Glass off and says so.
- **Connect a device** is a dialog on computers (it was a phone-style sheet
  that cut off Bluetooth in a short window); on phones the sheet scrolls.

## 2.17.3
- **Wi-Fi first, and it looks it:** the Devices page no longer offers
  "Pair over Bluetooth"; a **Connect** link (chain icon) opens every way to
  connect, Wi-Fi first and Bluetooth last. The welcome screen says "Works
  over Wi-Fi".
- **Bluetooth lets go once Wi-Fi works:** when Wi-Fi reaches a device,
  Sidekick hangs up its own Bluetooth connection to it (after 15 s idle).
  Only that one: headphones and other Bluetooth devices stay connected.

## 2.17.2
- No app changes since 2.17.1: a rebuild of the same app, released after
  the repo gained `sync.sh` and its syncing notes in `CLAUDE.md`.

## 2.17.1
- **Fixed: Open Sidekick in the tray panel opened the app and closed it
  again at once** (Mac and Windows), and the same for the panel's Settings.
- **Smoother:** Liquid Glass buttons and the computer's main panel no
  longer blur live behind themselves (they made screens slow to draw);
  switching tabs no longer draws both tabs at once.
- **Apple-like motion:** pages slide in like on an iPhone, on every
  platform; tabs switch at once with a quick fade; lists rise into place
  with a soft ease-out.

## 2.17.0
- **Liquid Glass everywhere it fits:** with Settings → Theme → Liquid
  Glass, buttons are frosted glass pills in their own colors (`GlassFill`,
  the theme's hue for main buttons), and so are segmented buttons, chips,
  switches, checkboxes, sliders, progress bars, text fields, menus,
  snackbars, tooltips and the selected tab / list row (`glassTheme`).

## 2.16.1
- **Fixed: the Apple-silicon Mac app had no background and its buttons did
  nothing** (2.16.0's see-through glass window). The Mac draws its glass
  itself again.
- The welcome email no longer mentions the clipboard or Screen Mirroring.
- Mac icon pictures in all four macOS looks (Default, Dark, Clear, Tinted):
  `website/mac-icons/`, made by `app/tool/mac_icon_looks.py`.

## 2.16.0
- **Separate Mac apps for Apple silicon and Intel:** each release has an
  Apple-silicon and an Intel `.dmg` and `.pkg`, each with only its own code.
- **Fixed: an M1 Mac showed no pairing code or QR code** with Liquid Glass
  on (the glass view drawn inside the window covered them).
- **Liquid Glass that looks like it:** on iPhone the backdrop has color
  again (even with Pure black or Monochrome) for the glass to show.

## 2.15.1
- **Liquid Glass: nothing hides behind the tab bar** any more: like the
  default bar, every screen ends 16 px above it (Settings' About and the
  Remote shortcuts were under it).

## 2.15.0
- **Simpler, calmer look:** plain rows instead of gradient cards and
  tinted icon tiles, quiet section titles, one Send button per device with
  Browse files, Remote control, Ping and Unpair in its ⋯ menu, and short
  fades instead of bouncing animations.
- **Real Liquid Glass tab bar on iPhone (iOS 26):** with Liquid Glass on,
  the tab bar is Apple's own, swipeable from tab to tab.
- **Phone notifications on your computer** (Android): Settings → Show
  notifications on computers; they appear in the Mac's Notification Center
  or as Windows notifications.
- **Screenshots go to your computer** as soon as you take them (iPhone and
  Android): Settings → Send screenshots to computers.
- **Removed:** the shared clipboard and Screen Mirroring.

## 2.14.0
- **Liquid Glass on iPhone and Mac (iOS / macOS 26 and newer):** Settings →
  Theme → Theme: Default or Liquid Glass, Apple's own glass under the
  tab bar and panels. Frosted, see-through cards and
  dialogs over a soft backdrop in your theme's colors, and a floating glass
  tab bar on the iPhone. Material stays the default, and on every other
  system.

## 2.13.0
- **Screen Mirroring:** a new Mirroring tab on Mac and Windows shows a
  paired iPhone's or Android phone's screen, live and lossless (only the
  parts that change are sent, pixel for pixel). Fast or Sharp, full screen,
  and it turns with the phone. The phone asks first (Always allow skips
  that), then iOS's Start Broadcast or Android's Start now.
- **Phones stay on:** Sidekick keeps running in the background on Android
  (even swiped away, and from the moment the phone starts) and on iPhone
  (until it's swiped away), so what you copy on the computer lands on the
  phone while you're in Chrome or any other app.
- Android: request notifications and Ping now work with Sidekick closed.

## 2.12.0
- **A panel in the tray / menu bar**, like CleanMyMac's: click Sidekick's
  icon for its status, your network, the clipboard, the last file you got,
  and every paired device with Send, Clipboard and Ping, plus a tip; Open
  Sidekick, Settings and Quit at the bottom. It closes when you click
  anywhere else.
- **Auto-load:** Sidekick starts in the tray when you log in (Windows and
  Mac), quietly: no window, no chime. Settings → Auto-load turns it off.
- **One Sidekick at a time on Windows:** opening it again brings back the
  one already running.

## 2.11.0
- **The clipboard shares itself, on every device:** copy, and it's on your
  other devices. iPhone too (while Sidekick is open: iOS allows no more);
  a one-time tip shows how to stop iOS asking "Allow Paste?". A copy made
  while a device is out of reach gets there when it's back.
- **Steadier connections:** Android keeps Wi-Fi awake while Sidekick runs
  in the background, the Mac no longer naps Sidekick in the menu bar, and
  a request that hits a dropped connection is tried again by itself.

## 2.10.1
- **Ping rings your ringtone until "Found It!":** the pinged device plays
  the owner's ringtone on repeat (loud; on Android heard even on silent)
  until someone taps Found It! on it.
- **Fixed: one press, one ping.** Pinging a device that's already ringing
  says "This device is already being pinged" instead of ringing again.

## 2.10.0
- **Live Activities on iPhone:** a transfer's progress on the Lock Screen
  and in the Dynamic Island, receiving and sending: who, what, a progress
  bar and percentage, then Received / Sent (or Declined) for a few seconds.

## 2.9.0
- **Shared clipboard on every device:** copy on one, paste on the other.
  Windows, Mac and Android send what you copy by themselves (Android while
  Sidekick is open); on an iPhone tap Clipboard on the device card. What
  arrives goes straight into the clipboard. Passwords from password
  managers are never shared. Settings → Share clipboard turns it off.
- **Ping:** a Ping button on each device card makes the other device play
  a loud sound (heard even on silent on Android) and say who pinged, to
  find it or get someone's attention.

## 2.8.0
- **Direct Wi-Fi between any two devices, no router needed:** Android ↔
  Android, iPhone ↔ Android, iPhone ↔ Windows, Windows ↔ Mac, Windows ↔
  Windows and Android ↔ computers (iPhone ↔ Mac already had Apple's link).
  An Android phone opens a private network, or a Windows PC a Wi-Fi Direct
  one, and the other device joins it; files and Remote then go at Wi-Fi
  speed instead of over Bluetooth.
- **Works on different Wi-Fi networks too:** Bluetooth only finds the other
  device and hands over the network's name and password.
- **Find nearby:** a device that can't be reached offers to turn on
  Bluetooth to find it.
- **Pair with no Wi-Fi and no Bluetooth:** with no Wi-Fi, an Android phone
  or PC puts a private network in its QR code; the phone that scans it
  joins and pairs.
- iPhones join by themselves where the build allows it; otherwise they show
  the network's name and password to join in Settings → Wi-Fi.

## 2.7.1
- **Fixed: the Mac's red close button quit Sidekick** (2.6.6 and 2.7.0).
  Now it only hides the window: Sidekick keeps running in the menu bar and
  the Dock, still receiving (requests pop up in the corner), until Quit
  Sidekick in the menu bar (or ⌘Q).

## 2.7.0
- **Direct Wi-Fi between iPhones and Macs, no router needed:** iPhone ↔
  Mac, iPhone ↔ iPhone and Mac ↔ Mac find each other and send at Wi-Fi
  speed over Apple's peer-to-peer Wi-Fi (the link AirDrop uses), with no
  shared network and no Bluetooth. Pairing by QR code works over it too.
  The device card says "Connected via direct Wi-Fi".

## 2.6.6
- **The Mac keeps Sidekick in the menu bar:** the red close button no
  longer quits it. Sidekick stays in the Dock and the menu bar (Open,
  Quit), still receiving, and a request pops up the small corner window,
  like on Windows, without taking the focus.
- **A nicer, animated corner pop-up** on Windows and Mac: it rises into
  the corner, rings ripple from the sending device, a countdown runs along
  the top, Accept glows, a ring and bar fill while files arrive, a check
  pops in when they're all in, and it fades away.

## 2.6.5
- **Remote on an iPhone** no longer shows a touchpad that can't work: it
  says iPhones can't be controlled (Apple doesn't allow it) and to use the
  iPhone as the remote instead. A one-time pop-up explains it the first
  time a device pairs with or picks an iPhone; iPhone cards have no Remote
  shortcut.

## 2.6.4
- **Sharper app icons:** the shadow and edge highlight behind "sk" are gone
  (Mac, iPhone, the Liquid Glass icon, the website's tab and home-screen
  icons): they blurred the letters.

## 2.6.3
- **Fixed: Windows crashed when a file request arrived while Sidekick was
  in the tray** (the sender saw "Connection reset by peer"). The corner
  window's skip-taskbar call hit a null pointer inside window_manager.
- **Close works on the sending screen again:** Close and Cancel close that
  screen, even if something opened on top of it; Cancel works even as the
  send moves on.
- **Bluetooth is off by default:** Sidekick uses Wi-Fi and doesn't ask for
  Bluetooth at start. Turn it on in Settings → Bluetooth (or when picking
  Bluetooth in Connect device).
- **Open button on phones:** a received file's folder icon opens the Files
  app at its folder; photos and videos open in Photos / the gallery.

## 2.6.2
- **Closing the window keeps Sidekick in the tray** (Windows) / menu bar
  (Mac), still receiving; Open and Quit are there. A file request then
  pops up a **small window in the bottom-right corner** with Accept and
  Decline, then the progress, and closes by itself when the files are in.
- **Notifications on iPhone and Android:** a request while Sidekick is in
  the background shows Accept / Decline; Android also shows the progress
  and keeps a small "Ready to receive" notification while it runs in the
  background (Back no longer closes it).
- **Wi-Fi first:** Bluetooth is only used when one of the devices isn't
  on Wi-Fi (no more Bluetooth while both are).
- **One QR code for everything:** the QR next to the 6-digit code is the
  same pairing code as Connect device → QR code; scanning either pairs.
- **Faster:** themes are built once instead of on every update, and
  nothing animates while the window is in the tray.

## 2.6.1
- **Photos and videos go straight to Photos / the gallery** on iPhone and
  Android, automatically: whatever is sent to the phone, and whatever it
  downloads from the computer. On Android they're in Pictures/Sidekick and
  Movies/Sidekick. Other files stay in the Sidekick folder. The transfer
  shows "in Photos" / "in the gallery".
- iPhone asks once to add to Photos (add-only: Sidekick can't see the
  library). The privacy policy says so.

## 2.6.0
- **A .pkg installer for the Mac**, next to the .dmg: open it, Continue,
  Install, and Sidekick lands in Applications. Its welcome page has the
  glass "sk", and the privacy policy is its second page. The website
  offers it to Mac visitors under the main download.
- **Privacy policy:** on the website (`privacy.html`, linked in the
  footer and under the download), on a page in the Windows installer
  before installing (and installed as `Privacy.txt`), and in the .pkg.
  No account, no servers, no analytics; what stays on the device, what
  nearby devices see, and every permission and why.

## 2.5.1
- **Sounds play on the Mac:** the chime file went to a folder that didn't
  exist on a Mac (`~/Library/Caches/<app id>`), so no sound ever played;
  it's created now, and sounds use AVAudioPlayer.
- **iPhone sounds** use the media volume (system sounds were muted by the
  silent switch); **Android** keeps its player until the sound ends, on
  the media volume.
- Turning Settings → Sound on plays the chime.
- **Only phones scan QR codes:** Mac and Windows just show theirs.

## 2.5.0
- **Pair with a QR code** (Connect device → QR code), alongside the 6-digit
  code:
  - Every device shows a one-time code (5 minutes, one device). iPhone,
    Android and Mac scan it with the camera and pair with nothing to type,
    over Wi-Fi or Bluetooth.
  - The scanner only accepts the device whose certificate is in the code.
  - The 6-digit code screen shows its QR too, and the code entry has
    "Scan the QR code instead".
  - Camera permission on iPhone, Mac and Android.

## 2.4.1
- **The owner's own sounds:** app startup, a new file request, request
  accepted and request declined (`tool/sounds/`, prepared into WAV by
  `tool/prepare_sounds.py`: trimmed, soft fades, equal loudness). Accept and
  decline play on both devices. Replaces the synthesized chimes.
- **One Sound switch** in Settings for all of them: "Sound enabled" /
  "Sound disabled".

## 2.4.0
- **Playful request chime:** a bouncy "ba-da-ding" when the Accept/Decline
  card appears, on all four platforms (Settings → Request sound, with a
  Play button).
- **Livelier Accept/Decline card:** the app behind blurs and the card
  springs up; its contents cascade in; the device circle breathes and
  "knocks"; the file chip flies in; Accept glows; the countdown turns red
  near the end; confetti on Accept and when everything has arrived.
- **Website tab icon:** favicon and home-screen icon, the glass "sk".

## 2.3.1
- **The startup chime plays:** from `main()`, no longer tied to the
  animation (which "Reduce motion" skips); on the Mac through NSSound
  (`sidekick/macos` → `playSound`), `afplay` only as a fallback.
  Settings → Startup sound has a Play button to hear it any time.
- **Visible icon on the receive card:** the device icon was fixed white on
  the theme's gradient, invisible in dark mode with the black-and-white
  theme; it now uses the theme's matching color.

## 2.3.0
- **New startup chime, on every device:** a soft lift, two mallet notes and
  a warm chord that blooms with the animation (stereo, ~2 s). Mac: afplay;
  Windows: PlaySound; iPhone: a system sound (follows the silent switch);
  Android: a UI sound (follows silent mode). Settings → Startup sound on
  all four.
- **Stability:**
  - Startup never ends on a blank window: a failure shows "Sidekick
    couldn't start" with Try again; bad saved settings, a failing device
    name lookup or any server start error no longer stop the app.
  - Unexpected errors are logged instead of crashing; a part that fails to
    draw shows a short note instead of a red screen.
  - Discovery rejoins the network when it changes (Wi-Fi switch, waking
    from sleep), so devices stop vanishing until a restart; the shown IP
    address updates too.
  - Phones coming back from the background check the server still
    answers and restart it (and discovery) if the system closed them.
  - Stricter checks (`unawaited_futures`, `use_build_context_synchronously`).

## 2.2.0
- **Liquid Glass app icon on Mac and iPhone:** an Icon Composer icon
  (`AppIcon.icon`) that macOS/iOS 26+ render as live glass (Dark, Clear and
  Tinted too); older systems get a pre-rendered glass version.
- **Media removed** (tab, device-card shortcut, Settings switch, Android
  notification access, native media code): iPhones can't control other
  apps' playback, so it never worked the same everywhere.
- **Bluetooth "Message failed authentication" says what to do:**
  - Devices announce their Sidekick release; a paired card shows "Update
    Sidekick on it" when the other one is older, and failed sends say so.
  - Different pairing keys are detected (key fingerprint in every sealed
    message) and shown as "Pair again" instead of endless retries.
  - Every refused Bluetooth message is logged on the receiver with why.

## 2.1.2
- **Sending photos and files over Bluetooth works reliably** (iPhone → Mac
  failed with "Message failed authentication"): files go in 32 KB sealed
  parts, each checked on arrival and resent if a packet got damaged,
  instead of one multi-MB message that one bad packet could fail.
  - Big messages are no longer refused for taking longer than 2 minutes.
  - Message ids start at random per client, so parallel clients can't mix
    chunks; re-pairing takes effect right away over Bluetooth.
  - If it still fails, the error says what it means (and to re-pair).

## 2.1.1
- **"Connect device"** (was "Add device") on the Devices tab, with plain
  options: **Wi-Fi**, **Bluetooth** and **IP address**, each with one short
  line on when to use it.

## 2.1.0
- **Startup animation** on every platform: the "sk" tile pops in, ripples
  spread, the name rises, then it zooms away into the app. A tap skips it;
  reduced motion turns it off.
- **Startup chime on the Mac** (Settings → Startup sound, on by default).
- **Simpler:** Devices has one "Add device" menu (Search Wi-Fi, Pair over
  Bluetooth, Add by IP); Settings descriptions are one short line each.
- **More icons:** tinted icon tiles on every Settings row, icons on section
  labels, Wi-Fi/Bluetooth/offline icons in status pills, icons on snackbars.
- **More motion:** cards, groups, empty states and file rows cascade in; tab
  switches slide and fade; a new track slides in on Media; a radar while
  looking for devices; device cards lift on hover.

## 2.0.2
- **Send files works on the Mac again:** the Mac file picker refused to open
  without a sandbox file entitlement (Sidekick isn't sandboxed) and the
  error was swallowed. The entitlement is declared, the check is skipped on
  Mac, and a picker that can't open now says why. Also fixes Settings →
  "Save received files to → Change" on the Mac.
- **"sk" logo inside the app:** the side rail and welcome screen show the
  monogram (3.png); the wide wordmark stays on the website only.

## 2.0.1
- **App icons are the "sk" monogram** (`website/3.png`) everywhere the
  system shows Sidekick: Mac dock, Windows desktop/taskbar/Start menu and
  installer, Android and iPhone home screens, at every size, with a little
  more breathing room around it. The website keeps the wide wordmark
  (`website/2.png`), and so does the logo inside the app.
- The logo inside the app is 10 px smaller (welcome screen 206 px wide,
  desktop side rail 66 px).

## 2.0.0
- **New logo:** the wide SIDEKICK wordmark (`website/2.png`) on app icons
  (replaced by the "sk" monogram in 2.0.1), in the app and on the website.
- **Redesign, still Material You** (wallpaper/theme colors unchanged):
  - One app-wide theme (`main.dart`): bold headlines, soft 16–28 px shapes,
    44 px buttons, rounded outlined fields, check icons on switches, the
    current Material 3 progress bars and sliders, floating rounded
    snackbars, restyled navigation rail/bar, fade-forward page transitions
    on Android/Windows, and a fade-through between tabs.
  - Pages (`PageFrame`) get a subtitle line (e.g. "1 paired · 1 connected")
    and never stretch wider than 1080 px on big screens.
  - Devices: a gradient "This device" hero card with Wi-Fi and Bluetooth
    status pills; paired cards with a status pill, one "Send files" button
    and icon shortcuts to Files, Remote and Media.
  - Shared pieces: `GradientBadge` (the signature icon tile) and
    `StatusPill`. Empty states use the gradient tile.

## 1.1.3
- **Styled Mac installer:** the .dmg opens on the purple background with an
  arrow; drag Sidekick (right) into Applications (left).
- Everything from the 1.1 line, which is where the history starts:
  - **Bluetooth that works on Apple:** iPhone and Mac use Sidekick's own
    CoreBluetooth code (`SidekickBLE.swift`). Mac ↔ iPhone pairing and
    transfers work with no Wi-Fi.
  - **Bluetooth on Windows:** Windows now finds devices (a subscription
    Windows doesn't support used to abort setup) and can be found
    (advertises through the GATT service).
  - **Bluetooth look-alikes filtered:** only devices that really advertise
    Sidekick are listed. Apple's shared background bitmask no longer shows
    random devices.
  - **Clear Bluetooth problems:**
    - An old system pairing ("Peer removed pairing information") says to
      forget the device in Bluetooth settings.
    - Windows' LE service being off (0x80070422) lists what to check.
    - Both have Settings buttons.
  - **Ask before receiving:** the sender sees a full-screen "Waiting for
    permission…", then a progress ring and bar, then Sent / Declined / No
    answer, and it closes by itself. The receiver gets an animated
    Accept/Decline card with a countdown and live progress.
    - Uploads to the receive folder need a ticket from an accepted offer.
    - Settings → "Ask before receiving files" (on by default).
  - **Live progress over Bluetooth** on both sender and receiver.
