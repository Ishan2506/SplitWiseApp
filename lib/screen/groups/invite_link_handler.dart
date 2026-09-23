import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../main.dart';
import '../../state/state_manager.dart';
import 'join_group_screen.dart';

/// Pulls the invite code out of a link, if it holds one.
///
/// Two shapes are recognised, matching what the backend hands out:
///   `paisasplit://join/<CODE>` — the app's own scheme
///   `https://<host>/join/<CODE>` — the web fallback / QR payload
///
/// A `?code=` query is accepted as a last resort, so the same parsing serves
/// both deep links and scanned QR codes.
String? inviteCodeFromUri(Uri uri) {
  final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();

  // paisasplit://join/<CODE> — "join" lands in the host on custom schemes.
  // The retired "splitwise" scheme is still parsed so links shared before the
  // rename keep working if they reach us at all.
  if (uri.scheme == 'paisasplit' || uri.scheme == 'splitwise') {
    if (uri.host == 'join' && segments.isNotEmpty) return segments.first;
    if (segments.length >= 2 && segments.first == 'join') return segments[1];
  }

  // https://<host>/join/<CODE>
  final joinIndex = segments.indexOf('join');
  if (joinIndex != -1 && joinIndex + 1 < segments.length) {
    return segments[joinIndex + 1];
  }

  // ...?code=<CODE> as a last resort.
  return uri.queryParameters['code'];
}

/// Listens for invite links and opens the join screen when one arrives.
///
/// A link that lands while the user is signed out is held until they sign in,
/// so tapping an invite before logging in still takes them to the group.
class InviteLinkHandler extends StatefulWidget {
  final Widget child;

  const InviteLinkHandler({super.key, required this.child});

  @override
  State<InviteLinkHandler> createState() => _InviteLinkHandlerState();
}

class _InviteLinkHandlerState extends State<InviteLinkHandler> {
  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _subscription;

  /// An invite that arrived before the user was signed in.
  String? _pendingCode;
  bool _wasLoggedIn = false;

  @override
  void initState() {
    super.initState();
    _wasLoggedIn = context.read<StateManager>().isLoggedIn;
    _startListening();
  }

  Future<void> _startListening() async {
    // A link may have cold-started the app.
    try {
      final initial = await _appLinks.getInitialLink();
      if (initial != null) _handleUri(initial);
    } catch (_) {
      // Deep links are unavailable on this platform — nothing to do.
    }

    _subscription = _appLinks.uriLinkStream.listen(
      _handleUri,
      onError: (_) {},
    );
  }

  void _handleUri(Uri uri) {
    final code = inviteCodeFromUri(uri);
    if (code == null || code.isEmpty) return;

    if (!mounted) return;
    if (!context.read<StateManager>().isLoggedIn) {
      // Hold it until they sign in.
      _pendingCode = code;
      return;
    }
    _openJoinScreen(code);
  }

  void _openJoinScreen(String code) {
    // Defer to after the current frame so this can be called from initState
    // and from build-time listeners alike.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      appNavigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (_) => JoinGroupScreen(inviteCode: code.toUpperCase()),
        ),
      );
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Release a held invite the moment the user signs in.
    final isLoggedIn = context.watch<StateManager>().isLoggedIn;
    if (isLoggedIn && !_wasLoggedIn && _pendingCode != null) {
      final code = _pendingCode!;
      _pendingCode = null;
      _openJoinScreen(code);
    }
    _wasLoggedIn = isLoggedIn;

    return widget.child;
  }
}
