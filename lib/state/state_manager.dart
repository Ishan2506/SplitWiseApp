import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/models.dart';
import '../model/group_model.dart';
import '../model/user_model.dart';
import '../network/api_service.dart';

/// What kind of event a notification describes. Drives its icon and tint.
enum ActivityKind { expenseAdded, settled, edited, memberJoined, groupCreated }

/// One row in the Activity tab.
class AppNotification {
  final String id;
  final ActivityKind kind;
  final String title;
  final String subtitle;
  final DateTime time;
  bool isRead;

  AppNotification({
    required this.id,
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.time,
    this.isRead = false,
  });

  /// "2 min ago", "Yesterday", "3 days ago" — relative to now.
  String get relativeTime {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) {
      return '${diff.inHours} hr${diff.inHours == 1 ? '' : 's'} ago';
    }
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    if (diff.inDays < 14) return 'Last week';
    return '${(diff.inDays / 7).floor()} weeks ago';
  }
}

class StateManager extends ChangeNotifier {
  final List<Member> _members = [];
  final List<Group> _groups = [];
  final List<Expense> _expenses = [];
  final List<Payment> _payments = [];
  final List<AppNotification> _notifications = [];

  /// Empty until a real session is restored or a user signs in.
  String _currentUserId = '';
  bool _isLoggedIn = false;
  String? _authErrorMessage;
  UserModel? _currentUserModel;

  StateManager() {
    // Nothing is seeded: members and groups arrive via [syncGroupsFromApi],
    // expenses via [loadGroupExpenses], and activity as real events occur.
    _sessionRestored = _initializeSession();
  }

  /// Completes once the stored token has been loaded and validated.
  ///
  /// The splash screen awaits this before deciding where to route, otherwise a
  /// slow `/auth/me` call would make an already-signed-in user land on login.
  late final Future<void> _sessionRestored;
  Future<void> get sessionRestored => _sessionRestored;

  /// Invoked on sign-out so other providers can clear their own state.
  /// Wired up in `main.dart`.
  void Function()? onSignedOut;

  String? get authErrorMessage => _authErrorMessage;
  UserModel? get currentUserModel => _currentUserModel;

  /// Restores a stored session. Never completes with an error: the splash
  /// screen awaits this before routing, so a thrown exception here would leave
  /// the user staring at the splash screen forever.
  Future<void> _initializeSession() async {
    try {
      await ApiService.init();
      if (ApiService.token == null) return;

      final result = await ApiService.getMe();
      final user = result['success'] == true ? result['user'] : null;
      if (user is UserModel) {
        _currentUserModel = user;
        _updateOrAddUserModel(user);
        _currentUserId = user.id;
        _isLoggedIn = true;
        notifyListeners();
        return;
      }

      // The call failed. `getMe` only clears the token when the server actually
      // rejected it (401), so if the token is still there this was a network or
      // server problem — stay signed in rather than forcing a needless re-login.
      if (ApiService.token != null) {
        _isLoggedIn = true;
        notifyListeners();
      }
    } catch (e) {
      // Corrupt storage, an unexpected payload shape — nothing here is worth
      // blocking startup over. Fall through to the login screen.
      debugPrint('Session restore failed: $e');
    }
  }

  void _updateOrAddUserModel(UserModel user) {
    final idx = _members.indexWhere((m) => m.id == user.id);
    final member = Member(
      id: user.id,
      name: user.name,
      email: user.email ?? '',
      avatarUrl: user.avatarUrl.isNotEmpty
          ? user.avatarUrl
          : 'https://api.dicebear.com/7.x/initials/svg?seed=${user.name}',
    );
    if (idx != -1) {
      _members[idx] = member;
    } else {
      _members.add(member);
    }
  }

