import 'dart:async';

import 'dock.dart';

import 'package:material_ui/material_ui.dart';

import '../app_state.dart';
import '../core/models.dart';
import '../core/server.dart';
import '../core/trust.dart';
import '../platform/desktop_window.dart';
import '../platform/gallery.dart';
import '../platform/home_widgets.dart';
import '../platform/live_activity.dart';
import '../platform/notifications.dart';
import '../platform/sound.dart';
import 'chat_page.dart';
import 'devices_page.dart';
import 'kit.dart';
import 'direct_wifi.dart';
import 'ping.dart';
import 'notices.dart';
import 'qr_pairing.dart';
import 'remote_page.dart';
import 'send_page.dart';
import 'settings_page.dart';
import 'text_messages.dart';
import 'transfer_screens.dart';
import 'widgets.dart';

class Shell extends StatefulWidget {
  const Shell({super.key, required this.state});
  final AppState state;

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int _index = 0;
  late final List<StreamSubscription<Object>> _subs;
  // Picks up permissions granted in system settings while we were away.
  late final AppLifecycleListener _lifecycle;

  AppState get state => widget.state;

  /// The tray panel's Settings is tab 4.
  List<({IconData icon, IconData selected, String label})> get _destinations => [
    (icon: Icons.devices_outlined, selected: Icons.devices, label: 'Devices'),
    (icon: Icons.chat_bubble_outline_rounded, selected: Icons.chat_bubble_rounded, label: 'Chat'),
    (icon: Icons.ios_share_rounded, selected: Icons.ios_share_rounded, label: 'Send'),
    (icon: Icons.screen_share_outlined, selected: Icons.screen_share, label: 'Remote'),
    (icon: Icons.settings_outlined, selected: Icons.settings, label: 'Settings'),
  ];

  @override
  void initState() {
    super.initState();
    _subs = [
      state.pairRequests.listen(_showPin),
      state.notices.listen(_showNotice),
      state.transferOffers.listen(_showOffer),
      state.sends.listen(_showSend),
      // Another device pinged this one: loud, and who.
      state.pings.listen((from) {
        if (mounted) unawaited(showPinged(context, state, from));
      }),
      // Text or a link: always asks Copy / Open (never saved as a file).
      state.texts.listen((message) {
        if (mounted) unawaited(showReceivedText(context, state, message));
      }),
      // iPhone: a network to join by hand for a direct link.
      state.manualJoins.listen((join) {
        if (mounted) unawaited(showManualJoin(context, join));
      }),
    ];
    _lifecycle = AppLifecycleListener(
      onResume: () {
        state.resumed();
        // A home-screen widget may have brought Sidekick forward.
        Timer(const Duration(milliseconds: 300), _widgetLink);
      },
    );
    // Home-screen widgets (phones) follow the devices and the last file.
    state.addListener(_updateWidgets);
    _updateWidgets();
    WidgetsBinding.instance.addPostFrameCallback((_) => _widgetLink());
    // The tray panel's Settings opens that tab.
    DesktopWindow.instance.openTab.addListener(_openTab);
    // The first time this device pairs with an iPhone: it can't be controlled.
    _subs.add(
      state.pairedEvents.listen((d) {
        if (d.platform == DevicePlatform.ios && !state.iphoneRemoteNoticeSeen && mounted) {
          unawaited(showIphoneRemoteNotice(context, state, d.name));
        }
      }),
    );
    // Phones: requests while Sidekick is in the background become notifications.
    unawaited(OfferNotifications.init());
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _lifecycle.dispose();
    state.removeListener(_updateWidgets);
    DesktopWindow.instance.openTab.removeListener(_openTab);
    super.dispose();
  }

  /// Which way the last tab change went, for the slide.
  bool _cameFromRight = true;

  void _go(int index) => setState(() {
    _cameFromRight = index >= _index;
    _index = index;
  });

  void _updateWidgets() => HomeWidgets.update(state);

