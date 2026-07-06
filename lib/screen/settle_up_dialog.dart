import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../state/state_manager.dart';

class SettleUpDialog extends StatefulWidget {
  final String? initialGroupId;
  const SettleUpDialog({Key? key, this.initialGroupId}) : super(key: key);

  @override
  State<SettleUpDialog> createState() => _SettleUpDialogState();
}

class _SettleUpDialogState extends State<SettleUpDialog> {
  final _formKey = GlobalKey<FormState>();
  String? _fromMemberId;
  String? _toMemberId;
  String? _groupId;
  double _amount = 0.0;

  @override
  void initState() {
    super.initState();
    _groupId = widget.initialGroupId;
    final state = Provider.of<StateManager>(context, listen: false);
    
    // Default payers: 'm2' (Amit) pays 'm1' (You)
    _fromMemberId = state.currentUserId == 'm1' && state.members.length > 1 ? 'm2' : state.currentUserId;
    _toMemberId = state.currentUserId;
  }

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<StateManager>(context);
    final members = state.members;
    final groups = state.groups;

    return AlertDialog(
      backgroundColor: const Color(0xFF1E293B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          const Icon(Icons.payment, color: Color(0xFF10B981)),
          const SizedBox(width: 10),
          const Text(
            'Record Payment',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ],
      ),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // From member selector
              DropdownButtonFormField<String>(
                value: _fromMemberId,
                dropdownColor: const Color(0xFF1E293B),
                decoration: const InputDecoration(
                  labelText: 'Who Paid?',
                  labelStyle: TextStyle(color: Color(0xFF94A3B8)),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF334155))),
                ),
                style: const TextStyle(color: Colors.white),
                items: members.map((m) {
                  return DropdownMenuItem(
                    value: m.id,
                    child: Text(m.name == 'You' ? 'You' : m.name),
                  );
                }).toList(),
                onChanged: (val) {
                  setState(() {
                    _fromMemberId = val;
                  });
                },
              ),
              const SizedBox(height: 12),

              // To member selector
              DropdownButtonFormField<String>(
                value: _toMemberId,
                dropdownColor: const Color(0xFF1E293B),
                decoration: const InputDecoration(
                  labelText: 'Who Received?',
                  labelStyle: TextStyle(color: Color(0xFF94A3B8)),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF334155))),
                ),
                style: const TextStyle(color: Colors.white),
                items: members.map((m) {
                  return DropdownMenuItem(
                    value: m.id,
                    child: Text(m.name == 'You' ? 'You' : m.name),
                  );
                }).toList(),
                onChanged: (val) {
                  setState(() {
                    _toMemberId = val;
                  });
                },
              ),
              const SizedBox(height: 12),

              // Group selector (optional)
              DropdownButtonFormField<String?>(
                value: _groupId,
                dropdownColor: const Color(0xFF1E293B),
                decoration: const InputDecoration(
                  labelText: 'Group (Optional)',
                  labelStyle: TextStyle(color: Color(0xFF94A3B8)),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF334155))),
                ),
                style: const TextStyle(color: Colors.white),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('No Group (Individual)'),
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
                  });
                },
              ),
              const SizedBox(height: 16),

              // Amount input
              TextFormField(
                style: const TextStyle(color: Colors.white, fontSize: 20),
                decoration: const InputDecoration(
                  prefixText: '₹ ',
                  prefixStyle: TextStyle(color: Color(0xFF10B981), fontSize: 20),
                  labelText: 'Amount Paid',
                  labelStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF334155))),
                  focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF10B981))),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (val) {
                  if (val == null || val.isEmpty) return 'Please enter amount';
                  final num = double.tryParse(val);
                  if (num == null || num <= 0) return 'Enter a valid amount';
                  return null;
                },
                onSaved: (val) {
                  _amount = double.parse(val!);
                },
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
            if (_formKey.currentState!.validate()) {
              _formKey.currentState!.save();
              
              if (_fromMemberId == _toMemberId) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Payer and Recipient cannot be the same person.')),
                );
                return;
              }

              final payment = Payment(
                id: 'p${state.payments.length + 1}',
                fromMemberId: _fromMemberId!,
                toMemberId: _toMemberId!,
                amount: _amount,
                date: DateTime.now(),
                groupId: _groupId,
              );

              state.addPayment(payment);
              Navigator.pop(context);
              
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: const Color(0xFF10B981),
                  content: Text('Recorded payment of ₹${_amount.toStringAsFixed(2)}!'),
                ),
              );
            }
          },
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
          child: const Text('Save Payment', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
