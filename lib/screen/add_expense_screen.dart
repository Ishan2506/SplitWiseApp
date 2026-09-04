import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../state/state_manager.dart';
import '../theme/app_theme.dart';
import '../utils/app_constants.dart';
import '../widgets/common_widgets.dart';

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
  final _notesController = TextEditingController();

  String? _groupId;
  String? _paidById;
  String _selectedCategory = 'Food & drink';
  DateTime _selectedDate = DateTime.now();
  SplitType _splitType = SplitType.equal;

  bool _isSaving = false;
  final Map<String, bool> _splitMembersSelected = {};
  final Map<String, TextEditingController> _customAmountControllers = {};

  final List<String> _categories = [
    'Food & drink',
    'Travel',
    'Accommodation',
    'Entertainment',
    'Other'
  ];

  @override
  void initState() {
    super.initState();
    _groupId = widget.preselectedGroupId;
    final state = Provider.of<StateManager>(context, listen: false);
    _paidById = state.currentUserId;
    _updateSelectedMembersForGroup(state);
  }

  void _updateSelectedMembersForGroup(StateManager state) {
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

  Future<void> _saveExpense() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final state = Provider.of<StateManager>(context, listen: false);
    final amount = double.parse(_amountController.text.trim());
    final selectedSplitMembers = _splitMembersSelected.entries
        .where((e) => e.value)
        .map((e) => e.key)
        .toList();

    try {
      final expense = Expense(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        description: _descriptionController.text.trim(),
        amount: amount,
        date: _selectedDate,
        paidById: _paidById!,
        splitType: _splitType,
        splits: _calculateSplits(amount, selectedSplitMembers),
        groupId: _groupId,
      );

      state.addExpense(expense);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppColors.primaryAccent,
            content: Text('Expense saved!'),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.error,
            content: Text('Error: $e'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Map<String, double> _calculateSplits(double total, List<String> members) {
    if (members.isEmpty) return {};
    if (_splitType == SplitType.equal) {
      final perMember = total / members.length;
      return {for (var m in members) m: perMember};
    }
    return {for (var m in members) m: double.tryParse(_customAmountControllers[m]?.text ?? '0') ?? 0};
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    _customAmountControllers.forEach((key, controller) => controller.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<StateManager>(context);
    final groups = state.groups;
    final members = state.members;

    final List<Member> activeMembers = _groupId != null
        ? members.where((m) => groups.firstWhere((g) => g.id == _groupId).memberIds.contains(m.id)).toList()
        : members;

    return Scaffold(
      backgroundColor: const Color(0xFFFFFFFF),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with gradient background
                Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment(0.0, -0.5),
                      end: Alignment(0.0, 1.0),
                      colors: [
                        Color(0xFFFFE3EC),
                        Color(0xFFFDF1F4),
                      ],
                    ),
                  ),
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Cancel, Title, Scan buttons
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: Text(
                              'Cancel',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF96707E),
                              ),
                            ),
                          ),
                          Text(
                            'Add expense',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: AppColors.textPrimary,
                                ),
                          ),
                          GestureDetector(
                            onTap: () {},
                            child: Text(
                              'Scan',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFFC2607C),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      // Amount input section
                      Column(
                        children: [
                          Text(
                            'AMOUNT',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF96707E),
                              letterSpacing: 0.06,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '₹',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                  height: 1.3,
                                ),
                              ),
                              Expanded(
                                child: TextField(
                                  controller: _amountController,
                                  textAlign: TextAlign.center,
                                  keyboardType: TextInputType.number,
                                  style: const TextStyle(
                                    fontSize: 48,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.textPrimary,
                                  ),
                                  decoration: const InputDecoration(
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.zero,
                                    hintText: '0',
                                    hintStyle: TextStyle(
                                      fontSize: 48,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFFE8D0D9),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Form Fields
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title
                      Text(
                        'Title',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      PSTextField(
                        label: '',
                        placeholder: 'Beach shack dinner',
                        controller: _descriptionController,
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Please enter expense title';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: AppSpacing.lg),

                      // Category & Date
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Category',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.md),
                                Container(
                                  height: 50,
                                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                                  decoration: BoxDecoration(
                                    color: AppColors.inputBg,
                                    borderRadius: BorderRadius.circular(AppRadius.lg),
                                    border: Border.all(color: AppColors.border),
                                  ),
                                  child: DropdownButton<String>(
                                    value: _selectedCategory,
                                    isExpanded: true,
                                    underline: const SizedBox(),
                                    onChanged: (val) {
                                      if (val != null) setState(() => _selectedCategory = val);
                                    },
                                    items: _categories
                                        .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                                        .toList(),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: AppSpacing.lg),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Date',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.md),
                                GestureDetector(
                                  onTap: () async {
                                    final picked = await showDatePicker(
                                      context: context,
                                      initialDate: _selectedDate,
                                      firstDate: DateTime(2020),
                                      lastDate: DateTime.now(),
                                    );
                                    if (picked != null) {
                                      setState(() => _selectedDate = picked);
                                    }
                                  },
                                  child: Container(
                                    height: 50,
                                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                                    decoration: BoxDecoration(
                                      color: AppColors.inputBg,
                                      borderRadius: BorderRadius.circular(AppRadius.lg),
                                      border: Border.all(color: AppColors.border),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          '${_selectedDate.day} ${_getMonthName(_selectedDate.month)}',
                                          style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                        const Icon(Icons.expand_more, color: AppColors.muted),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.lg),

                      // Notes
                      Text(
                        'Notes',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      PSTextField(
                        label: '',
                        placeholder: 'Curry Grill, table for five',
                        controller: _notesController,
                      ),
                      const SizedBox(height: AppSpacing.lg),

                      // Paid by
                      Text(
                        'Paid by',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: activeMembers.map((member) {
                            final isSelected = _paidById == member.id;
                            return GestureDetector(
                              onTap: () => setState(() => _paidById = member.id),
                              child: Container(
                                margin: const EdgeInsets.only(right: AppSpacing.md),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.lg,
                                  vertical: AppSpacing.sm,
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected ? AppColors.textPrimary : Colors.transparent,
                                  borderRadius: BorderRadius.circular(AppRadius.pill),
                                  border: isSelected ? null : Border.all(color: AppColors.border),
                                ),
                                child: Text(
                                  member.name,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: isSelected ? Colors.white : AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xxl),

                      // Split between
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Split between · ${_splitMembersSelected.values.where((v) => v).length} of ${activeMembers.length}',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                final allSelected =
                                    _splitMembersSelected.values.every((v) => v);
                                for (var key in _splitMembersSelected.keys) {
                                  _splitMembersSelected[key] = !allSelected;
                                }
                              });
                            },
                            child: Text(
                              'Select all',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primaryAccent,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Column(
                        children: activeMembers.map((member) {
                          final isSelected = _splitMembersSelected[member.id] ?? false;
                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                _splitMembersSelected[member.id] =
                                    !(_splitMembersSelected[member.id] ?? false);
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.lg,
                                vertical: AppSpacing.md,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.inputBg,
                                borderRadius: BorderRadius.circular(AppRadius.lg),
                                border: isSelected ? Border.all(color: AppColors.primaryAccent) : null,
                              ),
                              margin: const EdgeInsets.only(bottom: AppSpacing.md),
                              child: Row(
                                children: [
                                  Container(
                                    width: 22,
                                    height: 22,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(AppRadius.sm),
                                      color: isSelected ? AppColors.primaryAccent : Colors.transparent,
                                      border: isSelected ? null : Border.all(color: AppColors.border),
                                    ),
                                    child: isSelected
                                        ? const Icon(Icons.check, size: 14, color: Colors.white)
                                        : null,
                                  ),
                                  const SizedBox(width: AppSpacing.lg),
                                  Expanded(
                                    child: Text(
                                      member.name,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    _amountController.text.isEmpty
                                        ? '₹0'
                                        : '₹${(double.parse(_amountController.text) / activeMembers.length).toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: AppSpacing.xxl),

                      // Save button
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.lg,
                                vertical: AppSpacing.sm,
                              ),
                              decoration: BoxDecoration(
                                border: Border.all(color: AppColors.border),
                                borderRadius: BorderRadius.circular(AppRadius.pill),
                              ),
                              child: Text(
                                'Split ▾',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.lg),
                          Expanded(
                            child: PSButton(
                              label: 'Save expense',
                              onPressed: _isSaving ? () {} : _saveExpense,
                              isLoading: _isSaving,
                              isPrimary: true,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getMonthName(int month) {
    const months = [
      'JAN',
      'FEB',
      'MAR',
      'APR',
      'MAY',
      'JUN',
      'JUL',
      'AUG',
      'SEP',
      'OCT',
      'NOV',
      'DEC'
    ];
    return months[month - 1];
  }
}
