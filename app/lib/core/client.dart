import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:web_socket_channel/io.dart';

import '../platform/hotspot.dart';
import 'ble_protocol.dart';
import 'crypto.dart';
import 'models.dart';
import 'trust.dart';

/// The other device's answer to [PeerClient.offerFiles].
class OfferReply {
  const OfferReply({required this.accepted, required this.answer, this.ticket});
  final bool accepted;

  /// accepted, declined, cancelled or timedOut.
  final String answer;
  final String? ticket;
}

class SidekickException implements Exception {
  SidekickException(this.message, {this.status, this.identityChanged = false, this.connectionLost = false});
  final String message;
  final int? status;

  /// The other device stopped answering (Wi-Fi blinked, it slept, it moved
  /// to another network): worth trying again once it's back.
  final bool connectionLost;

  /// The device presented a different certificate than it paired with (it
  /// was reset or reinstalled): it has to be paired again.
  final bool identityChanged;

  bool get notPaired => status == 401;

  @override
  String toString() => message;
}

/// Progress callback for transfers: bytes done out of [total] (0 if unknown).
typedef Progress = void Function(int done, int total);

/// A device we're about to pair with: who it is and which certificate it
/// showed us.
typedef PairingTarget = ({DeviceInfo device, String fingerprint});

/// Talks to one remote Sidekick device, over Wi-Fi (HTTPS) or, when there's
/// no shared network, over Bluetooth ([ble]).
///
/// With a [fingerprint], only a server presenting exactly that certificate
/// is accepted. Without one (before pairing) any certificate is accepted,
/// and pairing proves which one was real.
class PeerClient {
  PeerClient({required this.host, this.port = sidekickPort, this.token, this.fingerprint, this.ble, this.seal});

  /// Same API over a Bluetooth connection. Slower, and no remote control.
  /// Paired requests are sealed with [seal].
  PeerClient.bluetooth(BleRpcClient this.ble, {this.token, this.seal})
    : host = 'bluetooth',
      port = 0,
      fingerprint = null;

  /// No address known yet: requests fail with "not reachable" (see [_send]).
  factory PeerClient.forDevice(PairedDevice device) => PeerClient(
    host: device.lastAddress ?? '',
    port: device.lastPort,
    token: device.token,
    fingerprint: device.fingerprint,
  );

  final String host;
  final int port;
  final String? token;
  final String? fingerprint;
  final BleRpcClient? ble;
  final BleSeal? seal;

  bool get viaBluetooth => ble != null;

  /// How the last successful request was protected: the certificate the
  /// device presented over Wi-Fi, or Bluetooth sealing. Null until a request
  /// succeeds (and over Bluetooth before pairing, which isn't sealed).
  TransferSecurity? lastSecurity;

  void _noteTls(HttpClientResponse res) {
    final cert = res.certificate;
    if (cert != null) lastSecurity = TransferSecurity.wifi(certificate: fingerprintOf(cert.der));
  }

  /// The IP address to remember for this device (none over Bluetooth).
  String? get _address => ble == null ? host : null;

  static final Map<String, HttpClient> _clients = {};

  /// One HTTP client per pinned certificate (and one that accepts any, for
  /// discovery and pairing).
  HttpClient get _http => _clients.putIfAbsent(fingerprint ?? '', () {
    final pin = fingerprint;
    return HttpClient(context: SecurityContext(withTrustedRoots: false))
      ..connectionTimeout = const Duration(seconds: 4)
      ..idleTimeout = const Duration(seconds: 15)
      ..badCertificateCallback = (cert, _, _) => pin == null || fingerprintOf(cert.der) == pin;
  });

  Uri _uri(String path, [Map<String, String>? query]) =>
      Uri(scheme: 'https', host: host, port: port, path: path, queryParameters: query);

