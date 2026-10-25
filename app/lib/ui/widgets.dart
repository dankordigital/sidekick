import 'dart:async';
import 'dart:io';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:material_ui/material_ui.dart';

import '../app_state.dart';
import '../core/errors.dart';
import '../core/models.dart';
import 'direct_wifi.dart';
import 'nothing.dart';
import '../core/host.dart';

IconData platformIcon(DevicePlatform platform) => switch (platform) {
  DevicePlatform.windows => Icons.desktop_windows_outlined,
  DevicePlatform.macos => Icons.laptop_mac_outlined,
  DevicePlatform.linux => Icons.computer_outlined,
  DevicePlatform.android => Icons.phone_android_outlined,
  DevicePlatform.ios => Icons.phone_iphone_outlined,
  DevicePlatform.unknown => Icons.devices_other_outlined,
};

String formatBytes(int bytes) {
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  var value = bytes.toDouble();
  var unit = 0;
  while (value >= 1000 && unit < units.length - 1) {
    value /= 1000;
    unit++;
  }
  return unit == 0 ? '$bytes B' : '${value.toStringAsFixed(value < 10 ? 1 : 0)} ${units[unit]}';
}

/// "5 s left", "2 min left", "1 h 5 min left".
String formatTimeLeft(Duration d) {
  if (d.inSeconds < 60) return '${d.inSeconds} s left';
  if (d.inMinutes < 60) return '${(d.inSeconds / 60).ceil()} min left';
  return '${d.inHours} h ${d.inMinutes.remainder(60)} min left';
}

String formatDuration(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return h > 0 ? '$h:${m.toString().padLeft(2, '0')}:$s' : '$m:$s';
}

/// Lets the screenshot tool preview the phone UI on a desktop.
bool debugForceMobile = false;

/// Running on a phone or tablet (touch-first, soft keyboard).
bool get isMobile => debugForceMobile || Host.isAndroid || Host.isIOS;

/// Lets the screenshot tool render the UI as another platform would.
DevicePlatform? debugHostPlatform;

bool get hostIsIOS => debugHostPlatform == null ? Host.isIOS : debugHostPlatform == DevicePlatform.ios;
bool get hostIsAndroid => debugHostPlatform == null ? Host.isAndroid : debugHostPlatform == DevicePlatform.android;

/// A Mac or a Windows PC (not a phone).
bool get hostIsComputer => !hostIsIOS && !hostIsAndroid;
bool get hostIsMacOS => debugHostPlatform == null ? Host.isMacOS : debugHostPlatform == DevicePlatform.macos;

/// `Platform.operatingSystem`, or the overridden platform's name.
String get hostOS => debugHostPlatform?.name ?? Platform.operatingSystem;

/// Lets the screenshot tool offer Liquid Glass on any host.
bool debugGlassAvailable = false;

/// The major version of iOS or macOS ("Version 26.0 (Build …)" → 26), or
/// null elsewhere.
int? get appleOsMajor {
  // The website's preview has no OS version: it shows the default look.
  if (Host.isWeb || (!Host.isIOS && !Host.isMacOS)) return null;
  final m = RegExp(r'(\d+)\.\d').firstMatch(Platform.operatingSystemVersion);
  return m == null ? null : int.tryParse(m.group(1)!);
}

/// Liquid Glass is offered on iOS and macOS 26 and newer (Apple's own look
/// since 26); everywhere else Sidekick is Material only.
bool get liquidGlassAvailable => debugGlassAvailable || (appleOsMajor ?? 0) >= 26;

/// Screens narrower than this get the compact phone layout.
const compactWidth = 600.0;

/// Content never gets wider than this, so big windows stay readable.
const maxContentWidth = 1080.0;

/// Page scaffold with a large title, used by every tab.
class PageFrame extends StatelessWidget {
  const PageFrame({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const [],
    required this.child,
    this.scroll = true,
    this.maxWidth = maxContentWidth,
  });

  final String title;

  /// How wide the page gets (title and content alike).
  final double maxWidth;

