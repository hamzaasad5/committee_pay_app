import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../../constants/app_colors.dart';

class MemberPaymentsScreen extends StatefulWidget {
  final String committeeId;
  final Map<String, dynamic> member;

  const MemberPaymentsScreen({
    super.key,
    required this.committeeId,
    required this.member,
  });

  @override
  State<MemberPaymentsScreen> createState() => _MemberPaymentsScreenState();
}

class _MemberPaymentsScreenState extends State<MemberPaymentsScreen> {
  bool _isLoading = true;
  String? _error;
  Map<String, dynamic> _committee = {};
  List<Map<String, dynamic>> _paymentsList = [];
  double remainingBalance = 0;
  double monthlyPaid = 0;

  @override
  void initState() {
    super.initState();
    _fetchCommitteeData();
  }

  /// Fetch committee and member payment data from Firebase
  Future<void> _fetchCommitteeData() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection("committees")
          .doc(widget.committeeId)
          .get();

      if (!doc.exists || doc.data() == null) {
        setState(() {
          _error = "Committee not found or no data";
          _isLoading = false;
        });
        return;
      }

      final data = doc.data()!;
      final payments = Map<String, dynamic>.from(data["membersPayments"] ?? {});
      final memberPayments =
      Map<String, dynamic>.from(payments[widget.member["uid"]] ?? {});

      final monthlyAmount = (data["monthlyAmount"] ?? 0).toDouble();
      final membersCount = (data["totalMembers"] ?? 1).toInt();
      final monthsCount = (data["monthsCount"] ?? 1);
      final isDaily = (data["type"] ?? "monthly") == "daily";
      final now = DateTime.now();

      double paidSum = 0;
      double currentMonthPaid = 0;
      List<Map<String, dynamic>> paymentsList = [];

      /// Iterate over payments
      memberPayments.forEach((key, value) {
        if (value is Map<String, dynamic> && value["amount"] != null) {
          double amt = (value["amount"] ?? 0).toDouble();

          DateTime dt;
          if (value["date"] is Timestamp) {
            dt = (value["date"] as Timestamp).toDate();
          } else {
            dt = DateTime.tryParse(value["date"]?.toString() ?? "") ??
                DateTime.now();
          }

          paidSum += amt;

          // Calculate monthly paid for daily committee
          if (isDaily && dt.year == now.year && dt.month == now.month) {
            currentMonthPaid += amt;
          }

          paymentsList.add({
            "amount": amt,
            "date": dt,
            "status": value["status"] ?? "Done",
          });
        }
      });

      // Sort payments descending by date
      paymentsList.sort((a, b) {
        final aDate = a["date"] as DateTime;
        final bDate = b["date"] as DateTime;
        return bDate.compareTo(aDate);
      });

      setState(() {
        _committee = data;
        _paymentsList = paymentsList;
        remainingBalance = (monthlyAmount * membersCount * monthsCount) - paidSum;
        monthlyPaid = currentMonthPaid;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  /// Format DateTime
  String _formatDate(DateTime date) {
    return DateFormat("dd MMMM yyyy").format(date);
  }

  /// Export payment history as PDF
  Future<void> _exportHistoryPdf() async {
    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text("Payment History for ${widget.member["name"]}",
                style:  pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 12),
            ..._paymentsList.map((payment) {
              final date = _formatDate(payment["date"]);
              final amt = payment["amount"];
              final status = payment["status"];
              return pw.Text(
                  "Rs $amt paid on $date | Payment Status: $status");
            }),
            pw.SizedBox(height: 12),
            pw.Text("Remaining Balance Overall: Rs ${remainingBalance.toStringAsFixed(0)}"),
          ],
        ),
      ),
    );

    await Printing.layoutPdf(onLayout: (format) => pdf.save());
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Text(
            _error!,
            style: const TextStyle(color: Colors.red),
          ),
        ),
      );
    }

    final memberName = widget.member["name"] ?? "Unknown";
    final isDaily = (_committee["type"] ?? "monthly") == "daily";
    final monthlyAmount = (_committee["monthlyAmount"] ?? 0).toDouble();
    final membersCount = (_committee["totalMembers"] ?? 1).toInt();

    return Scaffold(
      appBar: AppBar(
        title: Text("$memberName Payments"),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: _exportHistoryPdf,
            tooltip: "Export Payment History",
          ),
        ],
      ),
      body: Column(
        children: [
          // Balance info card
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  offset: const Offset(0, 2),
                  blurRadius: 6,
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Remaining Balance Overall: Rs ${remainingBalance.toStringAsFixed(0)}",
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Theme.of(context).colorScheme.primary),
                ),
                if (isDaily)
                  Text(
                    "This Month Remaining: Rs ${(monthlyAmount * membersCount - monthlyPaid).toStringAsFixed(0)}",
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: Theme.of(context).colorScheme.secondary),
                  ),
              ],
            ),
          ),

          // Payment history cards
          Expanded(
            child: _paymentsList.isEmpty
                ? const Center(child: Text("No payments recorded"))
                : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _paymentsList.length,
              itemBuilder: (context, index) {
                final payment = _paymentsList[index];
                final amount = payment["amount"]?.toString() ?? "-";
                final date = _formatDate(payment["date"]);
                final status = payment["status"] ?? "Done";

                final remainingMonthBalance = isDaily
                    ? (monthlyAmount * membersCount - monthlyPaid + payment["amount"])
                    : 0;

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius:
                    BorderRadius.circular(ThemeConstants.borderRadiusLarge),
                  ),
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Rs $amount paid on $date",
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Payment Status: $status",
                          style: const TextStyle(fontSize: 12, color: Colors.green),
                        ),
                        if (isDaily)
                          Text(
                            "Remaining Balance This Month: Rs ${remainingMonthBalance.toStringAsFixed(0)}",
                            style: const TextStyle(fontSize: 12),
                          ),
                        Text(
                          "Remaining Balance Overall: Rs ${remainingBalance.toStringAsFixed(0)}",
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
