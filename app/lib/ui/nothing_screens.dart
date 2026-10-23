import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../app_state.dart';
import '../core/models.dart';
import 'devices_page.dart' show pairWith, showConnectOptions;
import 'direct_wifi.dart';
import 'nothing.dart';
import 'ping.dart';
import 'qr_pairing.dart';
import 'transfer_screens.dart' show closeRoute;
import 'widgets.dart';

/// The Nothing look's own screens (Settings → Theme → Nothing): the Devices
/// home, a device's page, the tab bar and the computer's side bar, drawn
/// like the design it came from. Files, Remote and Settings keep their
/// layout in the look's colors. Delete with nothing.dart to drop the look.

/// How a paired device is reached, in a word or two.
String _how(AppState state, PairedDevice d) {
  if (state.needsRepair(d) != null) return 'Pair again';
  if (state.connectingDirect.contains(d.id)) return 'Setting up direct Wi-Fi';
  if (state.viaDirectWifi(d.id) || state.viaDirectLinkOnly(d.id)) return 'Direct Wi-Fi';
  if (state.viaBluetooth(d.id)) return 'Bluetooth';
  return state.isOnline(d.id) ? 'On Wi-Fi' : 'Offline';
}

Future<void> _pickAndSend(BuildContext context, AppState state, PairedDevice d) async {
  final files = await pickFilesToSend(context, title: 'Send to ${d.name}');
  if (files.isNotEmpty) await state.sendFiles(d, files);
}

Future<void> _ping(BuildContext context, AppState state, PairedDevice d) async {
  final rang = await state.ping(d);
  if (!rang && context.mounted) await showAlreadyPinged(context, d.name);
}

String _platformName(DevicePlatform p) => switch (p) {
  DevicePlatform.windows => 'Windows',
  DevicePlatform.macos => 'Mac',
  DevicePlatform.linux => 'Linux',
  DevicePlatform.android => 'Android',
  DevicePlatform.ios => 'iPhone',
  DevicePlatform.unknown => 'Device',
};

/// The transfer running now, if any (the newest).
Transfer? _running(AppState state) => state.transfers.where((t) => t.state == TransferState.running).lastOrNull;

// ------------------------------------------------------------------ Devices

class NothingDevicesPage extends StatelessWidget {
  const NothingDevicesPage({super.key, required this.state, required this.onOpen});
  final AppState state;

  /// Switches to a tab (1 Files, 2 Remote).
  final void Function(int tab) onOpen;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: state,
    builder: (context, _) => LayoutBuilder(
      builder: (context, constraints) =>
          constraints.maxWidth >= 640 ? _Wide(state: state, onOpen: onOpen) : _Narrow(state: state, onOpen: onOpen),
    ),
  );
}

/// Phones: "SIDEKICK", the two widgets (in reach, Wi-Fi), paired, nearby.
class _Narrow extends StatelessWidget {
  const _Narrow({required this.state, required this.onOpen});
  final AppState state;
  final void Function(int tab) onOpen;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
    children: [
      Row(
        children: [
          const Expanded(child: DotText('Sidekick', dot: 4.2)),
          const SizedBox(width: 12),
          NothingRound(
            icon: Icons.add_link_rounded,
            tooltip: 'Connect device',
            onPressed: () => showConnectOptions(context, state),
          ),
        ],
      ),
      const SizedBox(height: 10),
      NothingStatus('${state.name} · ready · encrypted', on: true),
      const SizedBox(height: 20),
      Row(
        children: [
          Expanded(
            child: AspectRatio(aspectRatio: 1, child: _InReach(state: state)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: AspectRatio(aspectRatio: 1, child: _Network(state: state)),
          ),
        ],
      ),
      const SizedBox(height: 12),
      _Paired(state: state, onOpen: onOpen),
      const SizedBox(height: 12),
      _Nearby(state: state),
    ],
  );
}

/// Computers: "DEVICES", the transfer (or ready) card and the in-reach
/// circle on top, paired and this computer below.
class _Wide extends StatelessWidget {
  const _Wide({required this.state, required this.onOpen});
  final AppState state;
  final void Function(int tab) onOpen;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(4, 26, 26, 26),
    children: [
      Row(
        children: [
          const Expanded(child: DotText('Devices', dot: 5)),
          NothingPill(
            label: 'Connect device',
            icon: Icons.add_link_rounded,
            onPressed: () => showConnectOptions(context, state),
          ),
        ],
      ),
      const SizedBox(height: 22),
      SizedBox(
        height: 250,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: _TransferCard(state: state)),
            const SizedBox(width: 14),
            AspectRatio(aspectRatio: 1, child: _InReach(state: state, round: true)),
          ],
        ),
      ),
      const SizedBox(height: 14),
      IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Paired(state: state, onOpen: onOpen),
                  const SizedBox(height: 14),
                  _Nearby(state: state),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(child: _ThisComputer(state: state)),
          ],
        ),
      ),
    ],
  );
}

