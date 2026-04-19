import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';

class AddUserPayment extends StatefulWidget {
  final String committeeId;
  final String currentUserId; // Creator/admin ID
  const AddUserPayment({
    super.key,
    required this.committeeId,
    required this.currentUserId,
  });

  @override
  State<AddUserPayment> createState() => _AddUserPaymentState();
}

class _AddUserPaymentState extends State<AddUserPayment> {
  final _formKey = GlobalKey<FormState>();
  String? selectedMemberId;
  int? paymentAmount;
  DateTime? selectedDate;
  bool loading = true;
  String committeeType = "monthly";
  List<Map<String, dynamic>> members = [];
  String? committeeCreatorId;

  @override
  void initState() {
    super.initState();
    fetchCommitteeData();
  }

  Future<void> fetchCommitteeData() async {
    final doc = await FirebaseFirestore.instance
        .collection('committees')
        .doc(widget.committeeId)
        .get();

    final data = doc.data();
    if (data != null) {
      setState(() {
        committeeType = data['type'] ?? 'monthly';
        members = List<Map<String, dynamic>>.from(data['members'] ?? []);
        committeeCreatorId = data['adminId']; // Creator/admin ID
        loading = false;
      });
    } else {
      setState(() {
        members = [];
        loading = false;
      });
    }
  }

  Future<void> savePayment() async {
    if (!_formKey.currentState!.validate() || selectedMemberId == null) return;
    if (selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a payment date")),
      );
      return;
    }

    // Ensure only creator/admin can add payment
    if (committeeCreatorId != widget.currentUserId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Only the creator can add payments")),
      );
      return;
    }

    _formKey.currentState!.save();

    // Key can be YYYY-MM-DD for daily or monthly too (for proof)
    final paymentKey =
        "${selectedDate!.year}-${selectedDate!.month.toString().padLeft(2, '0')}-${selectedDate!.day.toString().padLeft(2, '0')}";

    final docRef =
    FirebaseFirestore.instance.collection('committees').doc(widget.committeeId);

    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      final data = snapshot.data() ?? {};

      Map<String, dynamic> payments = {};
      if (data['membersPayments'] != null) {
        payments = Map<String, dynamic>.from(data['membersPayments']);
      }

      Map<String, dynamic> memberPayments = {};
      if (payments[selectedMemberId!] != null) {
        memberPayments = Map<String, dynamic>.from(payments[selectedMemberId!]);
      }

      // Store amount + actual date of payment
      memberPayments[paymentKey] = {
        "amount": paymentAmount,
        "date": selectedDate,
      };
      payments[selectedMemberId!] = memberPayments;

      transaction.update(docRef, {"membersPayments": payments});
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Payment recorded successfully")),
    );

    setState(() {
      selectedMemberId = null;
      paymentAmount = null;
      selectedDate = null;
    });
  }

  Future<void> pickDate(BuildContext context) async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 5),
    );
    if (date != null) {
      setState(() {
        selectedDate = date;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Add User Payment"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              const Text(
                "Select Member",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: selectedMemberId,
                items: members.map((member) {
                  final uid = member["uid"] as String;
                  final name = member["name"] as String;
                  return DropdownMenuItem<String>(
                    value: uid,
                    child: Text(name),
                  );
                }).toList(),
                hint: const Text("Select a member"),
                onChanged: (val) => setState(() => selectedMemberId = val),
                validator: (val) => val == null ? "Please select a member" : null,
              ),
              const SizedBox(height: 16),
              const Text(
                "Payment Amount",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextFormField(
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: "Enter amount received",
                ),
                validator: (val) {
                  if (val == null || val.isEmpty) return "Enter payment amount";
                  if (int.tryParse(val) == null) return "Enter valid number";
                  return null;
                },
                onSaved: (val) => paymentAmount = int.tryParse(val!),
              ),
              const SizedBox(height: 16),
              const Text(
                "Payment Date",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: () => pickDate(context),
                child: Container(
                  padding:
                  const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade400),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    selectedDate == null
                        ? "Pick a date"
                        : "${selectedDate!.day}/${selectedDate!.month}/${selectedDate!.year}",
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: savePayment,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.goldColor,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text(
                    "Add Payment",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