  SidekickException _tlsFailure() => fingerprint == null
      ? SidekickException("Couldn't connect securely to $host. Make sure both devices run Sidekick 0.3 or newer.")
      : SidekickException(
          "The other device has a new security key (it was reset or updated from 1.0.x). Pair it again.",
          identityChanged: true,
        );

  Future<HttpClientResponse> _send(
    String method,
    String path, {
    Map<String, String>? query,
    Object? json,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    if (host.isEmpty) throw _unreachable();
    try {
      // A connection kept from earlier can turn out dead (the other device
      // slept, its server restarted, Wi-Fi blinked): one more try on a fresh
      // one. Always for reads; for anything else only if the request never
      // went out, so nothing happens twice.
      for (var attempt = 0; ; attempt++) {
        var sent = false;
        try {
          final req = await _http.openUrl(method, _uri(path, query)).timeout(timeout);
          if (token != null) req.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
          if (json != null) {
            req.headers.contentType = ContentType.json;
            req.write(jsonEncode(json));
          }
          sent = true;
          final res = await req.close().timeout(timeout);
          if (res.statusCode >= 400) throw await _failure(res);
          _noteTls(res);
          return res;
        } on SocketException {
          if (attempt > 0 || (sent && method != 'GET')) rethrow;
        } on HttpException {
          if (attempt > 0 || (sent && method != 'GET')) rethrow;
        }
        await Future<void>.delayed(const Duration(milliseconds: 300));
      }
    } on HandshakeException {
      throw _tlsFailure();
    } on TlsException {
      throw _tlsFailure();
    } on SocketException {
      throw _unreachable();
    } on TimeoutException {
      throw _lost('The other device took too long to answer.');
    } on HttpException {
      throw _lost();
    }
  }

  static SidekickException _unreachable() => SidekickException(
    "Couldn't reach the other device. Make sure Sidekick is open on it and both are on the same Wi-Fi.",
    connectionLost: true,
  );

  static SidekickException _lost([String message = 'The connection to the other device dropped.']) =>
      SidekickException(message, connectionLost: true);

  static Future<SidekickException> _failure(HttpClientResponse res) async {
    var message = 'Request failed (${res.statusCode})';
    try {
      final body = jsonDecode(await utf8.decodeStream(res));
      if (body is Map && body['error'] is String) message = body['error'] as String;
    } catch (_) {}
    return SidekickException(message, status: res.statusCode);
  }

  Map<String, String> get _authHeaders => {if (token != null) 'authorization': 'Bearer $token'};

  /// A request over Bluetooth, with the same error handling as HTTP.
  Future<BleResponse> _bleSend(
    String method,
    String path, {
    Map<String, String>? query,
    List<int> body = const [],
    Map<String, String> headers = const {},
    Duration timeout = const Duration(seconds: 30),
    void Function(int sent, int total)? onSent,
  }) async {
    final BleResponse res;
    try {
      res = await ble!.request(
        method,
        path,
        query: query,
        headers: {..._authHeaders, ...headers},
        body: body,
        timeout: timeout,
        seal: seal,
        onSent: onSent,
      );
    } on TimeoutException {
      throw SidekickException('The device took too long to answer over Bluetooth.', connectionLost: true);
    } on StateError catch (e) {
      throw SidekickException(e.message);
    }
    // A success over a sealed link only completes if the reply decrypted
    // with our pairing key (see BleRpcClient).
    if (res.status < 400 && seal != null) lastSecurity = const TransferSecurity.bluetooth();
    if (res.status >= 400) {
      var message = 'Request failed (${res.status})';
      try {
        final json = jsonDecode(utf8.decode(res.body));
        if (json is Map && json['error'] is String) message = json['error'] as String;
      } catch (_) {}
      if (message == keysDontMatch) {
        // Only pairing again gives both devices the same key.
        throw SidekickException(
          "These two devices don't share the same pairing any more. Pair them again.",
          status: res.status,
          identityChanged: true,
        );
      }
      if (message == 'Message failed authentication') {
        message =
            "The other device couldn't verify what this device sent over Bluetooth. If this keeps happening, "
            'update Sidekick on both devices, or pair them again.';
      }
      throw SidekickException(message, status: res.status);
    }
    return res;
  }

  Future<dynamic> _getJson(String path, [Map<String, String>? query]) async {
    if (ble != null) return jsonDecode(utf8.decode((await _bleSend('GET', path, query: query)).body));
    final res = await _send('GET', path, query: query);
    return jsonDecode(await utf8.decodeStream(res));
  }

  Future<dynamic> _postJson(String path, Object body, {Duration timeout = const Duration(seconds: 30)}) async {
    if (ble != null) {
      final res = await _bleSend(
        'POST',
        path,
        body: utf8.encode(jsonEncode(body)),
        headers: {'content-type': 'application/json'},
        timeout: timeout,
      );
      return jsonDecode(utf8.decode(res.body));
    }
    final res = await _send('POST', path, json: body, timeout: timeout);
    return jsonDecode(await utf8.decodeStream(res));
  }

  // ------------------------------------------------------------ discovery

  /// Fetches the device's identity. Works without pairing.
  Future<DeviceInfo> info({Duration timeout = const Duration(seconds: 3)}) async {
    if (ble != null) {
      final res = await _bleSend('GET', '/v1/info', timeout: const Duration(seconds: 15));
      return DeviceInfo.fromJson(jsonDecode(utf8.decode(res.body)) as Map<String, dynamic>);
    }
    final res = await _send('GET', '/v1/info', timeout: timeout);
    final json = jsonDecode(await utf8.decodeStream(res)) as Map<String, dynamic>;
    return DeviceInfo.fromJson(json, address: host);
  }

  // ------------------------------------------------------------ pairing

  /// Asks the device to show a pairing code. Returns who it is and the
  /// certificate it presented.
  ///
  /// With [invite], we scanned its QR code: it shows no code, and pairing
  /// uses the QR code's secret.
  Future<PairingTarget> requestPairing(DeviceInfo me, {required String myFingerprint, bool invite = false}) async {
    Map<String, dynamic> json;
    String? seen;
    final body = {'device': me.toJson(), 'fingerprint': myFingerprint, if (invite) 'invite': true};
    if (ble != null) {
      json = await _postJson('/v1/pair/request', body) as Map<String, dynamic>;
    } else {
      final res = await _send('POST', '/v1/pair/request', json: body);
      seen = res.certificate == null ? null : fingerprintOf(res.certificate!.der);
      json = jsonDecode(await utf8.decodeStream(res)) as Map<String, dynamic>;
    }
    final claimed = json['fingerprint'];
    if (claimed is! String) throw SidekickException('Update Sidekick on the other device to pair with it.');
    // Over Wi-Fi the certificate we actually saw is what we pin; pairing
    // then proves the other side really has it.
    if (seen != null && seen != claimed) throw SidekickException('The connection was tampered with. Try again.');
    return (
      device: DeviceInfo.fromJson(json['device'] as Map<String, dynamic>, address: _address),
      fingerprint: claimed,
    );
  }

  /// Runs SPAKE2 with the code the user typed. On success returns a
  /// [PairedDevice] we can use to control them, and the token and key they
  /// use with us (`tokenForThem`, `key`), which the caller adds to its
  /// [TrustStore].
  Future<({PairedDevice device, String tokenForThem, String key})> confirmPairing({
    required String myId,
    required String myFingerprint,
    required PairingTarget target,
    required String pin,
  }) async {
    final context = pairingContext(
      idA: myId,
      fingerprintA: myFingerprint,
      idB: target.device.id,
      fingerprintB: target.fingerprint,
    );
    final spake = Spake2(isA: true, pin: pin.replaceAll(RegExp(r'\s'), ''), context: context);
    final start = await _postJson('/v1/pair/start', {'id': myId, 'msg': base64.encode(spake.message)}) as Map;
    final PairingKeys keys;
    try {
      keys = spake.finish(base64.decode(start['msg'] as String));
    } on FormatException {
      throw SidekickException('The other device sent a bad pairing message.');
    }
    final tokenForThem = newToken();
    final json = await _postJson('/v1/pair/confirm', {
      'id': myId,
      'confirm': confirmTag(keys.confirmA, context),
      'token': base64.encode(sealBytes(keys.linkKey, utf8.encode(tokenForThem), aad: utf8.encode('token A'))),
    }) as Map<String, dynamic>;
    // They must prove the same key too, or it's not really them.
    final theirConfirm = json['confirm'];
    if (theirConfirm is! String || !tagsEqual(confirmTag(keys.confirmB, context), theirConfirm)) {
      throw SidekickException("Couldn't verify the other device. Try pairing again.");
    }
    final String token;
    try {
      token = utf8.decode(unseal(keys.linkKey, base64.decode(json['token'] as String), aad: utf8.encode('token B')));
    } on FormatException {
      throw SidekickException("Couldn't verify the other device. Try pairing again.");
    }
    final info = DeviceInfo.fromJson(json['device'] as Map<String, dynamic>, address: _address);
    final key = base64.encode(keys.linkKey);
    return (
      device: PairedDevice(
        id: info.id,
        name: info.name,
        platform: info.platform,
        token: token,
        fingerprint: target.fingerprint,
        key: key,
        lastAddress: _address,
        lastPort: info.port,
      ),
      tokenForThem: tokenForThem,
      key: key,
    );
  }

  Future<void> unpair() => _postJson('/v1/unpair', const {});

  /// Makes the device ring until someone taps Found It on it (the Ping
  /// button). Throws a [SidekickException] with status 409 while it's
  /// already ringing.
  Future<void> ping() => _postJson('/v1/ping', const {});

  /// Shows a notification from this phone on the computer.
  Future<void> sendNotification({required String app, required String title, required String text}) =>
      _postJson('/v1/notification', {'app': app, 'title': title, 'text': text});

  /// Sends a screenshot this phone just took (Wi-Fi only: never worth
  /// Bluetooth's time).
  Future<void> sendScreenshot(File file, String name) async {
    if (ble != null) throw SidekickException('Screenshots go over Wi-Fi only.');
    final total = await file.length();
    try {
      final req = await _http.openUrl('POST', _uri('/v1/screenshot', {'name': name}));
      if (token != null) req.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      req.contentLength = total;
      await req.addStream(file.openRead());
      final res = await req.close();
      if (res.statusCode >= 400) throw await _failure(res);
      await res.drain<void>();
    } on HandshakeException {
      throw _tlsFailure();
    } on SocketException {
      throw _lost();
    }
  }

  // ------------------------------------------------------------ direct link

  /// Asks the device (over Bluetooth) to open a hotspot for us.
  Future<HotspotCredentials> startHotspot() async => HotspotCredentials.fromJson(
    await _postJson('/v1/link/hotspot', const {}, timeout: const Duration(seconds: 40)) as Map<String, dynamic>,
  );

  /// Asks the device (over Bluetooth) to join our hotspot. Returns our
  /// addresses it can reach.
  Future<List<String>> joinHotspot(HotspotCredentials creds) async {
    // Long enough for an iPhone user to join it in Settings (JoinByHand).
    final json = await _postJson('/v1/link/join', creds.toJson(), timeout: const Duration(minutes: 3)) as Map;
    return [for (final a in (json['addresses'] as List?) ?? const []) '$a'];
  }

  /// Tells the device we're done with the direct link.
  Future<void> releaseLink() => _postJson('/v1/link/release', const {}, timeout: const Duration(seconds: 5));

  // ------------------------------------------------------------ files

  Future<List<RemoteEntry>> roots() async =>
      (await _getJson('/v1/fs/roots') as List).map((e) => RemoteEntry.fromJson(e as Map<String, dynamic>)).toList();

  Future<List<RemoteEntry>> list(String path) async => (await _getJson('/v1/fs/list', {'path': path}) as List)
      .map((e) => RemoteEntry.fromJson(e as Map<String, dynamic>))
      .toList();

  /// Makes a folder [name] inside [parent] on the other device.
  Future<void> makeFolder(String parent, String name) => _postJson('/v1/fs/mkdir', {'path': parent, 'name': name});

  /// Downloads [remotePath] into [destination]. The file is written under a
  /// temporary name and only renamed once complete.
  ///
  /// With [resume], a download cut off by a dropped connection keeps what
  /// arrived, and the next call for the same [destination] asks only for
  /// the rest (Sidekick 3.0 and later; older ones send it all again).
  Future<File> download(String remotePath, File destination, {Progress? onProgress, bool resume = false}) async {
    final partial = File('${destination.path}.sidekick-part');
    if (ble != null) {
      final res = await _bleSend(
        'GET',
        '/v1/fs/download',
        query: {'path': remotePath},
        timeout: const Duration(minutes: 30),
      );
      await partial.writeAsBytes(res.body, flush: true);
      onProgress?.call(res.body.length, res.body.length);
      return partial.rename(destination.path);
    }
    var have = resume && await partial.exists() ? await partial.length() : 0;
    final res = await _send(
      'GET',
      '/v1/fs/download',
      query: {'path': remotePath, if (have > 0) 'offset': '$have'},
      timeout: const Duration(seconds: 30),
    );
    // Where the answer starts: an older Sidekick always starts at 0.
    final from = int.tryParse(res.headers.value('x-sidekick-offset') ?? '') ?? 0;
    if (from != have) have = 0;
    final total = res.contentLength < 0 ? 0 : have + res.contentLength;
    final sink = partial.openWrite(mode: have > 0 ? FileMode.append : FileMode.write);
    var done = have;
    var kept = false;
    try {
      try {
        await sink.addStream(
          // Nothing for 20 s: the connection is gone, even if no error says so.
          res.timeout(const Duration(seconds: 20)).map((chunk) {
            done += chunk.length;
            onProgress?.call(done, total);
            return chunk;
          }),
        );
      } on TimeoutException {
        kept = resume;
        throw _lost();
      } on SocketException {
        kept = resume;
        throw _lost();
      } on HttpException {
        kept = resume;
        throw _lost();
      }
      await sink.close();
      if (total > 0 && done != total) {
        kept = resume;
        throw _lost();
      }
      return await partial.rename(destination.path);
    } catch (_) {
      await sink.close().catchError((_) {});
      if (!kept && await partial.exists()) await partial.delete();
      rethrow;
    }
  }

  /// Removes what a [download] with `resume` kept, when it's given up on.
  static Future<void> dropPartialDownload(File destination) async {
    final partial = File('${destination.path}.sidekick-part');
    if (await partial.exists()) await partial.delete().catchError((_) => partial);
  }

  /// Asks the other device to accept [files] (name, size) and waits for the
  /// answer. [id] lets [cancelOffer] withdraw it. A device too old to ask
  /// counts as accepting, without a ticket.
  Future<OfferReply> offerFiles(String id, List<(String, int)> files) async {
    try {
      final json = await _postJson('/v1/transfer/offer', {
        'id': id,
        'files': [
          for (final (name, size) in files) {'name': name, 'size': size},
        ],
      }, timeout: const Duration(seconds: 90)) as Map<String, dynamic>;
      return OfferReply(
        accepted: json['accepted'] == true,
        answer: json['answer'] as String? ?? '',
        ticket: json['ticket'] as String?,
      );
    } on SidekickException catch (e) {
      if (e.status == 404) return const OfferReply(accepted: true, answer: 'accepted');
      rethrow;
    }
  }

  Future<void> cancelOffer(String id) => _postJson('/v1/transfer/cancel', {'id': id});

  /// Uploads [file]. Without [remoteDir] it goes to the device's receive
  /// folder. Returns the path it was saved to on the other device.
  ///
  /// With an [uploadId] (Sidekick 3.0 and later on the other side) it goes
  /// in parts over Wi-Fi too, and calling again with the same id after a
  /// dropped connection carries on where it stopped.
  Future<String> upload(
    File file, {
    String? name,
    String? remoteDir,
    String? ticket,
    String? uploadId,
    Progress? onProgress,
    bool Function()? cancelled,
  }) async {
    final total = await file.length();
    final query = {'name': name ?? file.uri.pathSegments.last, 'dir': ?remoteDir, 'ticket': ?ticket};
    if (ble != null) {
      if (total > bleMaxBody) {
        throw SidekickException('This file is too big for Bluetooth. Connect both devices to the same Wi-Fi.');
      }
      onProgress?.call(0, total);
      return _bleUploadInParts(file, total, query, onProgress, uploadId: uploadId);
    }
    if (host.isEmpty) throw _unreachable();
    if (uploadId != null) return _wifiUploadInParts(file, total, query, uploadId, onProgress, cancelled);
    try {
      final req = await _http.openUrl('POST', _uri('/v1/fs/upload', query));
      if (token != null) req.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      req.contentLength = total;
      var done = 0;
      await req.addStream(
        file.openRead().map((chunk) {
          if (cancelled?.call() ?? false) throw SidekickException(cancelledMessage);
          done += chunk.length;
          onProgress?.call(done, total);
          return chunk;
        }),
      );
      final res = await req.close();
      if (res.statusCode >= 400) throw await _failure(res);
      _noteTls(res);
      final json = jsonDecode(await utf8.decodeStream(res)) as Map<String, dynamic>;
      return json['path'] as String;
    } on HandshakeException {
      throw _tlsFailure();
    } on SocketException {
      throw _lost();
    } on HttpException {
      throw _lost();
    }
  }

  /// What an upload stopped with Cancel throws.
  static const cancelledMessage = 'Cancelled';

  /// How much of a file goes in one request over Wi-Fi: big enough to
  /// stay fast, small enough that a dropped connection costs little.
  static const wifiPartSize = 4 * 1024 * 1024;

  /// Sends [file] over Wi-Fi in parts (`/v1/fs/upload/part`). It starts by
  /// asking where the other device is (an empty part), so a second call
  /// with the same [uploadId] picks up where the first one stopped.
  Future<String> _wifiUploadInParts(
    File file,
    int total,
    Map<String, String> query,
    String uploadId,
    Progress? onProgress,
    bool Function()? cancelled,
  ) async {
    final raf = await file.open();
    try {
      List<int> bytes = const [];
      var offset = 0;
      var stuck = 0;
      while (true) {
        if (cancelled?.call() ?? false) throw SidekickException(cancelledMessage);
        final start = offset;
        final length = bytes.length;
        final answer = await _wifiPart(
          {...query, 'upload': uploadId, 'offset': '$start', 'total': '$total'},
          bytes,
          (sent) => onProgress?.call((start + sent).clamp(0, total), total),
        );
        if (answer['path'] is String) {
          onProgress?.call(total, total);
          return answer['path'] as String;
        }
        offset = (answer['received'] as num).toInt();
        onProgress?.call(offset, total);
        // A part went over but nothing moved: something's wrong on the other
        // side, and asking forever wouldn't fix it.
        stuck = length > 0 && offset == start ? stuck + 1 : 0;
        if (stuck >= 3 || offset > total) throw SidekickException('The other device stopped taking the file.');
        await raf.setPosition(offset);
        bytes = await raf.read((total - offset).clamp(0, wifiPartSize));
      }
    } finally {
      await raf.close();
    }
  }

  /// One part of [_wifiUploadInParts]: the other device's answer.
  Future<Map<String, dynamic>> _wifiPart(Map<String, String> query, List<int> bytes, void Function(int) sent) async {
    if (host.isEmpty) throw _unreachable();
    Future<Map<String, dynamic>> go() async {
      final req = await _http.openUrl('POST', _uri('/v1/fs/upload/part', query));
      if (token != null) req.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      req.contentLength = bytes.length;
      const slice = 64 * 1024;
      var done = 0;
      await req.addStream(
        Stream.fromIterable([
          for (var i = 0; i < bytes.length; i += slice) bytes.sublist(i, (i + slice).clamp(0, bytes.length)),
        ]).map((chunk) {
          done += chunk.length;
          sent(done);
          return chunk;
        }),
      );
      final res = await req.close();
      if (res.statusCode >= 400) throw await _failure(res);
      _noteTls(res);
      return jsonDecode(await utf8.decodeStream(res)) as Map<String, dynamic>;
    }

    try {
      // A part takes well under a second on Wi-Fi; a minute means it's stuck.
      return await go().timeout(const Duration(seconds: 60));
    } on HandshakeException {
      throw _tlsFailure();
    } on TlsException {
      throw _tlsFailure();
    } on SocketException {
      throw _lost();
    } on HttpException {
      throw _lost();
    } on TimeoutException {
      throw _lost();
    }
  }

  /// How much of a file goes in one Bluetooth request: a few seconds of
  /// radio time, so a damaged packet only costs a resend of this much.
  static const blePartSize = 32 * 1024;

  /// Sends [file] over Bluetooth in sealed parts (`/v1/fs/upload/part`).
  /// Each part is retried if it gets damaged on the way ("failed
  /// authentication"), times out, or the link hiccups.
  Future<String> _bleUploadInParts(
    File file,
    int total,
    Map<String, String> query,
    Progress? onProgress, {
    String? uploadId,
  }) async {
    uploadId ??= newToken().substring(0, 24);
    final raf = await file.open();
    try {
      var offset = 0;
      while (true) {
        final length = (total - offset).clamp(0, blePartSize);
        await raf.setPosition(offset);
        final bytes = await raf.read(length);
        final start = offset;
        Map<String, dynamic>? answer;
        for (var attempt = 1; answer == null; attempt++) {
          try {
            final res = await _bleSend(
              'POST',
              '/v1/fs/upload/part',
              query: {...query, 'upload': uploadId, 'offset': '$start', 'total': '$total'},
              body: bytes,
              timeout: const Duration(minutes: 2),
              // The message is a little bigger than the part (header, sealing).
              onSent: (sent, all) =>
                  onProgress?.call((start + sent * length ~/ (all == 0 ? 1 : all)).clamp(0, total), total),
            );
            answer = jsonDecode(utf8.decode(res.body)) as Map<String, dynamic>;
          } on SidekickException catch (e) {
            // An older Sidekick on the other side: send it whole, as before.
            if (e.status == 404 && start == 0 && e.message != 'Folder not found') {
              return await _bleUploadWhole(file, total, query, onProgress);
            }
            final retryable = !e.identityChanged && (e.status == null || e.status == 401 || e.status! >= 500);
            if (!retryable || attempt >= 4) rethrow;
            await Future<void>.delayed(Duration(milliseconds: 400 * attempt));
          }
        }
        if (answer['path'] is String) {
          onProgress?.call(total, total);
          return answer['path'] as String;
        }
        offset = (answer['received'] as num).toInt();
        onProgress?.call(offset, total);
      }
    } finally {
      await raf.close();
    }
  }

  /// The whole file in one Bluetooth request (Sidekick before 2.1.2).
  Future<String> _bleUploadWhole(File file, int total, Map<String, String> query, Progress? onProgress) async {
    final res = await _bleSend(
      'POST',
      '/v1/fs/upload',
      query: query,
      body: await file.readAsBytes(),
      timeout: const Duration(minutes: 30),
      onSent: (sent, all) => onProgress?.call((sent * total ~/ (all == 0 ? 1 : all)).clamp(0, total), total),
    );
    onProgress?.call(total, total);
    return (jsonDecode(utf8.decode(res.body)) as Map<String, dynamic>)['path'] as String;
  }

  // ------------------------------------------------------------ input

  Future<InputSession> openInput() async {
    if (ble != null) {
      throw SidekickException('Remote control needs both devices on the same Wi-Fi. Bluetooth is too slow for it.');
    }
    // Ask first, so a missing permission on the other side comes back as a
    // clear message rather than a failed WebSocket upgrade.
    try {
      await _getJson('/v1/input/status');
    } on SidekickException catch (e) {
      if (e.status != 404) rethrow; // 404: an older Sidekick without the check.
    }
    final channel = IOWebSocketChannel.connect(
      Uri(scheme: 'wss', host: host, port: port, path: '/v1/input'),
      headers: {if (token != null) 'authorization': 'Bearer $token'},
      pingInterval: const Duration(seconds: 10),
      connectTimeout: const Duration(seconds: 4),
      customClient: _http,
    );
    try {
      await channel.ready;
    } catch (_) {
      throw SidekickException("Couldn't start remote control. Is it turned on in the other device's settings?");
    }
    return InputSession._(channel);
  }
}

/// A live remote-control connection. Small mouse moves are coalesced so a
/// fast touchpad doesn't flood the network.
class InputSession {
  InputSession._(IOWebSocketChannel channel) : _out = channel.sink.add, _close = channel.sink.close {
    channel.stream.listen((_) {}, onDone: _ended, onError: (_) {});
  }