  Future<bool> loginWithIdentifierAndPassword({
    required String identifier,
    required String password,
  }) async {
    _authErrorMessage = null;
    final result = await ApiService.login(
      identifier: identifier,
      password: password,
    );
    if (result['success'] == true) {
      final user = result['user'] as UserModel;
      _currentUserModel = user;
      _updateOrAddUserModel(user);
      _currentUserId = user.id;
      _isLoggedIn = true;
      notifyListeners();
      return true;
    } else {
      _authErrorMessage = result['message'];
      notifyListeners();
      return false;
    }
  }

  // Getters
  List<Member> get members => _members;
  List<Group> get groups => _groups;
  List<Expense> get expenses => _expenses;
  List<Payment> get payments => _payments;
  String get currentUserId => _currentUserId;
  bool get isLoggedIn => _isLoggedIn;

  /// The signed-in user as a [Member].
  ///
  /// After a real login `_currentUserId` is a server-issued id, and the member
  /// list is only filled in once the user's groups load.
  /// Falling back to the authenticated profile (and finally to a placeholder)
  /// keeps this from throwing and blanking whatever screen is building.
  Member get currentUser {
    for (final m in _members) {
      if (m.id == _currentUserId) return m;
    }

    final user = _currentUserModel;
    final name = user?.name.trim();
    return Member(
      id: _currentUserId,
      name: (name == null || name.isEmpty) ? 'You' : name,
      email: user?.email ?? '',
      avatarUrl: (user != null && user.avatarUrl.isNotEmpty)
          ? user.avatarUrl
          : 'https://api.dicebear.com/7.x/initials/svg?seed='
              '${(name == null || name.isEmpty) ? 'You' : name}',
    );
  }

  /// Looks up any member by id, returning null instead of throwing.
  Member? memberById(String id) {
    for (final m in _members) {
      if (m.id == id) return m;
    }
    return null;
  }

