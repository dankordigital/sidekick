/// What each paired device and this one sent each other: the Chat tab's
/// list (Sidekick 4.0). Files, photos and videos, links and notes, newest
/// last, saved as JSON in the app's own folder and capped per device.
/// "Chat isn't a messaging app" (the owner's call): it's one place per
/// device for everything shared, not a conversation.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'text_message.dart';

/// What a [HistoryItem] is, for its card and the Chat tab's filters.
enum HistoryKind { file, photo, video, link, note }

/// One thing sent or received.
class HistoryItem {
  HistoryItem({
    required this.id,
    required this.device,
    required this.kind,
    required this.fromMe,
    required this.at,
    this.name,
    this.size,
    this.path,
    this.text,
  });

  /// A file sent or received with [device]: a photo or video by its name.
  factory HistoryItem.file({
    required String device,
    required bool fromMe,
    required String name,
    int? size,
    String? path,
    DateTime? at,
  }) => HistoryItem(
    id: newHistoryId(),
    device: device,
    kind: historyKindOf(name),
    fromMe: fromMe,
    at: at ?? DateTime.now(),
    name: name,
    size: size,
    path: path,
  );

  /// A link (the whole text is one web address) or a note.
  factory HistoryItem.text({required String device, required bool fromMe, required String text, DateTime? at}) =>
      HistoryItem(
        id: newHistoryId(),
        device: device,
        kind: isOnlyLink(text) ? HistoryKind.link : HistoryKind.note,
        fromMe: fromMe,
        at: at ?? DateTime.now(),
        text: text,
      );

  final String id;

  /// The paired device's id.
  final String device;
  final HistoryKind kind;

  /// This device sent it (else it came from [device]).
  final bool fromMe;
  final DateTime at;

  /// A file's name, its size in bytes and where it is on this device (a
  /// received file; null when it was sent from elsewhere or went to Photos).
  final String? name;
  final int? size;
  String? path;

  /// A link's or note's text.
  final String? text;

  /// A 6-digit verification code in a received note, for Copy code.
  String? get code => !fromMe && kind == HistoryKind.note ? sixDigitCode(text ?? '') : null;

  Map<String, Object?> toJson() => {
    'id': id,
    'device': device,
    'kind': kind.name,
    'fromMe': fromMe,
    'at': at.millisecondsSinceEpoch,
    if (name != null) 'name': name,
    if (size != null) 'size': size,
    if (path != null) 'path': path,
    if (text != null) 'text': text,
  };

  static HistoryItem? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['id'], device = json['device'], at = json['at'];
    final kind = HistoryKind.values.asNameMap()[json['kind']];
    if (id is! String || device is! String || at is! int || kind == null) return null;
    return HistoryItem(
      id: id,
      device: device,
      kind: kind,
      fromMe: json['fromMe'] == true,
      at: DateTime.fromMillisecondsSinceEpoch(at),
      name: json['name'] as String?,
      size: json['size'] as int?,
      path: json['path'] as String?,
      text: json['text'] as String?,
    );
  }
}

var _counter = 0;

/// A new item id: unique on this device.
String newHistoryId() => '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}-${(_counter++).toRadixString(36)}';

const _photos = {'jpg', 'jpeg', 'png', 'heic', 'heif', 'gif', 'webp', 'bmp', 'tif', 'tiff', 'dng', 'avif'};
const _videos = {'mov', 'mp4', 'm4v', 'avi', 'mkv', 'webm', '3gp', 'hevc'};

/// Photo, video or any other file, by its name.
HistoryKind historyKindOf(String name) {
  final dot = name.lastIndexOf('.');
  final ext = dot < 0 ? '' : name.substring(dot + 1).toLowerCase();
  if (_photos.contains(ext)) return HistoryKind.photo;
  if (_videos.contains(ext)) return HistoryKind.video;
  return HistoryKind.file;
}

/// The 6-digit verification code in [text], if it is one (the owner's call:
/// only 6-digit codes get the big Copy code button): the whole text ("482913"
/// or "482 913"), or a message that says it's a code ("Your Google
/// verification code is 482913", "G-482913 is your Google code", "Kod BLIK
/// 123456"). Never 4- or 8-digit numbers, phone numbers or order numbers.
String? sixDigitCode(String text) {
  final t = text.trim();
  final whole = RegExp(r'^\d{3}[ -]?\d{3}$');
  if (whole.hasMatch(t)) return t.replaceAll(RegExp(r'[ -]'), '');
  if (!RegExp(r'(\bcode|verif|one[- ]?time|\botp\b|passcode|\bkod)', caseSensitive: false).hasMatch(t)) return null;
  final m = RegExp(r'(?<!\d[ -]?)(\d{3}[ -]?\d{3})(?![ -]?\d)').firstMatch(t);
  return m?.group(1)?.replaceAll(RegExp(r'[ -]'), '');
}

