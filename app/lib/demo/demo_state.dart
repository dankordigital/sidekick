part of '../app_state.dart';

// The website's preview (getsidekick.app/preview.html): the real app,
// compiled for a browser, once as a Mac and once as an iPhone, side by side
// on one page. A browser has no network server, Bluetooth or file system, so
// [DemoAppState] stands in for those: the two copies talk through [DemoLink]
// (the page passes messages between them), and each keeps a few sample
// files. Everything on screen is the app's own: its screens, cards, sounds
// and notices. See lib/demo/preview_main.dart.

/// The other copy of the app on the preview page.
abstract class DemoLink {
  void send(Map<String, Object?> message);
  Stream<Map<String, Object?>> get messages;
}

/// A file picked in the preview: a name and a size, no contents.
class DemoFile implements File {
  DemoFile(this.path, this.size);

  @override
  final String path;
  final int size;

  @override
  Future<int> length() async => size;

  @override
  int lengthSync() => size;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// One of the two devices on the preview page.
class DemoAppState extends AppState {
  DemoAppState._(super.prefs, this.link, this.platform) : super._();

  final DemoLink link;
  final DevicePlatform platform;

  static const _macId = 'demo-macbook-pro';
  static const _iphoneId = 'demo-iphone-17-pro';

  bool get _isPhone => platform == DevicePlatform.ios;

  /// The other device, as this one knows it.
  late final PairedDevice _peer;
  late final TrustedPeer _peerAsTrusted;

  /// This device's files, by folder, for the other one to browse.
  final Map<String, List<RemoteEntry>> _tree = {};
  late final String _home;
  late final List<RemoteEntry> _roots;

  final Map<String, Completer<Map<String, Object?>>> _waiting = {};
  final Map<String, TransferOffer> _incoming = {};
  int _nextId = 0;

  static Future<DemoAppState> create(DevicePlatform platform, DemoLink link) async {
    final phone = platform == DevicePlatform.ios;
    // Each copy keeps its settings apart (both share the page's storage),
    // and starts fresh every time the page opens.
    SharedPreferences.setPrefix('sidekick-preview-${platform.name}.');
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    await prefs.setString('id', phone ? _iphoneId : _macId);
    await prefs.setString('name', phone ? 'iPhone 17 Pro' : 'MacBook Pro');
    await prefs.setBool('welcomed', true);
    await prefs.setBool('iphoneRemoteNotice', true);
    await prefs.setString(
      'receiveDir',
      phone
          ? '/var/mobile/Containers/Data/Application/5C1F2E8A-3D4B-4E7A-9C61-0B8D2F47A913/Documents'
          : '/Users/sam/Downloads/Sidekick',
    );
    final state = DemoAppState._(prefs, link, platform);
    state._restore();
    state.secrets = SecretStore(state._prefs);
    state.identity = Identity.generate();
    state._peer = PairedDevice(
      id: phone ? _macId : _iphoneId,
      name: phone ? 'MacBook Pro' : 'iPhone 17 Pro',
      platform: phone ? DevicePlatform.macos : DevicePlatform.ios,
      token: 'demo',
      fingerprint: phone
          ? 'a3f1c2d4e5b6978899aabbccddeeff00112233445566778899aabbccddeeff01'
          : 'b7e2d3c4a5f6071829a3b4c5d6e7f8091a2b3c4d5e6f708192a3b4c5d6e7f809',
      key: base64.encode(List.filled(32, 7)),
      lastAddress: phone ? '192.168.1.24' : '192.168.1.31',
    );
    state._peerAsTrusted = TrustedPeer(
      id: state._peer.id,
      name: state._peer.name,
      platform: state._peer.platform,
      token: 'demo',
      fingerprint: state._peer.fingerprint,
      key: state._peer.key,
    );
    state._paired[state._peer.id] = state._peer;
    state.trust.add(state._peerAsTrusted);
    state._plantFiles();
    return state;
  }

