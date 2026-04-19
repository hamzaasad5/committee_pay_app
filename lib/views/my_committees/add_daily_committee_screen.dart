import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/committees_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:share_plus/share_plus.dart';
import '../../constants/app_colors.dart';
import '../../utils/helper_methods.dart';
import '../../widgets/loading_overlay.dart';

class DailyCommitteeScreen extends StatefulWidget {
  final String adminId;
  const DailyCommitteeScreen({super.key, required this.adminId});

  @override
  State<DailyCommitteeScreen> createState() => _DailyCommitteeScreenState();
}

class _DailyCommitteeScreenState extends State<DailyCommitteeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _membersController = TextEditingController();
  final _amountController = TextEditingController();
  final _totalAmountController = TextEditingController();

  DateTime? _startDate;
  bool _isCreating = false;
  bool _isDuplicatePrevented = false;
  String? _generatedCode;

  // Calculated values
  int? _totalMembers;
  int? _dailyAmount;
  int? _totalAmount;
  int? _totalMonths;
  String? _endMonthYear;
  DateTime? _endDate;

  // Pakistan Rupee symbol
  static const String _rupeeSymbol = 'Rs. ';

  @override
  void initState() {
    super.initState();
    // Clear any previous state
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
    _startDate = null;
    _totalMembers = null;
    _dailyAmount = null;
    _totalAmount = null;
    _totalMonths = null;
    _endMonthYear = null;
    _endDate = null;
    _generatedCode = null;
    _isDuplicatePrevented = false;
  }

  // Calculate all values based on inputs
  void _calculateValues() {
    setState(() {
      _totalMembers = int.tryParse(_membersController.text);
      _dailyAmount = int.tryParse(_amountController.text);

      if (_totalMembers != null && _dailyAmount != null &&
          _totalMembers! > 0 && _dailyAmount! > 0) {
        // Total months = number of members
        _totalMonths = _totalMembers;

        // Total amount = daily amount × 30 days × number of members
        _totalAmount = _dailyAmount! * 30 * _totalMembers!;
        _totalAmountController.text = _totalAmount!.toString();

        // Calculate end date based on start date and member count
        if (_startDate != null) {
          _calculateEndDate();
        }
      } else {
        _totalAmountController.clear();
        _totalMonths = null;
        _endMonthYear = null;
        _endDate = null;
      }
    });
  }

  void _calculateEndDate() {
    if (_startDate != null && _totalMonths != null) {
      // End date = start date + (number of members - 1) months
      _endDate = DateTime(
        _startDate!.year,
        _startDate!.month + (_totalMonths! - 1),
        1, // Always use 1st day of month
      );

      // Format as Month Year only
      _endMonthYear = "${_getMonthName(_endDate!.month)} ${_endDate!.year}";
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
    // Format with commas for Pakistani numbering system (lakhs and crores)
    if (amount >= 10000000) { // Crore
      return '${(amount / 10000000).toStringAsFixed(2)} Cr';
    } else if (amount >= 100000) { // Lakh
      return '${(amount / 100000).toStringAsFixed(2)} Lac';
    } else {
      // Add commas for thousands (Pakistani format: 1,000, 10,000, 100,000)
      String numStr = amount.toString();
      String result = '';
      int len = numStr.length;

      if (len > 3) {
        // First 3 digits from right
        result = numStr.substring(len - 3);
        numStr = numStr.substring(0, len - 3);

        // Then groups of 2 digits (for lakhs)
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

  Future<void> _pickStartDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? now,
      firstDate: now,
      lastDate: DateTime(now.year + 2),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.goldColor,
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
        _startDate = DateTime(picked.year, picked.month, 1);
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
          .where('type', isEqualTo: 'daily')
          .where('status', isEqualTo: 'active')
          .limit(1)
          .get();

      return query.docs.isNotEmpty;
    } catch (e) {
      debugPrint('Error checking duplicate: $e');
      return false;
    }
  }

  Future<void> _createCommittee() async {
    // Prevent double tap
    if (_isDuplicatePrevented) return;

    // Validate form
    if (!_formKey.currentState!.validate()) return;

    // Check start date
    if (_startDate == null) {
      _showErrorSnackBar("Please select a start date");
      return;
    }

    // Check if all calculations are done
    if (_totalMembers == null || _dailyAmount == null || _totalAmount == null || _endDate == null) {
      _showErrorSnackBar("Please fill all fields correctly");
      return;
    }

    setState(() {
      _isCreating = true;
      _isDuplicatePrevented = true;
    });

    try {
      // Check for duplicate active committee
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

      // Get creator name
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.adminId)
          .get();

      if (!userDoc.exists) {
        throw Exception("User not found");
      }

      final creatorName = userDoc.data()?['name'] ?? 'Unknown';

      // Generate unique committee code
      final code = await _generateUniqueCode();

      // Add committee to Firestore
      await provider.addCommittee(
        name: _nameController.text.trim(),
        monthlyAmount: _dailyAmount! * 30,
        memberPhones: [],
        startMonth: _startDate!,
        endMonth: _endDate!,
        type: "daily",
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

        // Show success dialog
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
                color: AppColors.goldColor,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle,
                color: AppColors.goldColor,
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
                color: AppColors.goldColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.goldColor),
              ),
              child: SelectableText(
                code,
                style: const TextStyle(
                  color: AppColors.goldColor,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Valid from: ${_getMonthName(_startDate!.month)} ${_startDate!.year} to $_endMonthYear",
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 4),
            Text(
              "Total Value: ${_rupeeSymbol}${_formatPakistaniRupee(_totalAmount!)}",
              style: const TextStyle(color: AppColors.goldColor, fontSize: 14, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context); // Return to previous screen
            },
            child: const Text("Close"),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Share.share(
                'Join my daily committee "${_nameController.text}" using code: $code\n'
                    'Duration: ${_getMonthName(_startDate!.month)} ${_startDate!.year} to $_endMonthYear\n'
                    'Total Value: ${_rupeeSymbol}${_formatPakistaniRupee(_totalAmount!)}',
              );
            },
            icon: const Icon(Icons.share),
            label: const Text("Share"),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.goldColor,
            ),
          ),
        ],
      ),
    ).then((_) {
      // Reset form after dialog is closed
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
            backgroundColor: AppColors.goldColor,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: _isCreating ? null : () => Navigator.pop(context),
            ),
            title: const Text(
              "Create Daily Committee",
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
                        color: AppColors.goldColor,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.goldColor,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.today,
                            color: AppColors.goldColor,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Daily Committee",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "Each member pays daily for their turn",
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
                    hint: "e.g., Daily Savings Group",
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
                    label: "Daily Amount per Member (Rs.)",
                    icon: Icons.currency_rupee,
                    hint: "e.g., 100",
                    keyboardType: TextInputType.number,
                    onChanged: (_) => _calculateValues(),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return "Please enter daily amount";
                      }
                      final amount = int.tryParse(value);
                      if (amount == null) {
                        return "Please enter a valid amount";
                      }
                      if (amount < 10) {
                        return "Minimum amount is Rs. 10";
                      }
                      if (amount > 100000) {
                        return "Maximum amount is Rs. 1,00,000";
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 16),

                  // Start Date Picker
                  InkWell(
                    onTap: _pickStartDate,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceDark,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _startDate != null
                              ? AppColors.goldColor
                              : Colors.white.withOpacity(0.1),
                          width: _startDate != null ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.calendar_today,
                            color: _startDate != null
                                ? AppColors.goldColor
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
                                  _startDate == null
                                      ? "Select start month"
                                      : "${_getMonthName(_startDate!.month)} ${_startDate!.year}",
                                  style: TextStyle(
                                    color: _startDate != null
                                        ? Colors.white
                                        : AppColors.textSecondary,
                                    fontSize: 16,
                                    fontWeight: _startDate != null
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
                            ? AppColors.goldColor.withOpacity(0.3)
                            : Colors.white.withOpacity(0.1),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.account_balance_wallet,
                          color: _totalAmount != null
                              ? AppColors.goldColor
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
                                      ? AppColors.goldColor
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
                  if (_totalMembers != null && _dailyAmount != null && _startDate != null && _endMonthYear != null) ...[
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AppColors.goldColor,
                            AppColors.surfaceDark,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppColors.goldColor,
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
                                      "${_getMonthName(_startDate!.month)} ${_startDate!.year} - $_endMonthYear",
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
                                  label: "Per Member",
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
                                  value: "${_rupeeSymbol}${_formatPakistaniRupee(_dailyAmount! * 30)}",
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
                        backgroundColor: AppColors.goldColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                        disabledBackgroundColor: AppColors.goldColor,
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
                        "Create Daily Committee",
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
                  if (_totalMembers != null && _dailyAmount != null)
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
                                      "Each member pays ${_rupeeSymbol}${_dailyAmount! * 30} per month (${_rupeeSymbol}$_dailyAmount daily).",
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
                              color: AppColors.goldColor,
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
          prefixIcon: Icon(icon, color: AppColors.goldColor),
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