import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../app_state.dart';
import '../core/models.dart';
import '../platform/desktop_window.dart';
import 'nothing.dart';
import 'ping.dart';
import 'widgets.dart';
import '../core/host.dart';

/// What a click on the tray / menu-bar icon opens (Windows and Mac), like
/// CleanMyMac's: how Sidekick is doing, this device's network, the last
/// file received, and every paired device with Send and Ping; Open Sidekick, Settings and Quit at the bottom. It
/// closes when you click anywhere else.
class TrayPanel extends StatelessWidget {
  const TrayPanel({super.key, required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    if (isNothing(context)) return _NothingPanel(state: state);
    final scheme = Theme.of(context).colorScheme;
    // Always dark, in a deep shade of the theme's color.
    final background = HSLColor.fromColor(scheme.primary).withSaturation(0.4).withLightness(0.14).toColor();
    return Theme(
      data: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(seedColor: scheme.primary, brightness: Brightness.dark),
        fontFamily: Theme.of(context).textTheme.bodyMedium?.fontFamily,
      ),
      child: Material(
        color: background,
        child: ListenableBuilder(
          listenable: state,
          builder: (context, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
                  children: [
                    Entrance(child: _Header(state: state)),
                    const SizedBox(height: 14),
                    Entrance(index: 1, child: _StatusCard(state: state)),
                    const SizedBox(height: 10),
                    Entrance(index: 2, child: _ReceivedCard(state: state)),
                    const SizedBox(height: 10),
                    Entrance(index: 3, child: _DevicesCard(state: state)),
                    const SizedBox(height: 18),
                    Entrance(index: 4, child: const _Tip()),
                  ],
                ),
              ),
              const _Footer(),
            ],
          ),
        ),
      ),
    );
  }
}

const _faint = Color(0xB3FFFFFF);
const _good = Color(0xFF7EF0C0);
const _link = Color(0xFF8FD8FF);

/// A translucent card, like the panel's in CleanMyMac.
class _Card extends StatelessWidget {
  const _Card({required this.child, this.padding = const EdgeInsets.all(14)});
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.07),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
    ),
    child: child,
  );
}

class _Header extends StatelessWidget {
  const _Header({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final online = state.paired.where((d) => state.isOnline(d.id)).length;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text.rich(
                TextSpan(
                  children: [
                    const TextSpan(text: 'Sidekick: '),
                    TextSpan(
                      text: 'Ready',
                      style: TextStyle(color: _good.withValues(alpha: 0.95)),
                    ),
                  ],
                ),
                style: text.titleLarge?.copyWith(fontWeight: FontWeight.w800, color: Colors.white),
              ),
              const SizedBox(height: 2),
              Text(
                '${state.name} · ${online == 0 ? 'no devices nearby' : '$online connected'}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: text.bodyMedium?.copyWith(color: _faint),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        GradientBadge(icon: Host.isMacOS ? Icons.laptop_mac_rounded : Icons.desktop_windows_rounded, size: 52),
      ],
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final address = state.addresses.isEmpty ? null : state.addresses.first;
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.verified_user_rounded, color: _good, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Encrypted end to end',
                  style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700, color: Colors.white),
                ),
              ),
              const Icon(Icons.check_rounded, size: 16, color: Colors.white),
              const SizedBox(width: 4),
              Text('Ready to receive', style: text.bodySmall?.copyWith(color: Colors.white)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(state.wifiConnected ? Icons.wifi_rounded : Icons.wifi_tethering_rounded, size: 18, color: _faint),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  state.wifiConnected
                      ? 'On Wi-Fi${address == null ? '' : ' · $address'}'
                      : 'No Wi-Fi here: direct Wi-Fi ready',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodyMedium?.copyWith(color: _faint),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReceivedCard extends StatelessWidget {
  const _ReceivedCard({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final last = state.transfers.where((t) => t.received && t.state == TransferState.done).lastOrNull;
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.download_done_rounded, size: 20, color: Colors.white),
              const SizedBox(width: 8),
              Text(
                'Received',
                style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            last == null ? 'Nothing yet' : '${last.name} · ${last.deviceName}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: text.bodySmall?.copyWith(color: _faint),
          ),
          const SizedBox(height: 8),
          if (last?.localPath case final path?)
            Align(
              alignment: Alignment.centerRight,
              child: _Link(label: 'Show', onTap: () => revealInFolder(path)),
            ),
        ],
      ),
    );
  }
}

class _DevicesCard extends StatelessWidget {
  const _DevicesCard({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final devices = state.paired;
    return _Card(
      padding: const EdgeInsets.fromLTRB(14, 14, 8, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your devices',
            style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700, color: Colors.white),
          ),
          const SizedBox(height: 6),
          if (devices.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'None paired yet. Open Sidekick to connect one.',
                style: text.bodySmall?.copyWith(color: _faint),
              ),
            ),
          for (final d in devices) _DeviceRow(state: state, device: d),
        ],
      ),
    );
  }
}

