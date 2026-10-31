import 'dart:async';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_state.dart';
import '../core/models.dart';
import '../core/text_message.dart';
import '../platform/desktop_window.dart';
import '../platform/notifications.dart';
import '../platform/sound.dart';
import 'nothing.dart';
import 'widgets.dart';

/// Text or a link arrived: always ask, Copy or (for a link) Open, even from
/// a device whose files are accepted without asking (the owner's call:
/// text is never saved as a file). In the tray the window opens for it; a
/// phone in the background gets a notification and the card waits in the app.
Future<void> showReceivedText(BuildContext context, AppState state, ReceivedText message) async {
  if (state.sound) unawaited(playRequestSound());
  OfferNotifications.showText(message.from.name, message.text, link: message.link != null);
  if (DesktopWindow.supported) await DesktopWindow.instance.open();
  if (!context.mounted) return;
  final link = message.link;
  // Copy happens inside the card (it says "Copied" where you're looking).
  final open = await showDialog<bool>(
    context: context,
    builder: (context) => ReceivedTextDialog(message: message),
  );
  if (open != true || link == null) return;
  var opened = false;
  try {
    opened = await launchUrl(link, mode: LaunchMode.externalApplication);
  } catch (_) {}
  if (!opened && context.mounted) showError(context, "Couldn't open the link. Copy it instead.");
}

/// "bbcgoodfood.com" for https://www.bbcgoodfood.com/recipes: the site, which
/// is what people judge a link by.
String linkSite(Uri link) => link.host.toLowerCase().startsWith('www.') ? link.host.substring(4) : link.host;

/// The rest of the address after the site, readable ("/recipes/easy-pancakes").
String linkPath(Uri link) {
  final rest = link.toString().substring('${link.scheme}://${link.authority}'.length);
  try {
    return Uri.decodeFull(rest);
  } catch (_) {
    return rest;
  }
}

/// The card asking Copy / Open link: the link or note icon on the left of
/// who sent it, ✕ in the top-right corner (no Close button; the owner's
/// call). Pops true for Open link; Copy copies here, shows "Copied" on the
/// button, then closes. Enter does the main action (Open link, or Copy for
/// a note), Esc closes. In the Nothing look: hairlines and one red action.
class ReceivedTextDialog extends StatefulWidget {
  const ReceivedTextDialog({super.key, required this.message});
  final ReceivedText message;

  @override
  State<ReceivedTextDialog> createState() => _ReceivedTextDialogState();
}

class _ReceivedTextDialogState extends State<ReceivedTextDialog> {
  bool _copied = false;

  ReceivedText get message => widget.message;

  Future<void> _copy() async {
    if (_copied) return;
    await Clipboard.setData(ClipboardData(text: message.text.trim()));
    if (!mounted) return;
    setState(() => _copied = true);
    await Future<void>.delayed(const Duration(milliseconds: 750));
    if (mounted) Navigator.of(context).pop(false);
  }

  void _open() => Navigator.of(context).pop(true);