  /// A short line under the title (what this page is about right now).
  final String? subtitle;
  final List<Widget> actions;
  final Widget child;
  final bool scroll;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final compact = MediaQuery.sizeOf(context).width < compactWidth;
    final side = compact ? 16.0 : 28.0;
    final titleText = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // The Nothing look: page titles in dots.
        if (isNothing(context))
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 6),
            child: DotText(title, dot: compact ? 4.6 : 5),
          )
        else
          Text(title, style: compact ? text.headlineMedium : text.headlineLarge),
        if (subtitle != null)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              subtitle!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: text.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
      ],
    );
    // On phones the actions go under the title so they never overflow.
    final header = Padding(
      padding: EdgeInsets.fromLTRB(side, compact ? 16 : 24, compact ? 16 : 20, 12),
      child: compact
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                titleText,
                if (actions.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(spacing: 4, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: actions),
                ],
              ],
            )
          : Row(
              children: [
                Expanded(child: titleText),
                ...actions,
              ],
            ),
    );
    final body = Padding(padding: EdgeInsets.fromLTRB(side, 8, side, side), child: child);
    // Full width up to [maxContentWidth], centered; full height too when
    // the page doesn't scroll (Files, Remote fill the window).
    Widget centered(Widget w, {bool fillHeight = false}) => Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: SizedBox(width: double.infinity, height: fillHeight ? double.infinity : null, child: w),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        centered(header),
        Expanded(child: scroll ? SingleChildScrollView(child: centered(body)) : centered(body, fillHeight: true)),
      ],
    );
  }
}

class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.icon});
  final String text;

  /// Kept for callers; section titles are plain text (no icons).
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 28, bottom: 8, left: 16),
    child: isNothing(context)
        ? Text(text.toUpperCase(), style: nothingLabel(context))
        : Text(
            text,
            style: Theme.of(context).textTheme.labelLarge
                ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant, fontWeight: FontWeight.w500),
          ),
  );
}

/// Which container color an [IconTile] uses.
enum TileTone { primary, secondary, tertiary, error }

/// The leading icon of settings rows and list items: a plain icon in the
/// row's quiet color (only [TileTone.error] stands out).
class IconTile extends StatelessWidget {
  const IconTile(this.icon, {super.key, this.tone = TileTone.secondary, this.size = 40});
  final IconData icon;
  final TileTone tone;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: size * 0.6,
      height: size,
      child: Icon(icon, size: 22, color: tone == TileTone.error ? scheme.error : scheme.onSurfaceVariant),
    );
  }
}

/// Fades [child] in, rising a few pixels, the first time it's built, with
/// Apple's long, soft ease-out. Give siblings increasing [index]es for a
/// short stagger.
class Entrance extends StatefulWidget {
  const Entrance({super.key, required this.child, this.index = 0});
  final Widget child;
  final int index;

  @override
  State<Entrance> createState() => _EntranceState();
}

class _EntranceState extends State<Entrance> with SingleTickerProviderStateMixin {
  static const _step = 24, _length = 320;
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: _length + _step * widget.index.clamp(0, 8)),
  );
  late final Animation<double> _t = CurvedAnimation(
    parent: _c,
    curve: Interval(1 - _length / _c.duration!.inMilliseconds, 1, curve: Curves.easeOutQuint),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_c.isDismissed) {
      MediaQuery.of(context).disableAnimations ? _c.value = 1 : _c.forward();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  // Transitions, not a rebuild per frame.
  Widget build(BuildContext context) => FadeTransition(
    opacity: _t,
    child: SlideTransition(
      position: Tween(begin: const Offset(0, 0.02), end: Offset.zero).animate(_t),
      child: widget.child,
    ),
  );
}

/// Expanding rings around an icon: "looking for devices".
class Radar extends StatefulWidget {
  const Radar({super.key, required this.icon, this.size = 64});
  final IconData icon;
  final double size;

  @override
  State<Radar> createState() => _RadarState();
}

