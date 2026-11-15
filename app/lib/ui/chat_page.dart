import 'dart:async';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_state.dart';
import '../core/history.dart';
import '../core/host.dart';
import '../core/models.dart';
import '../core/text_message.dart';
import 'app_theme.dart';
import 'files_page.dart';
import 'kit.dart';
import 'lucide.dart';
import 'ping.dart';
import 'widgets.dart';

/// Sidekick 4.0's Chat tab: one place per paired device for everything the
/// two shared (files, photos, links, notes), not a messaging app (the
/// owner's call). Pick the device at the top, filter, hold a card for what
/// you can do with it, and send from the bar at the bottom.
class ChatPage extends StatefulWidget {
  const ChatPage({super.key, required this.state, this.onGoToDevices});
  final AppState state;
  final VoidCallback? onGoToDevices;

  @override
  State<ChatPage> createState() => _ChatPageState();
}

enum _Filter { all, files, photos, links, notes }

class _ChatPageState extends State<ChatPage> {
  AppState get state => widget.state;
  _Filter _filter = _Filter.all;
  final _text = TextEditingController();
  final _focus = FocusNode();

  /// The design's search (the round button by the title): filters this
  /// device's chat by name or text.
  bool _searching = false;
  final _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  PairedDevice? get _device {
    final paired = state.paired;
    if (paired.isEmpty) return null;
    // The one picked here, else the one last opened from Devices.
    return paired.where((d) => d.id == state.selectedId).firstOrNull ??
        // The device most recently shared with, else the first.
        (paired.toList()..sort((a, b) {
              final ta = state.history.last(a.id)?.at, tb = state.history.last(b.id)?.at;
              if (ta == null && tb == null) return 0;
              if (ta == null) return 1;
              if (tb == null) return -1;
              return tb.compareTo(ta);
            }))
            .first;
  }

  bool _keep(HistoryItem i) => _matches(i) && _kind(i);

  bool _matches(HistoryItem i) {
    final q = _query.text.trim().toLowerCase();
    if (!_searching || q.isEmpty) return true;
    return (i.name ?? '').toLowerCase().contains(q) || (i.text ?? '').toLowerCase().contains(q);
  }

