import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../state/state_manager.dart';

class AddExpenseScreen extends StatefulWidget {
  final String? preselectedGroupId;
  const AddExpenseScreen({Key? key, this.preselectedGroupId}) : super(key: key);

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();

  String? _groupId;
  String? _paidById;
  SplitType _splitType = SplitType.equal;

  // Track checked members and custom amounts
  final Map<String, bool> _splitMembersSelected = {};
  final Map<String, TextEditingController> _customAmountControllers = {};

  @override
  void initState() {
    super.initState();
    _groupId = widget.preselectedGroupId;
    final state = Provider.of<StateManager>(context, listen: false);
    _paidById = state.currentUserId;

    _updateSelectedMembersForGroup(state);
  }

  void _updateSelectedMembersForGroup(StateManager state) {
    // Determine which members are in the selected group (or all members if no group)
    List<String> memberIds;
    if (_groupId != null) {
      final grp = state.groups.firstWhere((g) => g.id == _groupId);
      memberIds = grp.memberIds;
    } else {
      memberIds = state.members.map((m) => m.id).toList();
    }

    _splitMembersSelected.clear();
    _customAmountControllers.forEach((key, controller) => controller.dispose());
    _customAmountControllers.clear();

    for (var mId in memberIds) {
      _splitMembersSelected[mId] = true;
      _customAmountControllers[mId] = TextEditingController(text: '0.00');
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _amountController.dispose();
    _customAmountControllers.forEach((key, controller) => controller.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<StateManager>(context);
    final groups = state.groups;
    final members = state.members;

    // Filter potential payers / splitters based on group selection
    final List<Member> activeMembers = _groupId != null
        ? state.members.where((m) => state.groups.firstWhere((g) => g.id == _groupId).memberIds.contains(m.id)).toList()
        : state.members;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Add Expense', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Group selector
              DropdownButtonFormField<String?>(
                value: _groupId,
                dropdownColor: const Color(0xFF1E293B),
                decoration: InputDecoration(
                  labelText: 'Select Group',
                  labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
                  filled: true,
                  fillColor: const Color(0xFF1E293B),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
                style: const TextStyle(color: Colors.white),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('Individual (No Group)'),
                  ),
                  ...groups.map((g) {
                    return DropdownMenuItem<String?>(
                      value: g.id,
                      child: Text(g.name),
                    );
                  }).toList(),
                ],
                onChanged: (val) {
                  setState(() {
                    _groupId = val;
                    if (_paidById != null && activeMembers.isNotEmpty) {
                      // Validate if current paidById is in the new group, otherwise switch
                      final hasPayer = activeMembers.any((m) => m.id == _paidById);
                      if (!hasPayer) {
                        _paidById = activeMembers.first.id;
                      }
                    }
                    _updateSelectedMembersForGroup(state);
                  });
                },
              ),
              const SizedBox(height: 16),

              // Description input
              TextFormField(
                controller: _descriptionController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Description',
                  labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
                  hintText: 'e.g. Groceries, Dinner, Rent',
                  hintStyle: const TextStyle(color: Color(0xFF475569)),
                  filled: true,
                  fillColor: const Color(0xFF1E293B),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
                validator: (val) {
                  if (val == null || val.isEmpty) return 'Please enter description';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Amount input
              TextFormField(
                controller: _amountController,
                style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Amount',
                  labelStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 16),
                  prefixText: '₹ ',
                  prefixStyle: const TextStyle(color: Color(0xFF0D9488), fontSize: 24, fontWeight: FontWeight.bold),
                  filled: true,
                  fillColor: const Color(0xFF1E293B),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
                validator: (val) {
                  if (val == null || val.isEmpty) return 'Please enter amount';
                  final num = double.tryParse(val);
                  if (num == null || num <= 0) return 'Enter a valid amount';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Payer Selector
              DropdownButtonFormField<String>(
                value: _paidById,
                dropdownColor: const Color(0xFF1E293B),
                decoration: InputDecoration(
                  labelText: 'Who Paid?',
                  labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
                  filled: true,
                  fillColor: const Color(0xFF1E293B),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
                style: const TextStyle(color: Colors.white),
                items: activeMembers.map((m) {
                  return DropdownMenuItem(
                    value: m.id,
                    child: Text(m.name == 'You' ? 'You' : m.name),
                  );
                }).toList(),
                onChanged: (val) {
                  setState(() {
                    _paidById = val;
                  });
                },
              ),
              const SizedBox(height: 24),

              // Split Options Section
              const Text(
                'Split Details',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      label: const Text('Split Equally'),
                      selected: _splitType == SplitType.equal,
                      selectedColor: const Color(0xFF0D9488),
                      backgroundColor: const Color(0xFF1E293B),
                      labelStyle: TextStyle(
                        color: _splitType == SplitType.equal ? Colors.white : const Color(0xFF94A3B8),
                        fontWeight: FontWeight.bold,
                      ),
                      onSelected: (selected) {
                        if (selected) setState(() => _splitType = SplitType.equal);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ChoiceChip(
                      label: const Text('Exact Amounts'),
                      selected: _splitType == SplitType.exact,
                      selectedColor: const Color(0xFF0D9488),
                      backgroundColor: const Color(0xFF1E293B),
                      labelStyle: TextStyle(
                        color: _splitType == SplitType.exact ? Colors.white : const Color(0xFF94A3B8),
                        fontWeight: FontWeight.bold,
                      ),
                      onSelected: (selected) {
                        if (selected) setState(() => _splitType = SplitType.exact);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Split lists
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.all(12),
                child: ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: activeMembers.length,
                  itemBuilder: (context, index) {
                    final member = activeMembers[index];
                    final isChecked = _splitMembersSelected[member.id] ?? false;

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: Row(
                        children: [
                          if (_splitType == SplitType.equal)
                            Checkbox(
                              value: isChecked,
                              activeColor: const Color(0xFF0D9488),
                              onChanged: (val) {
                                setState(() {
                                  _splitMembersSelected[member.id] = val ?? false;
                                });
                              },
                            )
                          else
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 16.0),
                              child: Icon(Icons.person, color: Color(0xFF94A3B8)),
                            ),
                          Expanded(
                            child: Text(
                              member.name == 'You' ? 'You' : member.name,
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: isChecked || _splitType == SplitType.exact ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          ),
                          if (_splitType == SplitType.exact)
                            SizedBox(
                              width: 100,
                              height: 40,
                              child: TextFormField(
                                controller: _customAmountControllers[member.id],
                                style: const TextStyle(color: Colors.white, fontSize: 14),
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                textAlign: TextAlign.right,
                                decoration: const InputDecoration(
                                  prefixText: '₹ ',
                                  prefixStyle: TextStyle(color: Color(0xFF94A3B8)),
                                  contentPadding: EdgeInsets.symmetric(vertical: 8),
                                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF334155))),
                                  focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF0D9488))),
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 32),

              // Save button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    if (_formKey.currentState!.validate()) {
                      final amount = double.parse(_amountController.text);
                      final Map<String, double> splits = {};

                      if (_splitType == SplitType.equal) {
                        final selectedCount = _splitMembersSelected.values.where((v) => v).length;
                        if (selectedCount == 0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Please select at least one person to split the expense with.')),
                          );
                          return;
                        }

                        // Populate map with selected members
                        for (var entry in _splitMembersSelected.entries) {
                          if (entry.value) {
                            splits[entry.key] = 0.0; // split equally later in state
                          }
                        }
                      } else {
                        // Exact split verification
                        double totalEntered = 0.0;
                        for (var entry in _customAmountControllers.entries) {
                          final share = double.tryParse(entry.value.text) ?? 0.0;
                          if (share < 0) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Splits cannot have negative values.')),
                            );
                            return;
                          }
                          if (share > 0) {
                            splits[entry.key] = share;
                            totalEntered += share;
                          }
                        }

                        // Check if total matches
                        if ((totalEntered - amount).abs() > 0.05) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Total split amount (₹${totalEntered.toStringAsFixed(2)}) does not match the expense amount (₹${amount.toStringAsFixed(2)})'),
                            ),
                          );
                          return;
                        }
                      }

                      final expense = Expense(
                        id: 'e${state.expenses.length + 1}',
                        description: _descriptionController.text.trim(),
                        amount: amount,
                        date: DateTime.now(),
                        paidById: _paidById!,
                        splitType: _splitType,
                        splits: splits,
                        groupId: _groupId,
                      );

                      state.addExpense(expense);
                      Navigator.pop(context);
                      
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: const Color(0xFF0D9488),
                          content: Text('Added expense: ${expense.description}!'),
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0D9488),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text(
                    'Save Expense',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
