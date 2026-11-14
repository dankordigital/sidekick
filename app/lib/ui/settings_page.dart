import 'package:file_picker/file_picker.dart';
import 'package:material_ui/material_ui.dart';

import '../app_state.dart';
import '../platform/android.dart';
import '../core/bluetooth.dart';
import '../core/models.dart';
import '../platform/app_icon.dart';
import '../platform/autoload.dart';
import 'kit.dart';
import 'permissions.dart';
import 'widgets.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, required this.state});
  final AppState state;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final _name = TextEditingController(text: widget.state.name);
  String? _receiveDir;

  AppState get state => widget.state;

  @override
  void initState() {
    super.initState();
    state.receiveDir().then((d) {
      if (mounted) setState(() => _receiveDir = d);
    });
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _pickReceiveDir() async {
    final String? dir;
    try {
      if (debugPickFolder case final pick?) {
        dir = await pick(context);
      } else {
        await prepareFilePicker();
        dir = await FilePicker.getDirectoryPath(dialogTitle: 'Save received files to…');
      }
    } catch (e) {
      if (mounted) showError(context, e, title: "Couldn't open the folder picker");
      return;
    }
    if (dir == null) return;
    state.setReceiveDir(dir);
    setState(() => _receiveDir = dir);
  }

  Future<void> _rename() async {
    _name.text = state.name;
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename this device'),
        content: TextField(
          controller: _name,
          autofocus: true,
          maxLength: 40,
          decoration: const InputDecoration(helperText: 'What your other devices see'),
          onSubmitted: (v) => Navigator.pop(context, v),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, _name.text), child: const Text('Save')),
        ],
      ),
    );
    if (name != null && name.trim().isNotEmpty) state.setName(name.trim());
  }

  /// "Files › Sidekick" rather than a long path.
  String get _saveTo {
    final dir = _receiveDir;
    if (dir == null) return '…';
    if (hostIsIOS) return 'Files › Sidekick';
    final parts = dir.split(RegExp(r'[\\/]')).where((p) => p.isNotEmpty).toList();
    return parts.length < 2 ? dir : '${parts[parts.length - 2]} › ${parts.last}';
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        final perms = state.permissions;
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const KTitle('Settings'),
                    const SizedBox(height: 18),
                    // This device: its name, and Rename.
                    KPanel(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              KDeviceTile(platform: state.me.platform, color: K.deviceColor(state.id)),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      state.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w500, color: K.text),
                                    ),
                                    const SizedBox(height: 2),
                                    const Text(
                                      'Visible to nearby devices',
                                      style: TextStyle(fontSize: 12.5, color: K.ok),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          KPill('Rename', style: KPillStyle.outline, onPressed: _rename),
                        ],
                      ),
                    ),
                    _label('Receiving'),
                    KPanel(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Column(
                        children: [
                          const _Row(title: 'Quick save', header: true),
                          for (final (value, label) in [
                            (QuickSave.off, 'Everyone asks'),
                            (QuickSave.favourites, 'Favorites'),
                            (QuickSave.on, 'No one asks'),
                          ])
                            _Row(
                              title: label,
                              selected: state.quickSave == value,
                              onTap: () => state.setQuickSave(value),
                              trailing: AnimatedOpacity(
                                opacity: state.quickSave == value ? 1 : 0,
                                duration: const Duration(milliseconds: 200),
                                child: const Icon(Icons.check_rounded, size: 24, color: K.text),
                              ),
                            ),
                          _Row(
                            title: 'Save to',
                            onTap: _pickReceiveDir,
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ConstrainedBox(
                                  constraints: const BoxConstraints(maxWidth: 180),
                                  child: Text(
                                    _saveTo,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 14, color: K.muted),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Icon(Icons.chevron_right_rounded, color: K.text),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    _label('Connections'),
                    KPanel(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Column(
                        children: [
                          if (AppState.bluetoothSupported)
                            _Switch(
                              'Bluetooth',
                              state.bluetoothOn,
                              state.setBluetooth,
                              detail: state.bluetoothOn ? 'Used only when a device has no Wi-Fi' : null,
                            ),
                          if (hostIsAndroid || hostIsIOS)
                            _Switch('Keep running in the background', state.keepRunning, state.setKeepRunning),
                          if (hostIsAndroid && state.keepRunning) const _AndroidBatteryRow(),
                          if (AutoLoad.supported)
                            _Switch(
                              'Open when you log in',
                              state.autoLoad,
                              state.setAutoLoad,
                              detail: 'Straight to the ${hostIsMacOS ? 'menu bar' : 'tray'}',
                            ),
                          if (!hostIsComputer)
                            _Switch('Send screenshots to computers', state.sendScreenshots, state.setSendScreenshots),
                          if (hostIsAndroid)
                            _Switch(
                              'Send verification codes to computers',
                              state.relayNotifications,
                              state.setRelayNotifications,
                              detail: 'Only the code, never the message',
                            ),
                          if (state.bluetoothOn) ?_bluetoothDetails(),
                        ],
                      ),
                    ),
                    _label('App icon'),
                    KPanel(
                      padding: const EdgeInsets.all(14),
                      child: Wrap(
                        spacing: 10,
                        runSpacing: 12,
                        children: [
                          for (final icon in AppIcon.choices)
                            _IconChoice(
                              name: icon,
                              selected: state.appIcon == icon,
                              onTap: () => state.setAppIcon(icon),
                            ),
                        ],
                      ),
                    ),
                    _label('Sound'),
                    KPanel(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: _Switch('Play sounds', state.sound, state.setSound),
                    ),
                    if (hostIsAndroid || hostIsMacOS) ...[
                      _label('Permissions'),
                      KPanel(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Column(children: hostIsAndroid ? _androidPermissions() : [const MacAccessibilityRow()]),
                      ),
                    ],
                    _label('Paired devices can'),
                    KPanel(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Column(
                        children: [
                          _Switch(
                            'Browse and download files',
                            perms.files,
                            (v) => state.setPermissions(perms.copyWith(files: v)),
                          ),
                          // iOS never lets another device control an iPhone.
                          if (!hostIsIOS)
                            _Switch(
                              'Control mouse and keyboard',
                              perms.input,
                              (v) => state.setPermissions(perms.copyWith(input: v)),
                            ),
                        ],
                      ),
                    ),
                    if (state.paired.isNotEmpty) ...[
                      _label('Security codes'),
                      KPanel(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Column(
                          children: [
                            for (final d in state.paired)
                              _Row(
                                title: d.name,
                                onTap: () => _showSecurityCode(d),
                                trailing: const Icon(Icons.chevron_right_rounded, color: K.text),
                              ),
                          ],
                        ),
                      ),
                    ],
                    _label('Privacy'),
                    KPanel(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const KSub('End-to-end encrypted.\nNo account, cloud or tracking.'),
                          const SizedBox(height: 10),
                          KSub(
                            state.secrets.secure
                                ? 'Pairing keys stay on this device, in ${switch (hostOS) {
                                    'ios' => 'the Keychain',
                                    'macos' => 'a file only your Mac account can read',
                                    'android' => 'the Android Keystore',
                                    'windows' => 'Windows-protected storage',
                                    _ => 'the system keyring',
                                  }}.'
                                : "Pairing keys are kept in Sidekick's settings: this device's secure storage "
                                      "didn't work.",
                            size: 12.5,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    Center(
                      child: Text(
                        [
                          state.appVersion.isEmpty ? 'Sidekick' : 'Sidekick ${state.appVersion}',
                          'ID ${state.id.substring(0, state.id.length.clamp(0, 8))}',
                          'port ${state.me.port}',
                        ].join(' · '),
                        style: const TextStyle(fontSize: 12, color: K.faint),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _label(String text) => Padding(padding: const EdgeInsets.fromLTRB(0, 22, 0, 10), child: KLabel(text));

  /// Bluetooth's state, a search button and its log, folded away.
  Widget? _bluetoothDetails() {
    final bt = state.bluetooth;
    if (bt == null) return null;
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        title: const Text('Bluetooth details', style: TextStyle(fontSize: 15.5, color: K.text)),
        subtitle: Text(switch (bt.status) {
          _ when bt.problem != null => bt.problem!,
          BluetoothStatus.on => bt.advertising ? 'On · visible to other devices' : 'On',
          BluetoothStatus.off => 'Bluetooth is off on this device',
          BluetoothStatus.unauthorized => "Sidekick isn't allowed to use Bluetooth",
          BluetoothStatus.unsupported => "This device's Bluetooth is too old (needs 4.0 or newer)",
          BluetoothStatus.starting => 'Starting…',
        }, style: const TextStyle(fontSize: 12.5, color: K.muted)),
        tilePadding: const EdgeInsets.symmetric(horizontal: 16),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (bt.status == BluetoothStatus.unauthorized)
                KPill('Allow', small: true, onPressed: bt.requestPermission),
              KPill(
                bt.scanning ? 'Searching…' : 'Search now',
                small: true,
                style: KPillStyle.dark,
                onPressed: bt.scanning || !bt.canScan ? null : state.scanBluetoothNow,
              ),
            ],
          ),
          const SizedBox(height: 12),
          const KLabel('Seen over Bluetooth'),
          const SizedBox(height: 4),
          if (state.bluetoothSightings.isEmpty) const KSub('Nothing yet', size: 13),
          for (final s in state.bluetoothSightings)
            KSub('${s.info.name} (${s.info.platform.name}), ${_ago(s.seen)}', size: 13),
          const SizedBox(height: 12),
          const KLabel('Bluetooth log'),
          const SizedBox(height: 4),
          SelectableText(
            bt.log.isEmpty ? 'Nothing yet' : bt.log.reversed.take(25).join('\n'),
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: K.muted),
          ),
        ],
      ),
    );
  }
}