class _RadarState extends State<Radar> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!MediaQuery.of(context).disableAnimations && !_c.isAnimating) _c.repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final s = widget.size;
    return SizedBox.square(
      dimension: s,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, child) => Stack(
          alignment: Alignment.center,
          children: [
            for (final offset in const [0.0, 0.5])
              Builder(
                builder: (context) {
                  final t = (_c.value + offset) % 1;
                  return Container(
                    width: s * (0.55 + 0.45 * t),
                    height: s * (0.55 + 0.45 * t),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: scheme.primary.withValues(alpha: 0.18 * (1 - t)),
                    ),
                  );
                },
              ),
            child!,
          ],
        ),
        child: Container(
          width: s * 0.55,
          height: s * 0.55,
          decoration: BoxDecoration(color: scheme.primaryContainer, shape: BoxShape.circle),
          child: Icon(widget.icon, size: s * 0.3, color: scheme.onPrimaryContainer),
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, required this.message, this.action});

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Entrance(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GradientBadge(icon: icon, size: 88),
                const SizedBox(height: 24),
                Text(title, style: Theme.of(context).textTheme.headlineSmall, textAlign: TextAlign.center),
                const SizedBox(height: 8),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
                if (action != null) ...[const SizedBox(height: 20), action!],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// An icon in a soft, flat rounded square (welcome screen, empty states).
class GradientBadge extends StatelessWidget {
  const GradientBadge({super.key, required this.icon, this.size = 56});
  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: scheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(size * 0.3)),
      child: Icon(icon, size: size * 0.46, color: scheme.onSurface),
    );
  }
}

/// The "sk" monogram on a flat tile in the theme's color.
class LogoTile extends StatelessWidget {
  const LogoTile({super.key, this.size = 72});
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // The Nothing look: "sk." in dots on a black tile, like its app icon.
    if (isNothing(context)) {
      return Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(size * 0.225),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: DotLogo(height: size * 0.33, color: Colors.white),
      );
    }
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.24),
      decoration: BoxDecoration(color: scheme.primary, borderRadius: BorderRadius.circular(size * 0.3)),
      child: Image.asset('assets/logo/logo.png', color: scheme.onPrimary, semanticLabel: 'Sidekick'),
    );
  }
}

/// Something is loading: a bar that keeps moving, under [child] if given,
/// with an optional [label]. It shows only after [delay], so whatever loads
/// quickly doesn't flash it.
class Loading extends StatefulWidget {
  const Loading({super.key, this.child, this.label, this.delay = const Duration(milliseconds: 250)});
  final Widget? child;
  final String? label;
  final Duration delay;

  @override
  State<Loading> createState() => _LoadingState();
}

class _LoadingState extends State<Loading> {
  Timer? _timer;
  late bool _shown = widget.delay == Duration.zero;

  @override
  void initState() {
    super.initState();
    if (!_shown) _timer = Timer(widget.delay, () => setState(() => _shown = true));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Center(
    child: AnimatedOpacity(
      opacity: _shown ? 1 : 0,
      duration: const Duration(milliseconds: 200),
      child: Semantics(
        label: widget.label ?? 'Loading',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.child != null) ...[widget.child!, const SizedBox(height: 28)],
            const SizedBox(width: 160, child: LinearProgressIndicator()),
            if (widget.label != null) ...[
              const SizedBox(height: 12),
              Text(
                widget.label!,
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

/// A status: a small colored dot (or icon) and a word, no background.
class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.label, required this.color, this.background, this.icon});
  final String label;
  final Color color;

  /// Kept for callers; statuses have no background.
  final Color? background;

  /// Shown in [color] instead of the dot.
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null)
          Icon(icon, size: 14, color: color)
        else
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ),
      ],
    );
  }
}

/// Chooses which paired device the Files and Remote tabs act on.
/// Shows an empty state when nothing is paired yet.
class DeviceGate extends StatelessWidget {
  const DeviceGate({
    super.key,
    required this.state,
    required this.feature,
    required this.icon,
    required this.builder,
    this.onGoToDevices,
  });

  final AppState state;
  final String feature;
  final IconData icon;
  final Widget Function(BuildContext context, PairedDevice device) builder;
  final VoidCallback? onGoToDevices;

  @override
  Widget build(BuildContext context) {
    final device = state.selected;
    if (device == null) {
      return EmptyState(
        icon: icon,
        title: 'Pair a device first',
        message:
            'Install Sidekick on your phone or another computer, then pair with it on the Devices tab to use $feature.',
        action: onGoToDevices == null
            ? null
            : FilledButton.tonalIcon(
                onPressed: onGoToDevices,
                icon: const Icon(Icons.devices_outlined),
                label: const Text('Go to Devices'),
              ),
      );
    }
    return builder(context, device);
  }
}

