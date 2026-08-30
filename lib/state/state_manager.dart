import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';
import '../model/user_model.dart';
import '../network/api_service.dart';

class StateManager extends ChangeNotifier {
  final List<Member> _members = [];
  final List<Group> _groups = [];
  final List<Expense> _expenses = [];
  final List<Payment> _payments = [];

  String _currentUserId = 'm1';
  bool _isLoggedIn = false;
  String? _authErrorMessage;
  UserModel? _currentUserModel;

  StateManager() {
    _loadMockData();
    _initializeSession();
  }

  String? get authErrorMessage => _authErrorMessage;
  UserModel? get currentUserModel => _currentUserModel;

  Future<void> _initializeSession() async {
    await ApiService.init();
    final result = await ApiService.getMe();
    if (result['success'] == true) {
      final user = result['user'] as UserModel;
      _currentUserModel = user;
      _updateOrAddUserModel(user);
      _currentUserId = user.id;
      _isLoggedIn = true;
      notifyListeners();
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

  void bypassLogin() {
    _currentUserId = 'm1';
    _isLoggedIn = true;
    notifyListeners();
  }

  // Getters
  List<Member> get members => _members;
  List<Group> get groups => _groups;
  List<Expense> get expenses => _expenses;
  List<Payment> get payments => _payments;
  String get currentUserId => _currentUserId;
  bool get isLoggedIn => _isLoggedIn;

  Member get currentUser => _members.firstWhere((m) => m.id == _currentUserId);

  void setCurrentUser(String id) {
    _currentUserId = id;
    notifyListeners();
  }

  void login(String memberId) {
    _currentUserId = memberId;
    _isLoggedIn = true;
    notifyListeners();
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
    await ApiService.clearToken();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    _currentUserModel = null;
    _isLoggedIn = false;
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
      final user = result['user'] as UserModel;
      _currentUserModel = user;
      _updateOrAddUserModel(user);
      notifyListeners();
    }
    return result;
  }

  // Prepopulate mock data
  void _loadMockData() {
    // Add default members
    _members.addAll([
      Member(id: 'm1', name: 'You', email: 'you@example.com', avatarUrl: 'https://api.dicebear.com/7.x/initials/svg?seed=You'),
      Member(id: 'm2', name: 'Amit Sharma', email: 'amit@example.com', avatarUrl: 'https://api.dicebear.com/7.x/initials/svg?seed=Amit'),
      Member(id: 'm3', name: 'Rahul Verma', email: 'rahul@example.com', avatarUrl: 'https://api.dicebear.com/7.x/initials/svg?seed=Rahul'),
      Member(id: 'm4', name: 'Priya Patel', email: 'priya@example.com', avatarUrl: 'https://api.dicebear.com/7.x/initials/svg?seed=Priya'),
      Member(id: 'm5', name: 'Sneha Reddy', email: 'sneha@example.com', avatarUrl: 'https://api.dicebear.com/7.x/initials/svg?seed=Sneha'),
    ]);

    // Add groups
    _groups.addAll([
      Group(
        id: 'g1',
        name: 'Flatmates 302',
        description: 'Rent, electricity and grocery splitting',
        memberIds: ['m1', 'm2', 'm3', 'm4'],
        category: 'Home',
      ),
      Group(
        id: 'g2',
        name: 'Goa Trip 2026',
        description: 'Fun times, car rental, and beach shacks',
        memberIds: ['m1', 'm2', 'm5'],
        category: 'Trip',
      ),
    ]);

    // Add initial expenses
    _expenses.addAll([
      Expense(
        id: 'e1',
        description: 'Monthly Rent',
        amount: 24000.0,
        date: DateTime.now().subtract(const Duration(days: 5)),
        paidById: 'm1', // You paid
        splitType: SplitType.equal,
        splits: {'m1': 0, 'm2': 0, 'm3': 0, 'm4': 0},
        groupId: 'g1',
      ),
      Expense(
        id: 'e2',
        description: 'Internet Bill',
        amount: 1200.0,
        date: DateTime.now().subtract(const Duration(days: 3)),
        paidById: 'm2', // Amit paid
        splitType: SplitType.equal,
        splits: {'m1': 0, 'm2': 0, 'm3': 0, 'm4': 0},
        groupId: 'g1',
      ),
      Expense(
        id: 'e3',
        description: 'Car Rental',
        amount: 9000.0,
        date: DateTime.now().subtract(const Duration(days: 2)),
        paidById: 'm1', // You paid
        splitType: SplitType.equal,
        splits: {'m1': 0, 'm2': 0, 'm5': 0},
        groupId: 'g2',
      ),
      Expense(
        id: 'e4',
        description: 'Beach Shack Dinner',
        amount: 4500.0,
        date: DateTime.now().subtract(const Duration(days: 1)),
        paidById: 'm5', // Sneha paid
        splitType: SplitType.equal,
        splits: {'m1': 0, 'm2': 0, 'm5': 0},
        groupId: 'g2',
      ),
      Expense(
        id: 'e5',
        description: 'Movie Tickets (Private)',
        amount: 800.0,
        date: DateTime.now().subtract(const Duration(hours: 4)),
        paidById: 'm1', // You paid
        splitType: SplitType.equal,
        splits: {'m1': 0, 'm2': 0}, // Split with Amit
        groupId: null,
      ),
    ]);

    // Initial payments (settlements)
    _payments.addAll([
      Payment(
        id: 'p1',
        fromMemberId: 'm2', // Amit settled 5000 to You
        toMemberId: 'm1',
        amount: 5000.0,
        date: DateTime.now().subtract(const Duration(days: 2)),
        groupId: 'g1',
      )
    ]);
  }

  // Add methods
  void addMember(String name, String email) {
    final id = 'm${_members.length + 1}';
    final member = Member(
      id: id,
      name: name,
      email: email,
      avatarUrl: 'https://api.dicebear.com/7.x/initials/svg?seed=$name',
    );
    _members.add(member);
    notifyListeners();
  }

  void addGroup(String name, String description, List<String> memberIds, String category) {
    final id = 'g${_groups.length + 1}';
    // Ensure current user is in the group
    if (!memberIds.contains(_currentUserId)) {
      memberIds = [_currentUserId, ...memberIds];
    }
    final group = Group(
      id: id,
      name: name,
      description: description,
      memberIds: memberIds,
      category: category,
    );
    _groups.add(group);
    notifyListeners();
  }

  void addExpense(Expense expense) {
    _expenses.add(expense);
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

      // Debiting splitting members
      final splitMembers = expense.splits.keys.toList();
      if (splitMembers.isEmpty) continue;

      switch (expense.splitType) {
        case SplitType.equal:
          final share = amount / splitMembers.length;
          for (var mId in splitMembers) {
            balances[mId] = (balances[mId] ?? 0.0) - share;
          }
          break;
        case SplitType.exact:
          for (var mId in splitMembers) {
            final share = expense.splits[mId] ?? 0.0;
            balances[mId] = (balances[mId] ?? 0.0) - share;
          }
          break;
        case SplitType.percentage:
          for (var mId in splitMembers) {
            final percent = expense.splits[mId] ?? 0.0;
            final share = amount * (percent / 100.0);
            balances[mId] = (balances[mId] ?? 0.0) - share;
          }
          break;
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
      final grp = _groups.firstWhere((g) => g.id == groupId);
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
        final fromMem = _members.firstWhere((m) => m.id == debtorId);
        final toMem = _members.firstWhere((m) => m.id == creditorId);
        simplified.add({
          'from': fromMem,
          'to': toMem,
          'amount': double.parse(minAmount.toStringAsFixed(2)),
        });
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
}
