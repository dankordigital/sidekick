import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../app_state.dart';
import '../core/models.dart';
import '../core/server.dart';
import '../platform/gallery.dart';
import '../platform/sound.dart';
import 'devices_page.dart' show pairWith, showConnectOptions;
import 'direct_wifi.dart';
import 'nothing.dart';
import 'ping.dart';
import 'transfer_screens.dart' show closeRoute;
import 'widgets.dart';

/// The Nothing look's own screens (Settings → Theme → Nothing), built 1:1
/// from the approved mock-ups: ink on paper (or paper on ink), lines
/// instead of cards, dot-matrix titles, mono labels, one red action per
/// screen, green only for "connected". Tabs: Devices · Send · Remote ·
/// Settings; Send works like LocalSend's, with Browse files full screen.
/// Remote and Settings keep their layout in the look's colors. Delete with
/// nothing.dart to drop the look.

/// How a paired device is reached, in a word or two.
String _how(AppState state, PairedDevice d) {
  if (state.needsRepair(d) != null) return 'Pair again';
  if (state.connectingDirect.contains(d.id)) return 'Setting up direct Wi-Fi';
  if (state.viaDirectWifi(d.id) || state.viaDirectLinkOnly(d.id)) return 'Direct Wi-Fi';
  if (state.viaBluetooth(d.id)) return 'Bluetooth';
  return state.isOnline(d.id) ? 'Wi-Fi' : 'Offline';
}

Future<void> _ping(BuildContext context, AppState state, PairedDevice d) async {
  final rang = await state.ping(d);
  if (!rang && context.mounted) await showAlreadyPinged(context, d.name);
}

String _platformName(DevicePlatform p) => switch (p) {
  DevicePlatform.windows => 'Windows',
  DevicePlatform.macos => 'macOS',
  DevicePlatform.linux => 'Linux',
  DevicePlatform.android => 'Android',
  DevicePlatform.ios => 'iOS',
  DevicePlatform.unknown => 'Device',
};

/// Page padding: roomier on computers.
EdgeInsets _pad(bool wide) =>
    wide ? const EdgeInsets.fromLTRB(40, 34, 40, 0) : const EdgeInsets.fromLTRB(24, 22, 24, 0);

/// What's picked on the Send tab. It stays picked until Clear, so the same
/// files can go to several devices (like LocalSend).
final sendSelection = ValueNotifier<List<File>>(const []);

void _addToSelection(List<File> files) {
  if (files.isEmpty) return;
  final have = {for (final f in sendSelection.value) f.path};
  sendSelection.value = [...sendSelection.value, ...files.where((f) => have.add(f.path))];
}

/// The selection's size, worked out once per selection.
final _sizes = Expando<int>();
int _selectionBytes(List<File> files) {
  if (_sizes[files] case final known?) return known;
  var sum = 0;
  for (final f in files) {
    try {
      sum += f.lengthSync();
    } catch (_) {
      // Gone since it was picked; sending will say so.
    }
  }
  return _sizes[files] = sum;
}

// ------------------------------------------------------------------ Devices

/// Devices: how many are ready, the list (a row opens the device), and the
/// one red button, Send files.
class NothingDevicesPage extends StatelessWidget {
  const NothingDevicesPage({super.key, required this.state, required this.onOpen});
  final AppState state;

  /// Switches to a tab (1 Send, 2 Remote).
  final void Function(int tab) onOpen;

  Future<void> _sendFiles(BuildContext context) async {
    final files = await pickFilesToSend(context, title: 'Send files');
    _addToSelection(files);
    if (files.isNotEmpty) onOpen(1);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: state,
    builder: (context, _) {
      final scheme = Theme.of(context).colorScheme;
      final wide = MediaQuery.sizeOf(context).width >= 700;
      final paired = state.paired;
      final ready = paired.where((d) => state.isOnline(d.id) && state.needsRepair(d) == null).length;
      final nearby = state.nearby;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ListView(
              padding: _pad(wide),
              children: [
                Row(
                  children: [
                    if (wide) const DotText('Devices', dot: 5) else const DotLogo(height: 15),
                    const Spacer(),
                    NothingChip(label: '+ Connect', onPressed: () => showConnectOptions(context, state)),
                  ],
                ),
                SizedBox(height: wide ? 34 : 30),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    DotText('$ready', dot: 15),
                    const SizedBox(width: 16),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            ready == 1 ? 'device' : 'devices',
                            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w500, height: 1.0),
                          ),
                          Text(
                            'ready',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w500,
                              height: 1.1,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    const NothingDot(on: true),
                    const SizedBox(width: 7),
                    Flexible(child: NothingLabel(state.name, size: 10.5, color: scheme.onSurface)),
                    const SizedBox(width: 10),
                    const NothingLabel('· Encrypted', size: 10.5),
                  ],
                ),
                const SizedBox(height: 34),
                const NothingSection('Your devices'),
                const NothingHair(),
                if (paired.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    child: Text(
                      'Nothing paired yet. Open Sidekick on your phone or computer and tap + Connect.',
                      style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 15),
                    ),
                  ),
                for (final d in paired) _DeviceRow(state: state, device: d, onOpen: onOpen),
                if (nearby.isNotEmpty) ...[
                  const SizedBox(height: 30),
                  const NothingSection('Nearby', trailing: 'Not paired'),
                  const NothingHair(),
                  for (final d in nearby) _NearbyRow(state: state, device: d),
                ],
                const SizedBox(height: 20),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(_pad(wide).left, 8, _pad(wide).right, wide ? 28 : 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: SizedBox(
                width: wide ? 320 : double.infinity,
                child: NothingButton(
                  label: 'Send files',
                  icon: Icons.north_east_rounded,
                  onPressed: () => _sendFiles(context),
                ),
              ),
            ),
          ),
        ],
      );
    },
  );
}

/// A paired device: its ring, name, a green dot when it's there, how; the
/// whole row opens its page. Files dropped on it are sent to it.
class _DeviceRow extends StatefulWidget {
  const _DeviceRow({required this.state, required this.device, required this.onOpen});
  final AppState state;
  final PairedDevice device;
  final void Function(int tab) onOpen;

