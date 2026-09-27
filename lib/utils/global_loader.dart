import 'package:flutter/foundation.dart';

/// Tracks how many network requests are currently in flight, app-wide.
///
/// [LoaderHttpClient] calls [show]/[hide] around every API request, so every
/// screen gets the loading overlay for free without wiring it into each
/// screen individually. The counter (not a bool) is what makes concurrent
/// requests safe: if two calls overlap, the overlay only disappears once
/// both have finished, never after just the first one to return.
class GlobalLoader extends ChangeNotifier {
  GlobalLoader._();
  static final GlobalLoader instance = GlobalLoader._();

  int _activeRequests = 0;
  bool get isVisible => _activeRequests > 0;

  void show() {
    _activeRequests++;
    if (_activeRequests == 1) notifyListeners();
  }

  void hide() {
    if (_activeRequests == 0) return;
    _activeRequests--;
    if (_activeRequests == 0) notifyListeners();
  }
}
