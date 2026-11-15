import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

import '../app_state.dart';
import '../core/errors.dart';
import '../core/models.dart';
import '../core/pairing_qr.dart';
import '../core/server.dart';
import 'bluetooth_pairing.dart';
import 'ping.dart';
import 'qr_pairing.dart';
import 'files_page.dart';
import 'kit.dart';
import 'text_messages.dart';
import 'transfer_screens.dart';
import 'widgets.dart';

/// Sidekick 4.0's Devices tab, built to match the design (Devices.png,
/// design/emulator `phDevices`): the title with "+ Connect", "Needs you"
/// while a device waits for an answer, Favorites and Paired in panels of
/// rows, Nearby in dashed ones. Less is on screen than before (the owner:
/// "less bloated… use Fitts's law"): each row is one big target that opens
/// the device's Chat, Send is the one button on it, and everything else is
/// a hold away.
class DevicesPage extends StatelessWidget {
  const DevicesPage({super.key, required this.state, required this.onOpen});
  final AppState state;
  final void Function(int tab) onOpen;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: state,
    builder: (context, _) {
      final paired = state.paired;
      final favourites = paired.where((d) => state.alwaysAccept.contains(d.id)).toList();
      final others = paired.where((d) => !state.alwaysAccept.contains(d.id)).toList();
      final nearby = state.nearby;
      final waiting = state.waitingOffers.where((o) => o.isOpen).toList();
      var n = 0;
      Widget enter(Widget child) => Entrance(index: n++, child: child);
      return ListView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        children: [
          enter(
            KTitle(
              'Devices',
              action: KPill('+ Connect', style: KPillStyle.dark, onPressed: () => showConnectOptions(context, state)),
            ),
          ),
          const SizedBox(height: 16),
          enter(const KSub('Your devices, a little closer.')),
          if (paired.isEmpty) ...[
            const SizedBox(height: 16),
            enter(_BetterTogether(onConnect: () => showConnectOptions(context, state))),
          ],
          for (final offer in waiting) ...[const SizedBox(height: 16), enter(_NeedsYou(state: state, offer: offer))],
          if (favourites.isNotEmpty) ...[
            const SizedBox(height: 16),
            enter(const KLabel('Favorites', icon: Icons.star_border_rounded)),
            const SizedBox(height: 10),
            enter(_Rows(state: state, devices: favourites, onOpen: onOpen)),
          ],
          if (others.isNotEmpty) ...[
            const SizedBox(height: 16),
            enter(const KLabel('Paired')),
            const SizedBox(height: 10),
            enter(_Rows(state: state, devices: others, onOpen: onOpen)),
          ],
          if (nearby.isNotEmpty) ...[
            const SizedBox(height: 16),
            enter(const KLabel('Nearby')),
            const SizedBox(height: 10),
            for (final d in nearby) ...[
              enter(
                KPanel(
                  dashed: true,
                  child: KRow(
                    platform: d.platform,
                    color: K.platformColor(d.platform),
                    name: d.name,
                    status: d.address == null ? 'Nearby over Bluetooth' : 'Same Wi-Fi',
                    statusColor: K.faint,
                    onTap: () => pairWith(context, state, d),
                    action: KPill(
                      'Pair',
                      style: KPillStyle.outline,
                      small: true,
                      onPressed: () => pairWith(context, state, d),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
            enter(const KSub('Only devices on your Wi-Fi can find you.', size: 12.5)),
          ],
          // Room to scroll the last row above the floating dock.
          const SizedBox(height: 24),
        ],
      );
    },
  );
}

/// No device yet: the design's "Better together." card.
class _BetterTogether extends StatelessWidget {
  const _BetterTogether({required this.onConnect});
  final VoidCallback onConnect;

  @override
  Widget build(BuildContext context) => KPanel(
    padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const KDeviceTile(platform: DevicePlatform.macos, color: K.green, size: 52),
        const SizedBox(height: 12),
        const Text(
          'Better together.',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: -0.5, color: K.text),
        ),
        const SizedBox(height: 8),
        const KSub('Send files, keep notes and control your computer, all over your Wi-Fi.'),
        const SizedBox(height: 16),
        KPill('Connect a device', onPressed: onConnect),
      ],
    ),
  );
}