  // Real Google Sign-In: gets an idToken from Google, sends it to the backend,
  // and logs in with the JWT the backend returns.
  //
  // serverClientId must be the *Web* OAuth client ID (same value as the
  // backend's GOOGLE_CLIENT_IDS) so Google issues an idToken your server can verify.
  static const String _googleServerClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
    // Web OAuth client ID (the audience the backend verifies against).
    defaultValue:
        '1057268747729-secn2jv99cbflfvv2p6f2eea0f85n6c6.apps.googleusercontent.com',
  );

  Future<bool> signInWithGoogle() async {
    _authErrorMessage = null;

    try {
      final googleSignIn = GoogleSignIn(
        scopes: const ['email', 'profile'],
        serverClientId: _googleServerClientId.isEmpty ? null : _googleServerClientId,
      );

      // Make sure any previous session is cleared so the account picker shows.
      await googleSignIn.signOut();

      final account = await googleSignIn.signIn();
      if (account == null) {
        // User cancelled the picker.
        _authErrorMessage = null;
        return false;
      }

      final auth = await account.authentication;
      final idToken = auth.idToken;
      if (idToken == null) {
        _authErrorMessage =
            'Could not get Google ID token. Check the serverClientId configuration.';
        notifyListeners();
        return false;
      }

      final result = await ApiService.googleLogin(idToken: idToken);
      if (result['success'] == true) {
        final user = result['user'] as UserModel;
        _currentUserModel = user;
        _updateOrAddUserModel(user);
        _currentUserId = user.id;
        _isLoggedIn = true;
        notifyListeners();
        return true;
      } else {
        _authErrorMessage = result['message'];
        notifyListeners();
        return false;
      }
    } catch (e) {
      _authErrorMessage = 'Google sign-in failed: $e';
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    try {
      await GoogleSignIn().signOut();
    } catch (_) {
      // Ignore — user may not have logged in via Google.
    }
    // `clearToken` removes the only persisted session key. A blanket
    // `prefs.clear()` here would also wipe unrelated user settings.
    await ApiService.clearToken();

    _currentUserModel = null;
    _isLoggedIn = false;
    _authErrorMessage = null;
    // Drop the signed-out user's identity and data so nothing of theirs is
    // still on screen if someone else signs in on this device.
    _currentUserId = '';
    _notifications.clear();
    _expenses.clear();
    _payments.clear();
    _groups.clear();
    // The member list is built from the previous user's groups, so it is
    // theirs too and must not survive into the next session.
    _members.clear();

    onSignedOut?.call();
    notifyListeners();
  }

  Future<Map<String, dynamic>> updateProfile({
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
    final result = await ApiService.updateProfile(
      name: name,
      email: email,
      mobileNumber: mobileNumber,
      avatarUrl: avatarUrl,
      preferredCurrency: preferredCurrency,
      language: language,
      emailNotifications: emailNotifications,
      pushNotifications: pushNotifications,
      password: password,
    );

    if (result['success'] == true) {
      _applyUpdatedUser(result['user'] as UserModel);
    }
    return result;
  }

  /// Uploads a new profile photo and refreshes the cached user.
  Future<Map<String, dynamic>> uploadAvatar({
    required List<int> bytes,
    required String filename,
  }) async {
    final result =
        await ApiService.uploadAvatar(bytes: bytes, filename: filename);
    if (result['success'] == true) {
      _applyUpdatedUser(result['user'] as UserModel);
    }
    return result;
  }

  /// Removes the profile photo, falling back to the generated initials avatar.
  Future<Map<String, dynamic>> removeAvatar() async {
    final result = await ApiService.deleteAvatar();
    if (result['success'] == true) {
      _applyUpdatedUser(result['user'] as UserModel);
    }
    return result;
  }

  /// Stores an updated profile and republishes it to every listener.
  void _applyUpdatedUser(UserModel user) {
    _currentUserModel = user;
    _updateOrAddUserModel(user);
    notifyListeners();
  }

  /// Mirrors the real groups fetched from the API into the local [Group] and
  /// [Member] lists.
  ///
  /// Groups themselves are served by `GroupProvider`, but the expense, history
  /// and settle-up screens work against these models. Keeping the two in step
  /// means those screens offer the user's actual groups and the people really
  /// in them — this is now the only source of that data.
  void syncGroupsFromApi(List<GroupModel> apiGroups) {
    _groups
      ..clear()
      ..addAll(
        apiGroups.map(
          (g) => Group(
            id: g.id,
            name: g.name,
            description: g.description,
            memberIds: g.members.map((m) => m.id).toList(),
            category: g.type.label,
          ),
        ),
      );

    // Add anyone we have not seen before, so member lookups never throw.
    for (final apiGroup in apiGroups) {
      for (final member in apiGroup.members) {
        final idx = _members.indexWhere((m) => m.id == member.id);
        final mapped = Member(
          id: member.id,
          name: member.id == _currentUserId ? 'You' : member.name,
          email: member.email ?? '',
          avatarUrl: member.avatarUrl.isNotEmpty
              ? member.avatarUrl
              : 'https://api.dicebear.com/7.x/initials/svg?seed=${member.name}',
        );
        if (idx == -1) {
          _members.add(mapped);
        } else {
          _members[idx] = mapped;
        }
      }
    }

    notifyListeners();
  }

  void addExpense(Expense expense) {
    _expenses.add(expense);
    notifyListeners();
  }

  /// Saves an expense to the server and keeps the stored copy in sync.
  ///
  /// The server is the authority on the splits: it rebuilds them from
  /// [participants]/[values] and returns the resolved per-person amounts, so
  /// the local copy comes from the response rather than from the optimistic
  /// one. Returns `{success, message}` for the caller to surface.
  ///
  /// An expense with no group has no server route to live on, so it is held
  /// locally only.
  Future<Map<String, dynamic>> saveExpense({
    required String description,
    required double amount,
    required String paidById,
    required SplitType splitType,
    required List<String> participants,
    required Map<String, double> splits,
    Map<String, double>? values,
    String? groupId,
    DateTime? date,
    String? notes,
  }) async {
    if (groupId == null || groupId.isEmpty) {
      addExpense(Expense(
        id: 'local-${DateTime.now().millisecondsSinceEpoch}',
        description: description,
        amount: amount,
        date: date ?? DateTime.now(),
        paidById: paidById,
        splitType: splitType,
        splits: splits,
      ));
      return {'success': true, 'local': true};
    }

    final result = await ApiService.createExpense(
      groupId: groupId,
      description: description,
      amount: amount,
      paidBy: paidById,
      participants: participants,
      splitType: Expense.splitTypeToApi(splitType),
      values: values,
      date: date,
      notes: notes,
    );

    if (result['success'] == true && result['expense'] != null) {
      addExpense(Expense.fromJson(
          Map<String, dynamic>.from(result['expense'] as Map)));
      return {'success': true};
    }

    return {
      'success': false,
      'message': result['message'] ?? 'Could not save the expense',
      if (result['limitExceeded'] == true) 'limitExceeded': true,
    };
  }

  /// Replaces the locally held expenses for a group with the server's copy.
  Future<void> loadGroupExpenses(String groupId) async {
    final result = await ApiService.getGroupExpenses(groupId);
    if (result['success'] != true) return;

    final fetched = (result['expenses'] as List? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(Expense.fromJson)
        .toList();

    _expenses.removeWhere((e) => e.groupId == groupId);
    _expenses.addAll(fetched);
    notifyListeners();
  }

  void addPayment(Payment payment) {
    _payments.add(payment);
    notifyListeners();
  }

  // Balance Calculations
  // Calculates net balance of a member: positive means they are owed money, negative means they owe money.
  Map<String, double> getNetBalances({String? groupId}) {
    final Map<String, double> balances = {};
    for (var member in _members) {
      balances[member.id] = 0.0;
    }

    // Process expenses
    for (var expense in _expenses) {
      if (groupId != null && expense.groupId != groupId) continue;
      if (groupId == null && expense.groupId != null) {
        // If we want overall, include all.
      }

      final amount = expense.amount;
      final payerId = expense.paidById;

      // Crediting the payer
      balances[payerId] = (balances[payerId] ?? 0.0) + amount;

      // Debiting splitting members.
      //
      // `splits` holds each member's resolved share in rupees, whatever the
      // split type was — percentages are converted to amounts when the expense
      // is saved. Re-deriving them here from splitType would double-apply the
      // conversion, so the stored amounts are used as-is.
      final splitMembers = expense.splits.keys.toList();
      if (splitMembers.isEmpty) continue;

      final storedTotal =
          expense.splits.values.fold<double>(0.0, (a, b) => a + b);

      if (storedTotal <= 0) {
        // Defensive: an expense that arrived without per-person shares falls
        // back to an even split so it still reconciles against the payer's
        // credit instead of leaving the books unbalanced.
        final share = amount / splitMembers.length;
        for (var mId in splitMembers) {
          balances[mId] = (balances[mId] ?? 0.0) - share;
        }
      } else {
        for (var mId in splitMembers) {
          balances[mId] = (balances[mId] ?? 0.0) - (expense.splits[mId] ?? 0.0);
        }
      }
    }

    // Process payments (settlements)
    for (var payment in _payments) {
      if (groupId != null && payment.groupId != groupId) continue;
      
      final fromId = payment.fromMemberId;
      final toId = payment.toMemberId;
      final amount = payment.amount;

      // Person who paid has their debt reduced (closer to 0, which means credited)
      balances[fromId] = (balances[fromId] ?? 0.0) + amount;
      // Person who received has their credit reduced (closer to 0, which means debited)
      balances[toId] = (balances[toId] ?? 0.0) - amount;
    }

    return balances;
  }

  // Get total balance of a specific user
  double getUserTotalBalance(String memberId) {
    final balances = getNetBalances();
    return balances[memberId] ?? 0.0;
  }

  // Get total amount the user is owed (sum of all positive debts from others)
  double getUserTotalOwed(String memberId) {
    double total = 0.0;
    final debts = getSimplifiedDebts();
    for (var debt in debts) {
      if (debt['to'].id == memberId) {
        total += debt['amount'];
      }
    }
    return total;
  }

  // Get total amount the user owes others (sum of all negative debts to others)
  double getUserTotalOwe(String memberId) {
    double total = 0.0;
    final debts = getSimplifiedDebts();
    for (var debt in debts) {
      if (debt['from'].id == memberId) {
        total += debt['amount'];
      }
    }
    return total;
  }

  // Debt Simplification Algorithm
  List<Map<String, dynamic>> getSimplifiedDebts({String? groupId}) {
    final netBalances = getNetBalances(groupId: groupId);

    // Filter to include only members in the group (if groupId specified)
    List<String> relevantMemberIds;
    if (groupId != null) {
      final grp = _groups.where((g) => g.id == groupId).firstOrNull;
      // An unknown group has no members to simplify debts between.
      if (grp == null) return [];
      relevantMemberIds = grp.memberIds;
    } else {
      relevantMemberIds = _members.map((m) => m.id).toList();
    }

    // Create a list of tuples: (memberId, balance)
    List<MapEntry<String, double>> debtors = [];
    List<MapEntry<String, double>> creditors = [];

    for (var mId in relevantMemberIds) {
      final bal = double.parse((netBalances[mId] ?? 0.0).toStringAsFixed(2));
      if (bal < -0.01) {
        debtors.add(MapEntry(mId, bal));
      } else if (bal > 0.01) {
        creditors.add(MapEntry(mId, bal));
      }
    }

    // Sort: debtors descending (most negative first), creditors descending (most positive first)
    debtors.sort((a, b) => a.value.compareTo(b.value));
    creditors.sort((a, b) => b.value.compareTo(a.value));

    List<Map<String, dynamic>> simplified = [];

    int dIdx = 0;
    int cIdx = 0;

    // Clone list values to manipulate
    List<double> dVals = debtors.map((e) => e.value).toList();
    List<double> cVals = creditors.map((e) => e.value).toList();

    while (dIdx < dVals.length && cIdx < cVals.length) {
      final debtorId = debtors[dIdx].key;
      final creditorId = creditors[cIdx].key;

      final oweAmount = -dVals[dIdx];
      final creditAmount = cVals[cIdx];

      final minAmount = oweAmount < creditAmount ? oweAmount : creditAmount;

      if (minAmount > 0.01) {
        final fromMem = memberById(debtorId);
        final toMem = memberById(creditorId);
        // Skip pairs we have no profile for rather than throwing mid-render.
        if (fromMem != null && toMem != null) {
          simplified.add({
            'from': fromMem,
            'to': toMem,
            'amount': double.parse(minAmount.toStringAsFixed(2)),
          });
        }
      }

      dVals[dIdx] += minAmount;
      cVals[cIdx] -= minAmount;

      if (dVals[dIdx] >= -0.01) {
        dIdx++;
      }
      if (cVals[cIdx] <= 0.01) {
        cIdx++;
      }
    }

    return simplified;
  }

  // ----- Activity feed ---------------------------------------------------

  List<AppNotification> get notifications =>
      List.unmodifiable(_notifications);

  int get unreadNotificationCount =>
      _notifications.where((n) => !n.isRead).length;

  void markAllNotificationsRead() {
    if (unreadNotificationCount == 0) return;
    for (final n in _notifications) {
      n.isRead = true;
    }
    notifyListeners();
  }

  void markNotificationRead(String id) {
    for (final n in _notifications) {
      if (n.id == id && !n.isRead) {
        n.isRead = true;
        notifyListeners();
        return;
      }
    }
  }

  /// Records an event so it shows up in the Activity tab.
  void pushNotification({
    required ActivityKind kind,
    required String title,
    required String subtitle,
  }) {
    _notifications.insert(
      0,
      AppNotification(
        id: 'n${DateTime.now().microsecondsSinceEpoch}',
        kind: kind,
        title: title,
        subtitle: subtitle,
        time: DateTime.now(),
      ),
    );
    notifyListeners();
  }
}