class _DeviceRow extends StatelessWidget {
  const _DeviceRow({required this.state, required this.device});
  final AppState state;
  final PairedDevice device;

  Future<void> _send(BuildContext context) => _sendFromPanel(context, state, device);

  Future<void> _ping(BuildContext context) => _pingFromPanel(context, state, device);

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final online = state.isOnline(device.id);
    final status = !online
        ? 'Offline'
        : state.viaDirectWifi(device.id) || state.viaDirectLinkOnly(device.id)
        ? 'Direct Wi-Fi'
        : state.viaBluetooth(device.id)
        ? 'Nearby'
        : 'Connected';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(platformIcon(device.platform), size: 22, color: online ? Colors.white : _faint),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  device.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodyLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w600),
                ),
                Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(color: online ? _good : _faint, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 6),
                    Text(status, style: text.bodySmall?.copyWith(color: _faint)),
                  ],
                ),
              ],
            ),
          ),
          _Action(icon: Icons.send_rounded, tooltip: 'Send files', onTap: online ? () => _send(context) : null),
          _Action(
            icon: Icons.notifications_active_outlined,
            tooltip: 'Ping',
            onTap: online ? () => _ping(context) : null,
          ),
        ],
      ),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({required this.icon, required this.tooltip, required this.onTap});
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: tooltip,
    onPressed: onTap,
    icon: Icon(icon, size: 20),
    color: Colors.white,
    disabledColor: Colors.white24,
    style: IconButton.styleFrom(backgroundColor: Colors.white.withValues(alpha: onTap == null ? 0.03 : 0.09)),
  );
}

class _Link extends StatelessWidget {
  const _Link({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(8),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Text(
        label,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(color: _link, fontWeight: FontWeight.w700),
      ),
    ),
  );
}

/// "Did you know": one of Sidekick's tricks, a different one each hour.
class _Tip extends StatelessWidget {
  const _Tip();

