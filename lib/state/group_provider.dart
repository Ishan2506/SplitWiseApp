import 'package:flutter/foundation.dart';
import '../model/group_model.dart';
import '../network/api_service.dart';

/// Owns everything about groups: the list itself, per-group balances, and the
/// invite flows. Screens read from here and call through to [ApiService];
/// nothing about groups is held as mock data any more.
class GroupProvider extends ChangeNotifier {
  List<GroupModel> _groups = [];
  final Map<String, GroupBalances> _balances = {};

  bool _isLoading = false;
  bool _hasLoadedOnce = false;
  String? _error;

  /// Called with the current group list whenever it changes, so the legacy
  /// expense and settle-up screens can keep working against real groups.
  /// Wired up in `main.dart`; harmless when left unset.
  void Function(List<GroupModel>)? onGroupsChanged;

  void _publish() => onGroupsChanged?.call(_groups);

  /// Groups the signed-in user belongs to, newest activity first.
  List<GroupModel> get groups => List.unmodifiable(_groups);
  bool get isLoading => _isLoading;
  bool get hasLoadedOnce => _hasLoadedOnce;
  String? get error => _error;

  GroupModel? groupById(String id) {
    for (final g in _groups) {
      if (g.id == id) return g;
    }
    return null;
  }

  /// Balances for a group; empty until [loadBalances] has run for it.
  GroupBalances balancesFor(String groupId) =>
      _balances[groupId] ?? const GroupBalances.empty();

  /// The signed-in user's net position in a group.
  double userBalanceIn(String groupId, String userId) =>
      balancesFor(groupId).balanceFor(userId);

  /// Total the user is owed across every loaded group, and the total they owe.
  /// These sum the same per-group balances the group cards show, so the
  /// dashboard headline can never disagree with the list beneath it.
  double totalOwedAcrossGroups(String userId) =>
      _sumBalances(userId, positive: true);

  double totalOweAcrossGroups(String userId) =>
      _sumBalances(userId, positive: false);

  double _sumBalances(String userId, {required bool positive}) {
    double total = 0.0;
    for (final g in _groups) {
      final bal = userBalanceIn(g.id, userId);
      if (positive ? bal > 0.01 : bal < -0.01) total += bal.abs();
    }
    return total;
  }

  /// Groups of one kind, for the type filter chips.
  List<GroupModel> groupsOfType(GroupType type) =>
      _groups.where((g) => g.type == type).toList();

  /// Reloads the group list. [silent] refreshes without showing a spinner,
  /// which is what pull-to-refresh and post-mutation refreshes want.
  Future<void> loadGroups({bool silent = false}) async {
    if (!silent) {
      _isLoading = true;
      _error = null;
      notifyListeners();
    }

    final result = await ApiService.getGroups();
    if (result['success'] == true) {
      _groups = List<GroupModel>.from(result['groups'] as List);
      _error = null;
    } else {
      _error = result['message'] as String?;
    }

    _isLoading = false;
    _hasLoadedOnce = true;
    _publish();
    notifyListeners();

    // Balances drive every group card, so fetch them for the whole list.
    await Future.wait(_groups.map((g) => loadBalances(g.id, notify: false)));
    notifyListeners();
  }

  /// Fetches balances for one group. Set [notify] to false when batching.
  Future<void> loadBalances(String groupId, {bool notify = true}) async {
    final result = await ApiService.getGroupBalances(groupId);
    if (result['success'] == true) {
      _balances[groupId] = result['balances'] as GroupBalances;
      if (notify) notifyListeners();
    }
  }

  /// Refreshes a single group and its balances after a change to it.
  Future<void> refreshGroup(String groupId) async {
    final result = await ApiService.getGroup(groupId);
    if (result['success'] == true) {
      _upsert(result['group'] as GroupModel);
    }
    await loadBalances(groupId);
  }

  void _upsert(GroupModel group) {
    final idx = _groups.indexWhere((g) => g.id == group.id);
    if (idx == -1) {
      _groups.insert(0, group);
    } else {
      _groups[idx] = group;
    }
    _publish();
    notifyListeners();
  }

  void _remove(String groupId) {
    _groups.removeWhere((g) => g.id == groupId);
    _balances.remove(groupId);
    _publish();
    notifyListeners();
  }