  // ---------------------------------------------------------------- this device

  @override
  DeviceInfo get me => DeviceInfo(
    id: id,
    name: name,
    platform: platform,
    port: sidekickPort,
    fingerprint: identity.fingerprint,
    app: appVersion.isEmpty ? null : appVersion,
    wifi: true,
    capabilities: Capabilities(files: permissions.files, input: permissions.input && !_isPhone),
  );

  @override
  Future<void> start() async {
    try {
      appVersion = (await PackageInfo.fromPlatform()).version;
    } catch (_) {}
    files = FileService(home: _home);
    server = SidekickServer(
      identity: identity,
      self: () => me,
      trust: trust,
      files: files,
      input: input,
      receiveDir: receiveDir,
      permissions: () => permissions,
      inputReady: () async => true,
      askBeforeReceiving: asksBeforeReceivingFrom,
      ringing: () => ringingFrom != null,
    );
    addresses = [_isPhone ? '192.168.1.31' : '192.168.1.24'];
    lan = addresses;
    wifiConnected = true;
    link.messages.listen(_onMessage);
    notifyListeners();
  }

  @override
  Future<String> receiveDir() async => _receiveDir ?? _home;

  // The other device is always on this Wi-Fi, a few metres away.
  @override
  bool _onLan(String id) => _paired.containsKey(id);

  @override
  bool _viaP2p(String id) => false;

  @override
  Capabilities? capabilitiesOf(String id) => id == _peer.id
      ? Capabilities(files: true, input: _peer.platform != DevicePlatform.ios)
      : super.capabilitiesOf(id);

  @override
  PeerClient clientFor(PairedDevice d) => _DemoClient(this, d);

  @override
  Future<bool> connectDirect(PairedDevice d) async => true;

  @override
  Future<bool> openQrNetwork() async => false;

  @override
  void closeQrNetwork() {}

  @override
  Future<void> resumed() async {}

  @override
  Future<void> refreshPlatform() async {}

  @override
  Future<bool> _inputReady() async => true;

  // Looks a moment, like the real scan, and finds nothing new.
  @override
  Future<void> scanNetwork() async {
    if (scanning) return;
    scanning = true;
    notifyListeners();
    await Future<void>.delayed(const Duration(seconds: 3));
    scanning = false;
    notifyListeners();
  }

  @override
  Future<DeviceInfo> addByAddress(String input) async {
    await Future<void>.delayed(const Duration(seconds: 2));
    throw SidekickException(
      "Couldn't reach ${input.trim()}. Check that Sidekick is open on it and that it's on the same Wi-Fi.",
    );
  }

  @override
  Future<void> requestPairing(DeviceInfo target) async =>
      throw SidekickException('This is a preview: ${_peer.name} is already paired.');

  @override
  Future<PairedDevice> pairWithInvite(InviteQr qr) async =>
      throw SidekickException('This is a preview: ${_peer.name} is already paired.');

  // Settings that would change the computer or phone itself: only the switch.
  @override
  Future<void> setBluetooth(bool on) async {
    bluetoothOn = on;
    await _prefs.setBool('bluetooth', on);
    notifyListeners();
  }

  @override
  void setAutoLoad(bool value) {
    autoLoad = value;
    notifyListeners();
  }

  @override
  void setKeepRunning(bool value) {
    keepRunning = value;
    notifyListeners();
  }

  @override
  Future<void> setRelayNotifications(bool value) async {
    relayNotifications = value;
    notifyListeners();
  }

  @override
  Future<void> setSendScreenshots(bool value) async {
    sendScreenshots = value;
    notifyListeners();
  }

  @override
  void setName(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return;
    name = trimmed.length > 40 ? trimmed.substring(0, 40) : trimmed;
    link.send({'t': 'name', 'name': name});
    notifyListeners();
  }

