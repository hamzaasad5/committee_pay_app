import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import '../../../constants/app_colors.dart';
import '../../../widgets/custom_app_bar.dart';

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
  bool _isAdmin = false;
  String? _currentUserId;

  // Summary statistics
  double _totalPaid = 0;
  double _remainingBalance = 0;
  double _totalCommitteeBalance = 0;
  double _committeePaidBalance = 0;
  double _committeeRemainingBalance = 0;
  double _monthlyContribution = 0;
  int _totalMonths = 0;
  int _paidMonths = 0;

  @override
  void initState() {
    super.initState();
    _getCurrentUserAndFetchData();
  }

  Future<void> _getCurrentUserAndFetchData() async {
    final auth = FirebaseAuth.instance;
    _currentUserId = auth.currentUser?.uid;
    await _fetchCommitteeData();
  }

  Future<void> _fetchCommitteeData() async {
    try {
      print('========== FETCHING COMMITTEE DATA ==========');
      print('Committee ID: ${widget.committeeId}');
      print('Current User ID: $_currentUserId');
      print('Widget Member: ${widget.member}');

      final doc = await FirebaseFirestore.instance
          .collection("committees")
          .doc(widget.committeeId)
          .get();

      if (!doc.exists) {
        print('❌ Committee not found');
        setState(() {
          _error = "Committee not found";
          _isLoading = false;
        });
        return;
      }

      final data = doc.data();
      if (data == null) {
        print('❌ Committee data is null');
        setState(() {
          _error = "Invalid committee data";
          _isLoading = false;
        });
        return;
      }

      print('✅ Committee data loaded');
      print('Committee name: ${data["name"]}');
      print('Admin ID: ${data["adminId"]}');
      print('Admin Name: ${data["adminName"]}');

      // Check if current user is admin
      _isAdmin = data["adminId"] == _currentUserId;
      print('Is Admin: $_isAdmin');

      // Safely get membersPayments
      final payments = data["membersPayments"];
      print('Members Payments type: ${payments.runtimeType}');
      print('Members Payments: $payments');

      final Map<String, dynamic> membersPayments = payments != null && payments is Map
          ? Map<String, dynamic>.from(payments)
          : {};

      print('Parsed membersPayments keys: ${membersPayments.keys.toList()}');

      // Get all members from committee
      final members = data["members"];
      print('Members list type: ${members.runtimeType}');
      print('Members list: $members');

      // Safely get member UID
      final memberUid = widget.member["uid"]?.toString();
      print('Member UID from widget: $memberUid');

      if (memberUid == null && !_isAdmin) {
        print('❌ Member data not found and not admin');
        setState(() {
          _error = "Member data not found";
          _isLoading = false;
        });
        return;
      }

      // Determine which payments to show
      Map<String, dynamic> relevantPayments = {};
      if (_isAdmin) {
        // Admin sees all payments
        print('📋 Admin view - showing all payments');
        relevantPayments = membersPayments;
      } else {
        // Regular user sees only their own payments
        print('👤 User view - showing only user payments');
        final userPayments = membersPayments[memberUid];
        print('User payments for $memberUid: $userPayments');
        if (userPayments != null && userPayments is Map) {
          relevantPayments = Map<String, dynamic>.from(userPayments);
        }
      }

      _monthlyContribution = (data["monthlyAmount"] ?? 0).toDouble();
      final membersCount = (data["totalMembers"] ?? 1).toInt();
      final totalMonths = (data["monthsCount"] ?? 1).toInt();

      print('Monthly Contribution: $_monthlyContribution');
      print('Members Count: $membersCount');
      print('Total Months: $totalMonths');

      // Calculate total committee balances
      _totalCommitteeBalance = _monthlyContribution * membersCount;
      print('Total Committee Balance: $_totalCommitteeBalance');

      double totalCommitteePaid = 0;
      membersPayments.forEach((memberId, memberPayment) {
        print('Processing member payment for ID: $memberId');
        if (memberPayment is Map) {
          print('Member payment keys: ${memberPayment.keys.toList()}');
          memberPayment.forEach((key, value) {
            if (value is Map && value["amount"] != null) {
              double amount = (value["amount"] as num).toDouble();
              totalCommitteePaid += amount;
              print('  - Payment $key: $amount');
            }
          });
        }
      });

      _committeePaidBalance = totalCommitteePaid;
      _committeeRemainingBalance = _totalCommitteeBalance - totalCommitteePaid;
      print('Committee Paid Balance: $_committeePaidBalance');
      print('Committee Remaining Balance: $_committeeRemainingBalance');

      double totalPaid = 0;
      int paidMonths = 0;
      List<Map<String, dynamic>> paymentsList = [];

      // Process payments based on role
      if (_isAdmin) {
        print('========== PROCESSING ADMIN PAYMENTS ==========');
        // Admin: Show all payments from all members
        membersPayments.forEach((memberId, memberPayment) {
          print('\n--- Processing payments for member ID: $memberId ---');
          print('Member payment data: $memberPayment');

          if (memberPayment is Map) {
            memberPayment.forEach((key, value) {
              if (value is Map<String, dynamic> && value["amount"] != null) {
                double amount = (value["amount"] ?? 0).toDouble();
                totalPaid += amount;
                paidMonths++;
                print('  - Payment key: $key, amount: $amount');

                DateTime paymentDate;
                if (value["date"] is Timestamp) {
                  paymentDate = (value["date"] as Timestamp).toDate();
                  print('  - Date (Timestamp): $paymentDate');
                } else if (value["date"] is String) {
                  paymentDate = DateTime.tryParse(value["date"]) ?? DateTime.now();
                  print('  - Date (String): $paymentDate');
                } else {
                  paymentDate = DateTime.now();
                  print('  - Date (Default): $paymentDate');
                }

                // Get member name safely
                print('  - Getting member name for ID: $memberId');
                final memberName = _getMemberName(memberId);
                print('  - Member name found: $memberName');

                paymentsList.add({
                  "amount": amount,
                  "date": paymentDate,
                  "status": value["status"] ?? "completed",
                  "memberName": memberName,
                  "memberId": memberId,
                  "paymentKey": key,
                });
              } else {
                print('  - Value is not a Map or missing amount: $value');
              }
            });
          } else {
            print('  - memberPayment is not a Map: $memberPayment');
          }
        });
      } else {
        print('========== PROCESSING USER PAYMENTS ==========');
        // Regular user: Show only their own payments
        relevantPayments.forEach((key, value) {
          print('Processing payment key: $key, value: $value');
          if (value is Map<String, dynamic> && value["amount"] != null) {
            double amount = (value["amount"] ?? 0).toDouble();
            totalPaid += amount;
            paidMonths++;
            print('  - Amount: $amount');

            DateTime paymentDate;
            if (value["date"] is Timestamp) {
              paymentDate = (value["date"] as Timestamp).toDate();
              print('  - Date (Timestamp): $paymentDate');
            } else if (value["date"] is String) {
              paymentDate = DateTime.tryParse(value["date"]) ?? DateTime.now();
              print('  - Date (String): $paymentDate');
            } else {
              paymentDate = DateTime.now();
              print('  - Date (Default): $paymentDate');
            }

            paymentsList.add({
              "amount": amount,
              "date": paymentDate,
              "status": value["status"] ?? "completed",
              "paymentKey": key,
            });
          } else {
            print('  - Value is not a Map or missing amount: $value');
          }
        });
      }

      // Sort payments by date (newest first)
      paymentsList.sort((a, b) =>
          (b["date"] as DateTime).compareTo(a["date"] as DateTime)
      );

      print('\n========== SUMMARY ==========');
      print('Total Payments Found: ${paymentsList.length}');
      print('Total Paid: $totalPaid');
      print('Paid Months: $paidMonths');

      final expectedTotal = _monthlyContribution * totalMonths;
      print('Expected Total: $expectedTotal');
      print('Remaining Balance: ${expectedTotal - totalPaid}');

      setState(() {
        _committee = data;
        _paymentsList = paymentsList;
        _totalPaid = totalPaid;
        _remainingBalance = expectedTotal - totalPaid;
        _totalMonths = totalMonths;
        _paidMonths = paidMonths;
        _isLoading = false;
      });

      print('========== DATA LOAD COMPLETE ==========\n');
    } catch (e) {
      print('❌ ERROR fetching committee data: $e');
      print('Stack trace: ${StackTrace.current}');
      setState(() {
        _error = "Failed to load payment data: ${e.toString()}";
        _isLoading = false;
      });
    }
  }

  String _getMemberName(String memberId) {
    try {
      print('🔍 Getting name for memberId: $memberId');

      final members = _committee["members"];
      print('  - Members list type: ${members.runtimeType}');
      print('  - Members list: $members');

      if (members != null && members is List) {
        print('  - Searching through ${members.length} members');
        for (int i = 0; i < members.length; i++) {
          final member = members[i];
          if (member is Map) {
            final uid = member["uid"]?.toString();
            final phone = member["phone"]?.toString();
            final name = member["name"];
            print('    Member $i - uid: $uid, phone: $phone, name: $name');

            if (uid == memberId || phone == memberId) {
              print('  ✅ Found match: $name');
              return name ?? "Unknown Member";
            }
          } else {
            print('    Member $i is not a Map: ${member.runtimeType}');
          }
        }
      } else {
        print('  - Members list is null or not a List');
      }

      // If not found in members, check if this is the admin
      final adminId = _committee["adminId"]?.toString();
      print('  - Admin ID: $adminId, comparing with: $memberId');

      if (adminId == memberId) {
        final adminName = _committee["adminName"];
        print('  ✅ Found admin: $adminName');
        return adminName ?? "Admin";
      }

      // Check if it's the current user
      if (_currentUserId == memberId) {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          print('  ✅ Found current user: ${user.displayName}');
          return user.displayName ?? "Current User";
        }
      }

      // Check if it's the member from the widget
      if (widget.member["uid"] == memberId) {
        final widgetMemberName = widget.member["name"];
        print('  ✅ Found in widget member: $widgetMemberName');
        return widgetMemberName ?? "Unknown Member";
      }

      print('  ❌ No match found for memberId: $memberId');
      return "Unknown Member";
    } catch (e) {
      print('❌ Error getting member name: $e');
      print('Stack trace: ${StackTrace.current}');
      return "Unknown Member";
    }
  }



  String _formatDateTime(DateTime date) {
    return DateFormat("dd MMM yyyy, hh:mm a").format(date);
  }

  String _formatDateOnly(DateTime date) {
    return DateFormat("dd MMM yyyy").format(date);
  }

  String _formatTimeOnly(DateTime date) {
    return DateFormat("hh:mm a").format(date);
  }

  String _formatCurrency(double amount) {
    return '\$${amount.toStringAsFixed(0)}';
  }

  Future<void> _exportToPDF() async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Center(
              child: pw.Text(
                "Payment History",
                style: pw.TextStyle(
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            pw.SizedBox(height: 20),
            pw.Text(
              _isAdmin
                  ? "Committee: ${_committee["name"] ?? "Unknown"}"
                  : "Member: ${widget.member["name"] ?? "Unknown"}",
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
            ),
            pw.Text("Committee: ${_committee["name"] ?? "Unknown"}"),
            pw.SizedBox(height: 20),

            // Summary Section
            pw.Container(
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text("Payment Summary",
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 8),
                  pw.Text("Total Paid: ${_formatCurrency(_totalPaid)}"),
                  if (!_isAdmin)
                    pw.Text("Remaining Balance: ${_formatCurrency(_remainingBalance)}"),
                  pw.Text("Paid: $_paidMonths of $_totalMonths months"),
                ],
              ),
            ),

            pw.SizedBox(height: 20),
            pw.Text("Payment History",
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 10),

            // Payments List
            ..._paymentsList.map((payment) {
              return pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 8),
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    if (_isAdmin && payment["memberName"] != null)
                      pw.Text(
                        "Member: ${payment["memberName"]}",
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                    pw.SizedBox(height: 4),
                    pw.Text(_formatDateTime(payment["date"])),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      "Amount: ${_formatCurrency(payment["amount"])}",
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) => pdf.save(),
      name: 'payment_history_${_isAdmin ? _committee["name"] : widget.member["name"]}',
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppColors.bg,
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: AppColors.goldColor),
              SizedBox(height: 16),
              Text(
                "Loading payment history...",
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: AppColors.bg,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.red.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.error_outline,
                  size: 48,
                  color: AppColors.red,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _error!,
                style: const TextStyle(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _fetchCommitteeData,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.goldColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppColors.r12),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                child: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    final title = _isAdmin ? "All Payments" : "Payment History";
    final subtitle = _isAdmin ? _committee["name"] ?? "Committee" : widget.member["name"] ?? "Unknown Member";

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: CustomAppBar(
        title: title,
        showBackButton: true,
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.picture_as_pdf, color: AppColors.goldColor),
            onPressed: _paymentsList.isEmpty ? null : _exportToPDF,
            tooltip: "Export as PDF",
          ),
        ],
      ),
      body: Column(
        children: [
          // Committee Balance Card
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surfaceDark,
              borderRadius: BorderRadius.circular(AppColors.r16),
              border: Border.all(color: AppColors.goldColor.withOpacity(0.3)),
            ),
            child: Column(
              children: [
                const Text(
                  "Committee Balance",
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _formatCurrency(_totalCommitteeBalance),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            _formatCurrency(_committeePaidBalance),
                            style: const TextStyle(
                              color: AppColors.green,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Text(
                            "Paid",
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 30,
                      color: AppColors.border,
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            _formatCurrency(_committeeRemainingBalance),
                            style: const TextStyle(
                              color: AppColors.orange,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Text(
                            "Remaining",
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Member Balance Card (only for non-admin users)
          if (!_isAdmin)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: _buildBalanceCard(
                      label: "Total Paid",
                      value: _formatCurrency(_totalPaid),
                      icon: Icons.payment,
                      color: AppColors.green,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildBalanceCard(
                      label: "Remaining",
                      value: _formatCurrency(_remainingBalance),
                      icon: Icons.account_balance_wallet,
                      color: AppColors.orange,
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 16),

          // Payment History Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Payment History",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.goldSoft,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    "${_paymentsList.length} payment${_paymentsList.length != 1 ? 's' : ''}",
                    style: const TextStyle(
                      color: AppColors.goldColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Payment History List
          Expanded(
            child: _paymentsList.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppColors.goldSoft,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.receipt_long,
                      size: 48,
                      color: AppColors.goldColor,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    "No Payment History",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isAdmin
                        ? "No payments have been made yet"
                        : "You haven't made any payments yet",
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
                : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _paymentsList.length,
              itemBuilder: (context, index) {
                final payment = _paymentsList[index];
                final date = payment["date"] as DateTime;
                final amount = payment["amount"] as double;
                final isLatest = index == 0;

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceDark,
                    borderRadius: BorderRadius.circular(AppColors.r16),
                    border: Border.all(
                      color: isLatest
                          ? AppColors.goldColor.withOpacity(0.3)
                          : AppColors.border,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Member Name for Admin View
                        if (_isAdmin && payment["memberName"] != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.person_outline,
                                  size: 14,
                                  color: AppColors.goldColor,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  payment["memberName"],
                                  style: TextStyle(
                                    color: AppColors.goldColor,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),

                        // Payment Info
                        Row(
                          children: [
                            // Date & Time
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _formatDateOnly(date),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _formatTimeOnly(date),
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Amount
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  _formatCurrency(amount),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.green.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Text(
                                    "Paid",
                                    style: TextStyle(
                                      color: AppColors.green,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
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
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceCard({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(AppColors.r12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 10,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}