extension on _SettingsPageState {
  void _showSecurityCode(PairedDevice d) {
    final code = state.securityCodeFor(d);
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.verified_user_rounded),
        title: Text('Security code for ${d.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SelectableText(
              code,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium
                  ?.copyWith(fontFeatures: const [FontFeature.tabularFigures()], letterSpacing: 2),
            ),
            const SizedBox(height: 16),
            Text(
              'On ${d.name}, open Sidekick → Settings → Paired devices and tap ${state.name}. If both show the same '
              'code, your connection is private: nobody is in between.',
            ),
          ],
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Done'))],
      ),
    );
  }

  /// One row per special permission, each with a button to the system screen
  /// that grants it. Status refreshes when the user comes back to the app.
  List<Widget> _androidPermissions() => androidPermissionRows();
}

/// Android stops "battery optimised" apps in the background on many
/// phones; this asks once to let Sidekick run.
class _AndroidBatteryRow extends StatefulWidget {
  const _AndroidBatteryRow();

  @override
  State<_AndroidBatteryRow> createState() => _AndroidBatteryRowState();
}

class _AndroidBatteryRowState extends State<_AndroidBatteryRow> {
  bool? _unrestricted;
  late final AppLifecycleListener _lifecycle = AppLifecycleListener(onResume: _check);