  /// A widget's Send opens Send for that device; Ping rings it.
  Future<void> _widgetLink() async {
    final link = await HomeWidgets.takeLink();
    if (link == null || !mounted) return;
    final device = state.paired.where((d) => d.id == link.queryParameters['id']).firstOrNull;
    switch (link.host) {
      case 'send' when device != null:
        state.select(device.id);
        _go(2);
      case 'ping' when device != null:
        state.select(device.id);
        _go(0);
        final rang = await state.ping(device);
        if (!rang && mounted) await showAlreadyPinged(context, device.name);
      default:
        _go(0);
    }
  }

  void _openTab() {
    final tab = DesktopWindow.instance.openTab.value;
    if (tab == null || !mounted) return;
    DesktopWindow.instance.openTab.value = null;
    _go(tab);
  }

  void _showOffer(TransferOffer offer) {
    // iPhone: the progress on the Lock Screen and in the Dynamic Island.
    LiveTransfers.followIncoming(offer);
    if (!mounted) return;
    if (state.sound) unawaited(playRequestSound());
    // Closed to the tray: the small corner window asks instead.
    if (DesktopWindow.supported && DesktopWindow.instance.show(offer)) return;
    // Phones in the background: a notification too; the card waits in the app.
    OfferNotifications.show(offer);
    showIncomingOffer(context, offer, state: state, sounds: state.sound);
  }

  void _showSend(OutgoingSend send) {
    LiveTransfers.followOutgoing(send);
    if (mounted) showSendingScreen(context, send, state: state);
  }

  void _showNotice(Notice notice) {
    if (notice.problem case final problem?) {
      showError(
        context,
        problem,
        title: notice.title,
        device: notice.device?.name,
        state: state,
        pairDevice: notice.device,
      );
      return;
    }
    showNotice(
      notice.message,
      icon: notice.info
          ? Icons.info_outline_rounded
          : notice.revealPath != null || notice.inGallery
          ? Icons.download_done_rounded
          : Icons.check_circle_rounded,
      actionLabel: notice.inGallery
          ? 'Open'
          : notice.revealPath != null && canRevealFiles
          ? revealLabel
          : null,
      onAction: notice.inGallery
          ? () => Gallery.open(notice.galleryUri)
          : notice.revealPath != null && canRevealFiles
          ? () => revealInFolder(notice.revealPath!)
          : null,
      // Long news gets longer to read (never more than 10 s).
      duration: Duration(seconds: notice.message.length > 90 ? 10 : 5),
    );
  }