  @override
  Future<void> unpair(String deviceId) async {
    if (deviceId == _peer.id) link.send({'t': 'unpaired'});
    _paired.remove(deviceId);
    trust.remove(deviceId);
    notifyListeners();
  }

  // ---------------------------------------------------------------- ping

  @override
  Future<bool> ping(PairedDevice d) async {
    final reply = await _ask({'t': 'ping'});
    if (reply['busy'] == true) return false;
    _notices.add(Notice('Pinging ${d.name}'));
    return true;
  }

  // ---------------------------------------------------------------- sending

  @override
  Future<void> sendFiles(PairedDevice d, List<File> localFiles, {String? remoteDir}) async {
    if (localFiles.isEmpty) return;
    final sizes = [for (final f in localFiles) await f.length()];
    final total = sizes.fold(0, (a, b) => a + b);
    final names = [for (final f in localFiles) p.basename(f.path)];
    final what = localFiles.length == 1 ? names.first : '${localFiles.length} files';
    if (remoteDir != null) _notices.add(Notice('Sending $what to ${d.name}…'));
    final send = OutgoingSend(device: d, names: names, total: total);
    if (remoteDir == null) _sends.add(send);
    final offerId = 'o${_nextId++}';

    if (remoteDir == null) {
      send._set(SendPhase.waiting);
      send._cancelOffer = () async => link.send({'t': 'cancel', 'id': offerId});
      final Map<String, Object?> reply;
      try {
        reply = await _ask({
          't': 'offer',
          'id': offerId,
          'files': [
            for (var i = 0; i < names.length; i++) [names[i], sizes[i]],
          ],
        }, timeout: const Duration(minutes: 2));
      } catch (_) {
        send._set(SendPhase.noAnswer);
        _notices.add(Notice('No answer from ${d.name}. Nothing was sent.'));
        return;
      }
      final answer = reply['answer'];
      if (send.cancelled || answer == 'cancelled') {
        send._set(SendPhase.failed, error: 'Cancelled');
        return;
      }
      if (answer != 'accepted') {
        final declined = answer == 'declined';
        if (declined && sound) unawaited(playDeclineSound());
        send._set(declined ? SendPhase.declined : SendPhase.noAnswer);
        _notices.add(Notice(declined ? '${d.name} declined $what' : 'No answer from ${d.name}. Nothing was sent.'));
        return;
      }
      if (sound) unawaited(playAcceptSound());
      send._set(SendPhase.sending);
    }

    // Wi-Fi speed, but never so fast the progress can't be seen.
    final ms = (total / 40e6 * 1000).clamp(1500, 4000).round();
    final start = DateTime.now();
    var before = 0;
    for (var i = 0; i < names.length; i++) {
      final t = _startTransfer(names[i], d, upload: true);
      send
        ..current = i
        .._progress(before);
      final share = total == 0 ? 1 / names.length : sizes[i] / total;
      final fileMs = (ms * share).round().clamp(200, ms);
      final fileStart = DateTime.now();
      while (true) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        final f = (DateTime.now().difference(fileStart).inMilliseconds / fileMs).clamp(0.0, 1.0);
        final bytes = (sizes[i] * f).round();
        _progress(t, bytes, sizes[i]);
        send._progress(before + bytes);
        link.send({'t': 'progress', 'id': offerId, 'bytes': before + bytes});
        if (f >= 1) break;
      }
      t
        ..state = TransferState.done
        ..security = TransferSecurity.wifi(certificate: _peer.fingerprint);
      before += sizes[i];
      link.send({'t': 'fileDone', 'id': offerId, 'name': names[i], 'size': sizes[i], 'dir': remoteDir});
      notifyListeners();
    }
    debugPrint('Sidekick preview: sent $what in ${DateTime.now().difference(start).inMilliseconds} ms');
    send._set(SendPhase.done);
    _notices.add(Notice('Sent $what to ${d.name}'));
  }

  // ---------------------------------------------------------------- downloading

