import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../state/state_manager.dart';
import 'add_expense_screen.dart';
import 'settle_up_dialog.dart';

class GroupsTab extends StatelessWidget {
  const GroupsTab({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<StateManager>(context);
    final groups = state.groups;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Your Groups',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                ElevatedButton.icon(
                  onPressed: () => _showCreateGroupDialog(context, state),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('New Group'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0D9488),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: groups.isEmpty
                  ? const Center(
                      child: Text('No groups yet. Create one to start splitting!', style: TextStyle(color: Color(0xFF94A3B8))),
                    )
                  : ListView.builder(
                      physics: const BouncingScrollPhysics(),
                      itemCount: groups.length,
                      itemBuilder: (context, index) {
                        final group = groups[index];
                        final simplified = state.getSimplifiedDebts(groupId: group.id);

                        // Calculate net group balance for the current user
                        final groupBalances = state.getNetBalances(groupId: group.id);
                        final userBal = groupBalances[state.currentUserId] ?? 0.0;

                        return Card(
                          color: const Color(0xFF1E293B),
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () {
                              Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => GroupDetailScreen(groupId: group.id),
                                  ));
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Row(
                                children: [
                                  // Category Icon
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF334155),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      group.category.toLowerCase() == 'trip'
                                          ? Icons.flight
                                          : group.category.toLowerCase() == 'home'
                                              ? Icons.home
                                              : Icons.restaurant,
                                      color: const Color(0xFF14B8A6),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          group.name,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${group.memberIds.length} members',
                                          style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        userBal == 0
                                            ? 'settled'
                                            : userBal > 0
                                                ? 'you are owed'
                                                : 'you owe',
                                        style: TextStyle(
                                          color: userBal == 0
                                              ? const Color(0xFF94A3B8)
                                              : userBal > 0
                                                  ? const Color(0xFF10B981)
                                                  : const Color(0xFFF43F5E),
                                          fontSize: 11,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        userBal == 0 ? '₹0.00' : '₹${userBal.abs().toStringAsFixed(2)}',
                                        style: TextStyle(
                                          color: userBal == 0
                                              ? const Color(0xFF94A3B8)
                                              : userBal > 0
                                                  ? const Color(0xFF10B981)
                                                  : const Color(0xFFF43F5E),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateGroupDialog(BuildContext context, StateManager state) {
    final formKey = GlobalKey<FormState>();
    String name = '';
    String description = '';
    String category = 'Trip';
    List<String> selectedMemberIds = [];

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1E293B),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text('Create New Group', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          labelText: 'Group Name',
                          labelStyle: TextStyle(color: Color(0xFF94A3B8)),
                          enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF334155))),
                        ),
                        validator: (val) {
                          if (val == null || val.isEmpty) return 'Enter group name';
                          return null;
                        },
                        onSaved: (val) => name = val!,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          labelText: 'Description',
                          labelStyle: TextStyle(color: Color(0xFF94A3B8)),
                          enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF334155))),
                        ),
                        onSaved: (val) => description = val ?? '',
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: category,
                        dropdownColor: const Color(0xFF1E293B),
                        decoration: const InputDecoration(
                          labelText: 'Category',
                          labelStyle: TextStyle(color: Color(0xFF94A3B8)),
                          enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF334155))),
                        ),
                        style: const TextStyle(color: Colors.white),
                        items: ['Trip', 'Home', 'Dining', 'Other'].map((cat) {
                          return DropdownMenuItem(value: cat, child: Text(cat));
                        }).toList(),
                        onChanged: (val) => setModalState(() => category = val!),
                      ),
                      const SizedBox(height: 16),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Select Members:',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Friends checklist (except 'You')
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 180),
                        child: ListView(
                          shrinkWrap: true,
                          children: state.members.where((m) => m.id != state.currentUserId).map((mem) {
                            final isSelected = selectedMemberIds.contains(mem.id);
                            return CheckboxListTile(
                              title: Text(mem.name, style: const TextStyle(color: Colors.white, fontSize: 14)),
                              value: isSelected,
                              activeColor: const Color(0xFF0D9488),
                              checkColor: Colors.white,
                              onChanged: (val) {
                                setModalState(() {
                                  if (val == true) {
                                    selectedMemberIds.add(mem.id);
                                  } else {
                                    selectedMemberIds.remove(mem.id);
                                  }
                                });
                              },
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(color: Color(0xFF94A3B8))),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (formKey.currentState!.validate()) {
                      formKey.currentState!.save();
                      if (selectedMemberIds.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please select at least one friend to add to the group.')),
                        );
                        return;
                      }
                      state.addGroup(name, description, selectedMemberIds, category);
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: const Color(0xFF0D9488),
                          content: Text('Created group "$name"!'),
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D9488)),
                  child: const Text('Create', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

// Group Details Screen
class GroupDetailScreen extends StatelessWidget {
  final String groupId;
  const GroupDetailScreen({Key? key, required this.groupId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<StateManager>(context);
    final group = state.groups.firstWhere((g) => g.id == groupId);
    final groupExpenses = state.expenses.where((e) => e.groupId == groupId).toList();
    final simplifiedDebts = state.getSimplifiedDebts(groupId: groupId);

    // Sort group expenses by date descending
    groupExpenses.sort((a, b) => b.date.compareTo(a.date));

    final groupBalances = state.getNetBalances(groupId: groupId);
    final userBal = groupBalances[state.currentUserId] ?? 0.0;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        title: Text(group.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Group Balance Summary Banner
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Color(0xFF14B8A6), size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Your Group Balance',
                          style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          userBal == 0
                              ? 'You are settled up in this group.'
                              : userBal > 0
                                  ? 'You are owed ₹${userBal.toStringAsFixed(2)} overall.'
                                  : 'You owe ₹${userBal.abs().toStringAsFixed(2)} overall.',
                          style: TextStyle(
                            color: userBal == 0
                                ? Colors.white
                                : userBal > 0
                                    ? const Color(0xFF10B981)
                                    : const Color(0xFFF43F5E),
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Group Members List
            const Text(
              'Group Members',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 70,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: group.memberIds.length,
                itemBuilder: (context, index) {
                  final mId = group.memberIds[index];
                  final member = state.members.firstWhere((m) => m.id == mId);
                  final bal = groupBalances[mId] ?? 0.0;

                  return Container(
                    margin: const EdgeInsets.only(right: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: const Color(0xFF334155),
                          child: Text(
                            member.initials,
                            style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              member.name == 'You' ? 'You' : member.name.split(' ')[0],
                              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              bal == 0
                                  ? 'settled'
                                  : bal > 0
                                      ? '+₹${bal.toStringAsFixed(0)}'
                                      : '-₹${bal.abs().toStringAsFixed(0)}',
                              style: TextStyle(
                                color: bal == 0
                                    ? const Color(0xFF94A3B8)
                                    : bal > 0
                                        ? const Color(0xFF10B981)
                                        : const Color(0xFFF43F5E),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),

            // Group Actions
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AddExpenseScreen(preselectedGroupId: groupId),
                        ),
                      );
                    },
                    icon: const Icon(Icons.add, color: Colors.white),
                    label: const Text('Add Expense', style: TextStyle(fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0D9488),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) => SettleUpDialog(initialGroupId: groupId),
                      );
                    },
                    icon: const Icon(Icons.payment, color: Color(0xFF0D9488)),
                    label: const Text('Settle Up', style: TextStyle(fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF0D9488),
                      side: const BorderSide(color: Color(0xFF0D9488), width: 1.5),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Group suggested settlements
            const Text(
              'Group Settlements Needed',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 8),
            if (simplifiedDebts.isEmpty)
              const Text('Everyone is settled in this group!', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13))
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: simplifiedDebts.length,
                itemBuilder: (context, index) {
                  final debt = simplifiedDebts[index];
                  final fromU = debt['from'];
                  final toU = debt['to'];
                  final amt = debt['amount'];

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${fromU.name == 'You' ? 'You' : fromU.name} ➔ ${toU.name == 'You' ? 'You' : toU.name}',
                          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '₹${amt.toStringAsFixed(2)}',
                          style: const TextStyle(color: Color(0xFFF43F5E), fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  );
                },
              ),
            const SizedBox(height: 24),

            // Expenses List
            const Text(
              'Expenses History',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 8),
            if (groupExpenses.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Text('No expenses recorded in this group yet.', style: TextStyle(color: Color(0xFF94A3B8))),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: groupExpenses.length,
                itemBuilder: (context, index) {
                  final exp = groupExpenses[index];
                  final payer = state.members.firstWhere((m) => m.id == exp.paidById);

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0D9488).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.receipt_long, color: Color(0xFF14B8A6), size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                exp.description,
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Paid by ${payer.name == 'You' ? 'you' : payer.name}',
                                style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '₹${exp.amount.toStringAsFixed(2)}',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${exp.date.day}/${exp.date.month}',
                              style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
