import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../state/state_manager.dart';
import 'add_expense_screen.dart';
import 'settle_up_dialog.dart';

class FriendsTab extends StatelessWidget {
  const FriendsTab({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<StateManager>(context);
    // Exclude the current user ('You') from the friends list
    final friends = state.members.where((m) => m.id != state.currentUserId).toList();
    final simplifiedDebts = state.getSimplifiedDebts();

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
                  'Friends',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                ElevatedButton.icon(
                  onPressed: () => _showAddFriendDialog(context, state),
                  icon: const Icon(Icons.person_add, size: 18),
                  label: const Text('Add Friend'),
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
              child: friends.isEmpty
                  ? const Center(
                      child: Text('No friends added yet. Add one to split!', style: TextStyle(color: Color(0xFF94A3B8))),
                    )
                  : ListView.builder(
                      physics: const BouncingScrollPhysics(),
                      itemCount: friends.length,
                      itemBuilder: (context, index) {
                        final friend = friends[index];

                        // Find if there's a simplified debt link between current user and this friend
                        double oneOnOneBal = 0.0;
                        for (var debt in simplifiedDebts) {
                          if (debt['from'].id == state.currentUserId && debt['to'].id == friend.id) {
                            oneOnOneBal = -debt['amount']; // you owe them
                          } else if (debt['to'].id == state.currentUserId && debt['from'].id == friend.id) {
                            oneOnOneBal = debt['amount']; // they owe you
                          }
                        }

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
                                  builder: (context) => FriendDetailScreen(friendId: friend.id),
                                ),
                              );
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: const Color(0xFF334155),
                                    radius: 20,
                                    child: Text(
                                      friend.initials,
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          friend.name,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          friend.email,
                                          style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        oneOnOneBal == 0
                                            ? 'settled'
                                            : oneOnOneBal > 0
                                                ? 'owes you'
                                                : 'you owe',
                                        style: TextStyle(
                                          color: oneOnOneBal == 0
                                              ? const Color(0xFF94A3B8)
                                              : oneOnOneBal > 0
                                                  ? const Color(0xFF10B981)
                                                  : const Color(0xFFF43F5E),
                                          fontSize: 11,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        oneOnOneBal == 0 ? '₹0.00' : '₹${oneOnOneBal.abs().toStringAsFixed(2)}',
                                        style: TextStyle(
                                          color: oneOnOneBal == 0
                                              ? const Color(0xFF94A3B8)
                                              : oneOnOneBal > 0
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

  void _showAddFriendDialog(BuildContext context, StateManager state) {
    final formKey = GlobalKey<FormState>();
    String name = '';
    String email = '';

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Add Friend', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Full Name',
                    labelStyle: TextStyle(color: Color(0xFF94A3B8)),
                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF334155))),
                  ),
                  validator: (val) {
                    if (val == null || val.isEmpty) return 'Enter friend name';
                    return null;
                  },
                  onSaved: (val) => name = val!,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Email Address',
                    labelStyle: TextStyle(color: Color(0xFF94A3B8)),
                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF334155))),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: (val) {
                    if (val == null || val.isEmpty) return 'Enter email address';
                    if (!val.contains('@')) return 'Enter a valid email';
                    return null;
                  },
                  onSaved: (val) => email = val!,
                ),
              ],
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
                  state.addMember(name, email);
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: const Color(0xFF0D9488),
                      content: Text('Added friend "$name"!'),
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D9488)),
              child: const Text('Add', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }
}

// Friend Detail Screen
class FriendDetailScreen extends StatelessWidget {
  final String friendId;
  const FriendDetailScreen({Key? key, required this.friendId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<StateManager>(context);
    final friend = state.members.firstWhere((m) => m.id == friendId);
    final simplifiedDebts = state.getSimplifiedDebts();

    // Fetch transactions (expenses + payments) between current user and friend
    final List<Map<String, dynamic>> friendActivities = [];

    // Filter shared expenses
    for (var exp in state.expenses) {
      final belongsToFriend = exp.splits.containsKey(friendId) || exp.paidById == friendId;
      final belongsToCurrentUser = exp.splits.containsKey(state.currentUserId) || exp.paidById == state.currentUserId;
      if (belongsToFriend && belongsToCurrentUser) {
        friendActivities.add({'type': 'expense', 'data': exp, 'date': exp.date});
      }
    }

    // Filter shared payments
    for (var pay in state.payments) {
      final isBetween = (pay.fromMemberId == state.currentUserId && pay.toMemberId == friendId) ||
          (pay.fromMemberId == friendId && pay.toMemberId == state.currentUserId);
      if (isBetween) {
        friendActivities.add({'type': 'payment', 'data': pay, 'date': pay.date});
      }
    }

    friendActivities.sort((a, b) => (b['date'] as DateTime).compareTo(a['date'] as DateTime));

    // Calculate direct balance
    double oneOnOneBal = 0.0;
    for (var debt in simplifiedDebts) {
      if (debt['from'].id == state.currentUserId && debt['to'].id == friendId) {
        oneOnOneBal = -debt['amount'];
      } else if (debt['to'].id == state.currentUserId && debt['from'].id == friendId) {
        oneOnOneBal = debt['amount'];
      }
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        title: Text(friend.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Summary Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: const Color(0xFF334155),
                    radius: 28,
                    child: Text(
                      friend.initials,
                      style: const TextStyle(fontSize: 22, color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          oneOnOneBal == 0
                              ? 'You are all settled up'
                              : oneOnOneBal > 0
                                  ? '${friend.name} owes you'
                                  : 'You owe ${friend.name}',
                          style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          oneOnOneBal == 0 ? '₹0.00' : '₹${oneOnOneBal.abs().toStringAsFixed(2)}',
                          style: TextStyle(
                            color: oneOnOneBal == 0
                                ? Colors.white
                                : oneOnOneBal > 0
                                    ? const Color(0xFF10B981)
                                    : const Color(0xFFF43F5E),
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Actions
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const AddExpenseScreen(),
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
                        builder: (context) => const SettleUpDialog(),
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
            const SizedBox(height: 28),

            // Transaction History
            const Text(
              'Shared History',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: friendActivities.isEmpty
                  ? const Center(
                      child: Text(
                        'No shared history yet.',
                        style: TextStyle(color: Color(0xFF94A3B8)),
                      ),
                    )
                  : ListView.builder(
                      physics: const BouncingScrollPhysics(),
                      itemCount: friendActivities.length,
                      itemBuilder: (context, index) {
                        final act = friendActivities[index];
                        final isExpense = act['type'] == 'expense';

                        if (isExpense) {
                          final exp = act['data'] as dynamic;
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
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Paid by ${payer.name == 'You' ? 'you' : payer.name}',
                                        style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
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
                        } else {
                          final pay = act['data'] as dynamic;
                          final fromM = state.members.firstWhere((m) => m.id == pay.fromMemberId);
                          final toM = state.members.firstWhere((m) => m.id == pay.toMemberId);
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
                                    color: const Color(0xFF10B981).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.check_circle_outline, color: Color(0xFF10B981), size: 20),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${fromM.name == 'You' ? 'You' : fromM.name} paid ${toM.name == 'You' ? 'you' : toM.name}',
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(height: 2),
                                      const Text(
                                        'Payment Record',
                                        style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      '₹${pay.amount.toStringAsFixed(2)}',
                                      style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${pay.date.day}/${pay.date.month}',
                                      style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        }
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