  bool _kind(HistoryItem i) => switch (_filter) {
    _Filter.all => true,
    _Filter.files => i.kind == HistoryKind.file,
    _Filter.photos => i.kind == HistoryKind.photo || i.kind == HistoryKind.video,
    _Filter.links => i.kind == HistoryKind.link,
    _Filter.notes => i.kind == HistoryKind.note,
  };

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: state,
    builder: (context, _) {
      final d = _device;
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            KTitle(
              'Chat',
              action: d == null
                  ? null
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _RoundButton(
                          icon: _searching ? 'close' : 'search',
                          label: _searching ? 'Close search' : 'Search',
                          onTap: () => setState(() {
                            _searching = !_searching;
                            if (!_searching) _query.clear();
                          }),
                        ),
                        const SizedBox(width: 10),
                        _RoundButton(icon: 'more', label: 'More', onTap: () => _more(context, d)),
                      ],
                    ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 260),
              curve: const Cubic(0.22, 1, 0.36, 1),
              child: _searching
                  ? Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: TextField(
                        controller: _query,
                        autofocus: true,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                          hintText: 'Search this chat',
                          prefixIcon: Padding(padding: EdgeInsets.all(14), child: LucideIcon('search', size: 18)),
                        ),
                      ),
                    )
                  : const SizedBox(width: double.infinity),
            ),
            const SizedBox(height: 14),
            if (d == null)
              Expanded(child: _NoDevices(onGoToDevices: widget.onGoToDevices))
            else ...[
              _DevicePicker(state: state, device: d, onPick: state.select),
              const SizedBox(height: 12),
              _Chips(value: _filter, onChanged: (f) => setState(() => _filter = f)),
              const SizedBox(height: 8),
              Expanded(child: _feed(context, d)),
              const SizedBox(height: 8),
              _MessageBar(
                controller: _text,
                focus: _focus,
                onSendText: () => _sendText(d),
                onSendFiles: () => _sendFiles(d),
              ),
            ],
          ],
        ),
      );
    },
  );

  Widget _feed(BuildContext context, PairedDevice d) {
    final items = state.history.forDevice(d.id).where(_keep).toList().reversed.toList();
    if (items.isEmpty) {
      final scheme = Theme.of(context).colorScheme;
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _filter == _Filter.all
                ? 'Nothing shared with ${d.name} yet. Send a file, a photo, a link or a note from the bar below.'
                : 'Nothing here yet.',
            textAlign: TextAlign.center,
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
        ),
      );
    }
    return ListView.builder(
      reverse: true,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: items.length,
      itemBuilder: (context, i) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // "Tuesday", "Today": above the first thing of each day.
            if (i == items.length - 1 || !_sameDay(items[i + 1].at, items[i].at))
              Padding(
                padding: const EdgeInsets.only(top: 6, bottom: 14),
                child: Text(
                  _dayLabel(items[i].at),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
              ),
            _ItemCard(
              key: ValueKey(items[i].id),
              item: items[i],
              device: d,
              state: state,
              fresh: i == 0 && DateTime.now().difference(items[i].at) < const Duration(seconds: 3),
            ),
          ],
        ),
      ),
    );
  }

  static bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  static String _dayLabel(DateTime t) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(t.year, t.month, t.day);
    final ago = today.difference(day).inDays;
    if (ago == 0) return 'Today';
    if (ago == 1) return 'Yesterday';
    const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    if (ago < 7) return days[t.weekday - 1];
    return '${t.day} ${months[t.month - 1]}${t.year == now.year ? '' : ' ${t.year}'}';
  }

  /// ⋯: what else there is to do with this device.
  Future<void> _more(BuildContext context, PairedDevice d) {
    final online = state.isOnline(d.id);
    return showActions(
      context,
      title: d.name,
      options: [
        ('Browse files', Icons.folder_open_rounded, online ? () => showFilesOf(context, state, d) : null),
        (
          'Ping',
          Icons.notifications_active_outlined,
          online
              ? () async {
                  final rang = await state.ping(d);
                  if (!rang && context.mounted) await showAlreadyPinged(context, d.name);
                }
              : null,
        ),
        ('Clear this chat', Icons.delete_outline_rounded, () => setState(() => state.history.forget(d.id))),
      ],
      footnote: 'Clearing only removes the list here. Files you got stay where they are.',
    );
  }

  Future<void> _sendText(PairedDevice d) async {
    final t = _text.text.trim();
    if (t.isEmpty) return;
    _text.clear();
    setState(() {});
    await state.sendText(d, t);
  }

  Future<void> _sendFiles(PairedDevice d) async {
    final files = await pickFilesToSend(context, title: 'Send to ${d.name}');
    if (files.isNotEmpty) await state.sendFiles(d, files);
  }
}

/// The device whose things are shown; tap to pick another.
class _DevicePicker extends StatelessWidget {
  const _DevicePicker({required this.state, required this.device, required this.onPick});
  final AppState state;
  final PairedDevice device;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final how = state.connectionLabel(device.id);
    return Semantics(
      button: true,
      label: 'Showing ${device.name}. Pick another device',
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: state.paired.length < 2 ? null : () => _pick(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              _DeviceBadge(platform: device.platform),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      device.name,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w400, color: K.text),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      how == null ? 'Not reachable' : '$how · encrypted',
                      style: TextStyle(fontSize: 13, color: how == null ? scheme.onSurfaceVariant : sidekickOk),
                    ),
                  ],
                ),
              ),
              if (state.paired.length > 1) const LucideIcon('down', size: 24, color: K.text),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pick(BuildContext context) async {
    final id = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          children: [
            for (final d in state.paired)
              ListTile(
                leading: _DeviceBadge(platform: d.platform, size: 40),
                title: Text(d.name),
                subtitle: Text(state.connectionLabel(d.id) ?? 'Not reachable'),
                selected: d.id == device.id,
                onTap: () => Navigator.pop(context, d.id),
              ),
          ],
        ),
      ),
    );
    if (id != null) onPick(id);
  }
}

