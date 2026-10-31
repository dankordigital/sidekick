import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

import '../app_state.dart';
import '../core/errors.dart';
import '../core/bluetooth.dart';
import '../core/models.dart';
import '../core/pairing_qr.dart';
import 'bluetooth_pairing.dart';
import 'direct_wifi.dart';
import 'ping.dart';
import 'qr_pairing.dart';
import 'text_messages.dart';
import 'widgets.dart';
import '../core/host.dart';

class DevicesPage extends StatelessWidget {
  const DevicesPage({super.key, required this.state, required this.onOpen});

  final AppState state;

  /// Switches to a tab (1 Files, 2 Remote).
  final void Function(int tab) onOpen;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        final paired = state.paired;
        final nearby = state.nearby;
        final online = paired.where((d) => state.isOnline(d.id)).length;
        return PageFrame(
          title: 'Devices',
          subtitle: paired.isEmpty
              ? 'Pair your phone or computer to get started'
              : '${paired.length} paired · $online connected'
                    '${nearby.isEmpty ? '' : ' · ${nearby.length} nearby'}',
          actions: [
            // One button; the ways to connect a device are in its menu,
            // each with a line saying when to use it.
            MenuAnchor(
              alignmentOffset: const Offset(0, 6),
              builder: (context, controller, _) => FilledButton.tonalIcon(
                onPressed: () => controller.isOpen ? controller.close() : controller.open(),
                icon: const Icon(Icons.add_link_rounded),
                label: const Text('Connect device'),
              ),
              menuChildren: [
                for (final way in _connectWays(context, state))
                  MenuItemButton(
                    leadingIcon: Icon(way.icon),
                    onPressed: way.onTap,
                    child: _MenuOption(title: way.title, detail: way.detail),
                  ),
              ],
            ),
          ],
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Entrance(child: _ThisDeviceCard(state: state)),
              if (paired.isNotEmpty) ...[
                const SectionLabel('Paired', icon: Icons.link_rounded),
                LayoutBuilder(
                  // As many equal columns as fit (cards at least 340 wide),
                  // lined up with the card above; one column on phones.
                  builder: (context, constraints) {
                    final columns = ((constraints.maxWidth + 16) ~/ 356).clamp(1, 3);
                    final width = (constraints.maxWidth - 16 * (columns - 1)) / columns;
                    return Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      children: [
                        for (final (i, d) in paired.indexed)
                          SizedBox(
                            width: width,
                            child: Entrance(
                              key: ValueKey(d.id),
                              index: i + 1,
                              child: _PairedCard(state: state, device: d, onOpen: onOpen),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ],
              const SectionLabel('Nearby', icon: Icons.near_me_outlined),
              if (nearby.isEmpty)
                Entrance(
                  index: paired.length + 1,
                  child: _Searching(state: state),
                )
              else
                Card.filled(
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      for (final d in nearby)
                        ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                          leading: IconTile(platformIcon(d.platform), size: 44),
                          title: Text(d.name),
                          subtitle: Row(
                            children: [
                              Icon(
                                d.address == null ? Icons.bluetooth_rounded : Icons.wifi_rounded,
                                size: 14,
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 4),
                              Flexible(child: Text(d.address ?? 'Nearby over Bluetooth', maxLines: 1)),
                            ],
                          ),
                          trailing: FilledButton.icon(
                            onPressed: () => pairWith(context, state, d),
                            icon: const Icon(Icons.link_rounded, size: 18),
                            label: const Text('Pair'),
                          ),
                        ),
                      // Always reachable, not only when nothing's nearby. Every way to
                      // connect, Wi-Fi first: Sidekick isn't a Bluetooth app.
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                        leading: const IconTile(Icons.link_rounded, tone: TileTone.tertiary, size: 44),
                        title: const Text('Connect a device'),
                        subtitle: const Text('Wi-Fi, QR code or another way'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => showConnectOptions(context, state),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Starts pairing with [device]: it shows a code, the user types it here.
Future<void> pairWith(BuildContext context, AppState state, DeviceInfo device) async {
  try {
    await state.requestPairing(device);
  } catch (e) {
    if (context.mounted) showError(context, e);
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

class _ThisDeviceCard extends StatelessWidget {
  const _ThisDeviceCard({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final error = state.networkError;
    final bt = state.bluetooth;
    final wifi = state.addresses.isNotEmpty;
    final details = [
      wifi ? state.addresses.join(', ') : 'No Wi-Fi',
      if (bt != null && bt.status == BluetoothStatus.on) bt.advertising ? 'Bluetooth: findable' : 'Bluetooth on',
    ].join(' · ');
    return Container(
      decoration: BoxDecoration(color: scheme.surfaceContainerLow, borderRadius: BorderRadius.circular(20)),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          Icon(platformIcon(state.me.platform), color: scheme.onSurfaceVariant),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(state.name, style: text.titleMedium),
                Text(
                  error ?? 'This device · $details',
                  style: text.bodySmall?.copyWith(color: error == null ? scheme.onSurfaceVariant : scheme.error),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PairedCard extends StatefulWidget {
  const _PairedCard({required this.state, required this.device, required this.onOpen});
  final AppState state;
  final PairedDevice device;
  final void Function(int tab) onOpen;

  @override
  State<_PairedCard> createState() => _PairedCardState();
}

class _PairedCardState extends State<_PairedCard> {
  bool _dragging = false;

  AppState get state => widget.state;
  PairedDevice get device => widget.device;

  void _open(int tab) {
    state.select(device.id);
    widget.onOpen(tab);
  }

  Future<void> _ping() async {
    final rang = await state.ping(device);
    if (!rang && mounted) await showAlreadyPinged(context, device.name);
  }

  Future<void> _pickAndSend() async {
    final files = await pickFilesToSend(context, title: 'Send to ${device.name}');
    if (files.isNotEmpty) await state.sendFiles(device, files);
  }

  Future<void> _confirmUnpair() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Unpair ${device.name}?'),
        content: const Text("Neither device will be able to control the other until you pair again."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Unpair')),
        ],
      ),
    );
    if (ok == true) await state.unpair(device.id);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final online = state.isOnline(device.id);
    final caps = state.capabilitiesOf(device.id);
    final reset = state.needsRepair(device) != null;

    final seen = state.lastSeen(device.id);
    final status = _dragging
        ? 'Drop to send'
        : reset
        ? 'Pair again'
        : state.connectionLabel(device.id) ??
              (state.isFinding(device.id)
                  ? 'Looking for it…'
                  : seen == null
                  ? 'Not reachable'
                  : 'Not reachable · seen ${formatAgo(seen)}');

    final statusIcon = _dragging
        ? Icons.file_download_outlined
        : reset
        ? Icons.error_outline_rounded
        : state.viaDirectWifi(device.id) || state.viaDirectLinkOnly(device.id)
        ? Icons.wifi_tethering_rounded
        : state.viaBluetooth(device.id)
        ? Icons.bluetooth_connected_rounded
        : online
        ? Icons.wifi_rounded
        : Icons.cloud_off_rounded;

    final canBrowse = caps?.files ?? true;
    // An iPhone can't be controlled (Apple doesn't allow it).
    final canControl = (caps?.input ?? true) && device.platform != DevicePlatform.ios;
    final findNearby = !online && AppState.bluetoothSupported && !state.bluetoothOn;

    return MaybeDropTarget(
      onHover: (hovering) => setState(() => _dragging = hovering),
      onFiles: (files) => state.sendFiles(device, files),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.fromLTRB(20, 14, 8, 14),
        decoration: BoxDecoration(
          color: _dragging ? scheme.secondaryContainer : scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _dragging ? scheme.primary : Colors.transparent, width: 2),
        ),
        child: Row(
          children: [
            Icon(platformIcon(device.platform), color: scheme.onSurfaceVariant),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    device.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 2),
                  StatusPill(
                    icon: _dragging ? statusIcon : null,
                    label: state.runsOlderApp(device) ? '$status · update Sidekick on it' : status,
                    color: reset ? scheme.error : (online ? Colors.green : scheme.outline),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (reset)
              FilledButton(
                onPressed: () => pairWith(context, state, state.forgetForRepair(device)),
                child: const Text('Pair again'),
              )
            else if (findNearby)
              FilledButton.tonal(
                onPressed: () => askToTurnOnBluetooth(context, state, device.name),
                child: const Text('Find nearby'),
              )
            else if (!online)
              // Not a dead, greyed-out Send: look for it.
              FilledButton.tonal(
                onPressed: state.isFinding(device.id) ? null : () => state.findDevice(device),
                child: const Text('Try again'),
              )
            else
              FilledButton(onPressed: _pickAndSend, child: const Text('Send')),
            PopupMenuButton<String>(
              tooltip: 'More',
              icon: const Icon(Icons.more_vert_rounded),
              onSelected: (v) => switch (v) {
                'files' => _open(1),
                'remote' => _open(2),
                'ping' => _ping(),
                'text' => askAndSendText(context, state, device),
                _ => _confirmUnpair(),
              },
              itemBuilder: (_) => [
                if (canBrowse) PopupMenuItem(value: 'files', enabled: online, child: const Text('Browse files')),
                if (canControl) PopupMenuItem(value: 'remote', enabled: online, child: const Text('Remote control')),
                PopupMenuItem(value: 'text', enabled: online, child: const Text('Send text or a link')),
                PopupMenuItem(value: 'ping', enabled: online, child: const Text('Ping')),
                const PopupMenuDivider(),
                const PopupMenuItem(value: 'unpair', child: Text('Unpair')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Searching extends StatelessWidget {
  const _Searching({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final offline = !state.wifiConnected;
    final bt = state.bluetooth;
    final bluetoothOff = bt == null || bt.status != BluetoothStatus.on;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: scheme.surfaceContainerLow, borderRadius: BorderRadius.circular(28)),
      child: Row(
        children: [
          Radar(icon: offline ? Icons.bluetooth_searching_rounded : Icons.wifi_find_rounded, size: 72),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  bluetoothOff && offline ? 'Turn on Bluetooth to find devices' : 'Looking for devices…',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  offline
                      ? bluetoothOff
                            ? 'No Wi-Fi here. Turn on Bluetooth, and open Sidekick on the other device.'
                            : 'Searching over Bluetooth. Open Sidekick on the other device.'
                      : 'Open Sidekick on your other device and it shows up here.'
                            '${Host.isWindows ? ' If Windows asks, allow Sidekick on private networks.' : ''}',
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
                // Every way to connect (Wi-Fi, QR code, Bluetooth when there's no Wi-Fi…).
                const SizedBox(height: 12),
                FilledButton.tonalIcon(
                  onPressed: () => showConnectOptions(context, state),
                  icon: const Icon(Icons.link_rounded),
                  label: const Text('Connect'),
                ),
              ],
            ),
          ),
        ],
      ),
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
    title: 'IP address',
    detail: 'Type the other device\'s address',
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

  if (!isMobile) {
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
      title: const Text('Add a device by IP'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Use this if the device doesn't show up by itself. Its IP address is shown on its Devices tab."),
          const SizedBox(height: 16),
          TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'IP address', hintText: '192.168.1.23'),
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
    if (context.mounted) showError(context, e);
  }
}

/// A menu entry: what it is, and a short line on when to use it.
class _MenuOption extends StatelessWidget {
  const _MenuOption({required this.title, required this.detail});
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title, style: text.titleSmall),
          Text(detail, style: text.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}