  /// Clears everything — called on sign-out so the next user starts clean.
  void reset() {
    _groups = [];
    _balances.clear();
    _hasLoadedOnce = false;
    _error = null;
    _publish();
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Mutations. Each returns {success, message} so the caller can show a snackbar.
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>> createGroup({
    required String name,
    String description = '',
    required GroupType type,
    String photoUrl = '',
    double balanceLimit = 0,
    List<String> memberIds = const [],
  }) async {
    final result = await ApiService.createGroup(
      name: name,
      description: description,
      type: type,
      photoUrl: photoUrl,
      balanceLimit: balanceLimit,
      memberIds: memberIds,
    );
    if (result['success'] == true) {
      _upsert(result['group'] as GroupModel);
      await loadBalances((result['group'] as GroupModel).id);
    }
    return result;
  }

  Future<Map<String, dynamic>> updateGroup({
    required String groupId,
    String? name,
    String? description,
    GroupType? type,
    String? photoUrl,
    double? balanceLimit,
    String? currency,
  }) async {
    final result = await ApiService.updateGroup(
      groupId: groupId,
      name: name,
      description: description,
      type: type,
      photoUrl: photoUrl,
      balanceLimit: balanceLimit,
      currency: currency,
    );
    if (result['success'] == true) {
      _upsert(result['group'] as GroupModel);
    }
    return result;
  }

  Future<Map<String, dynamic>> deleteGroup(String groupId) async {
    final result = await ApiService.deleteGroup(groupId);
    if (result['success'] == true) _remove(groupId);
    return result;
  }

  Future<Map<String, dynamic>> addMember({
    required String groupId,
    String? userId,
    String? email,
    String? mobileNumber,
  }) async {
    final result = await ApiService.addGroupMember(
      groupId: groupId,
      userId: userId,
      email: email,
      mobileNumber: mobileNumber,
    );
    if (result['success'] == true) {
      _upsert(result['group'] as GroupModel);
      await loadBalances(groupId);
    }
    return result;
  }

  Future<Map<String, dynamic>> inviteByEmail({
    required String groupId,
    required String email,
  }) async {
    final result = await ApiService.inviteToGroup(
      groupId: groupId,
      email: email,
    );
    if (result['success'] == true && result['group'] != null) {
      _upsert(result['group'] as GroupModel);
      if (result['added'] == true) await loadBalances(groupId);
    }
    return result;
  }

  Future<Map<String, dynamic>> revokeInvite({
    required String groupId,
    required String inviteId,
  }) async {
    final result =
        await ApiService.revokeInvite(groupId: groupId, inviteId: inviteId);
    if (result['success'] == true) _upsert(result['group'] as GroupModel);
    return result;
  }

  /// Removes a member. Pass the signed-in user's own id to leave the group.
  Future<Map<String, dynamic>> removeMember({
    required String groupId,
    required String userId,
    required String currentUserId,
  }) async {
    final result = await ApiService.removeGroupMember(
      groupId: groupId,
      userId: userId,
    );
    if (result['success'] == true) {
      if (userId == currentUserId) {
        // We just left, so the group is no longer ours to show.
        _remove(groupId);
      } else {
        _upsert(result['group'] as GroupModel);
        await loadBalances(groupId);
      }
    }
    return result;
  }

  /// Records a payment from one member to another and pulls the balances it
  /// moved.
  ///
  /// The refresh is what makes "balances update for everyone immediately"
  /// true rather than a claim: the server recomputes every position from its
  /// own expenses and settlements, so we never adjust balances locally.
  Future<Map<String, dynamic>> recordSettlement({
    required String groupId,
    required String fromUserId,
    required String toUserId,
    required double amount,
    String? note,
  }) async {
    final result = await ApiService.createSettlement(
      groupId: groupId,
      from: fromUserId,
      to: toUserId,
      amount: amount,
      note: note,
    );
    if (result['success'] == true) {
      await loadBalances(groupId);
    }
    return result;
  }

  /// Joins a group from a scanned QR code or a tapped invite link.
  Future<Map<String, dynamic>> joinByCode(String code) async {
    final result = await ApiService.joinGroupByCode(code);
    if (result['success'] == true && result['group'] != null) {
      final group = result['group'] as GroupModel;
      _upsert(group);
      await loadBalances(group.id);
    }
    return result;
  }

  Future<Map<String, dynamic>> previewInvite(String code) =>
      ApiService.previewInvite(code);

  Future<Map<String, dynamic>> refreshInvite(String groupId) async {
    final result = await ApiService.getGroupInvite(groupId);
    if (result['success'] == true) {
      _applyInvite(groupId, result['invite'] as GroupInvite);
    }
    return result;
  }

  Future<Map<String, dynamic>> rotateInvite(String groupId) async {
    final result = await ApiService.rotateGroupInvite(groupId);
    if (result['success'] == true) {
      _applyInvite(groupId, result['invite'] as GroupInvite);
    }
    return result;
  }

  Future<Map<String, dynamic>> setInviteEnabled({
    required String groupId,
    required bool enabled,
  }) async {
    final result = await ApiService.setInviteEnabled(
      groupId: groupId,
      enabled: enabled,
    );
    if (result['success'] == true) {
      _applyInvite(groupId, result['invite'] as GroupInvite);
    }
    return result;
  }

  // Swaps in a new invite without refetching the whole group.
  void _applyInvite(String groupId, GroupInvite invite) {
    final idx = _groups.indexWhere((g) => g.id == groupId);
    if (idx == -1) return;
    final g = _groups[idx];
    _groups[idx] = GroupModel(
      id: g.id,
      name: g.name,
      description: g.description,
      type: g.type,
      photoUrl: g.photoUrl,
      balanceLimit: g.balanceLimit,
      currency: g.currency,
      createdById: g.createdById,
      createdByName: g.createdByName,
      members: g.members,
      pendingInvites: g.pendingInvites,
      invite: invite,
      updatedAt: g.updatedAt,
    );
    notifyListeners();
  }
}
