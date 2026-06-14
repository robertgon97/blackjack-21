// Test del helper de avatar (core/widgets/avatar.dart): distingue una URL de
// foto (Google) de un emoji, para no renderizar la URL como texto (issue #66).

import 'package:blackjack_21/core/widgets/avatar.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('avatarEsUrl', () {
    test('una URL https/http es URL', () {
      expect(avatarEsUrl('https://lh3.googleusercontent.com/a/foto'), isTrue);
      expect(avatarEsUrl('http://ejemplo.com/x.png'), isTrue);
    });

    test('un emoji no es URL', () {
      expect(avatarEsUrl('🃏'), isFalse);
      expect(avatarEsUrl('😎'), isFalse);
      expect(avatarEsUrl('♠️'), isFalse);
    });

    test('cadena vacía no es URL', () {
      expect(avatarEsUrl(''), isFalse);
    });
  });
}