  /// A session that hands each message to [send] instead of a WebSocket:
  /// the website's preview (lib/demo/) passes it to the other device on
  /// the page. [onClose] ends it.
  InputSession.custom({required void Function(String message) send, required Future<void> Function() onClose})
    : _out = send,
      _close = onClose;

  final void Function(String) _out;
  final Future<void> Function() _close;
  final _closed = Completer<void>();

  void _ended() {
    if (!_closed.isCompleted) _closed.complete();
  }

  double _dx = 0, _dy = 0;
  Timer? _flush;

  Future<void> get closed => _closed.future;
  bool get isOpen => !_closed.isCompleted;

  void _raw(Map<String, Object?> msg) {
    if (isOpen) _out(jsonEncode(msg));
  }

  /// Sends [msg] after any pending movement, so a click lands where the
  /// pointer was moved to.
  void _send(Map<String, Object?> msg) {
    _flushMove();
    _raw(msg);
  }

  void _flushMove() {
    _flush?.cancel();
    _flush = null;
    final x = _dx.truncate(), y = _dy.truncate();
    _dx -= x;
    _dy -= y;
    if (x != 0 || y != 0) _raw({'t': 'move', 'dx': x, 'dy': y});
  }

  void move(double dx, double dy) {
    _dx += dx;
    _dy += dy;
    _flush ??= Timer(const Duration(milliseconds: 12), _flushMove);
  }

  void click({String button = 'left', int count = 1}) => _send({'t': 'click', 'b': button, 'n': count});
  void buttonDown([String button = 'left']) => _send({'t': 'down', 'b': button});
  void buttonUp([String button = 'left']) => _send({'t': 'up', 'b': button});
  void scroll({int dx = 0, int dy = 0}) => _send({'t': 'scroll', 'dx': dx, 'dy': dy});
  void key(String key, {List<String> modifiers = const []}) => _send({'t': 'key', 'k': key, 'mods': modifiers});
  void text(String text) => _send({'t': 'text', 's': text});

  Future<void> close() async {
    _flush?.cancel();
    await _close();
    _ended();
  }
}
