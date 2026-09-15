import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:splitwise_app/network/api_service.dart';

/// Drives ApiService.uploadAvatar against a throwaway local HTTP server, so
/// the multipart request is checked as the wire actually carries it: field
/// name, filename, content type and auth header.
void main() {
  late HttpServer server;
  late Map<String, String> captured;
  late List<int> capturedBody;

  setUp(() async {
    captured = {};
    capturedBody = [];
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((HttpRequest req) async {
      captured['method'] = req.method;
      captured['path'] = req.uri.path;
      captured['auth'] = req.headers.value('authorization') ?? '';
      captured['contentType'] = req.headers.contentType?.toString() ?? '';
      capturedBody = await req.fold<List<int>>([], (b, d) => b..addAll(d));

      req.response
        ..statusCode = 200
        ..headers.contentType = ContentType.json
        ..write(jsonEncode({
          'user': {
            'id': 'u1',
            'name': 'Avatar Test',
            'avatarUrl': 'http://example.com/uploads/avatars/u1-1.png',
            'preferredCurrency': 'INR',
            'language': 'en',
            'emailNotifications': true,
            'pushNotifications': true,
          }
        }));
      await req.response.close();
    });

    ApiService.baseUrlOverride = 'http://127.0.0.1:${server.port}/api';
    ApiService.debugSetToken('test-token-123');
  });

  tearDown(() async {
    ApiService.baseUrlOverride = null;
    ApiService.debugSetToken(null);
    await server.close(force: true);
  });

  test('uploadAvatar posts a well-formed multipart request', () async {
    final png = [137, 80, 78, 71, 13, 10, 26, 10, 1, 2, 3];

    final result = await ApiService.uploadAvatar(
      bytes: png,
      filename: 'photo.png',
    );

    expect(result['success'], isTrue);
    expect(captured['method'], 'POST');
    expect(captured['path'], '/api/users/avatar');
    expect(captured['auth'], 'Bearer test-token-123');
    expect(captured['contentType'], contains('multipart/form-data'));

    final body = latin1.decode(capturedBody);
    // The server reads req.file from the 'avatar' field.
    expect(body, contains('name="avatar"'));
    expect(body, contains('filename="photo.png"'));
    expect(body, contains('image/png'));
    // The raw PNG signature must survive the encoding intact.
    expect(capturedBody, containsAllInOrder(png));
  });

  test('a .jpg name is sent as image/jpeg', () async {
    await ApiService.uploadAvatar(bytes: [1, 2, 3], filename: 'snap.jpg');
    expect(latin1.decode(capturedBody), contains('image/jpeg'));
  });

  test('a .webp name is sent as image/webp', () async {
    await ApiService.uploadAvatar(bytes: [1, 2, 3], filename: 'pic.webp');
    expect(latin1.decode(capturedBody), contains('image/webp'));
  });
}
