import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;

import '../app_state.dart';
import '../core/models.dart';
import '../core/text_message.dart';
import 'kit.dart';
import 'lucide.dart';
import 'notices.dart';
import 'text_messages.dart';
import 'widgets.dart';

/// One thing waiting to be sent: a file, or a note / link (sent as a
/// message, never a file).
class Picked {
  Picked.file(File this.file) : text = null, size = _lengthOf(file);
  Picked.text(String this.text) : file = null, size = text.length;

  final File? file;
  final String? text;
  final int size;

  String get name {
    if (file case final f?) return p.basename(f.path);
    final t = text!.trim().replaceAll(RegExp(r'\s+'), ' ');
    return t.length > 40 ? '${t.substring(0, 40)}…' : t;
  }

  /// Its design icon (lucide.dart).
  String get icon {
    if (text case final t?) return isOnlyLink(t) ? 'link' : 'paste';
    final ext = p.extension(file!.path).toLowerCase();
    const photos = {'.jpg', '.jpeg', '.png', '.heic', '.gif', '.webp', '.mov', '.mp4', '.m4v'};
    return photos.contains(ext) ? 'photo' : 'file';
  }

  static int _lengthOf(File f) {
    try {
      return f.lengthSync();
    } catch (_) {
      return 0;
    }
  }
}

/// What's chosen on the Send tab. It stays while you switch tabs, until it's
/// sent or cleared.
final sendSelection = ValueNotifier<List<Picked>>(const []);

/// Sidekick 4.0's Send tab (design/figma/prototype/Send.png): four big
/// tiles to choose what, the selection with ✕ per item, then the devices
/// with a Send button each. The main action is the device's own Send, a
/// whole row away from nothing (Fitts's law: big, near the thumb).
class SendPage extends StatelessWidget {
  const SendPage({super.key, required this.state, this.onGoToDevices});
  final AppState state;
  final VoidCallback? onGoToDevices;

  void _add(List<Picked> more) {
    if (more.isEmpty) return;
    sendSelection.value = [...sendSelection.value, ...more];
  }

  Future<void> _files(BuildContext context, {bool media = false}) async {
    final files = await pickFiles(context, title: 'Choose what to send', media: media);
    _add([for (final f in files) Picked.file(f)]);
  }

  Future<void> _text(BuildContext context) async {
    final text = await askForText(context);
    if (text != null && text.trim().isNotEmpty) _add([Picked.text(text.trim())]);
  }

  Future<void> _paste(BuildContext context) async {
    final text = await readClipboard(context);
    if (text == null) return;
    if (text.trim().isEmpty) {
      if (context.mounted) showNotice('The clipboard is empty', icon: Icons.content_paste_off_rounded);
      return;
    }
    unawaited(HapticFeedback.selectionClick());
    _add([Picked.text(text.trim())]);
  }

  Future<void> _sendTo(PairedDevice d) async {
    final items = sendSelection.value;
    if (items.isEmpty) return;
    sendSelection.value = const [];
    for (final t in items.where((i) => i.text != null)) {
      await state.sendText(d, t.text!);
    }
    final files = [for (final i in items) ?i.file];
    if (files.isNotEmpty) await state.sendFiles(d, files);
  }

  @override
  Widget build(BuildContext context) {
    final phone = Platform.isIOS || Platform.isAndroid;
    final tiles = [
      _Tile('Files', 'file', () => _files(context)),
      _Tile('Photos & videos', 'photo', () => _files(context, media: true)),
      _Tile('Text or link', 'link', () => _text(context)),
      _Tile('Paste', 'paste', () => _paste(context)),
    ];
    return ListenableBuilder(
      listenable: Listenable.merge([state, sendSelection]),
      builder: (context, _) {
        final items = sendSelection.value;
        final devices = state.paired;
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
          children: [
            const KTitle('Send'),
            const SizedBox(height: 16),
            const KSub('What would you like to send?'),
            const SizedBox(height: 22),
            LayoutBuilder(
              builder: (context, box) {
                // Two by two on phones; one row of four when there's room.
                final perRow = box.maxWidth >= 640 ? 4 : 2;
                final w = (box.maxWidth - 12 * (perRow - 1)) / perRow;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [for (final t in tiles) SizedBox(width: w, child: t)],
                );
              },
            ),
            const SizedBox(height: 18),
            _Selection(items: items),
            const SizedBox(height: 22),
            if (devices.isEmpty)
              KPanel(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'No devices yet',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: K.text),
                    ),
                    const SizedBox(height: 6),
                    const KSub('Connect a device first, then send to it here.'),
                    if (onGoToDevices != null) ...[
                      const SizedBox(height: 14),
                      KPill('Go to Devices', style: KPillStyle.dark, onPressed: onGoToDevices),
                    ],
                  ],
                ),
              )
            else ...[
              const KLabel('Send to'),
              const SizedBox(height: 10),
              for (final d in devices)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: _Target(state: state, device: d, enabled: items.isNotEmpty, onSend: () => _sendTo(d)),
                ),
            ],
            SizedBox(height: phone ? 8 : 0),
          ],
        );
      },
    );
  }
}

