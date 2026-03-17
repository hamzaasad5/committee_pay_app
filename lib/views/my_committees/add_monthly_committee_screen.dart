import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/committees_provider.dart';
import '../../constants/app_colors.dart';
import '../../utils/helper_methods.dart';
import '../../widgets/loading_overlay.dart';
import 'package:share_plus/share_plus.dart';

class MonthlyCommitteeScreen extends StatefulWidget {
  final String adminId;
  const MonthlyCommitteeScreen({super.key, required this.adminId});

  @override
  State<MonthlyCommitteeScreen> createState() => _MonthlyCommitteeScreenState();
}

class _MonthlyCommitteeScreenState extends State<MonthlyCommitteeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _membersController = TextEditingController();
  final _amountController = TextEditingController();
  final _totalAmountController = TextEditingController();

  DateTime? _startMonth;
  bool _isCreating = false;
  bool _isDuplicatePrevented = false;
  String? _generatedCode;

  // Calculated values
  int? _totalMembers;
  int? _monthlyAmount;
  int? _totalAmount;
  int? _totalMonths;
  String? _endMonthYear;
  DateTime? _endMonth;

  // Pakistan Rupee symbol
  static const String _rupeeSymbol = 'Rs. ';

  @override
  void initState() {
    super.initState();
    _resetForm();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _membersController.dispose();
    _amountController.dispose();
    _totalAmountController.dispose();
    super.dispose();
  }

  void _resetForm() {
    _nameController.clear();
    _membersController.clear();
    _amountController.clear();
    _totalAmountController.clear();
    _startMonth = null;
    _totalMembers = null;
    _monthlyAmount = null;
    _totalAmount = null;
    _totalMonths = null;
    _endMonthYear = null;
    _endMonth = null;
    _generatedCode = null;
    _isDuplicatePrevented = false;
  }

  void _calculateValues() {
    setState(() {
      _totalMembers = int.tryParse(_membersController.text);
      _monthlyAmount = int.tryParse(_amountController.text);

      if (_totalMembers != null && _monthlyAmount != null &&
          _totalMembers! > 0 && _monthlyAmount! > 0) {
        // Total months = number of members
        _totalMonths = _totalMembers;

        // Total amount = monthly amount × number of members
        _totalAmount = _monthlyAmount! * _totalMembers!;
        _totalAmountController.text = _totalAmount!.toString();

        // Calculate end month based on start month and member count
        if (_startMonth != null) {
          _calculateEndMonth();
        }
      } else {
        _totalAmountController.clear();
        _totalMonths = null;
        _endMonthYear = null;
        _endMonth = null;
      }
    });
  }

  void _calculateEndMonth() {
    if (_startMonth != null && _totalMonths != null) {
      // End month = start month + (number of members - 1) months
      int endMonthNum = _startMonth!.month + _totalMonths! - 1;
      int year = _startMonth!.year + ((endMonthNum - 1) ~/ 12);
      int month = ((endMonthNum - 1) % 12) + 1;

      _endMonth = DateTime(year, month);

      // Format as Month Year only
      _endMonthYear = "${_getMonthName(_endMonth!.month)} ${_endMonth!.year}";
    }
  }

  String _getMonthName(int month) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return months[month - 1];
  }

  String _formatPakistaniRupee(int amount) {
    if (amount >= 10000000) { // Crore
      return '${(amount / 10000000).toStringAsFixed(2)} Cr';
    } else if (amount >= 100000) { // Lakh
      return '${(amount / 100000).toStringAsFixed(2)} Lac';
    } else {
      String numStr = amount.toString();
      String result = '';
      int len = numStr.length;

      if (len > 3) {
        result = numStr.substring(len - 3);
        numStr = numStr.substring(0, len - 3);

        while (numStr.isNotEmpty) {
          if (numStr.length >= 2) {
            result = numStr.substring(numStr.length - 2) + ',' + result;
            numStr = numStr.substring(0, numStr.length - 2);
          } else {
            result = numStr + ',' + result;
            numStr = '';
          }
        }
        return result;
      }
      return amount.toString();
    }
  }

  Future<void> _pickStartMonth() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _startMonth ?? now,
      firstDate: now,
      lastDate: DateTime(now.year + 5),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.primaryColor,
              onPrimary: Colors.white,
              surface: AppColors.surfaceDark,
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && mounted) {
      setState(() {
        _startMonth = DateTime(picked.year, picked.month, 1);
        _calculateValues();
      });
    }
  }

  Future<bool> _checkDuplicateCommittee() async {
    try {
      final query = await FirebaseFirestore.instance
          .collection('committees')
          .where('adminId', isEqualTo: widget.adminId)
          .where('name', isEqualTo: _nameController.text.trim())
          .where('type', isEqualTo: 'monthly')
          .where('status', isEqualTo: 'active')
          .limit(1)
          .get();

      return query.docs.isNotEmpty;
    } catch (e) {
      debugPrint('Error checking duplicate: $e');
      return false;
    }
  }

  Future<String> _generateUniqueCode() async {
    String code;
    bool exists;
    int attempts = 0;
    const maxAttempts = 10;

    do {
      code = generateCommitteeCode();
      final query = await FirebaseFirestore.instance
          .collection('committees')
          .where('committeeCode', isEqualTo: code)
          .limit(1)
          .get();

      exists = query.docs.isNotEmpty;
      attempts++;

      if (attempts >= maxAttempts) {
        throw Exception("Failed to generate unique code");
      }
    } while (exists);

    return code;
  }

  Future<void> _createCommittee() async {
    if (_isDuplicatePrevented) return;

    if (!_formKey.currentState!.validate()) return;

    if (_startMonth == null) {
      _showErrorSnackBar("Please select a start month");
      return;
    }

    if (_totalMembers == null || _monthlyAmount == null || _totalAmount == null || _endMonth == null) {
      _showErrorSnackBar("Please fill all fields correctly");
      return;
    }

    setState(() {
      _isCreating = true;
      _isDuplicatePrevented = true;
    });

    try {
      final isDuplicate = await _checkDuplicateCommittee();
      if (isDuplicate) {
        if (mounted) {
          _showErrorSnackBar("An active committee with this name already exists");
        }
        setState(() {
          _isCreating = false;
          _isDuplicatePrevented = false;
        });
        return;
      }

      final provider = context.read<CommitteesProvider>();

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.adminId)
          .get();

      if (!userDoc.exists) {
        throw Exception("User not found");
      }

      final creatorName = userDoc.data()?['name'] ?? 'Unknown';
      final code = await _generateUniqueCode();

      await provider.addCommittee(
        name: _nameController.text.trim(),
        monthlyAmount: _monthlyAmount!,
        memberPhones: [],
        startMonth: _startMonth!,
        endMonth: _endMonth!,
        type: "monthly",
        totalMembers: _totalMembers!,
        totalAmount: _totalAmount!,
        committeeCode: code,
        creatorId: widget.adminId,
        creatorName: creatorName,
      );

      if (mounted) {
        setState(() {
          _generatedCode = code;
          _isCreating = false;
        });

        _showSuccessDialog(code);
      }

    } catch (e) {
      if (mounted) {
        setState(() {
          _isCreating = false;
          _isDuplicatePrevented = false;
        });
        _showErrorSnackBar("Failed to create committee: ${e.toString()}");
      }
    }
  }

  void _showSuccessDialog(String code) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceDark,
        title: const Text(
          "Committee Created!",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle,
                color: Colors.green,
                size: 48,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              "Share this code with members to join:",
              style: TextStyle(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primaryColor),
              ),
              child: SelectableText(
                code,
                style: const TextStyle(
                  color: AppColors.primaryColor,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Valid from: ${_getMonthName(_startMonth!.month)} ${_startMonth!.year} to $_endMonthYear",
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 4),
            Text(
              "Total Value: ${_rupeeSymbol}${_formatPakistaniRupee(_totalAmount!)}",
              style: const TextStyle(color: Colors.green, fontSize: 14, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text("Close"),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Share.share(
                'Join my monthly committee "${_nameController.text}" using code: $code\n'
                    'Duration: ${_getMonthName(_startMonth!.month)} ${_startMonth!.year} to $_endMonthYear\n'
                    'Monthly Amount: ${_rupeeSymbol}${_formatPakistaniRupee(_monthlyAmount!)}\n'
                    'Total Value: ${_rupeeSymbol}${_formatPakistaniRupee(_totalAmount!)}',
              );
            },
            icon: const Icon(Icons.share),
            label: const Text("Share"),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryColor,
            ),
          ),
        ],
      ),
    ).then((_) {
      if (mounted) {
        _resetForm();
      }
    });
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (_isCreating) {
          _showErrorSnackBar("Please wait while committee is being created");
          return false;
        }
        return true;
      },
      child: LoadingOverlay(
        isLoading: _isCreating,
        child: Scaffold(
          backgroundColor: AppColors.backgroundDark,
          appBar: AppBar(
            backgroundColor: AppColors.primaryColor,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: _isCreating ? null : () => Navigator.pop(context),
            ),
            title: const Text(
              "Create Monthly Committee",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            centerTitle: true,
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Info
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceDark,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.primaryColor.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.primaryColor.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.calendar_month,
                            color: AppColors.primaryColor,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Monthly Committee",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "Each member pays monthly for their turn",
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Form Fields
                  _buildTextField(
                    controller: _nameController,
                    label: "Committee Name",
                    icon: Icons.group,
                    hint: "e.g., Monthly Savings Group",
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return "Please enter committee name";
                      }
                      if (value.length < 3) {
                        return "Name must be at least 3 characters";
                      }
                      if (value.length > 50) {
                        return "Name must be less than 50 characters";
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 16),

                  _buildTextField(
                    controller: _membersController,
                    label: "Number of Members",
                    icon: Icons.people,
                    hint: "e.g., 10",
                    keyboardType: TextInputType.number,
                    onChanged: (_) => _calculateValues(),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return "Please enter number of members";
                      }
                      final members = int.tryParse(value);
                      if (members == null) {
                        return "Please enter a valid number";
                      }
                      if (members < 2) {
                        return "Minimum 2 members required";
                      }
                      if (members > 100) {
                        return "Maximum 100 members allowed";
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 16),

                  _buildTextField(
                    controller: _amountController,
                    label: "Monthly Amount per Member (Rs.)",
                    icon: Icons.currency_rupee,
                    hint: "e.g., 1000",
                    keyboardType: TextInputType.number,
                    onChanged: (_) => _calculateValues(),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return "Please enter monthly amount";
                      }
                      final amount = int.tryParse(value);
                      if (amount == null) {
                        return "Please enter a valid amount";
                      }
                      if (amount < 100) {
                        return "Minimum amount is Rs. 100";
                      }
                      if (amount > 100000) {
                        return "Maximum amount is Rs. 1,00,000";
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 16),

                  // Start Month Picker
                  InkWell(
                    onTap: _pickStartMonth,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceDark,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _startMonth != null
                              ? AppColors.primaryColor
                              : Colors.white.withOpacity(0.1),
                          width: _startMonth != null ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.calendar_today,
                            color: _startMonth != null
                                ? AppColors.primaryColor
                                : AppColors.textSecondary,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Start Month",
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _startMonth == null
                                      ? "Select start month"
                                      : "${_getMonthName(_startMonth!.month)} ${_startMonth!.year}",
                                  style: TextStyle(
                                    color: _startMonth != null
                                        ? Colors.white
                                        : AppColors.textSecondary,
                                    fontSize: 16,
                                    fontWeight: _startMonth != null
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.arrow_drop_down,
                            color: AppColors.textSecondary,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Total Amount (Read Only)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceDark,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _totalAmount != null
                            ? Colors.green.withOpacity(0.3)
                            : Colors.white.withOpacity(0.1),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.account_balance_wallet,
                          color: _totalAmount != null
                              ? Colors.green
                              : AppColors.textSecondary,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Total Committee Value",
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _totalAmount != null
                                    ? "${_rupeeSymbol}${_formatPakistaniRupee(_totalAmount!)}"
                                    : "Will be calculated automatically",
                                style: TextStyle(
                                  color: _totalAmount != null
                                      ? Colors.green
                                      : AppColors.textSecondary,
                                  fontSize: 18,
                                  fontWeight: _totalAmount != null
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Summary Cards
                  if (_totalMembers != null && _monthlyAmount != null && _startMonth != null && _endMonthYear != null) ...[
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AppColors.primaryColor.withOpacity(0.2),
                            AppColors.surfaceDark,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppColors.primaryColor.withOpacity(0.3),
                        ),
                      ),
                      child: Column(
                        children: [
                          // Duration Info
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.timeline,
                                  color: Colors.blue,
                                  size: 16,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      "Committee Duration",
                                      style: TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      "$_totalMonths months",
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      "${_getMonthName(_startMonth!.month)} ${_startMonth!.year} - $_endMonthYear",
                                      style: TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 16),

                          // Member Contribution
                          Row(
                            children: [
                              Expanded(
                                child: _buildSummaryItem(
                                  label: "Per Member Total",
                                  value: "${_rupeeSymbol}${_formatPakistaniRupee(_totalAmount! ~/ _totalMembers!)}",
                                  icon: Icons.person,
                                  color: Colors.orange,
                                ),
                              ),
                              Container(
                                height: 30,
                                width: 1,
                                color: Colors.white.withOpacity(0.1),
                              ),
                              Expanded(
                                child: _buildSummaryItem(
                                  label: "Monthly",
                                  value: "${_rupeeSymbol}${_formatPakistaniRupee(_monthlyAmount!)}",
                                  icon: Icons.calendar_month,
                                  color: Colors.purple,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),

                  // Create Button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: (_isCreating || _isDuplicatePrevented) ? null : _createCommittee,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                        disabledBackgroundColor: AppColors.primaryColor.withOpacity(0.5),
                      ),
                      child: _isCreating
                          ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            "Creating...",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      )
                          : const Text(
                        "Create Monthly Committee",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Info Note
                  if (_totalMembers != null && _monthlyAmount != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue.withOpacity(0.3)),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.info_outline,
                                color: Colors.blue,
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  "For $_totalMembers members, the committee will run for $_totalMonths months. "
                                      "Each member pays ${_rupeeSymbol}$_monthlyAmount per month.",
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 12,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.primaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.star, color: Colors.amber, size: 16),
                                const SizedBox(width: 8),
                                Text(
                                  "Total Committee Value: ${_rupeeSymbol}${_formatPakistaniRupee(_totalAmount!)}",
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryItem({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required String hint,
    TextInputType? keyboardType,
    Function(String)? onChanged,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
        ),
      ),
      child: TextFormField(
        controller: controller,
        style: const TextStyle(color: Colors.white),
        keyboardType: keyboardType,
        onChanged: onChanged,
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: AppColors.textSecondary),
          hintText: hint,
          hintStyle: TextStyle(color: AppColors.textSecondary.withOpacity(0.5)),
          prefixIcon: Icon(icon, color: AppColors.primaryColor),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
      ),
    );
  }
}