@Tags(['e2e'])
library;

import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:splitwise_app/network/api_service.dart';

/// Drives the real Flutter client against a locally running backend.
/// Skipped automatically when the server is not up.
void main() {
  const base = 'http://127.0.0.1:7000/api';

  setUpAll(() => ApiService.baseUrlOverride = base);
  tearDownAll(() {
    ApiService.baseUrlOverride = null;
    ApiService.debugSetToken(null);
  });

  test('upload, serve and delete an avatar through ApiService', () async {
    // Register a throwaway user to get a real token.
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final reg = await http.post(
      Uri.parse('$base/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'name': 'E2E Avatar',
        'email': 'e2eavatar$stamp@example.com',
        'password': 'Passw0rd!x',
      }),
    );
    expect(reg.statusCode, anyOf(200, 201), reason: reg.body);
    ApiService.debugSetToken(jsonDecode(reg.body)['token'] as String);

    // A real 1x1 PNG.
    final png = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
    );

    final up = await ApiService.uploadAvatar(
      bytes: png,
      filename: 'avatar.png',
    );
    expect(up['success'], isTrue, reason: '${up['message']}');

    final url = (up['user'] as dynamic).avatarUrl as String;
    expect(url, contains('/uploads/avatars/'));

    // The uploaded photo must actually be fetchable at that URL.
    final fetched = await http.get(
      Uri.parse(url.replaceFirst('localhost', '127.0.0.1')),
    );
    expect(fetched.statusCode, 200);
    expect(fetched.headers['content-type'], contains('image/png'));
    expect(Uint8List.fromList(fetched.bodyBytes), equals(png));

    // And removing it clears the field.
    final del = await ApiService.deleteAvatar();
    expect(del['success'], isTrue, reason: '${del['message']}');
    expect((del['user'] as dynamic).avatarUrl, isEmpty);
  }, timeout: const Timeout(Duration(seconds: 60)));
}
