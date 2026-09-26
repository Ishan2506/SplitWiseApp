import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart' show MediaType;
import 'package:shared_preferences/shared_preferences.dart';
import '../model/group_model.dart';
import '../model/user_model.dart';

class ApiService {
  // Physical Android phone: use the PC's LAN IP (phone + PC on same Wi-Fi).
  // Emulator would use 10.0.2.2; web/desktop uses localhost.
  static const String _defaultBaseUrl = kIsWeb
      ? 'http://localhost:9856/api' //http://localhost:9856/api
      : 'http://103.212.121.139:7000/api';

  /// Points the client at a different host. Tests set this to a local stub
  /// server; it is null in a running app, which uses [_defaultBaseUrl].
  @visibleForTesting
  static String? baseUrlOverride;

  static String get baseUrl => baseUrlOverride ?? _defaultBaseUrl;

  /// Seeds the auth token without touching storage, for tests.
  @visibleForTesting
  static void debugSetToken(String? token) => _token = token;

  static String? _token;

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('auth_token');
  }

  static String? get token => _token;

  static Future<void> _saveToken(String token) async {
    _token = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
  }

  static Future<void> clearToken() async {
    _token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
  }

  static Map<String, String> _getHeaders() {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (_token != null) {
      headers['Authorization'] = 'Bearer $_token';
    }
    return headers;
  }

  // Register user
  static Future<Map<String, dynamic>> register({
    required String name,
    String? email,
    String? mobileNumber,
    required String password,
  }) async {
    try {
      final body = {
        'name': name,
        'password': password,
      };
      if (email != null && email.isNotEmpty) {
        body['email'] = email;
      }
      if (mobileNumber != null && mobileNumber.isNotEmpty) {
        body['mobileNumber'] = mobileNumber;
      }

      final response = await http.post(
        Uri.parse('$baseUrl/auth/register'),
        headers: _getHeaders(),
        body: jsonEncode(body),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 201) {
        final token = data['token'];
        if (token != null) {
          await _saveToken(token);
        }
        return {'success': true, 'user': UserModel.fromJson(data['user'])};
      } else {
        return {'success': false, 'message': data['message'] ?? 'Registration failed'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // Login user
  static Future<Map<String, dynamic>> login({
    required String identifier,
    required String password,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: _getHeaders(),
        body: jsonEncode({
          'identifier': identifier,
          'password': password,
        }),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        final token = data['token'];
        if (token != null) {
          await _saveToken(token);
        }
        return {'success': true, 'user': UserModel.fromJson(data['user'])};
      } else {
        return {'success': false, 'message': data['message'] ?? 'Login failed'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // Login / sign up with Google.
  // Sends the Google idToken to the backend, which verifies it and returns our JWT.
  static Future<Map<String, dynamic>> googleLogin({
    required String idToken,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/google'),
        headers: _getHeaders(),
        body: jsonEncode({'idToken': idToken}),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        final token = data['token'];
        if (token != null) {
          await _saveToken(token);
        }
        return {'success': true, 'user': UserModel.fromJson(data['user'])};
      } else {
        return {'success': false, 'message': data['message'] ?? 'Google login failed'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // Get current user profile (verify token)
  static Future<Map<String, dynamic>> getMe() async {
    if (_token == null) {
      return {'success': false, 'message': 'No authentication token'};
    }
    try {
      // Bounded so an unreachable host cannot stall app startup: without this
      // a dead server hangs on TCP connect for the OS default, far longer
      // than the splash screen is willing to wait.
      final response = await http
          .get(
            Uri.parse('$baseUrl/auth/me'),
            headers: _getHeaders(),
          )
          .timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {'success': true, 'user': UserModel.fromJson(data['user'])};
      }

      // Only a 401 means the token itself is bad. Any other status is a server
      // or gateway problem, and throwing the token away there would sign the
      // user out permanently over a transient outage.
      if (response.statusCode == 401) {
        await clearToken();
        return {
          'success': false,
          'message': data['message'] ?? 'Session expired',
          'expired': true,
        };
      }

      return {
        'success': false,
        'message': data['message'] ?? 'Could not reach the server',
      };
    } catch (e) {
      // Offline or unreachable server: keep the token so the session survives.
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // Forgot password
  static Future<Map<String, dynamic>> forgotPassword({
    required String email,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/forgot-password'),
        headers: _getHeaders(),
        body: jsonEncode({'email': email}),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {'success': true, 'message': data['message'] ?? 'Reset link sent'};
      } else {
        return {'success': false, 'message': data['message'] ?? 'Failed to send reset link'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // Get list of all users for group member selection
  static Future<Map<String, dynamic>> getUsers() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/users'),
        headers: _getHeaders(),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {'success': true, 'users': data['users'] ?? []};
      } else {
        return {'success': false, 'message': data['message'] ?? 'Failed to fetch users'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // Verify reset token
  static Future<Map<String, dynamic>> verifyResetToken({
    required String email,
    required String token,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/verify-reset-token'),
        headers: _getHeaders(),
        body: jsonEncode({'email': email, 'token': token}),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {'success': true};
      } else {
        return {'success': false, 'message': data['message'] ?? 'Invalid reset token'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // Reset password
  static Future<Map<String, dynamic>> resetPassword({
    required String email,
    required String token,
    required String password,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/reset-password'),
        headers: _getHeaders(),
        body: jsonEncode({'email': email, 'token': token, 'password': password}),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {'success': true, 'message': data['message'] ?? 'Password reset successful'};
      } else {
        return {'success': false, 'message': data['message'] ?? 'Failed to reset password'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // Update user profile
  static Future<Map<String, dynamic>> updateProfile({
    String? name,
    String? email,
    String? mobileNumber,
    String? avatarUrl,
    String? preferredCurrency,
    String? language,
    bool? emailNotifications,
    bool? pushNotifications,
    String? password,
  }) async {
    try {
      final body = <String, dynamic>{};
      if (name != null) body['name'] = name;
      if (email != null) body['email'] = email;
      if (mobileNumber != null) body['mobileNumber'] = mobileNumber;
      if (avatarUrl != null) body['avatarUrl'] = avatarUrl;
      if (preferredCurrency != null) body['preferredCurrency'] = preferredCurrency;
      if (language != null) body['language'] = language;
      if (emailNotifications != null) body['emailNotifications'] = emailNotifications;
      if (pushNotifications != null) body['pushNotifications'] = pushNotifications;
      if (password != null && password.isNotEmpty) body['password'] = password;

      final response = await http.put(
        Uri.parse('$baseUrl/users/profile'),
        headers: _getHeaders(),
        body: jsonEncode(body),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {'success': true, 'user': UserModel.fromJson(data['user'])};
      } else {
        return {'success': false, 'message': data['message'] ?? 'Profile update failed'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// POST /users/avatar — uploads a profile photo as multipart/form-data.
  ///
  /// [bytes] keeps this usable on web, where a file path is not available.
  /// The server validates the type and size and returns the updated user.
  static Future<Map<String, dynamic>> uploadAvatar({
    required List<int> bytes,
    required String filename,
  }) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/users/avatar'),
      );
      // Not _getHeaders(): that sets a JSON content type, which would break
      // the multipart boundary.
      if (_token != null) {
        request.headers['Authorization'] = 'Bearer $_token';
      }
      request.headers['Accept'] = 'application/json';
      request.files.add(http.MultipartFile.fromBytes(
        'avatar',
        bytes,
        filename: filename,
        contentType: _mediaTypeFor(filename),
      ));

      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);
      final data = _decode(response);

      if (_ok(response.statusCode)) {
        return {'success': true, 'user': UserModel.fromJson(data['user'])};
      }
      return {
        'success': false,
        'message': data['message'] ?? 'Could not upload the photo',
      };
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// DELETE /users/avatar — drops the photo and falls back to initials.
  static Future<Map<String, dynamic>> deleteAvatar() async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/users/avatar'),
        headers: _getHeaders(),
      );
      final data = _decode(response);
      if (_ok(response.statusCode)) {
        return {'success': true, 'user': UserModel.fromJson(data['user'])};
      }
      return {
        'success': false,
        'message': data['message'] ?? 'Could not remove the photo',
      };
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// The content type the server expects for an upload, from its extension.
  /// The server only accepts these three, so anything else is sent as JPEG
  /// and rejected there rather than being silently mislabelled here.
  static MediaType _mediaTypeFor(String filename) {
    final ext = filename.toLowerCase().split('.').last;
    switch (ext) {
      case 'png':
        return MediaType('image', 'png');
      case 'webp':
        return MediaType('image', 'webp');
      default:
        return MediaType('image', 'jpeg');
    }
  }

  // ---------------------------------------------------------------------------
  // Groups
  // ---------------------------------------------------------------------------

  // Decodes a response body, tolerating an empty or non-JSON payload.
  static Map<String, dynamic> _decode(http.Response response) {
    if (response.body.isEmpty) return {};
    try {
      final decoded = jsonDecode(response.body);
      return decoded is Map<String, dynamic> ? decoded : {};
    } catch (_) {
      return {};
    }
  }

  static bool _ok(int status) => status >= 200 && status < 300;

  // Runs a group request and returns either the parsed group or a message.
  static Future<Map<String, dynamic>> _groupRequest(
    Future<http.Response> Function() send, {
    String fallbackError = 'Request failed',
  }) async {
    try {
      final response = await send();
      final data = _decode(response);
      if (_ok(response.statusCode)) {
        return {
          'success': true,
          if (data['group'] != null)
            'group': GroupModel.fromJson(Map<String, dynamic>.from(data['group'])),
          'message': ?data['message'],
          'joined': ?data['joined'],
          'added': ?data['added'],
        };
      }
      return {
        'success': false,
        'message': data['message'] ?? fallbackError,
        'statusCode': response.statusCode,
        if (data['limitExceeded'] == true) 'limitExceeded': true,
      };
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// GET /groups — every group the signed-in user belongs to.
  static Future<Map<String, dynamic>> getGroups({String? type}) async {
    try {
      final uri = Uri.parse(
        '$baseUrl/groups${type != null ? '?type=$type' : ''}',
      );
      final response = await http.get(uri, headers: _getHeaders());
      final data = _decode(response);
      if (_ok(response.statusCode)) {
        final groups = (data['groups'] as List? ?? [])
            .whereType<Map<String, dynamic>>()
            .map(GroupModel.fromJson)
            .toList();
        return {'success': true, 'groups': groups};
      }
      return {'success': false, 'message': data['message'] ?? 'Could not load groups'};
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// GET /groups/:id
  static Future<Map<String, dynamic>> getGroup(String groupId) =>
      _groupRequest(
        () => http.get(Uri.parse('$baseUrl/groups/$groupId'),
            headers: _getHeaders()),
        fallbackError: 'Could not load group',
      );

  /// POST /groups
  static Future<Map<String, dynamic>> createGroup({
    required String name,
    String description = '',
    required GroupType type,
    String photoUrl = '',
    double balanceLimit = 0,
    String? currency,
    List<String> memberIds = const [],
  }) =>
      _groupRequest(
        () => http.post(
          Uri.parse('$baseUrl/groups'),
          headers: _getHeaders(),
          body: jsonEncode({
            'name': name,
            'description': description,
            'type': type.wireValue,
            'photoUrl': photoUrl,
            'balanceLimit': balanceLimit,
            'currency': ?currency,
            'memberIds': memberIds,
          }),
        ),
        fallbackError: 'Could not create the group',
      );

  /// PATCH /groups/:id — only the fields provided are changed.
  static Future<Map<String, dynamic>> updateGroup({
    required String groupId,
    String? name,
    String? description,
    GroupType? type,
    String? photoUrl,
    double? balanceLimit,
    String? currency,
  }) =>
      _groupRequest(
        () => http.patch(
          Uri.parse('$baseUrl/groups/$groupId'),
          headers: _getHeaders(),
          body: jsonEncode({
            'name': ?name,
            'description': ?description,
            if (type != null) 'type': type.wireValue,
            'photoUrl': ?photoUrl,
            'balanceLimit': ?balanceLimit,
            'currency': ?currency,
          }),
        ),
        fallbackError: 'Could not update the group',
      );

  /// PATCH /groups/:id/default-split — a remembered split ratio so a new
  /// expense in this group starts from it instead of an even split.
  /// [splits] maps memberId -> percentage (must sum to 100); pass null to
  /// clear it back to "no default".
  static Future<Map<String, dynamic>> setDefaultSplit({
    required String groupId,
    Map<String, double>? splits,
  }) =>
      _groupRequest(
        () => http.patch(
          Uri.parse('$baseUrl/groups/$groupId/default-split'),
          headers: _getHeaders(),
          body: jsonEncode({
            'splits': splits == null
                ? null
                : [
                    for (final entry in splits.entries)
                      {'user': entry.key, 'percentage': entry.value},
                  ],
          }),
        ),
        fallbackError: 'Could not update the default split',
      );

  /// DELETE /groups/:id
  static Future<Map<String, dynamic>> deleteGroup(String groupId) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/groups/$groupId'),
        headers: _getHeaders(),
      );
      final data = _decode(response);
      if (_ok(response.statusCode)) {
        return {'success': true, 'message': data['message'] ?? 'Group deleted'};
      }
      return {'success': false, 'message': data['message'] ?? 'Could not delete the group'};
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// GET /groups/:id/balances
  static Future<Map<String, dynamic>> getGroupBalances(String groupId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/groups/$groupId/balances'),
        headers: _getHeaders(),
      );
      final data = _decode(response);
      if (_ok(response.statusCode)) {
        return {'success': true, 'balances': GroupBalances.fromJson(data)};
      }
      return {
        'success': false,
        'message': data['message'] ?? 'Could not load balances',
      };
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// POST /groups/:groupId/settlements — record a payment between members.
  ///
  /// [from] defaults to the signed-in user on the server, but is sent
  /// explicitly so the sheet can also log a payment someone else made.
  static Future<Map<String, dynamic>> createSettlement({
    required String groupId,
    required String from,
    required String to,
    required double amount,
    String? note,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/groups/$groupId/settlements'),
        headers: _getHeaders(),
        body: jsonEncode({
          'from': from,
          'to': to,
          'amount': amount,
          if (note != null && note.isNotEmpty) 'note': note,
        }),
      );
      final data = _decode(response);
      if (_ok(response.statusCode)) {
        return {'success': true, 'settlement': data['settlement']};
      }
      return {
        'success': false,
        'message': data['message'] ?? 'Could not record the payment',
      };
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// GET /groups/:groupId/settlements — payments already recorded in a group.
  static Future<Map<String, dynamic>> getGroupSettlements(
      String groupId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/groups/$groupId/settlements'),
        headers: _getHeaders(),
      );
      final data = _decode(response);
      if (_ok(response.statusCode)) {
        return {
          'success': true,
          'settlements': (data['settlements'] as List? ?? [])
              .whereType<Map<String, dynamic>>()
              .toList(),
        };
      }
      return {
        'success': false,
        'message': data['message'] ?? 'Could not load payments',
      };
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// POST /groups/:id/members — add someone who already has an account.
  static Future<Map<String, dynamic>> addGroupMember({
    required String groupId,
    String? userId,
    String? email,
    String? mobileNumber,
  }) =>
      _groupRequest(
        () => http.post(
          Uri.parse('$baseUrl/groups/$groupId/members'),
          headers: _getHeaders(),
          body: jsonEncode({
            'userId': ?userId,
            'email': ?email,
            'mobileNumber': ?mobileNumber,
          }),
        ),
        fallbackError: 'Could not add the member',
      );

  /// DELETE /groups/:id/members/:userId — remove a member, or leave the group.
  static Future<Map<String, dynamic>> removeGroupMember({
    required String groupId,
    required String userId,
  }) =>
      _groupRequest(
        () => http.delete(
          Uri.parse('$baseUrl/groups/$groupId/members/$userId'),
          headers: _getHeaders(),
        ),
        fallbackError: 'Could not remove the member',
      );

  /// POST /groups/:id/invites — invite by email or mobile number. People who
  /// already have an account are added immediately; everyone else stays
  /// pending until they join through the link, QR code, or (for a phone
  /// invite, since there is no SMS provider) once they sign up with a
  /// matching number.
  static Future<Map<String, dynamic>> inviteToGroup({
    required String groupId,
    String? email,
    String? mobileNumber,
  }) =>
      _groupRequest(
        () => http.post(
          Uri.parse('$baseUrl/groups/$groupId/invites'),
          headers: _getHeaders(),
          body: jsonEncode({'email': ?email, 'mobileNumber': ?mobileNumber}),
        ),
        fallbackError: 'Could not send the invite',
      );

  /// DELETE /groups/:id/invites/:inviteId
  static Future<Map<String, dynamic>> revokeInvite({
    required String groupId,
    required String inviteId,
  }) =>
      _groupRequest(
        () => http.delete(
          Uri.parse('$baseUrl/groups/$groupId/invites/$inviteId'),
          headers: _getHeaders(),
        ),
        fallbackError: 'Could not revoke the invite',
      );

  // Shared handling for the three endpoints that return an invite payload.
  static Future<Map<String, dynamic>> _inviteRequest(
    Future<http.Response> Function() send,
    String fallbackError,
  ) async {
    try {
      final response = await send();
      final data = _decode(response);
      if (_ok(response.statusCode)) {
        return {
          'success': true,
          'invite': GroupInvite.fromJson(Map<String, dynamic>.from(data['invite'])),
        };
      }
      return {'success': false, 'message': data['message'] ?? fallbackError};
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// GET /groups/:id/invite — the current code, link and QR payload.
  static Future<Map<String, dynamic>> getGroupInvite(String groupId) =>
      _inviteRequest(
        () => http.get(Uri.parse('$baseUrl/groups/$groupId/invite'),
            headers: _getHeaders()),
        'Could not load the invite',
      );

  /// POST /groups/:id/invite/rotate — issue a fresh code, invalidating the old
  /// link and QR image.
  static Future<Map<String, dynamic>> rotateGroupInvite(
    String groupId, {
    int? expiresInHours,
  }) =>
      _inviteRequest(
        () => http.post(
          Uri.parse('$baseUrl/groups/$groupId/invite/rotate'),
          headers: _getHeaders(),
          body: jsonEncode({
            'expiresInHours': ?expiresInHours,
          }),
        ),
        'Could not regenerate the invite code',
      );

  /// PATCH /groups/:id/invite — turn joining on or off, or set an expiry.
  static Future<Map<String, dynamic>> setInviteEnabled({
    required String groupId,
    bool? enabled,
    int? expiresInHours,
    bool clearExpiry = false,
  }) =>
      _inviteRequest(
        () => http.patch(
          Uri.parse('$baseUrl/groups/$groupId/invite'),
          headers: _getHeaders(),
          body: jsonEncode({
            'enabled': ?enabled,
            // An explicit null clears the expiry; omitting the key leaves it.
            if (clearExpiry)
              'expiresInHours': null
            else
              'expiresInHours': ?expiresInHours,
          }),
        ),
        'Could not update the invite settings',
      );

  /// GET /groups/join/:code — what the group looks like before joining.
  static Future<Map<String, dynamic>> previewInvite(String code) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/groups/join/$code'),
        headers: _getHeaders(),
      );
      final data = _decode(response);
      if (_ok(response.statusCode)) {
        return {'success': true, 'preview': InvitePreview.fromJson(data)};
      }
      return {
        'success': false,
        'message': data['message'] ?? 'This invite could not be found',
      };
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// POST /groups/join — redeem an invite code from a link or a QR scan.
  static Future<Map<String, dynamic>> joinGroupByCode(String code) =>
      _groupRequest(
        () => http.post(
          Uri.parse('$baseUrl/groups/join'),
          headers: _getHeaders(),
          body: jsonEncode({'code': code}),
        ),
        fallbackError: 'Could not join the group',
      );

  /// GET /users?search= — used when picking members to add.
  static Future<Map<String, dynamic>> searchUsers({String? search}) async {
    try {
      final uri = Uri.parse(
        '$baseUrl/users${search != null && search.isNotEmpty ? '?search=${Uri.encodeQueryComponent(search)}' : ''}',
      );
      final response = await http.get(uri, headers: _getHeaders());
      final data = _decode(response);
      if (_ok(response.statusCode)) {
        final users = (data['users'] as List? ?? [])
            .whereType<Map<String, dynamic>>()
            .map(GroupMember.fromJson)
            .toList();
        return {'success': true, 'users': users};
      }
      return {'success': false, 'message': data['message'] ?? 'Could not load users'};
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // ---------------------------------------------------------------------
  // Expenses
  // ---------------------------------------------------------------------

  /// Shapes an expense response the same way for every expense call.
  static Future<Map<String, dynamic>> _expenseRequest(
    Future<http.Response> Function() send, {
    String fallbackError = 'Request failed',
  }) async {
    try {
      final response = await send();
      final data = _decode(response);
      if (_ok(response.statusCode)) {
        return {
          'success': true,
          if (data['expense'] != null)
            'expense': Map<String, dynamic>.from(data['expense']),
          if (data['expenses'] is List)
            'expenses': (data['expenses'] as List? ?? [])
                .whereType<Map<String, dynamic>>()
                .toList(),
          'message': ?data['message'],
        };
      }
      return {
        'success': false,
        'message': data['message'] ?? fallbackError,
        'statusCode': response.statusCode,
        // The server sends this when an expense would push someone past the
        // group's balance limit; the screen shows it as a specific warning.
        if (data['limitExceeded'] == true) 'limitExceeded': true,
      };
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// POST /groups/:groupId/expenses — create an expense in a group.
  ///
  /// [splitType] is 'equal', 'exact' or 'percentage'. For the latter two,
  /// [values] maps each participant id to their amount or percentage; the
  /// server rebuilds and validates the splits from these.
  static Future<Map<String, dynamic>> createExpense({
    required String groupId,
    required String description,
    required double amount,
    required String paidBy,
    required List<String> participants,
    String? category,
    String splitType = 'equal',
    Map<String, double>? values,
    DateTime? date,
    String? notes,
    // Set only when the expense was split between multiple payers — a map
    // of userId -> amount that userId fronted, summing to [amount].
    Map<String, double>? payers,
    // The currency [amount] (and any [values]/[payers] figures) were
    // entered in. Omitted (or equal to the group's own) means no
    // conversion is needed; anything else, the server converts.
    String? currency,
  }) =>
      _expenseRequest(
        () => http.post(
          Uri.parse('$baseUrl/groups/$groupId/expenses'),
          headers: _getHeaders(),
          body: jsonEncode({
            'description': description,
            'category': ?category,
            'amount': amount,
            'currency': ?currency,
            'paidBy': paidBy,
            'splitType': splitType,
            'participants': participants,
            'values': ?values,
            'date': ?date?.toIso8601String(),
            if (notes != null && notes.isNotEmpty) 'notes': notes,
            if (payers != null)
              'payers': [
                for (final entry in payers.entries)
                  {'user': entry.key, 'amount': entry.value},
              ],
          }),
        ),
        fallbackError: 'Could not save the expense',
      );

  /// GET /groups/:groupId/expenses — every expense recorded in a group.
  static Future<Map<String, dynamic>> getGroupExpenses(String groupId) =>
      _expenseRequest(
        () => http.get(
          Uri.parse('$baseUrl/groups/$groupId/expenses'),
          headers: _getHeaders(),
        ),
        fallbackError: 'Could not load expenses',
      );

  /// GET /expenses/:id — a single expense with its splits populated.
  static Future<Map<String, dynamic>> getExpense(String expenseId) =>
      _expenseRequest(
        () => http.get(
          Uri.parse('$baseUrl/expenses/$expenseId'),
          headers: _getHeaders(),
        ),
        fallbackError: 'Could not load the expense',
      );

  /// PATCH /expenses/:id — only the fields passed are changed.
  static Future<Map<String, dynamic>> updateExpense({
    required String expenseId,
    String? description,
    String? category,
    double? amount,
    String? paidBy,
    List<String>? participants,
    String? splitType,
    Map<String, double>? values,
    DateTime? date,
    String? notes,
    // Set only when the expense was split between multiple payers — a map
    // of userId -> amount that userId fronted, summing to [amount].
    Map<String, double>? payers,
    // The currency [amount] (and any [values]/[payers] figures) were
    // entered in, when changed.
    String? currency,
  }) =>
      _expenseRequest(
        () => http.patch(
          Uri.parse('$baseUrl/expenses/$expenseId'),
          headers: _getHeaders(),
          body: jsonEncode({
            'description': ?description,
            'category': ?category,
            'amount': ?amount,
            'currency': ?currency,
            'paidBy': ?paidBy,
            'participants': ?participants,
            'splitType': ?splitType,
            'values': ?values,
            'date': ?date?.toIso8601String(),
            'notes': ?notes,
            if (payers != null)
              'payers': [
                for (final entry in payers.entries)
                  {'user': entry.key, 'amount': entry.value},
              ],
          }),
        ),
        fallbackError: 'Could not update the expense',
      );

  /// DELETE /expenses/:id
  static Future<Map<String, dynamic>> deleteExpense(String expenseId) =>
      _expenseRequest(
        () => http.delete(
          Uri.parse('$baseUrl/expenses/$expenseId'),
          headers: _getHeaders(),
        ),
        fallbackError: 'Could not delete the expense',
      );

  /// POST /expenses/:id/receipt (multipart/form-data, field name: "receipt")
  static Future<Map<String, dynamic>> uploadExpenseReceipt({
    required String expenseId,
    required List<int> bytes,
    required String filename,
  }) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/expenses/$expenseId/receipt'),
      );
      // Not _getHeaders(): that sets a JSON content type, which would break
      // the multipart boundary.
      if (_token != null) {
        request.headers['Authorization'] = 'Bearer $_token';
      }
      request.headers['Accept'] = 'application/json';
      request.files.add(http.MultipartFile.fromBytes(
        'receipt',
        bytes,
        filename: filename,
        contentType: _mediaTypeFor(filename),
      ));

      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);
      final data = _decode(response);

      if (_ok(response.statusCode)) {
        return {
          'success': true,
          'expense': Map<String, dynamic>.from(data['expense']),
        };
      }
      return {
        'success': false,
        'message': data['message'] ?? 'Could not upload the receipt',
      };
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// DELETE /expenses/:id/receipt
  static Future<Map<String, dynamic>> deleteExpenseReceipt(
    String expenseId,
  ) =>
      _expenseRequest(
        () => http.delete(
          Uri.parse('$baseUrl/expenses/$expenseId/receipt'),
          headers: _getHeaders(),
        ),
        fallbackError: 'Could not remove the receipt',
      );

  // ---------------------------------------------------------------------
  // Recurring expenses
  // ---------------------------------------------------------------------

  /// Shapes a recurring-expense response the same way [_expenseRequest]
  /// does for plain expenses, just under the `recurringExpense(s)` keys.
  static Future<Map<String, dynamic>> _recurringRequest(
    Future<http.Response> Function() send, {
    String fallbackError = 'Request failed',
  }) async {
    try {
      final response = await send();
      final data = _decode(response);
      if (_ok(response.statusCode)) {
        return {
          'success': true,
          if (data['recurringExpense'] != null)
            'recurringExpense': Map<String, dynamic>.from(data['recurringExpense']),
          if (data['recurringExpenses'] is List)
            'recurringExpenses': (data['recurringExpenses'] as List? ?? [])
                .whereType<Map<String, dynamic>>()
                .toList(),
          'message': ?data['message'],
        };
      }
      return {
        'success': false,
        'message': data['message'] ?? fallbackError,
        'statusCode': response.statusCode,
      };
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// POST /groups/:groupId/recurring-expenses
  static Future<Map<String, dynamic>> createRecurringExpense({
    required String groupId,
    required String description,
    required double amount,
    required String paidBy,
    required List<String> participants,
    required String frequency,
    String? category,
    String splitType = 'equal',
    Map<String, double>? values,
    DateTime? startDate,
    Map<String, double>? payers,
  }) =>
      _recurringRequest(
        () => http.post(
          Uri.parse('$baseUrl/groups/$groupId/recurring-expenses'),
          headers: _getHeaders(),
          body: jsonEncode({
            'description': description,
            'category': ?category,
            'amount': amount,
            'paidBy': paidBy,
            'splitType': splitType,
            'participants': participants,
            'values': ?values,
            'frequency': frequency,
            'startDate': ?startDate?.toIso8601String(),
            if (payers != null)
              'payers': [
                for (final entry in payers.entries)
                  {'user': entry.key, 'amount': entry.value},
              ],
          }),
        ),
        fallbackError: 'Could not set up the recurring expense',
      );

  /// GET /groups/:groupId/recurring-expenses
  static Future<Map<String, dynamic>> getGroupRecurringExpenses(String groupId) =>
      _recurringRequest(
        () => http.get(
          Uri.parse('$baseUrl/groups/$groupId/recurring-expenses'),
          headers: _getHeaders(),
        ),
        fallbackError: 'Could not load recurring expenses',
      );

  /// PATCH /recurring-expenses/:id — used here just to pause/resume
  /// ([active]) or delete via [deleteRecurringExpense].
  static Future<Map<String, dynamic>> updateRecurringExpense({
    required String id,
    bool? active,
  }) =>
      _recurringRequest(
        () => http.patch(
          Uri.parse('$baseUrl/recurring-expenses/$id'),
          headers: _getHeaders(),
          body: jsonEncode({'active': ?active}),
        ),
        fallbackError: 'Could not update the recurring expense',
      );

  /// DELETE /recurring-expenses/:id
  static Future<Map<String, dynamic>> deleteRecurringExpense(String id) =>
      _recurringRequest(
        () => http.delete(
          Uri.parse('$baseUrl/recurring-expenses/$id'),
          headers: _getHeaders(),
        ),
        fallbackError: 'Could not delete the recurring expense',
      );

  /// GET /groups/:groupId/expenses/export — the server responds with raw
  /// CSV text (not JSON) on success, so this bypasses [_expenseRequest]'s
  /// JSON-shaped decoding.
  static Future<Map<String, dynamic>> exportGroupExpensesCsv(
    String groupId,
  ) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/groups/$groupId/expenses/export'),
        headers: _getHeaders(),
      );
      if (_ok(response.statusCode)) {
        return {'success': true, 'csv': response.body};
      }
      final data = _decode(response);
      return {
        'success': false,
        'message': data['message'] ?? 'Could not export expenses',
      };
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // ---------------------------------------------------------------------
  // Comments
  // ---------------------------------------------------------------------

  /// Shapes a comment response — same shared-decode pattern as the other
  /// `_xRequest` helpers, just under the `comment(s)` keys.
  static Future<Map<String, dynamic>> _commentRequest(
    Future<http.Response> Function() send, {
    String fallbackError = 'Request failed',
  }) async {
    try {
      final response = await send();
      final data = _decode(response);
      if (_ok(response.statusCode)) {
        return {
          'success': true,
          if (data['comment'] != null)
            'comment': Map<String, dynamic>.from(data['comment']),
          if (data['comments'] is List)
            'comments': (data['comments'] as List? ?? [])
                .whereType<Map<String, dynamic>>()
                .toList(),
          'message': ?data['message'],
        };
      }
      return {
        'success': false,
        'message': data['message'] ?? fallbackError,
        'statusCode': response.statusCode,
      };
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// GET /expenses/:expenseId/comments
  static Future<Map<String, dynamic>> getExpenseComments(String expenseId) =>
      _commentRequest(
        () => http.get(
          Uri.parse('$baseUrl/expenses/$expenseId/comments'),
          headers: _getHeaders(),
        ),
        fallbackError: 'Could not load comments',
      );

  /// POST /expenses/:expenseId/comments
  static Future<Map<String, dynamic>> createComment({
    required String expenseId,
    required String text,
  }) =>
      _commentRequest(
        () => http.post(
          Uri.parse('$baseUrl/expenses/$expenseId/comments'),
          headers: _getHeaders(),
          body: jsonEncode({'text': text}),
        ),
        fallbackError: 'Could not post the comment',
      );

  /// DELETE /comments/:id
  static Future<Map<String, dynamic>> deleteComment(String commentId) =>
      _commentRequest(
        () => http.delete(
          Uri.parse('$baseUrl/comments/$commentId'),
          headers: _getHeaders(),
        ),
        fallbackError: 'Could not delete the comment',
      );
}