/// How many paired devices are in reach, in dots. On computers, inside a
/// ring of dots that fills up with them.
class _InReach extends StatelessWidget {
  const _InReach({required this.state, this.round = false});
  final AppState state;
  final bool round;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final paired = state.paired;
    final online = paired.where((d) => state.isOnline(d.id)).length;
    if (round) {
      return Container(
        decoration: BoxDecoration(color: scheme.surfaceContainer, shape: BoxShape.circle),
        child: CustomPaint(
          painter: NothingDotRing(
            value: paired.isEmpty ? 0 : online / paired.length,
            on: scheme.onSurface,
            off: scheme.surfaceContainerHighest,
            count: 44,
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [DotText('$online', dot: 9), const SizedBox(height: 10), const NothingLabel('In reach')],
            ),
          ),
        ),
      );
    }
    return NothingTile(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const NothingLabel('In reach'),
          const Spacer(),
          DotText('$online', dot: 11),
          const SizedBox(height: 10),
          Text(online == 1 ? 'device' : 'devices', style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 14)),
        ],
      ),
    );
  }
}

/// The network, in a round widget with a ring of dots.
class _Network extends StatelessWidget {
  const _Network({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final wifi = state.wifiConnected;
    final address = state.addresses.isEmpty ? null : state.addresses.first;
    return Container(
      decoration: BoxDecoration(color: scheme.surfaceContainer, shape: BoxShape.circle),
      child: CustomPaint(
        painter: NothingDotRing(
          value: wifi ? 0.75 : 0.25,
          on: scheme.onSurface,
          off: scheme.surfaceContainerHighest,
          count: 36,
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(wifi ? Icons.wifi_rounded : Icons.wifi_tethering_rounded, size: 26),
                const SizedBox(height: 6),
                Text(wifi ? 'On Wi-Fi' : 'No Wi-Fi', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                NothingLabel(wifi ? (address ?? 'Wi-Fi') : 'Direct Wi-Fi', size: 9.5),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Paired extends StatelessWidget {
  const _Paired({required this.state, required this.onOpen});
  final AppState state;
  final void Function(int tab) onOpen;

  @override
  Widget build(BuildContext context) {
    final paired = state.paired;
    return NothingTile(
      padding: const EdgeInsets.fromLTRB(18, 16, 14, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const NothingLabel('Paired'),
          const SizedBox(height: 4),
          if (paired.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Nothing paired yet. Connect your phone or computer.',
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                  ),
                  const SizedBox(width: 12),
                  NothingPill(label: 'Connect', height: 36, onPressed: () => showConnectOptions(context, state)),
                ],
              ),
            ),
          for (final d in paired) _PairedRow(state: state, device: d, onOpen: onOpen),
        ],
      ),
    );
  }
}

class _PairedRow extends StatefulWidget {
  const _PairedRow({required this.state, required this.device, required this.onOpen});
  final AppState state;
  final PairedDevice device;
  final void Function(int tab) onOpen;

  @override
  State<_PairedRow> createState() => _PairedRowState();
}

class _PairedRowState extends State<_PairedRow> {
  bool _dragging = false;

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final d = widget.device;
    final scheme = Theme.of(context).colorScheme;
    final online = state.isOnline(d.id);
    final reset = state.needsRepair(d) != null;
    final findNearby = !online && AppState.bluetoothSupported && !state.bluetoothOn;
    final status = _dragging ? 'Drop to send' : _how(state, d);
    return MaybeDropTarget(
      onHover: (h) => setState(() => _dragging = h),
      onFiles: (files) => state.sendFiles(d, files),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => NothingDevicePage(state: state, device: d, onOpen: widget.onOpen),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: _dragging ? scheme.onSurface : scheme.outlineVariant, width: 1.2),
                ),
                child: Icon(platformIcon(d.platform), size: 21),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      d.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 4),
                    NothingStatus(state.runsOlderApp(d) ? '$status · update Sidekick' : status, on: online && !reset),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (reset)
                NothingPill(
                  label: 'Pair again',
                  height: 36,
                  onPressed: () => pairWith(context, state, state.forgetForRepair(d)),
                )
              else if (findNearby)
                NothingPill(
                  label: 'Find nearby',
                  solid: false,
                  height: 36,
                  onPressed: () => askToTurnOnBluetooth(context, state, d.name),
                )
              else
                NothingPill(
                  label: 'Send',
                  solid: online,
                  height: 36,
                  onPressed: online ? () => _pickAndSend(context, state, d) : null,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Nearby extends StatelessWidget {
  const _Nearby({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final nearby = state.nearby;
    return NothingTile(
      padding: const EdgeInsets.fromLTRB(18, 16, 14, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const NothingLabel('Nearby'),
          const SizedBox(height: 4),
          for (final d in nearby)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: scheme.outlineVariant, width: 1.2),
                    ),
                    child: Icon(platformIcon(d.platform), size: 21),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          d.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 4),
                        NothingLabel(d.address ?? 'Over Bluetooth'),
                      ],
                    ),
                  ),
                  NothingPill(label: 'Pair', height: 36, onPressed: () => pairWith(context, state, d)),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    nearby.isEmpty
                        ? 'Looking for devices… Open Sidekick on the other one.'
                        : 'Not here? Connect another way.',
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                ),
                const SizedBox(width: 12),
                NothingPill(
                  label: 'Connect',
                  solid: false,
                  height: 36,
                  onPressed: () => showConnectOptions(context, state),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Computers: the transfer happening now, in big dots, or "ready".
class _TransferCard extends StatelessWidget {
  const _TransferCard({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = _running(state);
    final fraction = t == null || t.total <= 0 ? 0.0 : (t.done / t.total).clamp(0.0, 1.0);
    return NothingTile(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: NothingLabel(
                  t == null ? 'Ready to receive' : '${t.upload ? 'Sending' : 'Receiving'} · ${t.name}',
                ),
              ),
              if (t != null) NothingLabel('${t.upload ? 'To' : 'From'} ${t.deviceName}', color: scheme.onSurface),
            ],
          ),
          const Spacer(),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(child: DotText(t == null ? 'Ready' : '${(fraction * 100).round()}%', dot: 10)),
              if (t != null)
                NothingLabel('${formatBytes(t.done)} / ${formatBytes(t.total)}', size: 12, color: scheme.onSurface),
            ],
          ),
          const SizedBox(height: 20),
          if (t != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: fraction,
                minHeight: 10,
                color: nothingRed,
                backgroundColor: scheme.surfaceContainerHighest,
              ),
            )
          else
            Text('Drop files on a device to send them.', style: TextStyle(color: scheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}

class _ThisComputer extends StatelessWidget {
  const _ThisComputer({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final address = state.addresses.isEmpty ? null : state.addresses.first;
    final last = state.transfers.where((t) => t.received && t.state == TransferState.done).lastOrNull;
    return NothingTile(
      padding: const EdgeInsets.fromLTRB(22, 18, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const NothingLabel('This computer'),
          const SizedBox(height: 16),
          Text(state.name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w500)),
          const SizedBox(height: 6),
          Text(
            [?address, state.wifiConnected ? 'On Wi-Fi' : 'No Wi-Fi'].join(' · '),
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 22),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              NothingPill(
                label: 'Show QR code',
                icon: Icons.qr_code_rounded,
                solid: false,
                height: 40,
                onPressed: () => showMyQrCode(context, state),
              ),
              if (last?.localPath case final path?)
                NothingPill(
                  label: 'Last received',
                  icon: Icons.folder_open_outlined,
                  solid: false,
                  height: 40,
                  onPressed: () => revealInFolder(path),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------ a device

/// One paired device: its name in dots, Send / Files / Remote / Ping, and
/// what went back and forth.
class NothingDevicePage extends StatelessWidget {
  const NothingDevicePage({super.key, required this.state, required this.device, required this.onOpen});
  final AppState state;
  final PairedDevice device;
  final void Function(int tab) onOpen;

  void _open(BuildContext context, int tab) {
    state.select(device.id);
    closeRoute(context);
    onOpen(tab);
  }

  Future<void> _unpair(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Unpair ${device.name}?'),
        content: const Text('Neither device will be able to control the other until you pair again.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Unpair')),
        ],
      ),
    );
    if (ok != true) return;
    await state.unpair(device.id);
    if (context.mounted) closeRoute(context);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: ListenableBuilder(
        listenable: state,
        builder: (context, _) {
          final scheme = Theme.of(context).colorScheme;
          final online = state.isOnline(device.id);
          final caps = state.capabilitiesOf(device.id);
          final canBrowse = caps?.files ?? true;
          final canControl = (caps?.input ?? true) && device.platform != DevicePlatform.ios;
          final recent = state.transfers.where((t) => t.deviceName == device.name).toList().reversed.take(8);
          return ListView(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
            children: [
              Row(
                children: [
                  NothingRound(icon: Icons.arrow_back_rounded, tooltip: 'Back', onPressed: () => closeRoute(context)),
                  const Spacer(),
                  PopupMenuButton<String>(
                    tooltip: 'More',
                    onSelected: (_) => _unpair(context),
                    itemBuilder: (_) => const [PopupMenuItem(value: 'unpair', child: Text('Unpair'))],
                    // The menu button takes the tap; this only draws it.
                    child: IgnorePointer(
                      child: NothingRound(icon: Icons.more_horiz_rounded, onPressed: () {}),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 26),
              DotText(device.name, dot: 5.2),
              const SizedBox(height: 12),
              NothingStatus(
                [_platformName(device.platform), _how(state, device)].join(' · '),
                on: online && state.needsRepair(device) == null,
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  _Action(
                    icon: Icons.north_east_rounded,
                    label: 'Send',
                    accent: true,
                    onTap: online ? () => _pickAndSend(context, state, device) : null,
                  ),
                  const SizedBox(width: 10),
                  _Action(
                    icon: Icons.folder_outlined,
                    label: 'Files',
                    onTap: online && canBrowse ? () => _open(context, 1) : null,
                  ),
                  const SizedBox(width: 10),
                  _Action(
                    icon: Icons.mouse_outlined,
                    label: 'Remote',
                    onTap: online && canControl ? () => _open(context, 2) : null,
                  ),
                  const SizedBox(width: 10),
                  _Action(
                    icon: Icons.notifications_none_rounded,
                    label: 'Ping',
                    onTap: online ? () => unawaited(_ping(context, state, device)) : null,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              NothingTile(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const NothingLabel('Recent'),
                    const SizedBox(height: 4),
                    if (recent.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text('Nothing sent yet', style: TextStyle(color: scheme.onSurfaceVariant)),
                      ),
                    for (final t in recent)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Row(
                          children: [
                            Icon(
                              t.upload ? Icons.north_east_rounded : Icons.south_west_rounded,
                              size: 18,
                              color: scheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 12),
                            Expanded(child: Text(t.name, maxLines: 1, overflow: TextOverflow.ellipsis)),
                            const SizedBox(width: 8),
                            NothingLabel(switch (t.state) {
                              TransferState.running => '${t.total > 0 ? (t.done * 100 ~/ t.total) : 0}%',
                              TransferState.done => formatBytes(t.total),
                              TransferState.failed => 'Failed',
                            }, size: 10),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    ),
  );
}

/// A square action: icon over a small label. Send is the red one.
class _Action extends StatelessWidget {
  const _Action({required this.icon, required this.label, required this.onTap, this.accent = false});
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final enabled = onTap != null;
    final fg = accent && enabled ? Colors.white : (enabled ? scheme.onSurface : scheme.onSurfaceVariant);
    return Expanded(
      child: AspectRatio(
        aspectRatio: 1,
        child: Material(
          color: accent && enabled ? nothingRed : scheme.surfaceContainer,
          borderRadius: BorderRadius.circular(22),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 26, color: fg),
                const SizedBox(height: 8),
                NothingLabel(label, size: 10, color: accent && enabled ? Colors.white : null),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ navigation

typedef NothingDestination = ({IconData icon, IconData selected, String label});

/// Phones: a floating bar of icons; the current one white, the rest grey.
class NothingTabBar extends StatelessWidget {
  const NothingTabBar({super.key, required this.destinations, required this.index, required this.onTap});
  final List<NothingDestination> destinations;
  final int index;
  final void Function(int) onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(18, 0, 18, 12),
      child: Container(
        height: 64,
        decoration: BoxDecoration(color: scheme.surfaceContainer, borderRadius: BorderRadius.circular(32)),
        child: Row(
          children: [
            for (final (i, d) in destinations.indexed)
              Expanded(
                child: Semantics(
                  selected: i == index,
                  button: true,
                  label: d.label,
                  child: Tooltip(
                    message: d.label,
                    child: InkResponse(
                      onTap: () => onTap(i),
                      radius: 28,
                      child: SizedBox.expand(
                        child: Icon(
                          i == index ? d.selected : d.icon,
                          size: 26,
                          color: i == index ? scheme.onSurface : scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Computers: "SIDEKICK" in dots, the pages as words, the status at the bottom.
class NothingSideBar extends StatelessWidget {
  const NothingSideBar({
    super.key,
    required this.destinations,
    required this.index,
    required this.onTap,
    required this.state,
  });
  final List<NothingDestination> destinations;
  final int index;
  final void Function(int) onTap;
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 220,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 30, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(padding: EdgeInsets.only(left: 8), child: DotText('Sidekick', dot: 2.6)),
            const SizedBox(height: 30),
            for (final (i, d) in destinations.indexed)
              Semantics(
                selected: i == index,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => onTap(i),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
                    child: Row(
                      children: [
                        Icon(
                          i == index ? d.selected : d.icon,
                          size: 21,
                          color: i == index ? scheme.onSurface : scheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          d.label,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: i == index ? FontWeight.w500 : FontWeight.w400,
                            color: i == index ? scheme.onSurface : scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: ListenableBuilder(
                listenable: state,
                builder: (context, _) => const NothingStatus('Ready · encrypted', on: true),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ sending

/// The sending screen in the Nothing look: the percentage in big dots, then
/// a card with where it goes, the files, a red bar, the speed and time left.
class NothingSendView extends StatefulWidget {
  const NothingSendView({
    super.key,
    required this.send,
    required this.onBack,
    required this.action,
    required this.onAction,
  });
  final OutgoingSend send;
  final VoidCallback onBack;
  final String action;
  final VoidCallback onAction;

  @override
  State<NothingSendView> createState() => _NothingSendViewState();
}

class _NothingSendViewState extends State<NothingSendView> {
  /// Bytes and time at the start of the last few seconds, for the speed.
  final _samples = <(DateTime, int)>[];

  double? get _speed {
    if (_samples.length < 2) return null;
    final (t0, b0) = _samples.first;
    final (t1, b1) = _samples.last;
    final ms = t1.difference(t0).inMilliseconds;
    return ms < 400 ? null : (b1 - b0) * 1000 / ms;
  }

  @override
  Widget build(BuildContext context) {
    final send = widget.send;
    final scheme = Theme.of(context).colorScheme;
    final now = DateTime.now();
    if (send.phase == SendPhase.sending) {
      _samples.add((now, send.done));
      _samples.removeWhere((s) => now.difference(s.$1) > const Duration(seconds: 4));
    }
    final speed = _speed;
    final left = speed == null || speed <= 0 ? null : ((send.total - send.done) / speed).ceil();
    final big = switch (send.phase) {
      SendPhase.sending => '${(send.fraction * 100).round()}%',
      SendPhase.done => 'Sent',
      SendPhase.declined => 'No',
      SendPhase.noAnswer || SendPhase.failed => 'Oops',
      _ => '···',
    };
    final d = send.device;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  NothingRound(icon: Icons.arrow_back_rounded, tooltip: 'Back', onPressed: widget.onBack),
                  Expanded(
                    child: Center(
                      child: NothingLabel(switch (send.phase) {
                        SendPhase.connecting => 'Connecting',
                        SendPhase.waiting => 'Waiting for an answer',
                        SendPhase.sending => 'Sending',
                        SendPhase.done => 'Sent',
                        SendPhase.declined => 'Declined',
                        SendPhase.noAnswer => 'No answer',
                        SendPhase.failed => "Couldn't send",
                      }),
                    ),
                  ),
                  const SizedBox(width: 42),
                ],
              ),
              const Spacer(),
              Center(
                child: Column(
                  children: [
                    DotText(big == '···' ? '...' : big, dot: 12),
                    const SizedBox(height: 20),
                    NothingLabel('${formatBytes(send.done)} / ${formatBytes(send.total)}'),
                  ],
                ),
              ),
              const Spacer(),
              NothingTile(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(platformIcon(d.platform), size: 22),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'To ${d.name}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                          ),
                        ),
                        if (speed != null) NothingLabel('${formatBytes(speed.round())}/s', color: scheme.onSurface),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      // When it fails, why (in place of the files).
                      send.phase == SendPhase.failed ? (send.error ?? send.names.join(', ')) : send.names.join(', '),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 16),
                    TweenAnimationBuilder<double>(
                      tween: Tween(end: send.fraction),
                      duration: const Duration(milliseconds: 250),
                      builder: (context, value, _) => ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: value,
                          minHeight: 10,
                          color: nothingRed,
                          backgroundColor: scheme.surfaceContainerHighest,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        const Expanded(child: NothingStatus('Encrypted', on: true)),
                        if (send.phase == SendPhase.sending)
                          NothingLabel(
                            [
                              if (left != null) '$left s left',
                              if (send.names.length > 1) '${send.current + 1} of ${send.names.length}',
                            ].join('  ·  '),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              NothingPill(label: widget.action, solid: false, height: 52, onPressed: widget.onAction),
            ],
          ),
        ),
      ),
    );
  }
}