  static const _tips = [
    (
      icon: Icons.notifications_active_rounded,
      title: "Can't find your phone?",
      body: 'Ping it: it rings until you tap Found It!, even on silent.',
    ),
    (
      icon: Icons.wifi_tethering_rounded,
      title: 'No Wi-Fi? No problem',
      body: 'Direct Wi-Fi connects your devices without a router.',
    ),
    (
      icon: Icons.file_download_outlined,
      title: 'Drop to send',
      body: 'Drag files onto a device in Sidekick to send them.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final tip = _tips[DateTime.now().hour % _tips.length];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Did you know?',
          style: text.titleMedium?.copyWith(color: _faint, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        _Card(
          child: Row(
            children: [
              GradientBadge(icon: tip.icon, size: 46),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tip.title,
                      style: text.titleSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(tip.body, style: text.bodySmall?.copyWith(color: _faint)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) {
    final window = DesktopWindow.instance;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.10))),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextButton.icon(
              onPressed: () => window.openFromPanel(),
              style: TextButton.styleFrom(foregroundColor: Colors.white, minimumSize: const Size(0, 44)),
              icon: Image.asset('assets/logo/logo.png', width: 22, height: 22),
              label: const Text('Open Sidekick', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
          IconButton(
            tooltip: 'Settings',
            onPressed: () => window.openFromPanel(tab: 3),
            color: Colors.white,
            style: IconButton.styleFrom(backgroundColor: Colors.white.withValues(alpha: 0.09)),
            icon: const Icon(Icons.settings_rounded, size: 20),
          ),
          const SizedBox(width: 6),
          IconButton(
            tooltip: 'Quit Sidekick',
            onPressed: window.quit,
            color: Colors.white,
            style: IconButton.styleFrom(backgroundColor: Colors.white.withValues(alpha: 0.09)),
            icon: const Icon(Icons.power_settings_new_rounded, size: 20),
          ),
        ],
      ),
    );
  }
}

Future<void> _sendFromPanel(BuildContext context, AppState state, PairedDevice device) async {
  final window = DesktopWindow.instance;
  // The file picker takes the focus: that's not leaving the panel.
  window.holdPanel = true;
  try {
    final files = await pickFilesToSend(context, title: 'Send to ${device.name}');
    if (files.isEmpty) return;
    // The full window follows the send.
    await window.openFromPanel();
    await state.sendFiles(device, files);
  } finally {
    window.holdPanel = false;
  }
}

Future<void> _pingFromPanel(BuildContext context, AppState state, PairedDevice device) async {
  final rang = await state.ping(device);
  if (!rang && context.mounted) await showAlreadyPinged(context, device.name);
}

/// The panel in the Nothing look (Settings → Theme → Nothing): black, the
/// name in dots, mono labels, round buttons, green only for "connected".
class _NothingPanel extends StatelessWidget {
  const _NothingPanel({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final dark = nothingTheme(ThemeData(colorScheme: nothingScheme(Brightness.dark), useMaterial3: true));
    return Theme(
      data: dark.copyWith(
        textTheme: dark.textTheme.apply(fontFamily: Theme.of(context).textTheme.bodyMedium?.fontFamily),
      ),
      child: Material(
        color: Colors.black,
        child: ListenableBuilder(
          listenable: state,
          builder: (context, _) {
            final scheme = Theme.of(context).colorScheme;
            final address = state.addresses.isEmpty ? null : state.addresses.first;
            final last = state.transfers.where((t) => t.received && t.state == TransferState.done).lastOrNull;
            final tip = _Tip._tips[DateTime.now().hour % _Tip._tips.length];
            return Padding(
              padding: const EdgeInsets.fromLTRB(14, 18, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: ListView(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Row(
                            children: [
                              const Expanded(child: DotText('Sidekick', dot: 3.2)),
                              const SizedBox(width: 12),
                              const NothingStatus('Ready', on: true),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        NothingTile(
                          radius: 20,
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.shield_outlined, size: 18),
                                  const SizedBox(width: 10),
                                  const Expanded(
                                    child: Text(
                                      'Encrypted end to end',
                                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                                    ),
                                  ),
                                  const NothingLabel('Ready to receive', size: 9.5),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Icon(
                                    state.wifiConnected ? Icons.wifi_rounded : Icons.wifi_tethering_rounded,
                                    size: 18,
                                    color: scheme.onSurfaceVariant,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      state.wifiConnected
                                          ? 'On Wi-Fi${address == null ? '' : ' · $address'}'
                                          : 'No Wi-Fi here: direct Wi-Fi ready',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        NothingTile(
                          radius: 20,
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const NothingLabel('Last received', size: 10),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  const Icon(Icons.south_west_rounded, size: 18),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          last?.name ?? 'Nothing yet',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                                        ),
                                        if (last != null)
                                          Text(
                                            'From ${last.deviceName}',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                                          ),
                                      ],
                                    ),
                                  ),
                                  if (last?.localPath case final path?)
                                    NothingPill(
                                      label: 'Show',
                                      solid: false,
                                      height: 32,
                                      onPressed: () => revealInFolder(path),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        NothingTile(
                          radius: 20,
                          padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const NothingLabel('Your devices', size: 10),
                              const SizedBox(height: 4),
                              if (state.paired.isEmpty)
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  child: Text(
                                    'None paired yet. Open Sidekick to connect one.',
                                    style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
                                  ),
                                ),
                              for (final d in state.paired) _nothingDevice(context, d),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        NothingTile(
                          radius: 20,
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.lightbulb_outline_rounded,
                                size: 20,
                                color: Theme.of(context).colorScheme.tertiary,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const NothingLabel('Did you know?', size: 10),
                                    const SizedBox(height: 6),
                                    Text(tip.body, style: const TextStyle(fontSize: 13)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: NothingPill(
                          label: 'Open Sidekick',
                          onPressed: () => DesktopWindow.instance.openFromPanel(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      NothingRound(
                        icon: Icons.settings_outlined,
                        tooltip: 'Settings',
                        size: 44,
                        onPressed: () => DesktopWindow.instance.openFromPanel(tab: 3),
                      ),
                      const SizedBox(width: 8),
                      NothingRound(
                        icon: Icons.power_settings_new_rounded,
                        tooltip: 'Quit Sidekick',
                        size: 44,
                        onPressed: DesktopWindow.instance.quit,
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _nothingDevice(BuildContext context, PairedDevice d) {
    final scheme = Theme.of(context).colorScheme;
    final online = state.isOnline(d.id);
    final status = !online
        ? 'Offline'
        : state.viaDirectWifi(d.id) || state.viaDirectLinkOnly(d.id)
        ? 'Direct Wi-Fi'
        : state.viaBluetooth(d.id)
        ? 'Bluetooth'
        : 'On Wi-Fi';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Icon(platformIcon(d.platform), size: 22, color: online ? scheme.onSurface : scheme.onSurfaceVariant),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  d.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: online ? scheme.onSurface : scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 3),
                NothingStatus(status, on: online),
              ],
            ),
          ),
          NothingRound(
            icon: Icons.north_east_rounded,
            tooltip: 'Send files',
            size: 36,
            outlined: true,
            onPressed: online ? () => _sendFromPanel(context, state, d) : null,
          ),
          const SizedBox(width: 8),
          NothingRound(
            icon: Icons.notifications_none_rounded,
            tooltip: 'Ping',
            size: 36,
            outlined: true,
            onPressed: online ? () => _pingFromPanel(context, state, d) : null,
          ),
        ],
      ),
    );
  }
}