  @override
  void initState() {
    super.initState();
    _lifecycle;
    _check();
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  Future<void> _check() async {
    final value = await AndroidBackground.batteryUnrestricted();
    if (mounted) setState(() => _unrestricted = value);
  }

  @override
  Widget build(BuildContext context) {
    final ok = _unrestricted ?? true;
    return ListTile(
      leading: IconTile(
        ok ? Icons.battery_full_rounded : Icons.battery_alert_rounded,
        tone: ok ? TileTone.primary : TileTone.error,
      ),
      title: const Text('Battery'),
      subtitle: Text(
        ok ? 'Unrestricted: Android leaves Sidekick running' : 'Android may stop Sidekick to save battery',
      ),
      trailing: ok
          ? null
          : FilledButton.tonal(onPressed: AndroidBackground.requestBatteryUnrestricted, child: const Text('Allow')),
    );
  }
}

/// A settings row: the whole row is the target, at least 52 px tall.
class _Row extends StatelessWidget {
  const _Row({required this.title, this.detail, this.trailing, this.onTap, this.selected = false, this.header = false});
  final String title;
  final String? detail;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool selected;

  /// A heading inside the panel ("Quick save").
  final bool header;

  @override
  Widget build(BuildContext context) => Semantics(
    button: onTap != null,
    selected: selected,
    child: InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: header ? 44 : 56),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(title, style: TextStyle(fontSize: 15.5, color: K.text)),
                    if (detail != null) ...[
                      const SizedBox(height: 2),
                      Text(detail!, style: const TextStyle(fontSize: 12.5, color: K.muted)),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 12), trailing!],
            ],
          ),
        ),
      ),
    ),
  );
}

/// One app icon to choose: the icon with its name, a white ring when it's
/// the one in use.
class _IconChoice extends StatelessWidget {
  const _IconChoice({required this.name, required this.selected, required this.onTap});
  final String name;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    return Semantics(
      button: true,
      selected: selected,
      label: '${AppIcon.label(name)} icon',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          width: 66,
          child: Column(
            children: [
              AnimatedContainer(
                duration: reduce ? Duration.zero : const Duration(milliseconds: 250),
                curve: const Cubic(0.34, 1.4, 0.64, 1),
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: selected ? K.white : Colors.transparent, width: 2),
                ),
                child: AnimatedScale(
                  scale: selected ? 1 : 0.92,
                  duration: reduce ? Duration.zero : const Duration(milliseconds: 300),
                  curve: const Cubic(0.34, 1.4, 0.64, 1),
                  child: Image.asset(AppIcon.asset(name), width: 52, height: 52),
                ),
              ),
              const SizedBox(height: 6),
              Text(AppIcon.label(name), style: TextStyle(fontSize: 12, color: selected ? K.text : K.muted)),
            ],
          ),
        ),
      ),
    );
  }
}

/// A row with a switch; tapping anywhere on it flips the switch.
class _Switch extends StatelessWidget {
  const _Switch(this.title, this.value, this.onChanged, {this.detail});
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;
  final String? detail;

  @override
  Widget build(BuildContext context) => MergeSemantics(
    child: _Row(
      title: title,
      detail: detail,
      onTap: () => onChanged(!value),
      trailing: Switch(value: value, onChanged: onChanged),
    ),
  );
}

String _ago(DateTime t) {
  final d = DateTime.now().difference(t);
  if (d.inSeconds < 60) return '${d.inSeconds} s ago';
  if (d.inMinutes < 60) return '${d.inMinutes} min ago';
  return '${d.inHours} h ago';
}