/// Dropdown chip for switching the target device.
class DevicePicker extends StatelessWidget {
  const DevicePicker({super.key, required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final devices = state.paired;
    final current = state.selected;
    if (current == null) return const SizedBox.shrink();
    if (devices.length < 2) {
      // Nothing to switch to: show which device, without a dead button.
      return Chip(
        avatar: _OnlineIcon(state: state, device: current),
        label: Text(current.name),
      );
    }
    return MenuAnchor(
      builder: (context, controller, _) => FilledButton.tonalIcon(
        onPressed: () => controller.isOpen ? controller.close() : controller.open(),
        icon: _OnlineIcon(state: state, device: current),
        label: Row(mainAxisSize: MainAxisSize.min, children: [Text(current.name), const Icon(Icons.arrow_drop_down)]),
      ),
      menuChildren: [
        for (final d in devices)
          MenuItemButton(
            leadingIcon: _OnlineIcon(state: state, device: d),
            onPressed: () => state.select(d.id),
            child: Text(d.name),
          ),
      ],
    );
  }
}

class _OnlineIcon extends StatelessWidget {
  const _OnlineIcon({required this.state, required this.device});
  final AppState state;
  final PairedDevice device;

  @override
  Widget build(BuildContext context) => Badge(
    smallSize: 8,
    backgroundColor: state.isOnline(device.id) ? Colors.green : Theme.of(context).colorScheme.outline,
    child: Icon(platformIcon(device.platform), size: 20),
  );
}

/// A banner shown while [device] is only reached over Bluetooth.
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key, required this.state, required this.device});
  final AppState state;
  final PairedDevice device;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (state.viaBluetooth(device.id)) {
      final connecting = state.connectingDirect.contains(device.id);
      final direct = state.canConnectDirect(device);
      return Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(color: scheme.secondaryContainer, borderRadius: BorderRadius.circular(16)),
        child: Row(
          children: [
            if (connecting)
              SizedBox.square(
                dimension: 24,
                child: CircularProgressIndicator(strokeWidth: 2.5, color: scheme.onSecondaryContainer),
              )
            else
              Icon(Icons.bluetooth, color: scheme.onSecondaryContainer),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                connecting
                    ? 'Setting up a direct Wi-Fi link with ${device.name}…'
                    : direct
                    ? 'Over Bluetooth (no shared Wi-Fi). Big files and Remote switch to direct Wi-Fi by themselves.'
                    : 'Over Bluetooth (no shared Wi-Fi): files are slower, and Remote needs Wi-Fi.',
                style: TextStyle(color: scheme.onSecondaryContainer),
              ),
            ),
            if (direct && !connecting)
              TextButton(onPressed: () => state.connectDirect(device), child: const Text('Use Wi-Fi')),
          ],
        ),
      );
    }
    return const SizedBox.shrink();
  }
}

/// "just now", "4 min ago", "2 h ago", "3 days ago".
String formatAgo(DateTime t) {
  final d = DateTime.now().difference(t);
  if (d.inSeconds < 60) return 'just now';
  if (d.inMinutes < 60) return '${d.inMinutes} min ago';
  if (d.inHours < 24) return '${d.inHours} h ago';
  return d.inDays == 1 ? 'yesterday' : '${d.inDays} days ago';
}

/// What Files and Remote show while [device] can't be reached: one calm
/// card that says so, what to check, and Try again (Sidekick looks for it
/// everywhere: its last address, the whole network, Bluetooth). The page
/// carries on by itself as soon as the device answers.
class UnreachableDevice extends StatefulWidget {
  const UnreachableDevice({super.key, required this.state, required this.device, this.lookAtStart = true});
  final AppState state;
  final PairedDevice device;

  /// Look for it as soon as this shows.
  final bool lookAtStart;

  @override
  State<UnreachableDevice> createState() => _UnreachableDeviceState();
}