  @override
  State<_DeviceRow> createState() => _DeviceRowState();
}

class _DeviceRowState extends State<_DeviceRow> {
  bool _dragging = false;

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final d = widget.device;
    final scheme = Theme.of(context).colorScheme;
    final online = state.isOnline(d.id);
    final reset = state.needsRepair(d) != null;
    final findNearby = !online && AppState.bluetoothSupported && !state.bluetoothOn;
    final on = online && !reset;
    final how = _dragging
        ? 'Drop to send'
        : [
            if (on && _how(state, d) == 'Wi-Fi') 'Connected' else _how(state, d),
            if (state.alwaysAccept.contains(d.id)) 'always accept',
            if (state.runsOlderApp(d)) 'update Sidekick',
          ].join(' · ');
    return MaybeDropTarget(
      onHover: (h) => setState(() => _dragging = h),
      onFiles: (files) => state.sendFiles(d, files),
      child: Column(
        children: [
          InkWell(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => NothingDevicePage(state: state, device: d, onOpen: widget.onOpen),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Row(
                children: [
                  NothingRing(platformIcon(d.platform), on: on, highlight: _dragging),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          d.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                            color: on ? scheme.onSurface : scheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Row(
                          children: [
                            NothingDot(on: on),
                            const SizedBox(width: 7),
                            Expanded(child: NothingLabel(how, size: 10)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (reset)
                    NothingChip(
                      label: 'Pair again',
                      onPressed: () => pairWith(context, state, state.forgetForRepair(d)),
                    )
                  else if (findNearby)
                    NothingChip(label: 'Find nearby', onPressed: () => askToTurnOnBluetooth(context, state, d.name))
                  else
                    Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
                ],
              ),
            ),
          ),
          const NothingHair(),
        ],
      ),
    );
  }
}

/// A device nearby that isn't paired yet.
class _NearbyRow extends StatelessWidget {
  const _NearbyRow({required this.state, required this.device});
  final AppState state;
  final DeviceInfo device;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            NothingRing(platformIcon(device.platform), on: false),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    device.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 5),
                  NothingLabel(device.address ?? 'Over Bluetooth', size: 10),
                ],
              ),
            ),
            NothingChip(label: 'Pair', onPressed: () => pairWith(context, state, device)),
          ],
        ),
      ),
      const NothingHair(),
    ],
  );
}

// ------------------------------------------------------------------ Send

/// The kinds of things to send. Folders only on computers: phones hand
/// apps a folder they can't read file by file.
enum _Kind { file, folder, media, text, paste }

/// Send, like LocalSend's: what to send (picked once, kept until Clear),
/// the devices in reach each with a red send button, and Browse files,
/// which opens another device's folders full screen.
class NothingSendPage extends StatefulWidget {
  const NothingSendPage({super.key, required this.state});
  final AppState state;

  @override
  State<NothingSendPage> createState() => _NothingSendPageState();
}

class _NothingSendPageState extends State<NothingSendPage> {
  _Kind _kind = _Kind.file;
  bool _dragging = false;

  AppState get state => widget.state;

  List<_Kind> get _kinds => debugPickFiles != null
      // The website's preview: sample files only (a browser has no folders
      // or temp files to read and write).
      ? const [_Kind.file, _Kind.media]
      : isMobile
      ? const [_Kind.file, _Kind.media, _Kind.text, _Kind.paste]
      : const [_Kind.file, _Kind.folder, _Kind.text, _Kind.paste];

  static (IconData, String) _look(_Kind k) => switch (k) {
    _Kind.file => (Icons.insert_drive_file_outlined, 'File'),
    _Kind.folder => (Icons.folder_outlined, 'Folder'),
    _Kind.media => (Icons.image_outlined, 'Media'),
    _Kind.text => (Icons.notes_rounded, 'Text'),
    _Kind.paste => (Icons.content_paste_rounded, 'Paste'),
  };

  Future<void> _pick(_Kind kind) async {
    setState(() => _kind = kind);
    switch (kind) {
      case _Kind.file:
        _addToSelection(await _pickFiles(FileType.any));
      case _Kind.media:
        _addToSelection(await _pickFiles(FileType.media));
      case _Kind.folder:
        await _pickFolder();
      case _Kind.text:
        final text = await _askForText();
        if (text != null && text.trim().isNotEmpty) await _addText(text, 'Text');
      case _Kind.paste:
        final text = (await Clipboard.getData(Clipboard.kTextPlain))?.text;
        if (text == null || text.trim().isEmpty) {
          if (mounted) showError(context, 'There is no text on the clipboard.');
        } else {
          await _addText(text, 'Clipboard');
        }
    }
  }

  Future<List<File>> _pickFiles(FileType type) async {
    if (debugPickFiles case final pick?) return pick(media: type == FileType.media);
    try {
      await prepareFilePicker();
      final picked = await FilePicker.pickFiles(dialogTitle: 'Send', type: type);
      return [
        for (final f in picked)
          if (f.path != null) File(f.path!),
      ];
    } catch (e) {
      if (mounted) showError(context, "Couldn't open the file picker: $e");
      return const [];
    }
  }

  /// Every file in a folder (and the folders inside it), up to 1000.
  Future<void> _pickFolder() async {
    try {
      await prepareFilePicker();
      final path = await FilePicker.getDirectoryPath(dialogTitle: 'Send a folder');
      if (path == null) return;
      final files = await Directory(path)
          .list(recursive: true, followLinks: false)
          .where((e) => e is File && !p.basename(e.path).startsWith('.'))
          .cast<File>()
          .take(1000)
          .toList();
      if (files.isEmpty && mounted) showError(context, 'That folder has no files in it.');
      _addToSelection(files);
    } catch (e) {
      if (mounted) showError(context, "Couldn't read that folder: $e");
    }
  }