  @override
  Widget build(BuildContext context) {
    final link = message.link;
    final onlyLink = isOnlyLink(message.text);
    final copyLabel = _copied ? 'Copied' : (onlyLink ? 'Copy link' : 'Copy text');
    final copyIcon = _copied ? Icons.check_rounded : Icons.copy_rounded;
    final nothing = isNothing(context);
    final scheme = Theme.of(context).colorScheme;
    final body = nothing ? _nothingBody(link, onlyLink) : _body(link, onlyLink);
    final buttons = nothing ? _nothingButtons(link, copyLabel, copyIcon) : _buttons(link, copyLabel, copyIcon);
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.enter): link != null ? _open : _copy,
        const SingleActivator(LogicalKeyboardKey.numpadEnter): link != null ? _open : _copy,
      },
      child: Focus(
        autofocus: true,
        child: Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(nothing ? 24 : 28),
            side: nothing ? BorderSide(color: scheme.outlineVariant) : BorderSide.none,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _header(onlyLink, nothing),
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(height: nothing ? 14 : 16),
                        body,
                        const SizedBox(height: 20),
                        buttons,
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// The link or note icon on the left, who sent it, and ✕ in the corner.
  Widget _header(bool onlyLink, bool nothing) {
    final scheme = Theme.of(context).colorScheme;
    final icon = onlyLink ? Icons.link_rounded : Icons.notes_rounded;
    return Row(
      children: [
        if (nothing)
          NothingRing(icon, size: 40)
        else
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: scheme.primaryContainer, borderRadius: BorderRadius.circular(14)),
            child: Icon(icon, size: 22, color: scheme.onPrimaryContainer),
          ),
        const SizedBox(width: 14),
        Expanded(
          child: Semantics(
            header: true,
            child: Text(
              '${message.from.name} sent ${onlyLink ? 'a link' : 'a note'}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 19, fontWeight: FontWeight.w600),
            ),
          ),
        ),
        const SizedBox(width: 4),
        IconButton(
          tooltip: 'Close',
          onPressed: () => Navigator.of(context).pop(false),
          icon: const Icon(Icons.close_rounded),
          color: scheme.onSurfaceVariant,
        ),
      ],
    );
  }

  /// The site in big letters, the rest of the address under it.
  Widget _linkTile(Uri link, {required bool framed}) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Semantics(
      label: 'Link to ${linkSite(link)}',
      child: Container(
        padding: framed ? const EdgeInsets.fromLTRB(12, 12, 14, 12) : EdgeInsets.zero,
        decoration: framed
            ? BoxDecoration(color: scheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(14))
            : null,
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: framed ? scheme.surface : Colors.transparent,
                shape: BoxShape.circle,
                border: framed ? null : Border.all(color: scheme.outlineVariant, width: 1.2),
              ),
              child: Icon(Icons.public_rounded, size: 20, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ExcludeSemantics(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      linkSite(link),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    if (linkPath(link).length > 1) ...[
                      const SizedBox(height: 2),
                      Text(
                        linkPath(link),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// A note: the whole text (selectable, scrolls when long).
  Widget _note({required bool framed}) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      constraints: const BoxConstraints(maxHeight: 240),
      padding: framed ? const EdgeInsets.symmetric(horizontal: 14, vertical: 12) : EdgeInsets.zero,
      decoration: framed
          ? BoxDecoration(color: scheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(14))
          : null,
      child: SingleChildScrollView(
        child: SelectableText(
          message.text.trim(),
          style: TextStyle(color: scheme.onSurface, fontSize: 15, height: 1.4),
        ),
      ),
    );
  }

  Widget _body(Uri? link, bool onlyLink) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (!onlyLink) _note(framed: true),
      if (!onlyLink && link != null) const SizedBox(height: 10),
      if (link != null) _linkTile(link, framed: true),
    ],
  );

  Widget _buttons(Uri? link, String copyLabel, IconData copyIcon) {
    Widget label(IconData icon, String text) => Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 18),
        const SizedBox(width: 8),
        Flexible(child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis)),
      ],
    );
    const size = Size.fromHeight(48);
    final copy = link == null
        ? FilledButton(
            onPressed: _copy,
            style: FilledButton.styleFrom(minimumSize: size),
            child: label(copyIcon, copyLabel),
          )
        : OutlinedButton(
            onPressed: _copy,
            style: OutlinedButton.styleFrom(minimumSize: size),
            child: label(copyIcon, copyLabel),
          );
    final open = link == null
        ? null
        : FilledButton(
            onPressed: _open,
            style: FilledButton.styleFrom(minimumSize: size),
            child: label(Icons.open_in_new_rounded, 'Open link'),
          );
    return _layout(main: open ?? copy, second: open == null ? null : copy);
  }

  /// Side by side when there's room (the main action on the right); on a
  /// phone stacked full width, the main action on top, so no label is cut.
  Widget _layout({required Widget main, Widget? second}) => LayoutBuilder(
    builder: (context, constraints) {
      final narrow = constraints.maxWidth < 360;
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (second == null)
            main
          else if (narrow) ...[
            main,
            const SizedBox(height: 10),
            second,
          ] else
            Row(
              children: [
                Expanded(child: second),
                const SizedBox(width: 10),
                Expanded(child: main),
              ],
            ),
        ],
      );
    },
  );

  Widget _nothingBody(Uri? link, bool onlyLink) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const NothingHair(),
      const SizedBox(height: 16),
      if (!onlyLink) _note(framed: false),
      if (!onlyLink && link != null) ...[const SizedBox(height: 16), const NothingHair(), const SizedBox(height: 14)],
      if (link != null) _linkTile(link, framed: false),
      const SizedBox(height: 16),
      const NothingHair(),
    ],
  );

  /// One red action: Open link, or Copy for a note.
  Widget _nothingButtons(Uri? link, String copyLabel, IconData copyIcon) {
    final copy = NothingButton(label: copyLabel, icon: copyIcon, red: link == null, height: 50, onPressed: _copy);
    final open = link == null
        ? null
        : NothingButton(label: 'Open link', icon: Icons.north_east_rounded, height: 50, onPressed: _open);
    return _layout(main: open ?? copy, second: open == null ? null : copy);
  }
}

/// Asks what text or link to send to [d] (the clipboard's text one tap away
/// with Paste), then sends it.
Future<void> askAndSendText(BuildContext context, AppState state, PairedDevice d) async {
  final text = await askForText(context, title: 'Send text or a link to ${d.name}', action: 'Send');
  if (text != null && text.trim().isNotEmpty) await state.sendText(d, text.trim());
}

/// A box to type or paste text into; null when cancelled.
Future<String?> askForText(BuildContext context, {String title = 'Send text or a link', String action = 'Add'}) {
  final controller = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: SizedBox(
        width: 420,
        child: TextField(
          controller: controller,
          autofocus: true,
          minLines: 4,
          maxLines: 10,
          decoration: const InputDecoration(hintText: 'Type or paste a link or a note', border: OutlineInputBorder()),
        ),
      ),
      actions: [
        TextButton.icon(
          onPressed: () async {
            final pasted = (await Clipboard.getData(Clipboard.kTextPlain))?.text;
            if (pasted == null || pasted.isEmpty) return;
            final sel = controller.selection;
            final value = controller.text;
            controller.value = sel.isValid
                ? TextEditingValue(
                    text: value.replaceRange(sel.start, sel.end, pasted),
                    selection: TextSelection.collapsed(offset: sel.start + pasted.length),
                  )
                : TextEditingValue(
                    text: value + pasted,
                    selection: TextSelection.collapsed(offset: value.length + pasted.length),
                  );
          },
          icon: const Icon(Icons.content_paste_rounded, size: 18),
          label: const Text('Paste'),
        ),
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(context, controller.text), child: Text(action)),
      ],
    ),
  ).whenComplete(controller.dispose);
}
