/// Text or a link sent from one device to another (`/v1/text`). It never
/// becomes a file: the receiver always asks whether to copy it, or open the
/// link, even for devices whose files are accepted without asking.
library;

import 'models.dart';

/// Text or a link that arrived from [from].
class ReceivedText {
  ReceivedText(this.from, this.text);
  final TrustedPeer from;
  final String text;

  /// The link to offer Open for, if there is one.
  Uri? get link => linkIn(text);
}

/// A name for text sent as a file ("Text 2026-10-31 14.05.09.txt").
String textFileName(String name, [DateTime? at]) {
  final now = at ?? DateTime.now();
  String two(int n) => n.toString().padLeft(2, '0');
  return '$name ${now.year}-${two(now.month)}-${two(now.day)} ${two(now.hour)}.${two(now.minute)}.${two(now.second)}.txt';
}

/// The longest text sent as a message (characters). Longer text goes as a
/// .txt file instead (it has to fit the server's 64 KB JSON body, escaped).
const maxTextMessage = 20000;

/// The link in [text] to offer Open for: [text] itself when it's a web
/// address ("https://…", or "www.…" without the https), else the first
/// http(s) link in it ("Look at this: https://…"). Only http and https:
/// never a file, app or script address someone else typed.
Uri? linkIn(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return null;
  if (!trimmed.contains(RegExp(r'\s'))) {
    final whole = _webLink(trimmed) ?? (trimmed.toLowerCase().startsWith('www.') ? _webLink('https://$trimmed') : null);
    if (whole != null) return whole;
  }
  for (final m in RegExp(r'https?://[^\s<>"]+', caseSensitive: false).allMatches(trimmed)) {
    // A sentence's full stop or closing bracket isn't part of the link.
    final link = _webLink(
      m
          .group(0)!
          .replaceFirst(
            RegExp(
              r'[.,;:!?)\]}>'
              "'"
              r']+$',
            ),
            '',
          ),
    );
    if (link != null) return link;
  }
  return null;
}

/// [text] is a link and nothing else (the card then says "sent a link").
bool isOnlyLink(String text) {
  final trimmed = text.trim();
  final link = linkIn(trimmed);
  return link != null && !trimmed.contains(RegExp(r'\s'));
}

Uri? _webLink(String s) {
  final uri = Uri.tryParse(s);
  if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) return null;
  if (uri.host.isEmpty || !uri.host.contains('.') && uri.host != 'localhost') return null;
  return uri;
}
