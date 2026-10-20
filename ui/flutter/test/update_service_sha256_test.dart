import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:dash_essential_ui/backend/update_service.dart';

void main() {
  test('specification vectors match the daemon sha256 port', () {
    const empty = <int>[];
    expect(
      sha256Bytes(empty),
      'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
    );
    const abc = <int>[97, 98, 99];
    expect(
      sha256Bytes(abc),
      'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
    );
    expect(
      sha256Bytes(utf8.encode('abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq')),
      '248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1',
    );
    expect(
      sha256Bytes(utf8.encode(
        'abcdefghbcdefghicdefghijdefghijkefghijklfghijklmghijklmnhijklmno'
        'ijklmnopjklmnopqklmnopqrlmnopqrsmnopqrstnopqrstu',
      )),
      'cf5b16a778af8380036ce59e7b0492370b249b11e8f07a51afac45037afee9d1',
    );
  });

  test('one megabyte of a reproduces the RFC vector', () {
    final million = List<int>.filled(1000000, 97);
    expect(
      sha256Bytes(million),
      'cdc76e5c9914fb9281a1c7e284d73e67f1809a48a497200e047d14d1d1a4efc0',
    );
  });

  test('incremental feeding equals one-shot digest', () {
    final rngSeed = <int>[1, 2, 3, ...List<int>.generate(200, (i) => i * 7)];
    final first = Sha256Digest()..add(rngSeed);
    final second = Sha256Digest();
    for (int i = 0; i < rngSeed.length; i += 31) {
      second.add(rngSeed.sublist(i, (i + 31 <= rngSeed.length ? i + 31 : rngSeed.length)));
    }
    expect(second.finish(), first.finish());
  });
}