/// A device waiting for an answer: amber, with View.
class _NeedsYou extends StatelessWidget {
  const _NeedsYou({required this.state, required this.offer});
  final AppState state;
  final TransferOffer offer;

  @override
  Widget build(BuildContext context) {
    final n = offer.files.length;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: K.amberBg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: K.amberLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Needs you',
            style: TextStyle(color: K.amber, fontWeight: FontWeight.w500, fontSize: 14),
          ),
          const SizedBox(height: 12),
          KRow(
            platform: offer.from.platform,
            color: K.platformColor(offer.from.platform),
            tileBackground: const Color(0x33000000),
            name: offer.from.name,
            status: n == 1 ? 'Wants to send you ${offer.files.first.name}' : 'Wants to send you $n files',
            statusColor: const Color(0xB3FFE2AD),
            padding: EdgeInsets.zero,
            onTap: () => showIncomingOffer(context, offer, state: state),
            action: KPill(
              'View',
              style: KPillStyle.amber,
              onPressed: () => showIncomingOffer(context, offer, state: state),
            ),
          ),
        ],
      ),
    );
  }
}

/// Paired devices in one panel.
class _Rows extends StatelessWidget {
  const _Rows({required this.state, required this.devices, required this.onOpen});
  final AppState state;
  final List<PairedDevice> devices;
  final void Function(int tab) onOpen;

  @override
  Widget build(BuildContext context) => KPanel(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Column(
      children: [for (final d in devices) _PairedRow(key: ValueKey(d.id), state: state, device: d, onOpen: onOpen)],
    ),
  );
}

/// One paired device: tap for its Chat, Send on the right, hold for more.
class _PairedRow extends StatelessWidget {
  const _PairedRow({super.key, required this.state, required this.device, required this.onOpen});
  final AppState state;
  final PairedDevice device;
  final void Function(int tab) onOpen;

  void _open(int tab) {
    state.select(device.id);
    onOpen(tab);
  }

  Future<void> _send(BuildContext context) async {
    final files = await pickFilesToSend(context, title: 'Send to ${device.name}');
    if (files.isNotEmpty) await state.sendFiles(device, files);
  }

  @override
  Widget build(BuildContext context) {
    final online = state.isOnline(device.id);
    final reset = state.needsRepair(device) != null;
    final how = state.connectionLabel(device.id);
    final seen = state.lastSeen(device.id);
    final finding = state.isFinding(device.id);
    final String status;
    if (reset) {
      status = 'Pair again to keep using it';
    } else if (online) {
      status = '${how ?? 'Connected'} · ready';
    } else if (finding) {
      status = 'Looking for it…';
    } else {
      status = seen == null ? 'Not reachable · open Sidekick' : 'Not reachable · seen ${formatAgo(seen)}';
    }
    final Widget action = reset
        ? KPill('Pair again', onPressed: () => pairWith(context, state, state.forgetForRepair(device)))
        : online
        ? KPill('Send', onPressed: () => _send(context))
        : KPill('Try again', style: KPillStyle.outline, onPressed: finding ? null : () => state.findDevice(device));
    return MaybeDropTarget(
      onFiles: (files) => state.sendFiles(device, files),
      child: KRow(
        platform: device.platform,
        // Its own colour; grey only for a device never heard from.
        color: online || seen != null ? K.platformColor(device.platform) : K.faint,
        name: device.name,
        status: status,
        statusColor: reset ? K.red : (online ? K.ok : K.faint),
        onTap: () => _open(1),
        onHold: () => _more(context),
        action: action,
      ),
    );
  }