class _DeviceBadge extends StatelessWidget {
  const _DeviceBadge({required this.platform, this.size = 48});
  final DevicePlatform platform;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(size * 0.3),
    ),
    child: Center(
      child: LucideIcon(deviceIconName(platform), size: size * 0.46, color: K.platformColor(platform)),
    ),
  );
}

class _Chips extends StatelessWidget {
  const _Chips({required this.value, required this.onChanged});
  final _Filter value;
  final ValueChanged<_Filter> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final (f, label) in [
            (_Filter.all, 'All'),
            (_Filter.files, 'Files'),
            (_Filter.photos, 'Photos'),
            (_Filter.links, 'Links'),
            (_Filter.notes, 'Notes'),
          ])
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(label),
                selected: value == f,
                showCheckmark: false,
                onSelected: (_) => onChanged(f),
                selectedColor: scheme.primary,
                backgroundColor: scheme.surfaceContainerHigh,
                labelStyle: TextStyle(
                  color: value == f ? scheme.onPrimary : scheme.onSurface,
                  fontWeight: value == f ? FontWeight.w500 : FontWeight.w400,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// One thing shared: a file, photos, a link or a note (a 6-digit code gets
/// its big Copy code button). Hold it, or right-click, for everything else.
class _ItemCard extends StatefulWidget {
  const _ItemCard({super.key, required this.item, required this.device, required this.state, this.fresh = false});
  final HistoryItem item;
  final PairedDevice device;
  final AppState state;
  final bool fresh;

  @override
  State<_ItemCard> createState() => _ItemCardState();
}

class _ItemCardState extends State<_ItemCard> {
  bool _held = false;

  HistoryItem get item => widget.item;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final me = item.fromMe;
    final fg = me ? scheme.onPrimary : scheme.onSurface;
    final soft = me ? const Color(0xFF555555) : scheme.onSurfaceVariant;
    final card = AnimatedScale(
      scale: _held ? 0.96 : 1,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      child: GestureDetector(
        onLongPress: () => _actions(context),
        onSecondaryTap: () => _actions(context),
        onLongPressDown: (_) => setState(() => _held = true),
        onLongPressCancel: () => setState(() => _held = false),
        onLongPressUp: () => setState(() => _held = false),
        child: Container(
          constraints: const BoxConstraints(minWidth: 220, maxWidth: 420),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: me ? scheme.primary : scheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(22),
          ),
          child: DefaultTextStyle.merge(
            style: TextStyle(color: fg),
            child: IconTheme.merge(
              data: IconThemeData(color: fg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: _body(context, fg, soft),
              ),
            ),
          ),
        ),
      ),
    );
    final when = TimeOfDay.fromDateTime(item.at).format(context);
    final column = Column(
      crossAxisAlignment: me ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Semantics(hint: 'Hold for more actions', child: card),
        const SizedBox(height: 6),
        Text(
          '${me ? 'You sent' : 'From ${widget.device.name}'} · $when',
          style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
        ),
      ],
    );
    final placed = Align(alignment: me ? Alignment.centerRight : Alignment.centerLeft, child: column);
    return widget.fresh ? Entrance(child: placed) : placed;
  }

  List<Widget> _body(BuildContext context, Color fg, Color soft) {
    final small = Theme.of(context).textTheme.bodySmall?.copyWith(color: soft);
    switch (item.kind) {
      case HistoryKind.note:
        final code = item.code;
        return [
          Text(item.text ?? '', style: const TextStyle(fontSize: 15.5)),
          if (code != null) ...[
            const SizedBox(height: 10),
            Text(
              code,
              style: const TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w600,
                letterSpacing: 4,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(height: 10),
            _Pill(
              icon: Icons.copy_rounded,
              label: 'Copy code',
              white: true,
              onTap: () {
                // Copied quietly: no pop-up (the owner's call).
                Clipboard.setData(ClipboardData(text: code));
                HapticFeedback.selectionClick();
              },
            ),
          ],
        ];
      case HistoryKind.link:
        final link = linkIn(item.text ?? '');
        final host = link?.host.replaceFirst(RegExp(r'^www\.'), '') ?? item.text ?? '';
        final path = link == null ? '' : '${link.path}${link.hasQuery ? '?${link.query}' : ''}';
        return [
          Text(host, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w600)),
          if (path.length > 1) Text(path, style: small, maxLines: 2, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 10),
          if (link != null)
            _Pill(
              label: 'Open link',
              dark: item.fromMe,
              onTap: () => launchUrl(link, mode: LaunchMode.externalApplication),
            ),
        ];
      case HistoryKind.file || HistoryKind.photo || HistoryKind.video:
        final icon = switch (item.kind) {
          HistoryKind.photo => Icons.image_outlined,
          HistoryKind.video => Icons.movie_outlined,
          _ => Icons.description_outlined,
        };
        final path = item.path;
        return [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 24),
              const SizedBox(width: 12),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.name ?? '', style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w500)),
                    if (item.size != null) Text(formatBytes(item.size!), style: small),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(item.fromMe ? 'Delivered ✓' : 'Received', style: small?.copyWith(fontSize: 13)),
          if (path != null) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _Pill(label: 'Open', dark: item.fromMe, onTap: () => _openFile(path)),
                _Pill(label: revealLabel, dark: item.fromMe, onTap: () => revealInFolder(path)),
              ],
            ),
          ],
        ];
    }
  }

  Future<void> _openFile(String path) async {
    // Computers open it in its app; phones show it in Files.
    if (Host.isIOS || Host.isAndroid || !await launchUrl(Uri.file(path))) await revealInFolder(path);
  }

  /// Everything you can do with it: Open, Copy, Show in folder, Send again,
  /// Remove from this list. ✕ or a flick down closes it.
  Future<void> _actions(BuildContext context) async {
    setState(() => _held = false);
    unawaited(HapticFeedback.mediumImpact());
    final i = item;
    final title = switch (i.kind) {
      HistoryKind.note || HistoryKind.link => i.text ?? '',
      _ => i.name ?? '',
    };
    final copyText = i.code ?? i.text ?? i.name ?? '';
    final open = switch (i.kind) {
      HistoryKind.link => () => launchUrl(linkIn(i.text ?? '')!, mode: LaunchMode.externalApplication),
      HistoryKind.note => null,
      _ => i.path == null ? null : () => _openFile(i.path!),
    };
    final options = <(String, IconData, VoidCallback?)>[
      ('Open', Icons.open_in_new_rounded, open),
      ('Copy', Icons.copy_rounded, () => Clipboard.setData(ClipboardData(text: copyText))),
      if (i.kind != HistoryKind.note && i.kind != HistoryKind.link)
        (revealLabel, Icons.folder_open_rounded, i.path == null ? null : () => revealInFolder(i.path!)),
      if (i.kind == HistoryKind.note || i.kind == HistoryKind.link)
        ('Send again', Icons.refresh_rounded, () => widget.state.sendText(widget.device, i.text ?? '')),
      ('Remove from this list', Icons.delete_outline_rounded, () => widget.state.removeFromHistory(i)),
    ];
    final scheme = Theme.of(context).colorScheme;
    Widget sheet(BuildContext context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  tooltip: 'Close',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                  style: IconButton.styleFrom(backgroundColor: scheme.surfaceContainerHigh),
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (final (label, icon, onTap) in options)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Material(
                  color: scheme.surfaceContainerHigh,
                  shape: const StadiumBorder(),
                  clipBehavior: Clip.antiAlias,
                  child: ListTile(
                    enabled: onTap != null,
                    leading: Icon(icon, size: 20),
                    title: Text(label),
                    onTap: onTap == null
                        ? null
                        : () {
                            Navigator.pop(context);
                            onTap();
                          },
                  ),
                ),
              ),
            Text(
              'Removing only changes this list. It never deletes the file.',
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
    if (usePhoneLayout(context)) {
      await showModalBottomSheet<void>(context: context, showDragHandle: true, builder: sheet);
    } else {
      await showDialog<void>(
        context: context,
        builder: (context) => Dialog(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(padding: const EdgeInsets.only(top: 16), child: sheet(context)),
          ),
        ),
      );
    }
  }
}