  Future<void> _showPin(PairingRequest request) async {
    // Close the dialog automatically once the other device enters the code.
    final done = state.pairedEvents.firstWhere((d) => d.id == request.device.id);
    final cancelled = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _PinDialog(request: request, done: done, state: state),
    );
    if (cancelled ?? true) state.cancelPairing(request.device.id);
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      DevicesPage(state: state, onOpen: _go),
      ChatPage(state: state, onGoToDevices: () => _go(0)),
      SendPage(state: state, onGoToDevices: () => _go(0)),
      RemotePage(state: state, onGoToDevices: () => _go(0)),
      SettingsPage(state: state),
    ];
    final wide = MediaQuery.sizeOf(context).width >= 700;
    final scheme = Theme.of(context).colorScheme;
    // Wide computer windows (the design's Computer · Devices): the device
    // list beside its Chat, so Chat isn't a tab of its own there.
    final split = MediaQuery.sizeOf(context).width >= 1000;
    final shown = split && _index == 1 ? 0 : _index;
    final Widget current = split && shown == 0
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(width: 390, child: pages[0]),
              const VerticalDivider(width: 1, thickness: 1, color: K.hair),
              Expanded(child: pages[1]),
            ],
          )
        : pages[shown];

    final body = ListenableBuilder(
      listenable: state,
      builder: (context, _) => Column(
        children: [
          if (state.activeRemoteSessions.isNotEmpty)
            MaterialBanner(
              backgroundColor: scheme.tertiaryContainer,
              leading: Icon(Icons.phonelink_ring_outlined, color: scheme.onTertiaryContainer),
              content: Text(
                '${state.activeRemoteSessions.values.map((p) => p.name).join(', ')} is controlling this computer',
                style: TextStyle(color: scheme.onTertiaryContainer),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    for (final id in state.activeRemoteSessions.keys.toList()) {
                      state.unpair(id);
                    }
                  },
                  child: const Text('Unpair and stop'),
                ),
              ],
            ),
          Expanded(
            // Like Apple's tab bars: the old tab is gone at once and the new
            // one fades in quickly. (Cross-fading two whole tabs meant drawing
            // both for 300 ms on every switch.)
            // The new tab glides in from the side it's on (right when moving
            // right along the dock), fading in; the old one is gone at once.
            child: AnimatedSwitcher(
              duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : const Duration(milliseconds: 300),
              reverseDuration: Duration.zero,
              switchInCurve: const Cubic(0.22, 1, 0.36, 1),
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween(begin: Offset(_cameFromRight ? 0.06 : -0.06, 0), end: Offset.zero).animate(animation),
                  child: child,
                ),
              ),
              child: KeyedSubtree(key: ValueKey(shown), child: current),
            ),
          ),
        ],
      ),
    );

    if (!wide) {
      // Sidekick 4.0: the floating dock.
      return Scaffold(
        body: SafeArea(bottom: false, child: body),
        bottomNavigationBar: SafeArea(
          minimum: const EdgeInsets.fromLTRB(16, 6, 16, 12),
          child: FloatingDock(
            index: _index,
            onTap: _go,
            items: [for (final d in _destinations) DockItem(icon: d.icon, selectedIcon: d.selected, label: d.label)],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0B0B0B),
      body: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SideRail(
              index: shown,
              onTap: _go,
              items: [
                for (final (i, d) in _destinations.indexed)
                  if (!(split && i == 1)) (i, DockItem(icon: d.icon, selectedIcon: d.selected, label: d.label)),
              ],
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: ColoredBox(color: K.page, child: body),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PinDialog extends StatefulWidget {
  const _PinDialog({required this.request, required this.done, required this.state});
  final PairingRequest request;
  final AppState state;
  final Future<Object> done;

  @override
  State<_PinDialog> createState() => _PinDialogState();
}

class _PinDialogState extends State<_PinDialog> {
  Timer? _expiry;

  /// The same QR code as Connect device → QR code: one code for every way
  /// of pairing. Only for phones (they scan); closed with the dialog.
  late final _invite = scansQr(widget.request.device.platform) ? widget.state.createInvite() : null;

  @override
  void initState() {
    super.initState();
    widget.done.then((_) {
      if (mounted) Navigator.of(context).pop(false);
    });
    _expiry = Timer(widget.request.expires.difference(DateTime.now()), () {
      if (mounted) Navigator.of(context).pop(true);
    });
  }

  @override
  void dispose() {
    _expiry?.cancel();
    if (_invite case final code?) widget.state.cancelInvite(code.invite);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pin = widget.request.pin;
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      icon: const Icon(Icons.link_rounded),
      title: Text('Pair with ${widget.request.device.name}?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Enter this code on the other device:', textAlign: TextAlign.center),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(color: scheme.primaryContainer, borderRadius: BorderRadius.circular(20)),
            // Read out digit by digit (a screen reader would say "123 thousand…").
            child: Semantics(
              label: 'Pairing code: ${pin.split('').join(' ')}',
              excludeSemantics: true,
              child: SelectableText(
                '${pin.substring(0, 3)} ${pin.substring(3)}',
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  color: scheme.onPrimaryContainer,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 6,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ),
          // A phone can scan this instead of typing the digits.
          if (_invite case final code?) ...[
            const SizedBox(height: 16),
            Text('or scan the QR code:', style: TextStyle(color: scheme.onSurfaceVariant)),
            const SizedBox(height: 12),
            PairingQrCode(data: code.qr, size: 150),
          ],
          const SizedBox(height: 16),
          Text(
            'Only pair with devices you own. A paired device can send and browse files and use the mouse and keyboard.',
            textAlign: TextAlign.center,
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
          ),
        ],
      ),
      actions: [TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Cancel'))],
    );
  }
}