  /// Hold (or right-click): everything that isn't Send.
  Future<void> _more(BuildContext context) async {
    unawaited(HapticFeedback.mediumImpact());
    final online = state.isOnline(device.id);
    final caps = state.capabilitiesOf(device.id);
    final canControl = (caps?.input ?? true) && device.platform != DevicePlatform.ios;
    final favourite = state.alwaysAccept.contains(device.id);
    final options = <(String, IconData, VoidCallback?)>[
      ('Open chat', Icons.chat_bubble_outline_rounded, () => _open(1)),
      if (caps?.files ?? true)
        ('Browse files', Icons.folder_open_rounded, online ? () => showFilesOf(context, state, device) : null),
      if (canControl) ('Remote control', Icons.mouse_outlined, online ? () => _open(3) : null),
      ('Send text or a link', Icons.notes_rounded, online ? () => askAndSendText(context, state, device) : null),
      (
        'Ping',
        Icons.notifications_active_outlined,
        online
            ? () async {
                final rang = await state.ping(device);
                if (!rang && context.mounted) await showAlreadyPinged(context, device.name);
              }
            : null,
      ),
      (
        favourite ? 'Remove from Favorites' : 'Add to Favorites',
        favourite ? Icons.star_rounded : Icons.star_border_rounded,
        () => state.setAlwaysAccept(device.id, !favourite),
      ),
      ('Unpair', Icons.link_off_rounded, () => _confirmUnpair(context)),
    ];
    await showActions(context, title: device.name, options: options);
  }

  Future<void> _confirmUnpair(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Unpair ${device.name}?'),
        content: const Text(
          "The two devices won't be able to send files to or control each other until you pair them again.",
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Unpair')),
        ],
      ),
    );
    if (ok == true) await state.unpair(device.id);
  }
}

Future<void> pairWith(BuildContext context, AppState state, DeviceInfo device) async {
  try {
    await state.requestPairing(device);
  } catch (e) {
    if (context.mounted) showError(context, e, title: "Couldn't pair with ${device.name}", device: device.name);
    return;
  }
  if (!context.mounted) return;
  final paired = await showDialog<PairedDevice>(
    context: context,
    barrierDismissible: false,
    builder: (context) => _EnterPinDialog(state: state, device: device),
  );
  if (paired != null && context.mounted) showPaired(context, paired);
}

class _EnterPinDialog extends StatefulWidget {
  const _EnterPinDialog({required this.state, required this.device});
  final AppState state;
  final DeviceInfo device;

  @override
  State<_EnterPinDialog> createState() => _EnterPinDialogState();
}

class _EnterPinDialogState extends State<_EnterPinDialog> {
  final _controller = TextEditingController();
  String? _error;
  bool _busy = false;

  Future<void> _submit() async {
    if (_controller.text.length != 6 || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final paired = await widget.state.confirmPairing(widget.device, _controller.text);
      if (mounted) Navigator.pop(context, paired);
    } catch (e) {
      setState(() {
        _busy = false;
        _error = describeError(e);
        _controller.clear();
      });
    }
  }