/// A big square-ish tile: icon on top, name under it. The whole tile is the
/// button.
class _Tile extends StatefulWidget {
  const _Tile(this.label, this.icon, this.onTap);
  final String label;
  final String icon;
  final VoidCallback onTap;

  @override
  State<_Tile> createState() => _TileState();
}

class _TileState extends State<_Tile> {
  bool _down = false;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: widget.label,
    excludeSemantics: true,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) => setState(() => _down = false),
      onTapCancel: () => setState(() => _down = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down ? 0.96 : 1,
        duration: Duration(milliseconds: _down ? 90 : 320),
        curve: _down ? Curves.easeOut : const Cubic(0.34, 1.56, 0.64, 1),
        child: Container(
          constraints: const BoxConstraints(minHeight: 118),
          padding: const EdgeInsets.fromLTRB(17, 18, 12, 16),
          decoration: BoxDecoration(color: K.panel, borderRadius: BorderRadius.circular(22)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              LucideIcon(widget.icon, size: 24, color: K.text),
              const SizedBox(height: 22),
              Text(
                widget.label,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w400, color: K.text),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// What's chosen: "2 files · 47.7 MB" with Clear, a row per item with ✕;
/// or "Nothing selected yet".
class _Selection extends StatelessWidget {
  const _Selection({required this.items});
  final List<Picked> items;

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    return AnimatedSize(
      duration: reduce ? Duration.zero : const Duration(milliseconds: 320),
      curve: const Cubic(0.22, 1, 0.36, 1),
      alignment: Alignment.topCenter,
      child: KPanel(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: items.isEmpty
            ? const Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Nothing selected yet', style: TextStyle(fontSize: 16, color: K.text)),
                  SizedBox(height: 14),
                  KSub('Choose files, photos, or a link above.'),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(child: KSub(_summary(items))),
                      KPill('Clear', style: KPillStyle.outline, onPressed: () => sendSelection.value = const []),
                    ],
                  ),
                  const SizedBox(height: 12),
                  for (final item in items) _PickedRow(item: item),
                ],
              ),
      ),
    );
  }

  static String _summary(List<Picked> items) {
    final files = items.where((i) => i.file != null).toList();
    final texts = items.length - files.length;
    final parts = [
      if (files.isNotEmpty)
        '${files.length} ${files.length == 1 ? 'file' : 'files'} · ${formatBytes(files.fold(0, (a, i) => a + i.size))}',
      if (texts > 0) '$texts ${texts == 1 ? 'note' : 'notes'}',
    ];
    return parts.join(' · ');
  }
}

class _PickedRow extends StatelessWidget {
  const _PickedRow({required this.item});
  final Picked item;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(top: 8),
    padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
    decoration: BoxDecoration(color: K.raised, borderRadius: BorderRadius.circular(18)),
    child: Row(
      children: [
        LucideIcon(item.icon, size: 22, color: K.text),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 15, color: K.text),
              ),
              const SizedBox(height: 2),
              Text(
                item.file != null ? formatBytes(item.size) : (isOnlyLink(item.text!) ? 'Link' : 'Note'),
                style: const TextStyle(fontSize: 12.5, color: K.muted),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Remove',
          onPressed: () => sendSelection.value = [
            for (final i in sendSelection.value)
              if (!identical(i, item)) i,
          ],
          icon: const Icon(Icons.close_rounded, size: 22),
          style: IconButton.styleFrom(backgroundColor: K.btn, minimumSize: const Size(46, 46)),
        ),
      ],
    ),
  );
}

/// A device under "Send to": the whole row is the tap target, Send on the
/// right (white when there's something to send and the device answers).
class _Target extends StatelessWidget {
  const _Target({required this.state, required this.device, required this.enabled, required this.onSend});
  final AppState state;
  final PairedDevice device;
  final bool enabled;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final online = state.isOnline(device.id);
    final seen = state.lastSeen(device.id);
    final how = state.connectionLabel(device.id);
    final ready = online && enabled;
    return KRow(
      platform: device.platform,
      color: online || seen != null ? K.platformColor(device.platform) : K.faint,
      name: device.name,
      status: online
          ? '${how ?? 'Connected'} · ready'
          : seen == null
          ? 'Not reachable'
          : 'Not reachable · seen ${formatAgo(seen)}',
      statusColor: online ? K.ok : K.faint,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      onTap: ready ? onSend : null,
      action: KPill('Send', onPressed: ready ? onSend : null),
    );
  }
}