  /// Text goes as a small .txt file.
  Future<void> _addText(String text, String name) async {
    try {
      final dir = await (await getTemporaryDirectory()).createTemp('sidekick_text');
      final now = DateTime.now();
      final stamp =
          '${now.year}-${_two(now.month)}-${_two(now.day)} ${_two(now.hour)}.${_two(now.minute)}.${_two(now.second)}';
      final file = File(p.join(dir.path, '$name $stamp.txt'));
      await file.writeAsString(text);
      _addToSelection([file]);
    } catch (e) {
      if (mounted) showError(context, "Couldn't keep that text: $e");
    }
  }

  static String _two(int n) => n.toString().padLeft(2, '0');

  Future<String?> _askForText() {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Send text'),
        content: SizedBox(
          width: 420,
          child: TextField(
            controller: controller,
            autofocus: true,
            minLines: 4,
            maxLines: 10,
            decoration: const InputDecoration(hintText: 'Type or paste here', border: OutlineInputBorder()),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('Add')),
        ],
      ),
    ).whenComplete(controller.dispose);
  }

  Future<void> _sendTo(PairedDevice d) async {
    var files = sendSelection.value;
    if (files.isEmpty) {
      files = await pickFilesToSend(context, title: 'Send to ${d.name}');
      _addToSelection(files);
    }
    if (files.isNotEmpty) await state.sendFiles(d, files);
  }

  void _openBrowser() =>
      Navigator.of(context)
          .push(MaterialPageRoute<void>(fullscreenDialog: true, builder: (_) => NothingBrowsePage(state: state)));

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 700;
    return ListenableBuilder(
      listenable: Listenable.merge([state, sendSelection]),
      builder: (context, _) {
        final scheme = Theme.of(context).colorScheme;
        final targets = state.paired.where((d) => state.isOnline(d.id) && state.needsRepair(d) == null).toList();
        final links = Row(
          children: [
            InkWell(
              onTap: () => showConnectOptions(context, state),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: NothingLabel('+ Add by address', size: 10.5, color: scheme.onSurface),
              ),
            ),
            const Spacer(),
            if (wide)
              InkWell(
                onTap: _openBrowser,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: NothingLabel('Browse files on another device →', size: 10.5, color: scheme.onSurface),
                ),
              ),
          ],
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ListView(
                padding: _pad(wide),
                children: [
                  DotText('Send', dot: wide ? 5 : 4.4),
                  SizedBox(height: wide ? 30 : 22),
                  const NothingSection('What'),
                  if (wide) _dropZone(scheme) else ..._phoneWhat(scheme),
                  SizedBox(height: wide ? 34 : 26),
                  NothingSection('Nearby', trailing: targets.isEmpty ? 'Nobody in reach' : 'In reach'),
                  const NothingHair(),
                  if (targets.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      child: Text(
                        state.paired.isEmpty
                            ? 'Pair a device on the Devices tab to send to it.'
                            : 'Your devices will show up here when they are in reach.',
                        style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 15),
                      ),
                    ),
                  for (final d in targets) _target(d, wide),
                  SizedBox(height: wide ? 8 : 6),
                  links,
                  const SizedBox(height: 16),
                ],
              ),
            ),
            if (!wide)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                child: NothingButton(
                  label: 'Browse files',
                  icon: Icons.folder_open_outlined,
                  red: false,
                  onPressed: _openBrowser,
                ),
              ),
          ],
        );
      },
    );
  }

  /// Phones: the kinds as tiles, then what's picked on one line.
  List<Widget> _phoneWhat(ColorScheme scheme) {
    final files = sendSelection.value;
    return [
      const SizedBox(height: 2),
      Row(
        children: [
          for (final (i, k) in _kinds.indexed) ...[
            if (i > 0) const SizedBox(width: 8),
            Expanded(child: _kindTile(k, scheme)),
          ],
        ],
      ),
      const SizedBox(height: 14),
      Container(
        height: 54,
        padding: const EdgeInsets.only(left: 16, right: 4),
        decoration: BoxDecoration(color: scheme.surfaceContainer, borderRadius: BorderRadius.circular(16)),
        child: Row(
          children: files.isEmpty
              ? [
                  Expanded(
                    child: Text('Nothing picked yet', style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 16)),
                  ),
                ]
              : [
                  Text(
                    files.length == 1 ? '1 file' : '${files.length} files',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: NothingLabel(formatBytes(_selectionBytes(files)), size: 10.5)),
                  _textButton('Edit', scheme.onSurface, _edit),
                  _textButton('Clear', scheme.onSurfaceVariant, () => sendSelection.value = const []),
                ],
        ),
      ),
    ];
  }

  Widget _textButton(String label, Color color, VoidCallback onTap) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(10),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
      child: NothingLabel(label, size: 10.5, color: color),
    ),
  );

  Widget _kindTile(_Kind k, ColorScheme scheme) {
    final (icon, name) = _look(k);
    final on = k == _kind && sendSelection.value.isNotEmpty;
    return AspectRatio(
      aspectRatio: 0.92,
      child: Material(
        color: on ? scheme.onSurface : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: on ? BorderSide.none : BorderSide(color: scheme.outlineVariant, width: 1.2),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _pick(k),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 22, color: on ? scheme.surface : scheme.onSurface),
              const SizedBox(height: 8),
              NothingLabel(name, size: 9, color: on ? scheme.surface : null),
            ],
          ),
        ),
      ),
    );
  }

  /// Computers: a drop zone with what's picked, and the kinds beside it.
  Widget _dropZone(ColorScheme scheme) {
    final files = sendSelection.value;
    return MaybeDropTarget(
      onHover: (h) => setState(() => _dragging = h),
      onFiles: _addToSelection,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 120,
        decoration: BoxDecoration(
          border: Border.all(color: _dragging ? scheme.onSurface : scheme.outlineVariant, width: 1.4),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            const SizedBox(width: 26),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    files.isEmpty
                        ? 'Drop files here'
                        : '${files.length == 1 ? '1 file' : '${files.length} files'} · ${formatBytes(_selectionBytes(files))}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w500,
                      color: files.isEmpty ? scheme.onSurfaceVariant : scheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: files.isEmpty
                        ? const [NothingLabel('or pick what to send', size: 10.5)]
                        : [
                            const NothingLabel('Drop more here · ', size: 10.5),
                            InkWell(
                              onTap: _edit,
                              child: NothingLabel('Edit', size: 10.5, color: scheme.onSurface),
                            ),
                            const NothingLabel(' · ', size: 10.5),
                            InkWell(
                              onTap: () => sendSelection.value = const [],
                              child: const NothingLabel('Clear', size: 10.5),
                            ),
                          ],
                  ),
                ],
              ),
            ),
            for (final k in _kinds)
              Padding(
                padding: const EdgeInsets.only(right: 14),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Material(
                      color: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(color: scheme.outlineVariant, width: 1.2),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () => _pick(k),
                        child: SizedBox.square(dimension: 48, child: Icon(_look(k).$1, size: 20)),
                      ),
                    ),
                    const SizedBox(height: 6),
                    NothingLabel(_look(k).$2, size: 9),
                  ],
                ),
              ),
            const SizedBox(width: 12),
          ],
        ),
      ),
    );
  }

  /// A device in reach, with its red send button.
  Widget _target(PairedDevice d, bool wide) {
    final scheme = Theme.of(context).colorScheme;
    final empty = sendSelection.value.isEmpty;
    return Column(
      children: [
        SizedBox(
          height: wide ? 74 : 70,
          child: Row(
            children: [
              NothingRing(platformIcon(d.platform)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            d.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                          ),
                        ),
                        // A favourite: its files are always accepted here.
                        if (state.alwaysAccept.contains(d.id)) ...[
                          const SizedBox(width: 6),
                          Icon(Icons.star_rounded, size: 16, color: scheme.onSurface),
                        ],
                      ],
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        const NothingDot(on: true),
                        const SizedBox(width: 7),
                        Expanded(child: NothingLabel('${_platformName(d.platform)} · ${_how(state, d)}', size: 10)),
                      ],
                    ),
                  ],
                ),
              ),
              if (wide)
                SizedBox(
                  width: 120,
                  child: NothingButton(
                    label: 'Send',
                    icon: Icons.north_east_rounded,
                    height: 40,
                    onPressed: () => _sendTo(d),
                  ),
                )
              else
                NothingSendDot(
                  tooltip: empty ? 'Pick files for ${d.name}' : 'Send to ${d.name}',
                  onPressed: () => _sendTo(d),
                ),
            ],
          ),
        ),
        const NothingHair(),
      ],
    );
  }

  /// What's picked, each with a remove button.
  Future<void> _edit() => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => ValueListenableBuilder(
      valueListenable: sendSelection,
      builder: (context, files, _) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.7),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
            children: [
              NothingSection('Picked', trailing: '${files.length}'),
              const NothingHair(),
              for (final f in files) ...[
                Row(
                  children: [
                    Expanded(child: Text(p.basename(f.path), maxLines: 1, overflow: TextOverflow.ellipsis)),
                    IconButton(
                      tooltip: 'Remove',
                      icon: const Icon(Icons.close_rounded, size: 20),
                      onPressed: () => sendSelection.value = [...files]..remove(f),
                    ),
                  ],
                ),
                const NothingHair(),
              ],
              const SizedBox(height: 16),
              NothingButton(
                label: 'Add more',
                red: false,
                onPressed: () async {
                  Navigator.pop(context);
                  await _pick(_kind);
                },
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

// ------------------------------------------------------------------ Browse files

/// Another device's folders, full screen; the X goes back. Tap a file to
/// bring it here; in a folder, New folder and Upload here.
class NothingBrowsePage extends StatefulWidget {
  const NothingBrowsePage({super.key, required this.state, this.device});
  final AppState state;

  /// Whose files; otherwise the selected device.
  final PairedDevice? device;

  @override
  State<NothingBrowsePage> createState() => _NothingBrowsePageState();
}

class _NothingBrowsePageState extends State<NothingBrowsePage> {
  AppState get state => widget.state;
  late PairedDevice? _device = widget.device ?? _firstBrowsable();
  final List<String> _stack = [];
  List<RemoteEntry> _entries = [];
  bool _loading = false;
  String? _error;
  bool _dragging = false;

  String? get _current => _stack.isEmpty ? null : _stack.last;

  /// Devices whose files can be browsed, the ones in reach first.
  List<PairedDevice> get _browsable {
    final list = state.paired.where((d) => state.capabilitiesOf(d.id)?.files ?? true).toList();
    return [...list.where((d) => state.isOnline(d.id)), ...list.where((d) => !state.isOnline(d.id))];
  }

  PairedDevice? _firstBrowsable() {
    final list = _browsable;
    final selected = state.selected;
    if (selected != null && list.any((d) => d.id == selected.id)) return selected;
    return list.firstOrNull;
  }

  @override
  void initState() {
    super.initState();
    if (_device != null) _load();
  }

  Future<void> _load() async {
    final device = _device;
    if (device == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final client = state.clientFor(device);
      final entries = _current == null ? await client.roots() : await client.list(_current!);
      entries.sort(
        (a, b) => a.isDir != b.isDir ? (a.isDir ? -1 : 1) : a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );
      if (!mounted || device != _device) return;
      setState(() {
        _entries = entries.where((e) => !e.name.startsWith('.')).toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  void _switchTo(PairedDevice d) {
    state.select(d.id);
    setState(() {
      _device = d;
      _stack.clear();
      _entries = [];
    });
    _load();
  }

  void _open(String path) {
    _stack.add(path);
    _load();
  }

  /// Back one folder, or out to where you were.
  void _back() {
    if (_stack.isEmpty) return closeRoute(context);
    _stack.removeLast();
    _load();
  }

  Future<void> _upload(List<File> files) async {
    final device = _device;
    if (files.isEmpty || device == null || _current == null) return;
    await state.sendFiles(device, files, remoteDir: _current);
    if (mounted) unawaited(_load());
  }

  Future<void> _newFolder() async {
    final device = _device;
    final here = _current;
    if (device == null || here == null) return;
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New folder'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Name'),
          onSubmitted: (v) => Navigator.pop(context, v),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('Make it')),
        ],
      ),
    ).whenComplete(controller.dispose);
    if (name == null || name.trim().isEmpty) return;
    try {
      await state.clientFor(device).makeFolder(here, name.trim());
      if (mounted) unawaited(_load());
    } catch (e) {
      if (mounted) showError(context, "Couldn't make the folder: $e");
    }
  }

  String _path() {
    final device = _device!;
    if (_stack.isEmpty) return device.name;
    final first = p.basename(_stack.first).isEmpty ? _stack.first : p.basename(_stack.first);
    return [device.name, first, for (final s in _stack.skip(1)) p.basename(s)].join(' / ');
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final wide = MediaQuery.sizeOf(context).width >= 700;
    return Scaffold(
      body: SafeArea(
        child: ListenableBuilder(
          listenable: state,
          builder: (context, _) {
            final device = _device;
            final choices = _browsable;
            return Padding(
              padding: EdgeInsets.fromLTRB(_pad(wide).left, 14, _pad(wide).right, wide ? 28 : 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      NothingRound(
                        icon: Icons.close_rounded,
                        tooltip: 'Close',
                        size: 44,
                        outlined: true,
                        onPressed: () => closeRoute(context),
                      ),
                      const Spacer(),
                      if (device != null)
                        PopupMenuButton<PairedDevice>(
                          tooltip: 'Another device',
                          onSelected: _switchTo,
                          itemBuilder: (_) => [
                            for (final d in choices)
                              PopupMenuItem(
                                value: d,
                                child: Row(
                                  children: [
                                    Icon(platformIcon(d.platform), size: 18),
                                    const SizedBox(width: 10),
                                    Text(d.name),
                                  ],
                                ),
                              ),
                          ],
                          child: Container(
                            height: 36,
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: scheme.outlineVariant, width: 1.2),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(platformIcon(device.platform), size: 16),
                                const SizedBox(width: 8),
                                Text(device.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                                const SizedBox(width: 4),
                                Icon(Icons.expand_more_rounded, size: 18, color: scheme.onSurfaceVariant),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 30),
                  const DotText('Files', dot: 4.4),
                  const SizedBox(height: 12),
                  if (device == null)
                    Expanded(
                      child: Align(
                        alignment: Alignment.topLeft,
                        child: Text(
                          'Pair a device on the Devices tab to browse its files.',
                          style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 15),
                        ),
                      ),
                    )
                  else ...[
                    Row(
                      children: [
                        if (_stack.isNotEmpty)
                          InkWell(
                            onTap: _back,
                            child: Padding(
                              padding: const EdgeInsets.only(right: 10),
                              child: NothingLabel('← Up', size: 10.5, color: scheme.onSurface),
                            ),
                          ),
                        Expanded(child: NothingLabel(_path(), size: 10.5)),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const NothingHair(),
                    Expanded(
                      child: MaybeDropTarget(
                        enable: _current != null,
                        onHover: (h) => setState(() => _dragging = h),
                        onFiles: _upload,
                        child: Container(
                          color: _dragging ? scheme.surfaceContainer : null,
                          child: _list(device, scheme),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_current != null)
                      Row(
                        children: [
                          Expanded(
                            child: NothingButton(label: 'New folder', red: false, mono: true, onPressed: _newFolder),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: NothingButton(
                              label: 'Upload here',
                              icon: Icons.north_east_rounded,
                              onPressed: () async =>
                                  _upload(await pickFilesToSend(context, title: 'Upload to ${device.name}')),
                            ),
                          ),
                        ],
                      ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _list(PairedDevice device, ColorScheme scheme) {
    if (_loading) return const Loading(label: 'Opening folder…');
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Couldn't open this folder", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
            const SizedBox(height: 6),
            Text(_error!, style: TextStyle(color: scheme.onSurfaceVariant)),
            const SizedBox(height: 14),
            NothingChip(label: 'Try again', onPressed: _load),
          ],
        ),
      );
    }
    if (_entries.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 18),
        child: Text(
          _current == null ? 'Nothing shared here.' : 'This folder is empty.',
          style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 15),
        ),
      );
    }
    return ListView.builder(
      padding: EdgeInsets.zero,
      itemCount: _entries.length,
      itemBuilder: (context, i) {
        final e = _entries[i];
        return Column(
          children: [
            InkWell(
              onTap: e.isDir ? () => _open(e.path) : () => state.download(device, e),
              child: SizedBox(
                height: 58,
                child: Row(
                  children: [
                    Icon(
                      e.isDir ? Icons.folder_outlined : _fileIcon(e.name),
                      size: 22,
                      color: e.isDir ? scheme.onSurface : scheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        e.name.isEmpty ? e.path : e.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 16, fontWeight: e.isDir ? FontWeight.w500 : FontWeight.w400),
                      ),
                    ),
                    if (!e.isDir) ...[const SizedBox(width: 8), NothingLabel(formatBytes(e.size), size: 10)],
                    const SizedBox(width: 12),
                    e.isDir
                        ? Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant)
                        : Tooltip(
                            message: 'Bring it here',
                            child: Icon(Icons.south_west_rounded, size: 18, color: scheme.onSurface),
                          ),
                  ],
                ),
              ),
            ),
            const NothingHair(),
          ],
        );
      },
    );
  }

  static IconData _fileIcon(String name) => switch (p.extension(name).toLowerCase()) {
    '.jpg' || '.jpeg' || '.png' || '.gif' || '.webp' || '.heic' || '.bmp' => Icons.image_outlined,
    '.mp4' || '.mkv' || '.mov' || '.avi' || '.webm' => Icons.movie_outlined,
    '.mp3' || '.flac' || '.wav' || '.m4a' || '.ogg' => Icons.audio_file_outlined,
    '.zip' || '.rar' || '.7z' || '.tar' || '.gz' => Icons.folder_zip_outlined,
    _ => Icons.description_outlined,
  };
}

// ------------------------------------------------------------------ a device

/// One paired device: its name in dots, Send / Files / Remote / Ping,
/// Always accept, and what went back and forth.
class NothingDevicePage extends StatelessWidget {
  const NothingDevicePage({super.key, required this.state, required this.device, required this.onOpen});
  final AppState state;
  final PairedDevice device;
  final void Function(int tab) onOpen;

  void _remote(BuildContext context) {
    state.select(device.id);
    closeRoute(context);
    onOpen(2);
  }

  Future<void> _send(BuildContext context) async {
    final files = await pickFilesToSend(context, title: 'Send to ${device.name}');
    if (files.isNotEmpty) await state.sendFiles(device, files);
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
          final wide = MediaQuery.sizeOf(context).width >= 700;
          final online = state.isOnline(device.id);
          final caps = state.capabilitiesOf(device.id);
          final canBrowse = caps?.files ?? true;
          final canControl = (caps?.input ?? true) && device.platform != DevicePlatform.ios;
          final recent = state.transfers.where((t) => t.deviceName == device.name).toList().reversed.take(8);
          return ListView(
            padding: EdgeInsets.fromLTRB(_pad(wide).left, 14, _pad(wide).right, 24),
            children: [
              Row(
                children: [
                  NothingRound(
                    icon: Icons.arrow_back_rounded,
                    tooltip: 'Back',
                    size: 44,
                    outlined: true,
                    onPressed: () => closeRoute(context),
                  ),
                  const Spacer(),
                  PopupMenuButton<String>(
                    tooltip: 'More',
                    onSelected: (_) => _unpair(context),
                    itemBuilder: (_) => const [PopupMenuItem(value: 'unpair', child: Text('Unpair'))],
                    // The menu button takes the tap; this only draws it.
                    child: IgnorePointer(
                      child: NothingRound(icon: Icons.more_horiz_rounded, size: 44, outlined: true, onPressed: () {}),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 30),
              Center(child: NothingRing(platformIcon(device.platform), size: 76, on: online)),
              const SizedBox(height: 22),
              Center(child: DotText(device.name, dot: 4.6)),
              const SizedBox(height: 14),
              Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    NothingDot(on: online && state.needsRepair(device) == null),
                    const SizedBox(width: 8),
                    NothingLabel(
                      '${_platformName(device.platform)} · ${_how(state, device)}',
                      size: 11,
                      color: scheme.onSurface,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 34),
              Row(
                children: [
                  _Action(
                    icon: Icons.north_east_rounded,
                    label: 'Send',
                    accent: true,
                    onTap: online ? () => _send(context) : null,
                  ),
                  const SizedBox(width: 8),
                  _Action(
                    icon: Icons.folder_open_outlined,
                    label: 'Files',
                    onTap: online && canBrowse
                        ? () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              fullscreenDialog: true,
                              builder: (_) => NothingBrowsePage(state: state, device: device),
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 8),
                  _Action(
                    icon: Icons.mouse_outlined,
                    label: 'Remote',
                    onTap: online && canControl ? () => _remote(context) : null,
                  ),
                  const SizedBox(width: 8),
                  _Action(
                    icon: Icons.notifications_none_rounded,
                    label: 'Ping',
                    onTap: online ? () => unawaited(_ping(context, state, device)) : null,
                  ),
                ],
              ),
              const SizedBox(height: 26),
              const NothingHair(),
              InkWell(
                onTap: () => state.setAlwaysAccept(device.id, !state.alwaysAccept.contains(device.id)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Always accept from ${device.name}', style: const TextStyle(fontSize: 16)),
                            const SizedBox(height: 4),
                            const NothingLabel('Its files come in without asking', size: 10),
                          ],
                        ),
                      ),
                      Switch(
                        value: state.alwaysAccept.contains(device.id),
                        onChanged: (v) => state.setAlwaysAccept(device.id, v),
                      ),
                    ],
                  ),
                ),
              ),
              const NothingHair(),
              const SizedBox(height: 30),
              const NothingSection('Recent'),
              const NothingHair(),
              if (recent.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text('Nothing sent yet', style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 15)),
                ),
              for (final t in recent) _TransferRow(transfer: t, meta: _transferMeta(t)),
            ],
          );
        },
      ),
    ),
  );
}

