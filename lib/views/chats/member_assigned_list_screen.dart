// lib/screens/member_assignment_screen.dart (Production Ready)
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../../../providers/committees_provider.dart';
import '../../../utils/app_local_storage.dart';
import 'committee_chat_screen.dart';

class MemberAssignmentScreen extends StatefulWidget {
  final String committeeId;
  const MemberAssignmentScreen({super.key, required this.committeeId});

  @override
  State<MemberAssignmentScreen> createState() =>
      _MemberAssignmentScreenState();
}

class _MemberAssignmentScreenState extends State<MemberAssignmentScreen> {
  Map<String, dynamic>? _committee;
  bool loading = true;
  bool isSaving = false;

  String? selectedMonth;
  String? selectedMemberId;
  String? currentUserId;

  // Dynamic month list based on committee start date and member count
  List<MapEntry<int, String>> _availableMonths = [];

  final Map<int, String> monthNames = {
    1: "January",
    2: "February",
    3: "March",
    4: "April",
    5: "May",
    6: "June",
    7: "July",
    8: "August",
    9: "September",
    10: "October",
    11: "November",
    12: "December",
  };

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    fetchUser();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> fetchUser() async {
    currentUserId = await LocalStorage.getUserId();
    fetchCommittee();
  }

  Future<void> fetchCommittee() async {
    try {
      final provider = context.read<CommitteesProvider>();
      final data = await provider.fetchCommitteeById(widget.committeeId);

      if (mounted) {
        setState(() {
          _committee = data;
          _calculateAvailableMonths(); // Calculate months based on committee data
          loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          loading = false;
        });
        Fluttertoast.showToast(
          msg: "Error loading committee: $e",
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
      }
    }
  }

  /// Calculate the months that should be shown in dropdown
  /// Logic: Start from committee start month, show consecutive months
  /// equal to the number of members in the committee.
  void _calculateAvailableMonths() {
    if (_committee == null) return;

    // Get committee start date
    final startDateStr = _committee!["startDate"] as String?;

    if (startDateStr == null) {
      // Fallback to all months if start date not available
      _availableMonths = monthNames.entries.toList();
      return;
    }

    try {
      // Parse start date
      final startDate = DateTime.parse(startDateStr);
      int startMonth = startDate.month;
      int startYear = startDate.year;

      // Get members count (only non-admin members if needed)
      final members = List<Map<String, dynamic>>.from(_committee!["members"] ?? []);
      final memberCount = members.length;

      if (memberCount == 0) {
        _availableMonths = [];
        return;
      }

      // Generate months starting from start month, up to memberCount months
      List<MapEntry<int, String>> generatedMonths = [];
      int currentMonth = startMonth;
      int currentYear = startYear;

      for (int i = 0; i < memberCount; i++) {
        generatedMonths.add(MapEntry(currentMonth, monthNames[currentMonth]!));

        // Move to next month
        if (currentMonth == 12) {
          currentMonth = 1;
          currentYear++;
        } else {
          currentMonth++;
        }
      }

      _availableMonths = generatedMonths;
    } catch (e) {
      // Fallback to all months if parsing fails
      _availableMonths = monthNames.entries.toList();
    }
  }

  String _monthLabel(String monthKey) {
    if (monthKey.isEmpty) return "";
    final number = int.tryParse(monthKey.replaceAll("Month", ""));
    return number != null ? monthNames[number] ?? monthKey : monthKey;
  }

  bool _isMonthAssigned(String monthKey) {
    if (_committee == null) return false;
    final assignments = _committee!["winners"];
    if (assignments == null) return false;
    return assignments.containsKey(monthKey);
  }

  bool _isMemberAssignedToAnyMonth(String memberId) {
    if (_committee == null || memberId.isEmpty) return false;
    final assignments = _committee!["winners"];
    if (assignments == null) return false;
    return assignments.containsValue(memberId);
  }

  String _getMonthNumber(String monthKey) {
    if (monthKey.isEmpty) return "";
    return monthKey.replaceAll("Month", "");
  }

  // Get unassigned members count
  int _getUnassignedMembersCount(List<Map<String, dynamic>> members) {
    int count = 0;
    for (var member in members) {
      final id = (member["uid"] ?? member["phone"]).toString();
      if (!_isMemberAssignedToAnyMonth(id)) {
        count++;
      }
    }
    return count;
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_committee == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text("Monthly Assignments"),
          backgroundColor: Theme.of(context).primaryColor,
        ),
        body: const Center(
          child: Text("Failed to load committee data"),
        ),
      );
    }

    final committee = _committee!;
    final members = List<Map<String, dynamic>>.from(committee["members"] ?? []);
    final assignments = Map<String, dynamic>.from(committee["winners"] ?? {});
    final bool isCreator = committee["adminId"] == currentUserId;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text(
          "Monthly Assignments",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        backgroundColor: Theme.of(context).primaryColor,
        elevation: 0,
        centerTitle: false,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            child: IconButton(
              icon: const Icon(Icons.chat_bubble_outline),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CommitteeChatScreen(
                      committeeId: widget.committeeId,
                      committeeName: committee["name"] ?? "Committee Chat",
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      body: isSaving
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              "Assigning member...",
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      )
          : RefreshIndicator(
        onRefresh: fetchCommittee,
        color: Theme.of(context).primaryColor,
        child: CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // Creator Form Section - Only shown to admin/creator
                  if (isCreator)
                    _buildAssignmentForm(context, committee, members),

                  if (isCreator) const SizedBox(height: 24),

                  // Assignments List Header
                  _buildSectionHeader(assignments.length),
                  const SizedBox(height: 16),

                  // Assignments List
                  if (assignments.isEmpty)
                    _buildEmptyState(isCreator)
                  else
                    ...assignments.entries.map((entry) =>
                        _buildAssignmentCard(entry, members)).toList(),
                  const SizedBox(height: 20),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAssignmentForm(
      BuildContext context,
      Map<String, dynamic> committee,
      List<Map<String, dynamic>> members,
      ) {
    final theme = Theme.of(context);
    final unassignedCount = _getUnassignedMembersCount(members);

    // Get assignments from committee data
    final assignments = Map<String, dynamic>.from(committee["winners"] ?? {});
    final assignedCount = assignments.length;
    final totalMonths = _availableMonths.length;
    final remainingMonths = totalMonths - assignedCount;

    // Check if all members are already assigned
    final allMembersAssigned = unassignedCount == 0;
    // Check if all months are assigned
    final allMonthsAssigned = assignedCount >= totalMonths;

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Create Assignment",
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            /// Info about available assignments
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 18, color: Colors.blue.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Members: ${members.length} | "
                          "Months: $totalMonths | "
                          "Remaining: ${remainingMonths > 0 ? remainingMonths : 0}",
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Show completion message if all assignments are done
            if (allMembersAssigned || allMonthsAssigned)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, size: 18, color: Colors.green.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        allMembersAssigned
                            ? "All members have been assigned!"
                            : "All months have been assigned!",
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.green.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            /// MONTH DROPDOWN with Black Theme (Dynamic months starting from committee start date)
            Theme(
              data: Theme.of(context).copyWith(
                canvasColor: Colors.black,
                brightness: Brightness.dark,
              ),
              child: DropdownButtonFormField<String>(
                value: selectedMonth,
                isExpanded: true,
                hint: const Text(
                  "Select Month",
                  style: TextStyle(color: Colors.white70),
                ),
                decoration: InputDecoration(
                  labelText: "Select Month",
                  labelStyle: const TextStyle(color: Colors.white70),
                  prefixIcon:
                  const Icon(Icons.calendar_today, color: Colors.white70),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.white30),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.white),
                  ),
                ),
                dropdownColor: Colors.black,
                style: const TextStyle(color: Colors.white),
                items: _availableMonths.map((entry) {
                  final key = "Month${entry.key}";
                  final monthName = entry.value;
                  final assigned = _isMonthAssigned(key);

                  return DropdownMenuItem<String>(
                    value: key,
                    enabled: !assigned,
                    child: Text(
                      assigned ? "$monthName (Assigned)" : monthName,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: assigned ? Colors.white54 : Colors.white,
                      ),
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null && !_isMonthAssigned(value)) {
                    setState(() => selectedMonth = value);
                  }
                },
              ),
            ),

            const SizedBox(height: 16),

            /// MEMBER DROPDOWN with Black Theme
            Theme(
              data: Theme.of(context).copyWith(
                canvasColor: Colors.black,
                brightness: Brightness.dark,
              ),
              child: DropdownButtonFormField<String>(
                value: selectedMemberId,
                isExpanded: true,
                hint: const Text(
                  "Select Member",
                  style: TextStyle(color: Colors.white70),
                ),
                decoration: InputDecoration(
                  labelText: "Select Member",
                  labelStyle: const TextStyle(color: Colors.white70),
                  prefixIcon: const Icon(Icons.person, color: Colors.white70),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.white30),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.white),
                  ),
                ),
                dropdownColor: Colors.black,
                style: const TextStyle(color: Colors.white),
                items: members.map((m) {
                  final id = (m["uid"] ?? m["phone"]).toString();
                  final name = m["name"] ?? "Unknown";
                  final assigned = _isMemberAssignedToAnyMonth(id);

                  return DropdownMenuItem<String>(
                    value: id,
                    enabled: !assigned,
                    child: Text(
                      assigned ? "$name (Assigned)" : name,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: assigned ? Colors.white54 : Colors.white,
                      ),
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null && !_isMemberAssignedToAnyMonth(value)) {
                    setState(() => selectedMemberId = value);
                  }
                },
              ),
            ),

            const SizedBox(height: 20),

            /// SAVE BUTTON
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: (selectedMonth != null &&
                    selectedMemberId != null &&
                    !_isMonthAssigned(selectedMonth!) &&
                    !_isMemberAssignedToAnyMonth(selectedMemberId!))
                    ? _saveAssignment
                    : null,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text("Save Assignment"),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(int count) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            Icons.assignment_turned_in,
            color: Theme.of(context).primaryColor,
            size: 22,
          ),
        ),
        const SizedBox(width: 12),
        const Text(
          "Assigned Members",
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2C3E50),
          ),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 6,
          ),
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            "$count",
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAssignmentCard(
      MapEntry<String, dynamic> entry,
      List<Map<String, dynamic>> members,
      ) {
    final member = members.firstWhere(
          (m) => (m["uid"] ?? m["phone"]).toString() == entry.value.toString(),
      orElse: () => {"name": "Unknown Member"},
    );

    final monthKey = entry.key.toString();
    final monthNumber = _getMonthNumber(monthKey);
    final monthLabel = _monthLabel(monthKey);
    final memberName = member["name"]?.toString() ?? "Unknown Member";

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.05),
            spreadRadius: 1,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            // Optional: Show details dialog
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Theme.of(context).primaryColor,
                        Theme.of(context).primaryColor.withOpacity(0.7),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      monthNumber.isNotEmpty ? monthNumber : "?",
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        monthLabel.isNotEmpty ? monthLabel : "Unknown Month",
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Color(0xFF2C3E50),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.person_outline,
                            size: 14,
                            color: Colors.grey[500],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            memberName,
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.check_circle,
                    color: Colors.green,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isCreator) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.assignment_outlined,
              size: 60,
              color: Colors.grey[400],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            "No Assignments Yet",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isCreator
                ? "Create your first assignment above"
                : "No assignments have been created yet",
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Future<void> _saveAssignment() async {
    if (selectedMonth == null || selectedMemberId == null) return;

    setState(() => isSaving = true);

    try {
      await _saveAssignmentToFirebase(
        committeeId: widget.committeeId,
        monthKey: selectedMonth!,
        memberId: selectedMemberId!,
      );

      if (mounted) {
        setState(() {
          selectedMonth = null;
          selectedMemberId = null;
        });
        // Refresh committee data to update assignments list
        await fetchCommittee();

        Fluttertoast.showToast(
          msg: "Assignment saved successfully!",
          backgroundColor: Colors.green,
          textColor: Colors.white,
          gravity: ToastGravity.BOTTOM,
        );
      }
    } catch (e) {
      if (mounted) {
        Fluttertoast.showToast(
          msg: "Error: ${e.toString()}",
          backgroundColor: Colors.red,
          textColor: Colors.white,
          gravity: ToastGravity.BOTTOM,
        );
      }
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  Future<void> _saveAssignmentToFirebase({
    required String committeeId,
    required String monthKey,
    required String memberId,
  }) async {
    final provider = context.read<CommitteesProvider>();
    await provider.saveWinnerManual(
      committeeId: committeeId,
      monthKey: monthKey,
      memberId: memberId,
    );
  }
}