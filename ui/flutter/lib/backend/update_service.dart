import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

/// GitHub release discovery and staged downloads for in-app updates.
/// Networking and hashing run in the UI isolate only as async IO; the heavy
/// digest is recomputed inside an isolate. The daemon never trusts a path
/// before re-verifying the same digest itself.
class UpdateRelease {
  const UpdateRelease({
    required this.tag,
    required this.notes,
    required this.apkUrl,
    required this.apkName,
    required this.apkSize,
    required this.apkSha256,
    required this.zipUrl,
    required this.zipName,
    required this.zipSize,
    required this.zipSha256,
  });

  final String tag;
  final String notes;
  final String apkUrl;
  final String apkName;
  final int apkSize;
  final String? apkSha256;
  final String zipUrl;
  final String zipName;
  final int zipSize;
  final String? zipSha256;
}

/// FIPS 180-4 SHA-256. The daemon-rust twin under runtime/daemon-rust/src/
/// sha256.rs carries the specification vectors; this port must stay able to
/// reproduce every one of them (custom wheels/ui test asserts parity).
class Sha256Digest {
  Sha256Digest()
    : _h = Uint32List.fromList(<int>[
        0x6a09e667,
        0xbb67ae85,
        0x3c6ef372,
        0xa54ff53a,
        0x510e527f,
        0x9b05688c,
        0x1f83d9ab,
        0x5be0cd19,
      ]);

  static const List<int> _k = <int>[
    0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, //
    0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
    0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3,
    0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
    0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc,
    0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
    0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7,
    0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
    0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13,
    0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
    0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3,
    0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
    0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5,
    0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
    0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208,
    0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
  ];

  final Uint32List _h;
  final Uint8List _block = Uint8List(64);
  int _filled = 0;
  int _bytes = 0;

  void add(List<int> bytes) {
    _bytes += bytes.length;
    int offset = 0;
    while (offset < bytes.length) {
      final room = 64 - _filled;
      final take = bytes.length - offset < room ? bytes.length - offset : room;
      _block.setRange(_filled, _filled + take, bytes, offset);
      _filled += take;
      offset += take;
      if (_filled == 64) {
        _compress(_block);
        _filled = 0;
      }
    }
  }

  void _compress(List<int> block) {
    final w = Uint32List(64);
    for (int i = 0; i < 16; i++) {
      w[i] =
          (block[i * 4] << 24) |
          (block[i * 4 + 1] << 16) |
          (block[i * 4 + 2] << 8) |
          block[i * 4 + 3];
    }
    for (int i = 16; i < 64; i++) {
      final s0 =
          ((w[i - 15] >> 7) | (w[i - 15] << 25)) ^
          ((w[i - 15] >> 18) | (w[i - 15] << 14)) ^
          (w[i - 15] >> 3);
      final s1 =
          ((w[i - 2] >> 17) | (w[i - 2] << 15)) ^
          ((w[i - 2] >> 19) | (w[i - 2] << 13)) ^
          (w[i - 2] >> 10);
      w[i] = (w[i - 16] + s0 + w[i - 7] + s1) & 0xffffffff;
    }
    int a = _h[0], b = _h[1], c = _h[2], d = _h[3];
    int e = _h[4], f = _h[5], g = _h[6], h = _h[7];
    for (int i = 0; i < 64; i++) {
      final s1 =
          ((e >> 6) | (e << 26)) ^ ((e >> 11) | (e << 21)) ^ ((e >> 25) | (e << 7));
      final ch = (e & f) ^ ((~e & 0xffffffff) & g);
      final t1 = (h + s1 + ch + _k[i] + w[i]) & 0xffffffff;
      final s0 =
          ((a >> 2) | (a << 30)) ^ ((a >> 13) | (a << 19)) ^ ((a >> 22) | (a << 10));
      final maj = (a & b) ^ (a & c) ^ (b & c);
      final t2 = (s0 + maj) & 0xffffffff;
      h = g;
      g = f;
      f = e;
      e = (d + t1) & 0xffffffff;
      d = c;
      c = b;
      b = a;
      a = (t1 + t2) & 0xffffffff;
    }
    for (int i = 0; i < 8; i++) {
      _h[i] = (_h[i] + <int>[a, b, c, d, e, f, g, h][i]) & 0xffffffff;
    }
  }

  String finish() {
    final bits = _bytes * 8;
    add(const <int>[0x80]);
    while (_filled != 56) {
      add(const <int>[0]);
    }
    final length = Uint8List(8);
    for (int i = 0; i < 8; i++) {
      length[7 - i] = (bits >> (8 * i)) & 0xff;
    }
    add(length);
    final out = StringBuffer();
    for (final v in _h) {
      out.write(v.toRadixString(16).padLeft(8, '0'));
    }
    return out.toString();
  }
}