String _transferMeta(Transfer t) => switch (t.state) {
  TransferState.running => '${t.total > 0 ? (t.done * 100 ~/ t.total) : 0}%',
  TransferState.done => formatBytes(t.total),
  TransferState.failed => 'Failed',
};

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
    final red = accent && enabled;
    final fg = red ? Colors.white : (enabled ? scheme.onSurface : scheme.outline);
    return Expanded(
      child: AspectRatio(
        aspectRatio: 0.92,
        child: Material(
          color: red ? nothingRed : Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: red ? BorderSide.none : BorderSide(color: scheme.outlineVariant, width: 1.2),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 22, color: fg),
                const SizedBox(height: 8),
                NothingLabel(label, size: 9, color: red ? Colors.white : (enabled ? null : scheme.outline)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A file that went one way or the other: ↙ in, ↗ out. Tapping a
/// received one shows where it is.
class _TransferRow extends StatelessWidget {
  const _TransferRow({required this.transfer, required this.meta, this.open = false});
  final Transfer transfer;
  final String meta;

  /// An "Open" at the end of the row.
  final bool open;

  void _show() {
    final t = transfer;
    if (t.inGallery) {
      Gallery.open(t.galleryUri);
    } else if (t.localPath != null && canRevealFiles) {
      unawaited(revealInFolder(t.localPath!));
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = transfer;
    final canShow = t.state == TransferState.done && (t.inGallery || (t.localPath != null && canRevealFiles));
    return Column(
      children: [
        InkWell(
          onTap: canShow ? _show : null,
          child: SizedBox(
            height: 52,
            child: Row(
              children: [
                SizedBox(
                  width: 26,
                  child: Icon(
                    t.upload ? Icons.north_east_rounded : Icons.south_west_rounded,
                    size: 16,
                    color: t.state == TransferState.failed ? nothingRed : scheme.onSurfaceVariant,
                  ),
                ),
                Expanded(
                  child: Text(
                    t.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 15),
                  ),
                ),
                const SizedBox(width: 8),
                NothingLabel(meta, size: 10),
                if (open && canShow) ...[
                  const SizedBox(width: 14),
                  NothingLabel('Open', size: 10.5, color: scheme.onSurface),
                ],
              ],
            ),
          ),
        ),
        const NothingHair(),
      ],
    );
  }
}

// ------------------------------------------------------------------ Receive (computers)

/// The column at the right on computers: this device the way others see
/// it, Quick save, and the last files received.
class NothingReceivePanel extends StatelessWidget {
  const NothingReceivePanel({super.key, required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 340,
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: scheme.outlineVariant)),
      ),
      padding: const EdgeInsets.fromLTRB(32, 34, 32, 28),
      child: ListenableBuilder(
        listenable: state,
        builder: (context, _) {
          final address = state.addresses.isEmpty ? null : state.addresses.first;
          final received = state.transfers.where((t) => t.received && t.state == TransferState.done).toList();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              NothingLabel('Receive', size: 10.5, color: scheme.onSurface),
              const SizedBox(height: 26),
              Center(child: NothingRing(platformIcon(currentPlatform), size: 64)),
              const SizedBox(height: 16),
              Center(child: DotText(state.name, dot: 3.4)),
              const SizedBox(height: 10),
              Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const NothingDot(on: true),
                    const SizedBox(width: 8),
                    NothingLabel(
                      address == null ? 'Ready to receive' : 'Ready · $address',
                      size: 10.5,
                      color: scheme.onSurface,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),
              const NothingSection('Quick save'),
              NothingQuickSave(state: state),
              const SizedBox(height: 10),
              NothingLabel(switch (state.quickSave) {
                QuickSave.off => 'Every device asks first',
                QuickSave.favourites => 'Favourites skip the Accept step',
                QuickSave.on => 'Paired devices never ask',
              }, size: 9.5),
              const Spacer(),
              const NothingSection('Recent'),
              const NothingHair(),
              if (received.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Text('Nothing received yet', style: TextStyle(color: scheme.onSurfaceVariant)),
                ),
              for (final t in received.reversed.take(3)) _TransferRow(transfer: t, meta: t.deviceName, open: true),
            ],
          );
        },
      ),
    );
  }
}

