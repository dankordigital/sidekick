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
  final messenger = ScaffoldMessenger.maybeOf(context);
  final link = message.link;
  final action = await showDialog<_TextAction>(
    context: context,
    builder: (context) => ReceivedTextDialog(message: message),
  );
  switch (action) {
    case _TextAction.copy:
      await Clipboard.setData(ClipboardData(text: message.text));
      messenger?.showSnackBar(const SnackBar(content: Text('Copied')));
    case _TextAction.open when link != null:
      var opened = false;
      try {
        opened = await launchUrl(link, mode: LaunchMode.externalApplication);
      } catch (_) {}
      if (!opened && context.mounted) showError(context, "Couldn't open the link. Copy it instead.");
    case _:
  }
}

enum _TextAction { copy, open }

/// The card asking Copy / Open (public for the screenshot tools).
class ReceivedTextDialog extends StatelessWidget {
  const ReceivedTextDialog({super.key, required this.message});
  final ReceivedText message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final link = message.link;
    final onlyLink = isOnlyLink(message.text);
    Widget button(String label, IconData icon, _TextAction action, {required bool filled}) {
      final child = Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [Icon(icon, size: 18), const SizedBox(width: 8), Text(label)],
      );
      void tap() => Navigator.pop(context, action);
      const size = Size.fromHeight(48);
      return filled
          ? FilledButton(
              onPressed: tap,
              style: FilledButton.styleFrom(minimumSize: size),
              child: child,
            )
          : OutlinedButton(
              onPressed: tap,
              style: OutlinedButton.styleFrom(minimumSize: size),
              child: child,
            );
    }

    return AlertDialog(
      icon: Center(child: GradientBadge(icon: onlyLink ? Icons.link_rounded : Icons.notes_rounded, size: 52)),
      title: Text('${message.from.name} sent ${onlyLink ? 'a link' : 'a note'}', textAlign: TextAlign.center),
      content: SizedBox(
        width: 400,
        child: Container(
          constraints: const BoxConstraints(maxHeight: 260),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(color: scheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(12)),
          child: SingleChildScrollView(
            child: SelectableText(
              onlyLink ? link.toString() : message.text,
              style: TextStyle(color: onlyLink ? scheme.primary : scheme.onSurface, height: 1.35),
            ),
          ),
        ),
      ),
      // Copy and Open side by side, so they fit on a phone; Close under them.
      actions: [
        SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(child: button('Copy', Icons.copy_rounded, _TextAction.copy, filled: link == null)),
                  if (link != null) ...[
                    const SizedBox(width: 10),
                    Expanded(child: button('Open', Icons.open_in_new_rounded, _TextAction.open, filled: true)),
                  ],
                ],
              ),
              const SizedBox(height: 4),
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
            ],
          ),
        ),
      ],
    );
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