String sha256Bytes(List<int> bytes) {
  final digest = Sha256Digest()..add(bytes);
  return digest.finish();
}

class UpdateService {
  UpdateService._();
  static const String repo = 'afrizal1211/dash-essentials';

  static HttpClient? _client;

  static HttpClient _http() => _client ??= (
    HttpClient()
      ..connectionTimeout = const Duration(seconds: 25)
      ..userAgent = 'DashEssential-App');

  static Future<String> _fetchText(String url) async {
    final request = await _http().getUrl(Uri.parse(url));
    final response = await request.close();
    final body = await response.transform(utf8.decoder).join();
    if (response.statusCode != 200) {
      throw StateError('$url -> HTTP ${response.statusCode}');
    }
    return body;
  }

  static Future<String?> _assetSha256(String url) async {
    final raw = await _fetchText(url);
    final hex = raw.trim().split(RegExp(r'\s+')).first.toLowerCase();
    if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(hex)) {
      throw StateError('checksum asset is malformed: $url');
    }
    return hex;
  }

  /// Latest release metadata with checksums when the release ships them.
  static Future<UpdateRelease> latest() async {
    final raw = await _fetchText(
      'https://api.github.com/repos/$repo/releases/latest',
    );
    final json = jsonDecode(raw) as Map<String, dynamic>;
    String? apkUrl, apkName, zipUrl, zipName, apkShaUrl, zipShaUrl;
    int apkSize = 0, zipSize = 0;
    for (final dynamic asset in (json['assets'] as List? ?? <dynamic>[])) {
      final name = asset['name'] as String? ?? '';
      final url = asset['browser_download_url'] as String? ?? '';
      final size = (asset['size'] as num?)?.toInt() ?? 0;
      if (name.endsWith('.apk.sha256')) {
        apkShaUrl = url;
      } else if (name.endsWith('.zip.sha256')) {
        zipShaUrl = url;
      } else if (name.endsWith('.apk')) {
        apkUrl = url;
        apkName = name;
        apkSize = size;
      } else if (name.endsWith('.zip')) {
        zipUrl = url;
        zipName = name;
        zipSize = size;
      }
    }
    if (apkUrl == null || zipUrl == null) {
      throw StateError('release has no staged APK and module zip pair');
    }
    String? apkSha, zipSha;
    if (apkShaUrl != null) {
      try {
        apkSha = await _assetSha256(apkShaUrl);
      } catch (_) {
        apkSha = null;
      }
    }
    if (zipShaUrl != null) {
      try {
        zipSha = await _assetSha256(zipShaUrl);
      } catch (_) {
        zipSha = null;
      }
    }
    return UpdateRelease(
      tag: json['tag_name'] as String? ?? '',
      notes: (json['body'] as String? ?? '').trim(),
      apkUrl: apkUrl,
      apkName: apkName!,
      apkSize: apkSize,
      apkSha256: apkSha,
      zipUrl: zipUrl,
      zipName: zipName!,
      zipSize: zipSize,
      zipSha256: zipSha,
    );
  }

  /// Streams <url> into <path> with progress 0..=1. Verification happens in
  /// [verifyFile] afterwards so the digest never blocks the socket pump.
  static Future<void> download(
    String url,
    String path,
    void Function(double progress)? onProgress,
  ) async {
    final request = await _http().openUrl('GET', Uri.parse(url));
    final response = await request.close();
    if (response.statusCode != 200) {
      throw StateError('download -> HTTP ${response.statusCode}');
    }
    final total = response.contentLength > 0 ? response.contentLength : 0;
    final sink = File(path).openSync(mode: FileMode.write);
    int received = 0;
    try {
      await for (final chunk in response) {
        sink.writeFromSync(chunk);
        received += chunk.length;
        if (total > 0 && onProgress != null) {
          final at = (received / total).clamp(0.0, 1.0);
          onProgress(at);
        }
      }
    } finally {
      sink.flushSync();
      sink.closeSync();
    }
  }

  static Future<String> fileSha256(String path) => Isolate.run(() {
    final digest = Sha256Digest();
    final reader = File(path).openSync();
    try {
      final buffer = Uint8List(262144);
      while (true) {
        final read = reader.readIntoSync(buffer);
        if (read == 0) break;
        digest.add(Uint8List.sublistView(buffer, 0, read));
      }
    } finally {
      reader.closeSync();
    }
    return digest.finish();
  });
}
