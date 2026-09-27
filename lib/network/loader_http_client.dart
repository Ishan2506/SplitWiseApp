import 'package:http/http.dart' as http;
import '../utils/global_loader.dart';

/// Wraps the real HTTP client so every request — get/post/put/patch/delete
/// and the multipart upload calls — shows the global loader for exactly as
/// long as it's in flight, with no per-call-site wiring required.
class LoaderHttpClient extends http.BaseClient {
  final http.Client _inner = http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    GlobalLoader.instance.show();
    try {
      return await _inner.send(request);
    } finally {
      GlobalLoader.instance.hide();
    }
  }
}
