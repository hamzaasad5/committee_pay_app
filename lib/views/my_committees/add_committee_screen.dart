import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/services.dart';
import '../../providers/committees_provider.dart';

class AddCommitteeScreen extends StatefulWidget {
  final String adminId;
  const AddCommitteeScreen({super.key, required this.adminId});

  @override
  State<AddCommitteeScreen> createState() => _AddCommitteeScreenState();
}

enum CommitteeType { monthly, daily }

class _AddCommitteeScreenState extends State<AddCommitteeScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _membersController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _totalAmountController =
  TextEditingController(); // Auto-calculated total
  final TextEditingController _endDateController =
  TextEditingController(); // Auto-generated end date

  CommitteeType _type = CommitteeType.daily;

  DateTime? _startMonth;
  DateTime? _endMonth;
  DateTime? _dailyStartDate;
  DateTime? _dailyEndDate;

  int? _calculatedTotal;
  bool _isCreating = false;
  String? _generatedLink;

  // ---------------------------
  // SWITCH TYPE AND RESET FIELDS
  // ---------------------------
  void _switchType(CommitteeType type) {
    setState(() {
      _type = type;

      // Reset all fields when switching type
      _nameController.clear();
      _membersController.clear();
      _amountController.clear();
      _totalAmountController.clear();
      _endDateController.clear();
      _startMonth = null;
      _endMonth = null;
      _dailyStartDate = null;
      _dailyEndDate = null;
      _calculatedTotal = null;
      _generatedLink = null;
    });
  }

  // ---------------------------
  // DATE PICKERS
  // ---------------------------
  Future<void> _pickStartMonth() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _startMonth ?? now,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 5),
      helpText: "Select Start Month",
    );
    if (picked != null) {
      setState(() {
        _startMonth = DateTime(picked.year, picked.month);
        _autoFillEndDate();
      });
    }
  }

  Future<void> _pickDailyStart() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dailyStartDate ?? now,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 5),
      helpText: "Select Start Date",
    );
    if (picked != null) {
      setState(() {
        _dailyStartDate = picked;
        _autoFillEndDate();
      });
    }
  }

  // ---------------------------
  // CALCULATIONS
  // ---------------------------
  void _calculateTotal() {
    if (_membersController.text.isEmpty || _amountController.text.isEmpty) {
      setState(() {
        _calculatedTotal = null;
        _totalAmountController.text = '';
        _endDateController.text = '';
      });
      return;
    }

    final members = int.tryParse(_membersController.text) ?? 0;
    final amount = int.tryParse(_amountController.text) ?? 0;

    if (_type == CommitteeType.monthly) {
      _calculatedTotal = members * amount;
    } else {
      _calculatedTotal = members * amount * 30; // Daily approximate
    }

    _totalAmountController.text = _calculatedTotal.toString();
    _autoFillEndDate();
    setState(() {});
  }

  // ---------------------------
  // AUTO-GENERATE END DATE
  // ---------------------------
  void _autoFillEndDate() {
    final members = int.tryParse(_membersController.text) ?? 0;
    if (_type == CommitteeType.monthly && _startMonth != null && members > 0) {
      // End month = start month + number of members
      int endMonthNum = _startMonth!.month + members - 1;
      int year = _startMonth!.year + ((endMonthNum - 1) ~/ 12);
      int month = ((endMonthNum - 1) % 12) + 1;
      _endMonth = DateTime(year, month);
      _endDateController.text = "${_endMonth!.month}/${_endMonth!.year}";
    } else if (_type == CommitteeType.daily &&
        _dailyStartDate != null &&
        members > 0) {
      _dailyEndDate = _dailyStartDate!.add(Duration(days: members - 1));
      _endDateController.text =
      "${_dailyEndDate!.day}/${_dailyEndDate!.month}/${_dailyEndDate!.year}";
    } else {
      _endDateController.clear();
    }
  }

  // ---------------------------
  // CREATE COMMITTEE
  // ---------------------------
  Future<void> _createCommittee() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill all fields")),
      );
      return;
    }

    if (_type == CommitteeType.monthly &&
        (_startMonth == null || _endMonth == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Select start & end months")),
      );
      return;
    }

    if (_type == CommitteeType.daily &&
        (_dailyStartDate == null || _dailyEndDate == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Select start & end dates")),
      );
      return;
    }

    setState(() => _isCreating = true);

    final provider = context.read<CommitteesProvider>();

    final startDate = _type == CommitteeType.monthly ? _startMonth! : _dailyStartDate!;
    final endDate = _type == CommitteeType.monthly ? _endMonth! : _dailyEndDate!;

    // Generate unique committee code
    final committeeCode = generateCommitteeCode();

    final creatorId = widget.adminId;
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.adminId)
        .get();

    final creatorName = userDoc.exists
        ? (userDoc.data()?['name'] ?? 'Unknown') // 'name' field in your Users collection
        : 'Unknown';

    // Create committee in provider
    final id = await provider.addCommittee(
      name: _nameController.text,
      monthlyAmount: int.parse(_amountController.text),
      memberPhones: [], // Add invited members if needed
      startMonth: startDate,
      endMonth: endDate,
      type: _type == CommitteeType.monthly ? "monthly" : "daily",
      totalMembers: int.parse(_membersController.text),
      totalAmount: _calculatedTotal ?? 0,
      committeeCode: committeeCode,
      creatorId: creatorId,
      creatorName: creatorName,
    );

    if (id != null) {
      setState(() => _generatedLink = committeeCode);
    }

    setState(() => _isCreating = false);
  }



  // ---------------------------
  // UI
  // ---------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Add Committee")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            // Type Toggle
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _type == CommitteeType.monthly
                          ? Theme.of(context).primaryColor
                          : Colors.grey[300],
                    ),
                    onPressed: () => _switchType(CommitteeType.monthly),
                    child: Text(
                      "Monthly Committee",
                      style: TextStyle(
                        color: _type == CommitteeType.monthly
                            ? Colors.white
                            : Colors.black,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _type == CommitteeType.daily
                          ? Theme.of(context).primaryColor
                          : Colors.grey[300],
                    ),
                    onPressed: () => _switchType(CommitteeType.daily),
                    child: Text(
                      "Daily Committee",
                      style: TextStyle(
                        color: _type == CommitteeType.daily
                            ? Colors.white
                            : Colors.black,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            Form(
              key: _formKey,
              child: Column(
                children: [
                  // Committee Name
                  TextFormField(
                    controller: _nameController,
                    decoration:
                    const InputDecoration(labelText: "Committee Name"),
                    validator: (v) =>
                    v!.isEmpty ? "Enter committee name" : null,
                  ),
                  const SizedBox(height: 16),

                  // Total Members
                  TextFormField(
                    controller: _membersController,
                    decoration:
                    const InputDecoration(labelText: "Total Members"),
                    keyboardType: TextInputType.number,
                    validator: (v) =>
                    v!.isEmpty ? "Enter total members" : null,
                    onChanged: (_) => _calculateTotal(),
                  ),
                  const SizedBox(height: 16),

                  // Amount per member
                  TextFormField(
                    controller: _amountController,
                    decoration: InputDecoration(
                      labelText: _type == CommitteeType.monthly
                          ? "Amount per Member (Monthly)"
                          : "Daily Amount per Member",
                    ),
                    keyboardType: TextInputType.number,
                    validator: (v) => v!.isEmpty ? "Enter amount" : null,
                    onChanged: (_) => _calculateTotal(),
                  ),
                  const SizedBox(height: 16),

                  // Auto-calculated total (read-only)
                  TextFormField(
                    controller: _totalAmountController,
                    decoration: const InputDecoration(
                        labelText: "Total Amount (Auto Calculated)"),
                    readOnly: true,
                  ),
                  const SizedBox(height: 16),

                  // Auto-generated End Date (read-only)
                  TextFormField(
                    controller: _endDateController,
                    decoration: const InputDecoration(
                        labelText: "End Date (Auto Calculated)"),
                    readOnly: true,
                  ),
                  const SizedBox(height: 16),

                  // Monthly Date Range
                  if (_type == CommitteeType.monthly)
                    InkWell(
                      onTap: _pickStartMonth,
                      child: InputDecorator(
                        decoration: const InputDecoration(labelText: "Start Month"),
                        child: Text(_startMonth == null
                            ? "Select"
                            : "${_startMonth!.month}/${_startMonth!.year}"),
                      ),
                    ),

                  // Daily Committee Start
                  if (_type == CommitteeType.daily)
                    InkWell(
                      onTap: _pickDailyStart,
                      child: InputDecorator(
                        decoration: const InputDecoration(labelText: "Start Date"),
                        child: Text(_dailyStartDate == null
                            ? "Select"
                            : "${_dailyStartDate!.day}/${_dailyStartDate!.month}/${_dailyStartDate!.year}"),
                      ),
                    ),

                  const SizedBox(height: 30),

                  // Create button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isCreating ? null : _createCommittee,
                      child: _isCreating
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text("Create Committee"),
                    ),
                  ),

                  // Generated link
                  if (_generatedLink != null) ...[
                    const SizedBox(height: 24),
                    const Text("Invitation Link",
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    Card(
                      child: ListTile(
                        title: Text(_generatedLink!),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.copy),
                              onPressed: () {
                                Clipboard.setData(
                                    ClipboardData(text: _generatedLink!));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text("Link copied!")),
                                );
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.share),
                              onPressed: () => Share.share(
                                  "Join my committee: $_generatedLink"),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}



String generateCommitteeCode() {
  const chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
  final random = List.generate(5, (index) {
    final i = DateTime.now().millisecondsSinceEpoch + index;
    return chars[i % chars.length];
  }).join();
  return "CT-$random";
}