/// Everything shared with each paired device, saved to [file].
class History {
  History(this.file);

  /// Where it's kept (`history.json` in the app's own folder). Null keeps
  /// it in memory only (tests, the website's demo).
  final File? file;

  /// The most kept per device; the oldest go first.
  static const perDevice = 500;

  final Map<String, List<HistoryItem>> _byDevice = {};
  final _changes = StreamController<String>.broadcast();
  Timer? _saveSoon;

  /// The id of the device whose list changed.
  Stream<String> get changes => _changes.stream;

  /// What [device] and this one shared, oldest first.
  List<HistoryItem> forDevice(String device) => List.unmodifiable(_byDevice[device] ?? const <HistoryItem>[]);

  /// The newest item with [device], for the device lists ("You sent …").
  HistoryItem? last(String device) => _byDevice[device]?.lastOrNull;

  void add(HistoryItem item) {
    final list = _byDevice.putIfAbsent(item.device, () => []);
    list.add(item);
    if (list.length > perDevice) list.removeRange(0, list.length - perDevice);
    _changed(item.device);
  }

  /// Takes one item off the list ("Remove from this list"): never the file.
  bool remove(String device, String id) {
    final list = _byDevice[device];
    final before = list?.length ?? 0;
    list?.removeWhere((i) => i.id == id);
    if ((list?.length ?? 0) == before) return false;
    _changed(device);
    return true;
  }

  /// Forgets everything with [device] (it was unpaired).
  void forget(String device) {
    if (_byDevice.remove(device) != null) _changed(device);
  }

  void _changed(String device) {
    _changes.add(device);
    _saveSoon?.cancel();
    _saveSoon = Timer(const Duration(milliseconds: 400), () => unawaited(save()));
  }

  Future<void> load() async {
    final f = file;
    if (f == null || !await f.exists()) return;
    try {
      final json = jsonDecode(await f.readAsString());
      if (json is! List) return;
      _byDevice.clear();
      for (final j in json) {
        final item = HistoryItem.fromJson(j);
        if (item != null) _byDevice.putIfAbsent(item.device, () => []).add(item);
      }
      for (final list in _byDevice.values) {
        list.sort((a, b) => a.at.compareTo(b.at));
      }
    } catch (_) {
      // A damaged file starts the history over rather than stopping the app.
    }
  }

  Future<void> save() async {
    _saveSoon?.cancel();
    final f = file;
    if (f == null) return;
    final all = [for (final list in _byDevice.values) ...list.map((i) => i.toJson())];
    final tmp = File('${f.path}.tmp');
    await tmp.parent.create(recursive: true);
    await tmp.writeAsString(jsonEncode(all), flush: true);
    await tmp.rename(f.path);
  }

  Future<void> dispose() async {
    if (_saveSoon?.isActive ?? false) await save();
    await _changes.close();
  }
}

/// The one-time code in a phone notification ("Your code is 482913",
/// "G-482913 is your Google verification code", "Kod: 4821"), or null when
/// it doesn't look like one. Sidekick passes on only this, never the rest of
/// the message (the owner's call, 4.0).
String? verificationCode(String text) {
  final t = text.replaceAll('\n', ' ');
  if (!RegExp(
    r'(\bcodes?\b|verif|one[- ]?time|\botp\b|passcode|\bpin\b|2fa|two[- ]factor|security code|\bkod|\bcódigo|\bcode\b)',
    caseSensitive: false,
  ).hasMatch(t)) {
    return null;
  }
  // 4 to 8 digits, maybe split in two by a space or dash ("482 913"), not
  // part of a longer number (a phone number, an amount, a date).
  final m = RegExp(r'(?<![\d.,:/])(\d{3,4}[ -]\d{3,4}|\d{4,8})(?![\d,:/]|[.]\d)')
      .firstMatch(t.replaceAll(RegExp(r'\b[A-Z]-(?=\d)'), ' '));
  return m?.group(1)?.replaceAll(RegExp(r'[ -]'), '');
}