  @override
  Future<File?> download(PairedDevice d, RemoteEntry entry) async {
    final t = _startTransfer(entry.name, d, upload: false);
    final ms = (entry.size / 40e6 * 1000).clamp(600, 3000).round();
    final start = DateTime.now();
    while (true) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      final f = (DateTime.now().difference(start).inMilliseconds / ms).clamp(0.0, 1.0);
      _progress(t, (entry.size * f).round(), entry.size);
      if (f >= 1) break;
    }
    final dir = await receiveDir();
    final path = p.join(dir, entry.name);
    t
      ..state = TransferState.done
      ..security = TransferSecurity.wifi(certificate: _peer.fingerprint)
      ..localPath = path;
    notifyListeners();
    final file = DemoFile(path, entry.size);
    if (_isPhone && Gallery.kindOf(entry.name, android: false) != null) {
      t
        ..localPath = null
        ..inGallery = true;
      _notices.add(Notice('Saved ${entry.name}. It\'s in ${Gallery.name}.', inGallery: true));
    } else {
      _addFile(dir, entry.name, entry.size);
      _notices.add(Notice('Saved ${entry.name}'));
    }
    return file;
  }

  // ---------------------------------------------------------------- the other device's messages

  /// Sends [message] and waits for the other device's reply.
  Future<Map<String, Object?>> _ask(Map<String, Object?> message, {Duration timeout = const Duration(seconds: 8)}) {
    final id = message['id'] as String? ?? 'q${_nextId++}';
    final waiting = _waiting[id] = Completer<Map<String, Object?>>();
    link.send({...message, 'id': id, 'ask': true});
    return waiting.future.timeout(timeout, onTimeout: () => throw SidekickException("${_peer.name} didn't answer."))
      ..whenComplete(() => _waiting.remove(id)).ignore();
  }

  void _reply(Map<String, Object?> to, Map<String, Object?> answer) =>
      link.send({...answer, 't': 'reply', 'id': to['id']});

  void _onMessage(Map<String, Object?> m) {
    switch (m['t']) {
      case 'reply':
        _waiting.remove(m['id'])?.complete(m);
      case 'ping':
        final busy = ringingFrom != null;
        if (!busy) {
          ringingFrom = _peerAsTrusted;
          unawaited(startPingRingtone());
          _pings.add(_peerAsTrusted);
          notifyListeners();
        }
        _reply(m, {'busy': busy});
      case 'offer':
        final offer = TransferOffer(
          id: m['id']! as String,
          from: _peerAsTrusted,
          files: [for (final f in m['files']! as List) OfferedFile((f as List)[0] as String, (f[1] as num).toInt())],
        );
        _incoming[offer.id] = offer;
        final ask = asksBeforeReceivingFrom(offer.from.id);
        if (!ask) offer.accept();
        unawaited(
          offer.answer.then(
            (a) => _reply(m, {
              'answer': switch (a) {
                OfferAnswer.accepted => 'accepted',
                OfferAnswer.declined => 'declined',
                OfferAnswer.cancelled => 'cancelled',
                OfferAnswer.timedOut => 'timedOut',
              },
            }),
          ),
        );
        if (ask) _offers.add(offer);
      case 'cancel':
        _incoming.remove(m['id'])?.decline();
      case 'progress':
        final offer = _incoming[m['id']];
        if (offer != null) {
          final bytes = (m['bytes']! as num).toInt();
          if (bytes > offer.received) offer.debugReceived(bytes - offer.received);
        }
      case 'fileDone':
        _received(m);
      case 'roots':
        _reply(m, {
          'entries': [for (final e in _roots) e.toJson()],
        });
      case 'list':
        final path = m['path']! as String;
        final entries = _tree[path];
        _reply(
          m,
          entries == null
              ? {'error': "That folder isn't there any more."}
              : {
                  'entries': [for (final e in entries) e.toJson()],
                },
        );
      case 'remote':
        if (m['active'] == true) {
          activeRemoteSessions[_peer.id] = _peerAsTrusted;
        } else {
          activeRemoteSessions.remove(_peer.id);
        }
        notifyListeners();
      case 'name':
        _peer.name = m['name']! as String;
        _peerAsTrusted.name = _peer.name;
        notifyListeners();
      case 'unpaired':
        final name = _paired.remove(_peer.id)?.name;
        notifyListeners();
        if (name != null) _notices.add(Notice('$name unpaired from this device'));
    }
  }

  /// A file came in: into the receive folder (and Photos on the iPhone), or
  /// into the folder the other device uploaded it to.
  void _received(Map<String, Object?> m) {
    final name = m['name']! as String;
    final size = (m['size']! as num).toInt();
    final dir = m['dir'] as String?;
    final offer = _incoming[m['id']];
    offer?.debugReceived(size, fileDone: true);
    if (offer != null && offer.complete) _incoming.remove(offer.id);
    final folder = dir ?? _receiveDir ?? _home;
    final path = p.join(folder, name);
    final transfer = Transfer(name: name, upload: false, deviceName: _peer.name)
      ..done = size
      ..total = size
      ..state = TransferState.done
      ..received = true
      ..security = TransferSecurity.wifi(certificate: _peer.fingerprint)
      ..peerFingerprint = _peer.fingerprint
      ..localPath = path;
    transfers.insert(0, transfer);
    notifyListeners();
    if (dir == null && _isPhone && Gallery.kindOf(name, android: false) != null) {
      transfer
        ..localPath = null
        ..inGallery = true;
      _notices.add(Notice('Received $name from ${_peer.name}. It\'s in ${Gallery.name}.', inGallery: true));
    } else {
      _addFile(folder, name, size);
      _notices.add(Notice('Received $name from ${_peer.name}', revealPath: path));
    }
  }

  // ---------------------------------------------------------------- sample files

  void _plantFiles() {
    final now = DateTime.now();
    DateTime days(int n) => now.subtract(Duration(days: n));
    RemoteEntry dir(String parent, String name) => RemoteEntry(name: name, path: p.join(parent, name), isDir: true);
    RemoteEntry file(String parent, String name, int size, int age) =>
        RemoteEntry(name: name, path: p.join(parent, name), isDir: false, size: size, modified: days(age));
    if (_isPhone) {
      _home = '/var/mobile/Containers/Data/Application/5C1F2E8A-3D4B-4E7A-9C61-0B8D2F47A913/Documents';
      _roots = [RemoteEntry(name: 'Sidekick files', path: _home, isDir: true)];
      _tree[_home] = [
        dir(_home, 'Received'),
        file(_home, 'Boarding pass.pdf', 240000, 2),
        file(_home, 'Voice memo.m4a', 1200000, 5),
      ];
      _tree[p.join(_home, 'Received')] = [
        file(p.join(_home, 'Received'), 'Slides.key', 8400000, 9),
        file(p.join(_home, 'Received'), 'Notes.txt', 4200, 12),
      ];
    } else {
      _home = '/Users/sam';
      final folders = ['Desktop', 'Documents', 'Downloads', 'Pictures', 'Music'];
      _roots = [
        for (final f in folders) dir(_home, f),
        RemoteEntry(name: 'Home', path: _home, isDir: true),
        const RemoteEntry(name: '/', path: '/', isDir: true),
      ];
      _tree['/'] = [dir('/', 'Applications'), dir('/', 'Library'), dir('/', 'System'), dir('/', 'Users')];
      _tree['/Applications'] = [dir('/Applications', 'Sidekick.app'), dir('/Applications', 'Safari.app')];
      _tree['/Library'] = [];
      _tree['/System'] = [];
      _tree['/Users'] = [dir('/Users', 'sam'), dir('/Users', 'Shared')];
      _tree['/Users/Shared'] = [];
      _tree[_home] = [for (final f in folders) dir(_home, f), dir(_home, 'Movies')];
      final desk = p.join(_home, 'Desktop'), docs = p.join(_home, 'Documents'), down = p.join(_home, 'Downloads');
      _tree[desk] = [file(desk, 'Invoice_0923.pdf', 182000, 1), file(desk, 'Notes.txt', 4200, 3)];
      _tree[docs] = [
        dir(docs, 'School'),
        file(docs, 'Budget 2026.numbers', 512000, 6),
        file(docs, 'Trip plan.pages', 1340000, 14),
      ];
      _tree[p.join(docs, 'School')] = [file(p.join(docs, 'School'), 'Essay.docx', 86000, 4)];
      _tree[down] = [dir(down, 'Sidekick'), file(down, 'Holiday_2026.mp4', 212000000, 2)];
      _tree[p.join(down, 'Sidekick')] = [];
      _tree[p.join(_home, 'Pictures')] = [
        file(p.join(_home, 'Pictures'), 'IMG_1988.HEIC', 2800000, 3),
        file(p.join(_home, 'Pictures'), 'Sunset.jpg', 4100000, 20),
      ];
      _tree[p.join(_home, 'Music')] = [];
      _tree[p.join(_home, 'Movies')] = [];
    }
  }

  void _addFile(String folder, String name, int size) {
    final list = _tree.putIfAbsent(folder, () => []);
    list
      ..removeWhere((e) => e.name == name)
      ..add(RemoteEntry(name: name, path: p.join(folder, name), isDir: false, size: size, modified: DateTime.now()))
      ..sort((a, b) {
        if (a.isDir != b.isDir) return a.isDir ? -1 : 1;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
  }

  /// Sample files to send (the browser can't hand over real ones): photos
  /// and a video, or a document.
  Future<List<File>> pickSamples({required bool media}) async => media
      ? [DemoFile('IMG_2041.HEIC', 3200000), DemoFile('IMG_2042.HEIC', 2900000), DemoFile('Trip.mov', 41000000)]
      : [DemoFile(_isPhone ? 'Boarding pass.pdf' : 'Invoice_0923.pdf', _isPhone ? 240000 : 182000)];
}

/// Requests to the other device on the page: its files, remote control,
/// unpairing.
class _DemoClient extends PeerClient {
  _DemoClient(this._state, PairedDevice d)
    : super(host: d.lastAddress ?? '', port: d.lastPort, token: d.token, fingerprint: d.fingerprint) {
    lastSecurity = TransferSecurity.wifi(certificate: d.fingerprint);
  }

  final DemoAppState _state;

  List<RemoteEntry> _entries(Map<String, Object?> reply) {
    if (reply['error'] case final String why) throw SidekickException(why);
    return [for (final e in reply['entries']! as List) RemoteEntry.fromJson((e as Map).cast<String, dynamic>())];
  }

  @override
  Future<List<RemoteEntry>> roots() async => _entries(await _state._ask({'t': 'roots'}));

  @override
  Future<List<RemoteEntry>> list(String path) async => _entries(await _state._ask({'t': 'list', 'path': path}));

  @override
  Future<void> unpair() async {}

  @override
  Future<DeviceInfo> info({Duration timeout = const Duration(seconds: 3)}) async => DeviceInfo(
    id: _state._peer.id,
    name: _state._peer.name,
    platform: _state._peer.platform,
    port: sidekickPort,
    address: _state._peer.lastAddress,
    fingerprint: _state._peer.fingerprint,
    app: _state.appVersion,
    wifi: true,
  );

  @override
  Future<InputSession> openInput() async {
    _state.link.send({'t': 'remote', 'active': true});
    return InputSession.custom(
      send: (message) => _state.link.send({'t': 'input', 'msg': message}),
      onClose: () async => _state.link.send({'t': 'remote', 'active': false}),
    );
  }
}
