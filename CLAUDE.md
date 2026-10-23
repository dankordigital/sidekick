# Sidekick

Use your phone and computer as one: send files both ways, control one device
from another (touchpad, keyboard, shortcuts), and connect over Bluetooth
when there's no shared Wi-Fi. Everything is encrypted.

One Flutter app for **Windows, macOS, Android and iOS** (`app/`), plus a
website (`index.html` at the top of the repo; its images live in
`website/` and it links them as `/website/…`). It lives at
**https://getsidekick.app**, the official domain (the owner's, hosting on
OVHcloud; it was at sk.dankor.digital on cyber_Folks before). Use
getsidekick.app wherever an address is shown (ads, trailers, the app).
The owner uploads with FileZilla: `index.html`, `index.php`, `wishlist.php`, `np7dpanel.php`, `privacy.html`,
`404.html`, `.htaccess`, `robots.txt` and `website/` go in the site's root
folder (`www`). The
pages link only with relative or `/…` paths, so nothing in them names the
domain. `.github/workflows/website.yml`
uploads exactly those over FTPS whenever they change on the branch, once
the owner adds the secrets `FTP_SERVER`, `FTP_USERNAME`, `FTP_PASSWORD` and
`FTP_DIR` (it skips until then). Never put the FTP login anywhere else.