  /// Scans the QR code next to the 6-digit code instead of typing it. It's
  /// the same QR code as everywhere else (an invite), which pairs on its own.
  Future<void> _scan() async {
    final code = await scanPairingQr(context);
    if (code == null || !mounted) return;
    switch (code) {
      case InviteQr() when code.id == widget.device.id:
        setState(() {
          _busy = true;
          _error = null;
        });
        try {
          final paired = await widget.state.pairWithInvite(code);
          if (mounted) Navigator.pop(context, paired);
        } catch (e) {
          if (mounted) {
            setState(() {
              _busy = false;
              _error = describeError(e);
            });
          }
        }
      // A device before 2.6.2 shows the 6 digits as a QR code.
      case PinQr() when code.id == widget.device.id:
        _controller.text = code.pin;
        await _submit();
      default:
        setState(
          () => _error = "That's not the code ${widget.device.name} is showing. Scan the one next to the 6 digits.",
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: Icon(platformIcon(widget.device.platform)),
      title: Text('Pair with ${widget.device.name}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Type the 6-digit code shown on ${widget.device.name}.', textAlign: TextAlign.center),
          const SizedBox(height: 20),
          SizedBox(
            width: 220,
            child: TextField(
              controller: _controller,
              autofocus: true,
              enabled: !_busy,
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              maxLength: 6,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(letterSpacing: 8),
              decoration: InputDecoration(counterText: '', errorText: _error, errorMaxLines: 3),
              onChanged: (v) {
                if (v.length == 6) _submit();
              },
              onSubmitted: (_) => _submit(),
            ),
          ),
          if (_busy) const Padding(padding: EdgeInsets.only(top: 16), child: LinearProgressIndicator()),
          if (canScanQr) ...[
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _busy ? null : _scan,
              icon: const Icon(Icons.qr_code_scanner_rounded),
              label: const Text('Scan the QR code instead'),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(onPressed: _busy ? null : () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: _busy ? null : _submit, child: const Text('Pair')),
      ],
    );
  }
}

typedef _ConnectWay = ({IconData icon, String title, String detail, VoidCallback? onTap});

/// The ways to connect a device, Wi-Fi first. Bluetooth is only the fallback
/// for when there's no shared Wi-Fi.
List<_ConnectWay> _connectWays(BuildContext context, AppState state) => [
  (
    icon: Icons.wifi_rounded,
    title: 'Wi-Fi',
    detail: state.scanning ? 'Looking on this network…' : 'Find devices on the same Wi-Fi',
    onTap: state.scanning ? null : state.scanNetwork,
  ),
  (
    icon: Icons.qr_code_2_rounded,
    title: 'QR code',
    detail: canScanQr ? 'Show or scan a code, nothing to type' : 'Show a code to scan with your phone',
    onTap: () => showMyQrCode(context, state),
  ),
  (
    icon: Icons.dialpad_rounded,
    title: 'Address',
    detail: 'Type the address shown on the other device',
    onTap: () => _addByIp(context, state),
  ),
  if (state.bluetooth != null || AppState.bluetoothSupported)
    (
      icon: Icons.bluetooth_rounded,
      title: 'Bluetooth',
      detail: 'Only when there\'s no shared Wi-Fi',
      onTap: () => showBluetoothPairing(context, state),
    ),
];

/// The same choices as the Connect device button: a dialog on computers,
/// a sheet from the bottom on phones. Both scroll, so a short window never
/// hides the last choice.
Future<void> showConnectOptions(BuildContext context, AppState state) {
  Widget options(BuildContext popup) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final way in _connectWays(context, state))
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 2),
          leading: IconTile(way.icon, size: 40),
          title: Text(way.title),
          subtitle: Text(way.detail),
          enabled: way.onTap != null,
          onTap: () {
            Navigator.pop(popup);
            way.onTap?.call();
          },
        ),
    ],
  );

  if (!usePhoneLayout(context)) {
    return showDialog<void>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Connect a device'),
        contentPadding: const EdgeInsets.only(top: 12, bottom: 8),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: SingleChildScrollView(child: options(dialog)),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(dialog), child: const Text('Cancel'))],
      ),
    );
  }
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheet) => SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Text('Connect a device', style: Theme.of(sheet).textTheme.titleLarge),
            ),
            options(sheet),
            const SizedBox(height: 12),
          ],
        ),
      ),
    ),
  );
}

/// Adds a device by its IP address, then pairs.
Future<void> _addByIp(BuildContext context, AppState state) async {
  final controller = TextEditingController();
  final address = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Connect by address'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Use this when the other device doesn't show up by itself. Its address (like 192.168.1.23) is under "
            'its name on its Devices tab.',
          ),
          const SizedBox(height: 16),
          TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Address', hintText: '192.168.1.23'),
            onSubmitted: (v) => Navigator.pop(context, v),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('Connect')),
      ],
    ),
  );
  if (address == null || address.trim().isEmpty || !context.mounted) return;
  try {
    final info = await state.addByAddress(address);
    if (context.mounted) await pairWith(context, state, info);
  } catch (e) {
    if (context.mounted) showError(context, e, title: "Couldn't connect to ${address.trim()}", device: address.trim());
  }
}

/// A menu entry: what it is, and a short line on when to use it.