/// Quick save: Off / Favourites / On.
class NothingQuickSave extends StatelessWidget {
  const NothingQuickSave({super.key, required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) => NothingSegments<QuickSave>(
    values: QuickSave.values,
    labels: const ['Off', 'Favourites', 'On'],
    value: state.quickSave,
    onChanged: state.setQuickSave,
  );
}

// ------------------------------------------------------------------ navigation

/// The tab names; each has a dotted icon ([DotIcon]).
const nothingTabs = ['Devices', 'Send', 'Remote', 'Settings'];

/// Phones: a hairline, then the dotted icons with their names under them;
/// the current tab in ink, the rest grey.
class NothingTabBar extends StatelessWidget {
  const NothingTabBar({super.key, required this.index, required this.onTap});
  final int index;
  final void Function(int) onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ColoredBox(
      color: scheme.surface,
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.only(bottom: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const NothingHair(),
            SizedBox(
              height: 70,
              child: Row(
                children: [
                  for (final (i, name) in nothingTabs.indexed)
                    Expanded(
                      child: Semantics(
                        selected: i == index,
                        button: true,
                        label: name,
                        excludeSemantics: true,
                        child: InkResponse(
                          onTap: () => onTap(i),
                          radius: 36,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              DotIcon(name, size: 24, color: i == index ? scheme.onSurface : scheme.onSurfaceVariant),
                              const SizedBox(height: 7),
                              NothingLabel(name, size: 9.5, color: i == index ? scheme.onSurface : null),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Computers: the dotted logo, the tabs as dotted icons and words, and
/// this computer's state at the bottom.
class NothingSideBar extends StatelessWidget {
  const NothingSideBar({super.key, required this.index, required this.onTap, required this.state});
  final int index;
  final void Function(int) onTap;
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 210,
      decoration: BoxDecoration(
        border: Border(right: BorderSide(color: scheme.outlineVariant)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 34, 14, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(padding: EdgeInsets.only(left: 8), child: DotLogo(height: 15)),
          const SizedBox(height: 38),
          for (final (i, name) in nothingTabs.indexed)
            Semantics(
              selected: i == index,
              button: true,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => onTap(i),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                  child: Row(
                    children: [
                      DotIcon(name, size: 18, color: i == index ? scheme.onSurface : scheme.onSurfaceVariant),
                      const SizedBox(width: 12),
                      Text(
                        name,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
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
              builder: (context, _) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const NothingDot(on: true),
                      const SizedBox(width: 7),
                      NothingLabel('Ready', size: 10.5, color: scheme.onSurface),
                    ],
                  ),
                  const SizedBox(height: 6),
                  NothingLabel(state.name, size: 10.5),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------ incoming

/// Files a device wants to send, in the Nothing look: who, the files,
/// "Always accept from …", Decline and the red Accept. Then the files
/// coming in, and it closes when they're all here. Full screen on phones,
/// a card on computers.
Future<void> showNothingIncoming(BuildContext context, AppState state, TransferOffer offer) {
  final wide = MediaQuery.sizeOf(context).width >= 700;
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierLabel: 'Incoming files',
    barrierColor: wide ? Colors.black45 : Colors.transparent,
    transitionDuration: const Duration(milliseconds: 320),
    pageBuilder: (_, _, _) => _NothingIncoming(state: state, offer: offer, wide: wide),
    transitionBuilder: (_, animation, _, child) {
      final curve = CurvedAnimation(parent: animation, curve: Curves.easeOutQuint);
      return FadeTransition(
        opacity: curve,
        child: SlideTransition(
          position: Tween(begin: const Offset(0, 0.04), end: Offset.zero).animate(curve),
          child: child,
        ),
      );
    },
  );
}

class _NothingIncoming extends StatefulWidget {
  const _NothingIncoming({required this.state, required this.offer, required this.wide});
  final AppState state;
  final TransferOffer offer;
  final bool wide;

  @override
  State<_NothingIncoming> createState() => _NothingIncomingState();
}

enum _Stage { asking, receiving, done, gone }

class _NothingIncomingState extends State<_NothingIncoming> {
  TransferOffer get offer => widget.offer;
  _Stage _stage = _Stage.asking;
  int _received = 0;
  bool _always = false;
  bool _closing = false;
  StreamSubscription<int>? _progress;

  @override
  void initState() {
    super.initState();
    _always = widget.state.alwaysAccept.contains(offer.from.id);
    offer.answer.then((answer) {
      if (!mounted || _stage != _Stage.asking) return;
      switch (answer) {
        // Answered from the notification or the corner pop-up: follow along.
        case OfferAnswer.accepted:
          _receive();
        case OfferAnswer.declined:
          _leave();
        case OfferAnswer.cancelled || OfferAnswer.timedOut:
          setState(() => _stage = _Stage.gone);
          Timer(const Duration(milliseconds: 1400), _leave);
      }
    });
  }

  @override
  void dispose() {
    _progress?.cancel();
    super.dispose();
  }

  void _leave() {
    if (_closing || !mounted) return;
    _closing = true;
    closeRoute(context);
  }

  void _accept() {
    if (_always) widget.state.setAlwaysAccept(offer.from.id, true);
    offer.accept();
    if (widget.state.sound) unawaited(playAcceptSound());
    _receive();
  }

  void _decline() {
    offer.decline();
    if (widget.state.sound) unawaited(playDeclineSound());
    _leave();
  }

  void _receive() {
    if (_stage != _Stage.asking) return;
    setState(() => _stage = _Stage.receiving);
    _progress = offer.progress.listen(
      (bytes) => setState(() => _received = bytes),
      onDone: () {
        if (!mounted) return;
        setState(() => _stage = _Stage.done);
        Timer(const Duration(milliseconds: 1200), _leave);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final files = offer.files;
    final total = offer.totalBytes;
    final name = offer.from.name;
    final count = files.length == 1 ? '1 file' : '${files.length} files';
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: widget.wide ? MainAxisSize.min : MainAxisSize.max,
      children: [
        SizedBox(height: widget.wide ? 4 : 40),
        Center(
          child: _stage == _Stage.done
              ? Container(
                  width: 76,
                  height: 76,
                  decoration: const BoxDecoration(color: nothingGreen, shape: BoxShape.circle),
                  child: const Icon(Icons.check_rounded, color: Colors.white, size: 38),
                )
              : NothingRing(platformIcon(offer.from.platform), size: 76),
        ),
        const SizedBox(height: 22),
        Center(
          child: Text(
            name,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w500, letterSpacing: -0.4),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: NothingLabel(switch (_stage) {
            _Stage.asking => 'Wants to send you $count · ${formatBytes(total)}',
            _Stage.receiving => 'Sending you $count',
            _Stage.done => 'All here',
            _Stage.gone => 'Stopped sending',
          }, size: 11),
        ),
        const SizedBox(height: 34),
        const NothingSection('Files'),
        const NothingHair(),
        for (final f in files.take(widget.wide ? 4 : 5))
          Column(
            children: [
              SizedBox(
                height: 52,
                child: Row(
                  children: [
                    SizedBox(
                      width: 26,
                      child: Icon(Icons.crop_square_rounded, size: 14, color: scheme.onSurfaceVariant),
                    ),
                    Expanded(
                      child: Text(
                        f.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 15),
                      ),
                    ),
                    const SizedBox(width: 8),
                    NothingLabel(formatBytes(f.size), size: 10),
                  ],
                ),
              ),
              const NothingHair(),
            ],
          ),
        if (files.length > (widget.wide ? 4 : 5))
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: NothingLabel('and ${files.length - (widget.wide ? 4 : 5)} more', size: 10),
          ),
        const SizedBox(height: 18),
        if (_stage == _Stage.asking)
          InkWell(
            onTap: () => setState(() => _always = !_always),
            borderRadius: BorderRadius.circular(8),
            child: Row(
              children: [
                Checkbox(value: _always, onChanged: (v) => setState(() => _always = v ?? false)),
                const SizedBox(width: 4),
                Expanded(child: Text('Always accept from $name', style: const TextStyle(fontSize: 15))),
              ],
            ),
          ),
        if (_stage == _Stage.receiving) ...[
          TweenAnimationBuilder<double>(
            tween: Tween(end: total > 0 ? (_received / total).clamp(0.0, 1.0) : 0),
            duration: const Duration(milliseconds: 250),
            builder: (_, value, _) => ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: total > 0 ? value : null,
                minHeight: 8,
                color: nothingRed,
                backgroundColor: scheme.outlineVariant,
              ),
            ),
          ),
          const SizedBox(height: 10),
          NothingLabel('${formatBytes(_received)} / ${formatBytes(total)}', size: 10.5),
        ],
        if (widget.wide) const SizedBox(height: 28) else const Spacer(),
        if (_stage == _Stage.asking)
          Row(
            children: [
              Expanded(
                child: NothingButton(label: 'Decline', red: false, mono: true, height: 56, onPressed: _decline),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: NothingButton(label: 'Accept', height: 56, onPressed: _accept),
              ),
            ],
          )
        else if (_stage == _Stage.receiving)
          NothingButton(label: 'Hide', red: false, mono: true, height: 56, onPressed: _leave),
        SizedBox(height: widget.wide ? 0 : 20),
      ],
    );
    if (!widget.wide) {
      return Material(
        color: scheme.surface,
        child: SafeArea(
          child: Padding(padding: const EdgeInsets.symmetric(horizontal: 24), child: content),
        ),
      );
    }
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Material(
          color: scheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
            side: BorderSide(color: scheme.outlineVariant),
          ),
          child: Padding(padding: const EdgeInsets.fromLTRB(28, 30, 28, 26), child: content),
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