**The site is a wishlist, not a download page** (the owner's call: Sidekick
isn't out yet). No download buttons or links anywhere: the top bar, the hero
and `#wishlist` (the old `#download` section) say "Join the wishlist", and
`404.html` links there. **The wishlist is real** (`wishlist.php`, PHP only,
no database: the owner's OVHcloud free plan): signing up puts the address
on the list and emails "Got your email! We'll remind you when Sidekick
comes out." (the owner's words; no confirm step) from `FROM`
(`info@getsidekick.app`, the owner's mailbox) **over SMTP to OVHcloud's
mail server** (`ssl0.ovh.net`: 465 SSL, then 587 STARTTLS; 993 is IMAP, it can't send; logged in as `FROM`; PHP `mail()` never
delivered on the hosting, so it's only a fallback), the password in
`wishlist-config.php` next to it on the hosting, **never in git**
(`.gitignore`; template `wishlist-config.example.php`); every failure goes
to `sidekick-wishlist/mail.log` (never the password). The email is HTML
(`welcome_html`: the header image, a signature at the bottom (`email_footer`: the "sk" logo as `cid:logo`, Sidekick, getsidekick.app, `FROM`), `website/email-header.png` as a JPEG inside `wishlist.php` (`header_image`), attached inline as `cid:header`,
a "Cancel my sign-up" button: the remove link) with a plain-text part, with a
remove link, and a note to `FROM` about each sign-up (`NOTIFY_OWNER`); a
honeypot field, a 2-second minimum, and 5 tries an hour per hashed IP.
`wishlist-check.php` (upload once, open, delete) loads `wishlist.php`'s
functions (`WISHLIST_LIB`) and checks the hosting: PHP, the private
folder, openssl, the password, and a real test email to `FROM`, showing
the log's reason if it fails. The list is `sidekick-wishlist/list.csv`,
next to `www` (outside the web root; inside it behind a deny-all
.htaccess only if that's not writable). On localhost (`php -S
localhost:8000`) emails go to `sidekick-wishlist/outbox` instead. Both
privacy policies describe exactly this; keep them true if it changes.
**Released mode:** `.htaccess` sends `/` and `/index.html` to `index.php`,
which counts the visit (`record_visit`) and serves index.html; when
site.json says released it adds `class="released"` to `<html>` and
`window.SIDEKICK_RELEASE` (`release_files`: the GitHub release's .exe,
Apple-silicon and Intel .dmg/.pkg, .apk, .ipa). index.html marks the two
looks with `only-wish` / `only-released` (Download buttons, `#download`
tiles). Without PHP it's still the wishlist.
**`np7dpanel.php`** (the owner's name for it; not linked anywhere): the
wishlist admin panel. Tabs: Overview (counts, sign-ups per day for 30 days,
devices), Visits (home-page visits and different visitors per day, 30-day
chart, referring sites; `sidekick-wishlist/visits.json`, visitors only as
a day-salted hash of IP + browser, bots skipped; plus **Who visited**: every
IP address (bots marked) for 30 days in `ips.json` (`record_ip`), with
country, city and network from ipwho.is, looked up only from the panel
(`ip_places`, 25 a load, `ip-places.json`), and a countries chart; both
privacy policies say so), Website (the newest GitHub release, `latest_release()`: the GitHub API,
cached 10 minutes in `latest-release.json`, with **Release latest** and
Check again; **Release Sidekick** with a version / **Make it a wishlist
again**: `sidekick-wishlist/site.json`), **Edit** (every text on the home
page in a box, with a search; saved to `sidekick-wishlist/edits.json` as
{original → new} and put in by index.php (`apply_site_edits`), so
index.html is never changed and new uploads keep them; an edit whose
original text is gone does nothing and is listed to forget), People (search, add, remove, send the welcome email again, send it
to everyone who never got it, CSV export), Email everyone, Past sends
(`sends/<id>.json`), Mail log (view, clear) and Health (PHP, openssl,
folder, password, the mail server's ports). Its password is
`admin_password` in `wishlist-config.php`, or the mailbox password if that
isn't set; **never in git**. 5 wrong tries per 15 minutes per visitor,
session cookie (Strict), CSRF token. Sends in batches of 8 from the page,
each with the person's own remove link and `List-Unsubscribe`; who got a
send is kept in `sidekick-wishlist/sends/<id>.txt`, so sending the same text
again skips them. "Send a test" goes to `FROM` first.

**Every change must work on all four platforms.**

## Keeping this file up to date

`HISTORY.md` is the running record of what's been done (newest first), for
picking up after `/clear`: update it when something notable is done.

**Every release adds an entry to `VERSIONS.md`** (newest first) with its
biggest features and fixes (see [Releasing](#releasing)). It's a separate
file so it isn't loaded into every session (the owner's call, to save
tokens): read it only when releasing or when asked what changed in a
release. Keep this file for how things work now, not for history.

## Layout

- `app/lib/app_state.dart`: the app's state (paired and nearby devices,
  transfers, settings), and sending and receiving.
- `app/lib/core/`: platform-independent logic, unit-tested.
  - `server.dart`: HTTPS server on port 53318 (the same handler also serves
    Bluetooth). Pairing, files, transfer offers and tickets, input.
  - `client.dart`: `PeerClient`, over HTTPS (pinned certificate) or Bluetooth.
  - `crypto.dart`: identity certificates, SPAKE2 pairing, AES-GCM sealing,
    security codes.
  - `pairing_qr.dart`: what pairing QR codes say. `sidekick://pair?…` (an
    invite: id, name, addresses, port, certificate fingerprint, one-time
    secret) and `sidekick://pin?id=&c=` (the 6-digit code as a QR).
  - `ble_protocol.dart`: Bluetooth message framing, chunking, sealing, and
    the request dispatcher.
  - `bluetooth.dart`: `BluetoothService` (scan, identify, links,
    candidates, the pairing search).
  - `ble_backend.dart`: the radio behind it. `AppleBleBackend` talks over
    channels to `SidekickBLE.swift` (CoreBluetooth). `PluginBleBackend` uses
    the `bluetooth_low_energy` plugin on Android and Windows.
- `app/lib/ui/`: screens. `transfer_screens.dart` holds the sender's full
  screen and the receiver's Accept/Decline card.
  - `qr_pairing.dart`: pairing by QR code (Connect device → QR code).
    Every device can show its code; only iPhone and Android scan
    (`mobile_scanner`). Mac and Windows never offer scanning (the owner's
    call: their cameras can't scan another screen); they show codes and
    type the 6 digits. **One QR code for everything** (the owner's call):
    every QR Sidekick shows is the same invite (`sidekick://pair?…`), on
    Connect device → QR code and next to the 6 digits (when the other
    device is a phone); scanning it pairs on its own, from either
    scanner. `sidekick://pin` is only still read, from older releases.
  - `corner_popup.dart`: the small window in the bottom-right corner on
    Windows and Mac (380×172) when a request arrives while Sidekick is in
    the tray: Accept / Decline, then a progress bar; it closes by itself
    as soon as the files are in, or at once on Decline. Animated: the
    window rises into its corner (Mac: native fade in `showPopup`, fade
    out in `hidePopup`; Windows: a few `setPosition` steps), the contents
    cascade in, rings ripple from the device badge, a countdown runs along
    the top, a ring fills while receiving, a check pops in, and the
    contents fade out (`CornerPopup.exit`) before `onDone`. Reduced motion
    turns all of it off.
  - `startup.dart`: the startup animation (every platform; a tap skips it,
    reduced motion turns it off).
  - Motion is Apple-like (2.17.1): Apple's push between pages on every
    platform (`CupertinoPageTransitionsBuilder`, from `cupertino_ui`), tabs
    switch at once with a quick fade-in, and `Entrance` fades in rising a
    few pixels with a long ease-out (`easeOutQuint`, 320 ms).
  - `widgets.dart` has the shared pieces: `PageFrame`, `SectionLabel` (with
    an icon), `IconTile` (tinted icon square for rows), `StatusPill`,
    `Entrance` (fade/slide-in cascade), `Radar` (searching), `GradientBadge`.
- `app/lib/platform/`: per-OS glue (input, files, device names,
  secret storage, hotspot, and the sounds in `sound.dart`: PlaySound on
  Windows, `playSound` on the `sidekick/macos`, `sidekick/ios` and
  `sidekick/android` channels). Mac and iPhone use AVAudioPlayer, Android
  MediaPlayer, all on the media volume and held until they finish (not
  iPhone system sounds: muted by the silent switch). The WAV is copied to
  the temp folder first; on the Mac that's `~/Library/Caches/<app id>`,
  which must be created (it wasn't, and the Mac never played a sound).
  The sounds are the owner's own recordings in `app/tool/sounds/` (MP3),
  turned into `app/assets/sounds/*.wav` by `app/tool/prepare_sounds.py`
  (WAV: Windows PlaySound can't play MP3; silence
  trimmed, soft fades, equal loudness). `appstartupchime` → startup.wav
  (launch), `newfilesendrequest` → request.wav (Accept/Decline card
  appears), `filerequest_accept` → accept.wav and `filerequest_deny` →
  decline.wav (on both devices: the one tapping and the sender getting the
  answer). One switch for all of them: Settings → Sound ("Sound enabled" /
  "Sound disabled"; `AppState.sound`, pref `sound`). Don't synthesize
  replacements.
- `platform/desktop_window.dart` (Windows, Mac; `window_manager`,
  `tray_manager` 0.5.x: 0.6+ is a native-library rewrite): closing the
  window hides it to the tray / menu bar (Open, Quit). On the Mac the
  close is caught at every step, because 2.6.6 and 2.7.0 still quit on the
  red button: `MainFlutterWindow` (`performClose` and `close` →
  `hideToMenuBar`), window_manager's prevent-close (`onWindowClose` →
  `hideToMenuBar`), and `AppDelegate` never quits after the last window
  while `keepInMenuBar` is on. It's set at start, before the tray icon (the
  Dock icon always brings the window back). Only Quit Sidekick or ⌘Q quits.
  Sidekick stays in the Dock with its dot (the owner's call). The pop-up is shown with `orderFrontRegardless`
  (no focus taken), the window's minimum size lifted while it's up. A
  request then shows [CornerPopup] instead of the app (main.dart `_withCornerPopup`),
  the window put back afterwards. While hidden, animations are paused.
  **Never call `setSkipTaskbar`** (or anything else using the plugin's
  taskbar object) on Windows: it's only created in `waitUntilReadyToShow`,
  so it's a null pointer and the app crashes (2.6.2 crashed this way when a
  request arrived in the tray).
  Tray icons: `assets/tray/` and Android's `ic_stat_sidekick`, from
  `make_icons.py` (`tray()`).
  **The tray panel** (`ui/tray_panel.dart`, the owner's idea: like
  CleanMyMac's): a click on the tray / menu-bar icon while Sidekick is in
  the tray turns the same window into a 380×640 panel by the icon
  (`togglePanel`; Mac under the menu bar at the icon, Windows above the
  taskbar's corner), deep purple gradient in the theme's hue with a glow,
  translucent cards: "Sidekick: Ready", encrypted / ready to receive and
  the network, the last file received (Show), every
  paired device with Send / Ping, a "Did you know?" tip, and
  Open Sidekick / Settings / Quit. It takes the focus and closes when it
  loses it (`onWindowBlur`; not while its file picker is open,
  `holdPanel`). With the main window open, the icon just brings it
  forward; right-click shows the menu. Closing the panel is one shared
  `_closingPanel` future: hiding it takes the focus, and that blur used to
  start a second close that hid the window right after Open Sidekick
  showed it (2.17.1: "opens and closes"). A request arriving takes over the
  window as the corner pop-up. Rendered by `tool/screenshots_test.dart`
  (`tray-panel.png`).
- **Auto-load** (`platform/autoload.dart`, Settings, Windows and Mac, on by
  default; the owner's call): starts at login, straight to the tray.
  Windows: a `Run` registry value with `--hidden` (the runner then never
  shows the window; it also allows one Sidekick at a time, bringing the
  running one back instead of starting a second, which would confuse
  paired devices). Mac: a LaunchAgent with `SIDEKICK_HIDDEN=1` (hides to
  the menu bar). No splash or startup chime then. Rewritten every start
  while on, so it follows the app.
- `platform/notifications.dart` (phones): a request while Sidekick isn't on
  screen becomes a notification with Accept / Decline (`notifyOffer`;
  the buttons come back as `offerAction`). Android: `Notifications.kt`
  (also the progress and "Received"), `OfferActionReceiver`, and
  `SidekickService`, a foreground service (connectedDevice, stopWithTask)
  with a small "Ready to receive" notification; Back on the last screen
  sends Sidekick to the background instead of closing it. iPhone:
  `OfferNotifier` in AppDelegate.swift (only while it runs in the
  background; iOS stops apps that are swiped away). The in-app card follows
  answers given there.
- The "open" button (folder icon) on received files and on the
  "Received" snackbar: Explorer/Finder on computers; on phones the Files
  app at the folder (`openFolder`: iPhone `shareddocuments://`, Android
  DocumentsContract, Download/Sidekick), or Photos / the gallery for photos
  and videos (`openGallery`; Android returns the MediaStore uri from
  `saveToGallery`).
- Screens close themselves with `closeRoute` (their own route, never
  "whatever's on top": that closed the wrong thing and left the sending
  screen's Close button dead).
- Photos and videos a phone receives (sent to it, or downloaded from the
  other device's files) go straight to Photos / the gallery, automatically,
  like AirDrop (the owner's call: no switch). `platform/gallery.dart` picks
  which files (`Gallery.kindOf`) and calls `saveToGallery` on
  `sidekick/ios` (`PhotosSaver`: add-only access, the file is moved in) and
  `sidekick/android` (MediaStore, Pictures/Sidekick and Movies/Sidekick,
  on a worker thread; the original is deleted after). Files a computer
  copies into a folder it browsed to stay there (`FileReceived.
  toReceiveFolder`). If saving fails, the file stays in the receive folder
  and the notice says why.
- Native code:
  - `app/ios/Runner/SidekickBLE.swift` and `app/macos/Runner/SidekickBLE.swift`
    must stay **identical** (copy one to the other after any edit).
  - `AppDelegate.swift` (iOS) and `MainFlutterWindow.swift` (macOS) register
    the channels.
  - The Windows runner compiles C++ with `/W4 /WX`.
- `app/macos/packaging/`: the .dmg background (1x and 2x), and `pkg/`: the
  .pkg installer's welcome page and corner icon (glass "sk", 1x and 2x).
  Macs get both: the .dmg (drag to Applications) and the .pkg (installs
  into /Applications). CI builds the .pkg with pkgbuild/productbuild.
- Privacy policy: `privacy.html` at the top of the repo (the website) and
  `app/packaging/privacy.txt` (shown by the Windows installer before
  installing, installed as `Privacy.txt`, and the .pkg's second page). Keep
  the two saying the same thing, and true: no account, no servers, no
  analytics; what's stored on the device; what's announced to nearby
  devices; every permission and why.
- Website hero (`website/hero.webp`, `hero.png` fallback): a MacBook
  receiving and an iPhone sending, made from the ad render frames
  (`tool/ad_frames_test.dart`), transparent so the page's colors show.
  There is no Media anywhere on the site (removed with the feature).
- `404.html` (top of the repo): the not-found page, for any missing
  address, so every link in it is absolute (`/…`). `.htaccess` makes the
  server show it for every wrong address, keeping the address and a real
  404 status (no redirect); folder listings are off and show it too. Same look and theme
  choice as the site, system fonts only, like `privacy.html`.
- **The site stays out of search results** (the owner's call: not yet):
  `noindex` in every page's `<meta name="robots">` and in the
  `X-Robots-Tag` header `.htaccess` puts on every file; `robots.txt` lets
  Google, Bing, DuckDuckGo, Apple and Yandex read the pages (they must, to
  see the noindex) and keeps every other bot out. Remove all three to be
  found.
- Website sounds (`website/sounds/`, copies of the owner's MP3s): the
  request sound when the demo phone asks, accept / decline on its buttons,
  accept on a download; only after a click; the speaker button in the top
  bar turns them off (`localStorage` `sidekick-sound`).
- Logos (`website/`): `2.png` is the wide wordmark, used **only on the
  website**; `3.png` is the "sk" monogram, used for every app icon and the
  logo inside the app (`app/assets/logo/logo.png`). `app/tool/make_icons.py`
  regenerates all of them; re-run it after changing 3.png.
  - Mac and iPhone icons are Liquid Glass: `Runner/AppIcon.icon` (Icon
    Composer format, in both Xcode projects' Resources) is what macOS/iOS
    26+ show, rendered live by the system (Dark, Clear, Tinted too). The
    `AppIcon.appiconset` PNGs are a pre-rendered glass look for older
    systems. Both come from `make_icons.py`; Xcode 26 (CI) builds the .icon.
    **No shadow or edge highlight behind "sk"** (the owner's call: they
    blurred the letters): the .icon's group shadow is `none`, and
    `glass_tile` draws the glyph crisp.
  - The website's tab icon (`website/favicon.png`) and home-screen icon
    (`website/apple-touch-icon.png`) are the same glass "sk", also from
    `make_icons.py`.
- Mac: the file picker (`file_picker`) needs the
  `files.user-selected.read-write` entitlement and `prepareFilePicker()`
  (skips its sandbox check), or Send files silently does nothing.
- `.github/workflows/build.yml`: CI and releases.

## Conventions

- Flutter is at `/home/user/tools/flutter/bin`. The UI library is
  `material_ui`.
- Format with `dart format -l 120`. Before pushing, `flutter analyze` must
  report no issues and `flutter test` must pass.
- Screenshots without a device:
  - `flutter test tool/screenshots_test.dart` renders the tabs.
  - `flutter test tool/transfer_shots_test.dart` renders the send and
    receive screens.
  - The first also renders the startup animation as `startup-NN.png`
    frames (50 ms apart).
  - `flutter test tool/qr_shots_test.dart --plain-name mac` (then
    `iphone`, with `SIDEKICK_CAMERA=` a picture for the camera) renders the
    QR pairing screens at 2x/3x for ads; `SIDEKICK_FONTS=` a folder of
    Inter TTFs stands in for San Francisco.
  - `flutter test tool/ad_frames_test.dart` renders the startup animation,
    an iPhone sending and the Mac's Accept card as 30 fps frames
    (`build/ad/<scene>/NNN.png`) for video ads. `SIDEKICK_THEME=mono`
    renders both tools in the Monochrome theme. `SIDEKICK_DPR=4` renders
    the Mac scene at 4x (`receive@4x`), sharp enough to zoom into in 4K.
    `--plain-name "remote iphone"`, then `"remote mac"` (run separately,
    or the iPhone shows up in the Mac's Nearby list), saves stills of a
    paired iPhone's Remote tab and the Mac's Devices tab, paired with a
    real loopback stand-in.
  - Output goes to `build/screenshots/`.
- Swift can't be compiled here. CI (`ios` and `macos` jobs) is the check.
- Bluetooth:
  - **Off by default** (the owner's call): Settings → Bluetooth turns it
    on (`AppState.bluetoothOn`, pref `bluetooth`); until then Sidekick
    never starts the radio, so no permission prompt at start. Picking
    Bluetooth in Connect device asks to turn it on.
  - **Wi-Fi first** (the owner's call): while this device is on Wi-Fi
    (`lanAddresses`: private ranges on real Wi-Fi/Ethernet interfaces,
    not mobile data, VPNs or virtual adapters) Bluetooth is never used,
    unless the other device says it isn't on Wi-Fi (`DeviceInfo.wifi`,
    sent over Bluetooth). "Not on Wi-Fi" needs two checks in a row. On
    Wi-Fi, Bluetooth scans once a minute at most. Once Wi-Fi reaches a
    device, Sidekick hangs up its own Bluetooth connection to it after 15 s
    idle (`_hangUpBluetoothWhereWifiWorks`, `BluetoothService.closeLink`):
    only that one; the radio and other devices (headphones…) are untouched.
  - **Sidekick isn't a Bluetooth app** (the owner's call): the Devices
    page's entries say "Connect" with a link icon and open every way to
    connect, Wi-Fi first (`showConnectOptions`, `_connectWays`); Bluetooth
    is the last choice there.
  - Writes are always one packet (MTU minus 3), never long writes.
  - Files go over Bluetooth in 32 KB sealed parts (`/v1/fs/upload/part`),
    each retried if it arrives damaged ("Message failed authentication"),
    never as one giant message: one bad packet in a multi-MB message used
    to fail the whole file. Older receivers get the whole file (fallback).
  - Message ids start at a random number per client, so two clients on one
    connection never mix their chunks.
  - Sealed messages carry `kid` (a short fingerprint of the pairing key).
    A mismatch is refused as "Pairing keys don't match" and the app shows
    "Pair again"; a failed decrypt with the same key means a damaged packet.
    Every refusal is written to the receiver's Bluetooth log.
- **Direct Wi-Fi for every other pair** (`platform/hotspot.dart`
  `DirectLink`, the owner's call: "make it work for everything"): one
  device opens a small network and the other joins. Opens: Android
  (local-only hotspot), Windows (Wi-Fi Direct "legacy" network through
  PowerShell's WinRT, `-EncodedCommand`; no native code). Joins: Android
  10+ (`WifiNetworkSpecifier`, asks once; `bindProcessToNetwork` so Dart's
  sockets use it), Windows (netsh), Mac (networksetup), iPhone
  (`NEHotspotConfiguration`, needs `Runner.entitlements`' Hotspot
  Configuration, which only signed builds have; otherwise `JoinByHand`:
  the iPhone shows the name and password to join in Settings,
  `ui/direct_wifi.dart`). `directLinkHost` decides who opens it (Android,
  then Windows; two of a kind: the smaller id), tested in
  `test/direct_link_test.dart`. How the two find each other:
  - Bluetooth (the doorbell): a paired device seen over Bluetooth but on no
    shared network is `viaDirectLinkOnly`; sending or Remote sets up the
    link first, even when both are on (different) Wi-Fi networks:
    Bluetooth then never carries the files. Bluetooth is still off by
    default; an unreachable device's card offers "Find nearby", which asks
    to turn it on (`askToTurnOnBluetooth`).
  - A QR code: with no Wi-Fi, an Android phone or PC showing its code opens
    its network first and puts it in the code (`ws`, `wk`, `wt`); the
    scanning phone joins it and pairs (`_reachInviteNetwork`).
  Over Bluetooth (both off Wi-Fi), transfers over 1 MB switch to the link.
- **Direct Wi-Fi between iPhones and Macs** (no router, no Bluetooth):
  Apple's peer-to-peer Wi-Fi (AWDL, AirDrop's link), through the Network
  framework (`includePeerToPeer`). `SidekickP2P.swift` (identical in
  ios/Runner and macos/Runner, like SidekickBLE) advertises
  `_sidekick-p2p._tcp` named after the device id and hands each incoming
  connection to the device's own server on 127.0.0.1; `connect` gives a
  127.0.0.1 port that leads to another device. Sidekick's HTTPS (pinned
  certificate) goes through untouched. Dart: `platform/apple_p2p.dart`;
  `AppState` (`_checkP2p`, `viaDirectWifi`, `clientFor`) uses it only when
  the device isn't on the same network (`_onLan`). Looking for devices
  costs Wi-Fi time, so on Wi-Fi it looks 10 s a minute while a paired
  iPhone/Mac is away, and stays on only while one is reached, while
  pairing (QR code: `_reachInviteDirect`), or with no Wi-Fi at all. The
  server never records 127.0.0.1 as a device's address (`_remoteAddress`).
  Both Info.plists list the service in `NSBonjourServices`.
- Pairing is SPAKE2 with either the 6-digit code or a QR invite's secret
  (`PairingInvite`: 5 minutes, one device, closed with the dialog). The
  scanner only talks to the address that presents the QR code's
  certificate fingerprint, and falls back to Bluetooth. Camera: iOS
  `NSCameraUsageDescription`; Android's permission comes from the plugin.
  The Mac has no camera permission (it never scans).
- **Live Activities** (iPhone, iOS 16.2+): a transfer's progress on the
  Lock Screen and in the Dynamic Island, for files coming in (once
  accepted) and going out with Send (`platform/live_activity.dart`
  `LiveTransfers`, at most one update a second; ends with Received / Sent /
  Declined…, gone 4 s later). Native: `LiveTransfers` in AppDelegate.swift
  (`liveStart`, `liveUpdate`, `liveEnd`); `Runner/TransferActivity.swift`
  (the attributes) is compiled into both the app and the **SidekickLive**
  widget extension (`ios/SidekickLive/`, its own target in the Xcode
  project, embedded by "Embed Foundation Extensions", which must stay
  before "Thin Binary"; bundle id `dev.sidekick.sidekick.LiveActivity`,
  which the TestFlight job renames along with the app's).
  `NSSupportsLiveActivities` is on in Info.plist. When adding objects to
  the .pbxproj by hand, use IDs nothing else has (2.7.0's first push reused
  the app icon's and Xcode called the project damaged).
- **Phone notifications on computers** (2.15.0, Android only: iOS lets
  no app see others' notifications; Settings → Show notifications on
  computers, pref `relayNotifications`, off by default): `NotificationRelay`
  (PhoneRelay.kt, a NotificationListenerService the user allows in
  Notification access) skips ongoing, private, summary and system ones and
  calls Dart on `sidekick/phone`; `AppState._relayNotification` posts
  `/v1/notification` {app, title, text} to paired computers in reach. Macs
  and PCs show it with `platform/desktop_notify.dart`: Notification Center
  (`showNotification` on `sidekick/macos`, `MacNotifications`) or a Windows
  toast through PowerShell under the AUMID `Sidekick.Sidekick`, which the
  installer's Start menu shortcut carries (`sidekick.iss`).
- **Screenshots to computers** (2.15.0, phones; Settings → Send screenshots
  to computers, pref `sendScreenshots`, off by default): Android's
  `ScreenshotWatcher` (MediaStore observer, READ_MEDIA_IMAGES) and the
  iPhone's `ScreenshotWatcher` in AppDelegate.swift (PHPhotoLibrary change
  observer, full read access; "Limited" never sees new ones; only while
  Sidekick runs) copy each new screenshot to a temp file and call
  `screenshot` on `sidekick/phone`; it goes over Wi-Fi only to
  `/v1/screenshot` (no Accept; straight into the receive folder,
  `FileReceived.screenshot`), and the computer shows a notification.
- **No shared clipboard and no Screen Mirroring** (removed in 2.15.0, the
  owner's call: mirroring was too laggy). Don't bring them back.
- **Always running on phones** (2.13.0): Android keeps one Flutter engine
  outside the screen (`KeepRunning.kt` `SidekickEngine`, cached;
  MainActivity borrows it and never destroys it), `SidekickService` is
  sticky and doesn't stop with the task, `BootReceiver` starts it at boot,
  Settings → Keep running in the background (pref `keepRunning`) plus a
  battery-optimisation row. With no screen, `sidekick/android` is answered
  by the engine's background handlers (notifications, sounds: `Sounds.kt`);
  MainActivity takes over while open. iPhone: `KeepAlive` in AppDelegate
  plays silence (mixes with others) and revives itself after interruptions,
  route changes, media resets and via a 5 s watchdog. iOS still stops apps
  swiped away.
- **Ping** (`/v1/ping`, the card's Ping button): the other device rings
  the owner's ringtone (`tool/sounds/ping_ringtone.mp3` → `ping.wav`, kept
  whole and loud by `prepare_sounds.py`) **on repeat until Found It!** on
  it (`ui/ping.dart`, `AppState.ringingFrom` / `foundIt`). Looping is native:
  `loopSound` / `stopLoop` on the Mac, iPhone (playback category: through
  the silent switch) and Android (alarm volume: heard on silent) channels,
  PlaySound with `SND_LOOP` on Windows. One ping at a time: while it rings,
  the server answers another with 409 and the sender shows "This device is
  already being pinged" (`showAlreadyPinged`). In the tray the window
  opens; a phone in the background gets a notification. Plays whatever
  Settings → Sound says.
- **Steady connections:** Android's `SidekickService` holds a high-perf
  Wi-Fi lock (`WAKE_LOCK`) so Wi-Fi doesn't doze with the screen off; the
  Mac holds a `latencyCritical` activity (`MainFlutterWindow.awake`) so App
  Nap doesn't throttle it in the menu bar; `PeerClient._send` retries once
  on a dead kept-alive connection (always for GET, otherwise only if the
  request never went out).
- **Liquid Glass** (2.14.0, the owner's call: Material is the default
  everywhere): on iOS and macOS 26+ (`liquidGlassAvailable`, from
  `appleOsMajor`), Settings → Theme has a "Theme" dropdown: Default /
  Liquid Glass (`AppState.liquidGlass`, pref `look`). Nowhere else is it
  offered. `ui/glass.dart`: `glassTheme` turns the Material theme
  translucent (cards, dialogs, sheets, menus, bars) and adds `GlassLook`;
  `GlassBackdrop` (soft blobs of the theme's colors) sits under every
  screen (MaterialApp `builder`); `GlassPanel` (blur, tint, bright rim)
  frames the phone's floating tab bar and the computer's content panel
  (shell.dart). Since 2.17.0 `glassTheme` also makes buttons (`GlassFill`
  through `backgroundBuilder`), selections, switches, fields, menus,
  snackbars and tooltips glass, each tinted in its own color. **No live
  blur on controls or the computer's content panel** (2.17.1): only the
  soft backdrop is behind them, and a BackdropFilter per button made
  screens slow; only the phone's floating tab bar blurs. Rendered by `tool/screenshots_test.dart` (`glass-*.png`).
- Devices announce their release (`DeviceInfo.app`, "2.2.0"); a paired card
  shows "Update Sidekick on it" when the other device runs an older one.
- **iPhones can't be controlled** (Apple allows no app to): Remote on an
  iPhone shows only why (`_IphoneCantBeControlled`, no input session, no
  touchpad), iPhone device cards have no Remote shortcut, and a one-time
  pop-up says so the first time a device pairs with or picks an iPhone
  (`showIphoneRemoteNotice`, pref `iphoneRemoteNotice`).
- There is no Media feature (removed in 2.2.0: iPhones can't control other
  apps' playback). Don't bring it back.
  - iPhone and Mac use native CoreBluetooth, not the plugin: the plugin
    reported no devices on Apple.
  - Windows advertises through `addService` only. Its advertiser rejects
    service IDs.
- Mac secrets live in a 0600 file, never the keychain (an unsigned app gets
  endless keychain password prompts).
- Develop on `claude/sidekick-app-architecture-main`, the repo's default and
  only branch (the owner's call, 15 Oct 2026: it was
  `claude/sidekick-app-architecture-8ilytw`, renamed on GitHub). A session
  set up with another, random branch name (`claude/brave-goldberg-…` and
  the like) still works here and pushes here; don't leave extra branches
  on GitHub (they confused the owner and their son).
- **Syncing with GitHub (`dankordigital/sidekick`):** the app is written in
  Claude cloud sessions (claude.ai/code: Flutter is there; CI builds all four
  platforms). A copy also lives on the family Mac
  (`~/Documents/GitHub/sidekick`, macOS 12, no Flutter or Xcode). Nobody
  should have to remember to sync (the owner's call), so Claude does it
  without asking:
  - **Before starting work:** `git pull --rebase --autostash`, since the
    other place may have pushed.
  - **After each finished change:** push it (cloud sessions push as usual;
    on the Mac, `printf 'y\n' | ./sync.sh "<what changed>"`, which pulls,
    commits everything and pushes, never uploading to the hosting). Don't
    push half-done work.
  - If it stops on a conflict, explain it to the owner and resolve it with
    them. Never force-push.

## Releasing

The owner wants finished work released right away: once a feature or fix
is done and CI is green, release it (next patch version unless they name
one) without asking.

1. Push to the branch. CI runs tests and builds all four platforms.
2. Run the `Build` workflow (workflow_dispatch) with `release_tag: vX.Y.Z`.
   It builds everything and publishes the release: `SidekickSetup-X.Y.Z.exe`,
   `Sidekick-X.Y.Z-Apple-silicon.dmg` / `.pkg`, `Sidekick-X.Y.Z-Intel.dmg` /
   `.pkg` (2.16.0, the owner's call: one app per kind of Mac; CI thins the
   universal build with `ditto --arch` and signs each again, ad hoc),
   `Sidekick-X.Y.Z.apk`, `Sidekick-X.Y.Z.ipa`, `altstore.json`.
3. While the site is a wishlist there are no download links to bump. When
   downloads come back: update `index.html` (every `X.Y.Z` link, `version:`
   and "Version X.Y.Z"), including `RELEASE.files.macosPkg` (the `.pkg`).
4. Add the version to the top of `VERSIONS.md`.