/// A small pill button inside a card.
class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.onTap, this.icon, this.white = false, this.dark = false});
  final String label;
  final IconData? icon;
  final VoidCallback onTap;

  /// The white "Copy code" button.
  final bool white;

  /// On a white card (something this device sent).
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = white
        ? scheme.primary
        : dark
        ? const Color(0xFF2A2A2A)
        : const Color(0x12FFFFFF);
    final fg = white ? scheme.onPrimary : const Color(0xFFF2F2F2);
    return Material(
      color: bg,
      shape: const StadiumBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: white ? 18 : 14, vertical: white ? 11 : 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[Icon(icon, size: 17, color: fg), const SizedBox(width: 8)],
              Text(
                label,
                style: TextStyle(color: fg, fontWeight: FontWeight.w500, fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The rounded bar at the bottom: +, a note or a link, and Send files, which
/// turns into a round Send button while typing.
class _MessageBar extends StatefulWidget {
  const _MessageBar({
    required this.controller,
    required this.focus,
    required this.onSendText,
    required this.onSendFiles,
  });
  final TextEditingController controller;
  final FocusNode focus;
  final VoidCallback onSendText;
  final VoidCallback onSendFiles;

  @override
  State<_MessageBar> createState() => _MessageBarState();
}

class _MessageBarState extends State<_MessageBar> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    super.dispose();
  }

  void _changed() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final typing = widget.controller.text.trim().isNotEmpty;
    const spring = Cubic(0.22, 1, 0.36, 1);
    final reduce = MediaQuery.disableAnimationsOf(context);
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: const Color(0x1FFFFFFF)),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Send files',
            onPressed: widget.onSendFiles,
            icon: const Icon(Icons.add_rounded),
            style: IconButton.styleFrom(
              backgroundColor: scheme.surfaceContainerHighest,
              minimumSize: const Size(46, 46),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: TextField(
              controller: widget.controller,
              focusNode: widget.focus,
              minLines: 1,
              maxLines: 4,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => widget.onSendText(),
              decoration: const InputDecoration(
                hintText: 'Write a note or paste a link',
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(width: 6),
          // Send files shrinks into a round Send while typing.
          AnimatedSize(
            duration: reduce ? Duration.zero : const Duration(milliseconds: 320),
            curve: spring,
            child: Material(
              color: scheme.primary,
              shape: const StadiumBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: typing ? widget.onSendText : widget.onSendFiles,
                child: Semantics(
                  button: true,
                  label: typing ? 'Send' : 'Send files',
                  excludeSemantics: true,
                  child: SizedBox(
                    height: 46,
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: typing ? 13 : 18),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AnimatedSwitcher(
                            duration: reduce ? Duration.zero : const Duration(milliseconds: 220),
                            transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
                            child: Icon(
                              typing ? Icons.arrow_upward_rounded : Icons.ios_share_rounded,
                              key: ValueKey(typing),
                              size: 20,
                              color: scheme.onPrimary,
                            ),
                          ),
                          if (!typing) ...[
                            const SizedBox(width: 8),
                            Text(
                              'Send files',
                              style: TextStyle(color: scheme.onPrimary, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NoDevices extends StatelessWidget {
  const _NoDevices({this.onGoToDevices});
  final VoidCallback? onGoToDevices;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Nothing to show yet', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(
          'Pair a device first. Everything you share with it shows up here.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        if (onGoToDevices != null) ...[
          const SizedBox(height: 16),
          FilledButton(onPressed: onGoToDevices, child: const Text('Connect a device')),
        ],
      ],
    ),
  );
}

/// The design's round #262626 button beside a title (search, ⋯).
class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.icon, required this.label, required this.onTap});
  final String icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    excludeSemantics: true,
    child: Material(
      color: K.raised,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox.square(
          dimension: 48,
          child: Center(child: LucideIcon(icon, size: 22, color: K.text)),
        ),
      ),
    ),
  );
}