class _UnreachableDeviceState extends State<UnreachableDevice> {
  @override
  void initState() {
    super.initState();
    // After this frame: looking redraws the app, which can't happen mid-build.
    if (widget.lookAtStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(widget.state.findDevice(widget.device));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final state = widget.state;
    final d = widget.device;
    final looking = state.isFinding(d.id);
    final seen = state.lastSeen(d.id);
    final noWifi = !state.wifiConnected;
    final offerBluetooth = AppState.bluetoothSupported && !state.bluetoothOn;
    final tips = [
      'Open Sidekick on ${d.name}',
      if (noWifi) 'Connect this device to Wi-Fi' else 'Put both on the same Wi-Fi',
      if (offerBluetooth) 'No shared Wi-Fi? Find nearby connects them directly',
    ];
    return Center(
      child: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox.square(
                  dimension: 96,
                  child: looking
                      ? Radar(icon: platformIcon(d.platform), size: 96)
                      : Container(
                          decoration: BoxDecoration(color: scheme.surfaceContainerHighest, shape: BoxShape.circle),
                          child: Icon(platformIcon(d.platform), size: 40, color: scheme.onSurfaceVariant),
                        ),
                ),
                const SizedBox(height: 20),
                Text(
                  looking ? 'Looking for ${d.name}…' : "Can't reach ${d.name}",
                  style: text.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  seen == null ? 'Not seen since Sidekick started' : 'Last seen ${formatAgo(seen)}',
                  style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 20),
                for (final tip in tips)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle_outline_rounded, size: 18, color: scheme.onSurfaceVariant),
                        const SizedBox(width: 10),
                        Expanded(child: Text(tip, style: text.bodyMedium)),
                      ],
                    ),
                  ),
                const SizedBox(height: 22),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  alignment: WrapAlignment.center,
                  children: [
                    FilledButton.icon(
                      onPressed: looking ? null : () => state.findDevice(d),
                      icon: const Icon(Icons.refresh_rounded),
                      label: Text(looking ? 'Looking…' : 'Try again'),
                    ),
                    if (offerBluetooth)
                      OutlinedButton.icon(
                        onPressed: () => askToTurnOnBluetooth(context, state, d.name),
                        icon: const Icon(Icons.near_me_outlined),
                        label: const Text('Find nearby'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Drag-and-drop target, except on iOS where the plugin doesn't exist.
class MaybeDropTarget extends StatelessWidget {
  const MaybeDropTarget({super.key, required this.child, required this.onFiles, this.onHover, this.enable = true});

  final Widget child;
  final void Function(List<File> files) onFiles;

  /// Called with true when files are dragged over, false when they leave.
  final void Function(bool hovering)? onHover;
  final bool enable;

  @override
  Widget build(BuildContext context) {
    if (Host.isIOS) return child;
    return DropTarget(
      enable: enable,
      onDragEntered: (_) => onHover?.call(true),
      onDragExited: (_) => onHover?.call(false),
      onDragDone: (details) {
        onHover?.call(false);
        onFiles([for (final f in details.files) File(f.path)]);
      },
      child: child,
    );
  }
}

/// The website's preview (a browser, which can't hand over real files)
/// picks sample files here instead: media (photos and videos) or any.
Future<List<File>> Function({required bool media})? debugPickFiles;

/// Lets the user pick files to send. Phones get a choice between the photo
/// gallery and the file browser.
Future<List<File>> pickFilesToSend(BuildContext context, {required String title}) async {
  var type = FileType.any;
  if (isMobile) {
    final choice = await showModalBottomSheet<FileType>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Photos & videos'),
              onTap: () => Navigator.pop(context, FileType.media),
            ),
            ListTile(
              leading: const Icon(Icons.folder_outlined),
              title: const Text('Files'),
              onTap: () => Navigator.pop(context, FileType.any),
            ),
          ],
        ),
      ),
    );
    if (choice == null) return const [];
    type = choice;
  }
  if (debugPickFiles case final pick?) return pick(media: type == FileType.media);
  try {
    await prepareFilePicker();
    final picked = await FilePicker.pickFiles(dialogTitle: title, type: type);
    return [
      for (final f in picked)
        if (f.path != null) File(f.path!),
    ];
  } catch (e) {
    // Never fail silently: say why no picker appeared.
    if (context.mounted) showError(context, "Couldn't open the file picker: ${describeError(e)}");
    return const [];
  }
}

bool _filePickerReady = false;

/// On a Mac the file picker checks for sandbox file entitlements before it
/// opens. Sidekick isn't sandboxed (it can read any file already), so that
/// check only gets in the way; turn it off once.
Future<void> prepareFilePicker() async {
  if (_filePickerReady || !Host.isMacOS) return;
  try {
    await FilePicker.skipEntitlementsChecks();
  } catch (_) {
    // Older plugin, or not needed: the entitlement is declared as well.
  }
  _filePickerReady = true;
}

void showError(BuildContext context, Object error) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(
        children: [
          Icon(Icons.error_outline_rounded, color: Theme.of(context).colorScheme.inversePrimary),
          const SizedBox(width: 12),
          Expanded(child: Text(error is String ? error : describeError(error))),
        ],
      ),
    ),
  );
}
