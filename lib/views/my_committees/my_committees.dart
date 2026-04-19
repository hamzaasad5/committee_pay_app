import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../constants/app_colors.dart';
import '../../providers/committees_provider.dart';
import '../../widgets/custom_app_bar.dart';
import 'add_user_payment.dart';
import 'committee_members_screen.dart';
import 'winners_list_screen.dart';

class MyCommitteesScreen extends StatefulWidget {
  final String userId;
  const MyCommitteesScreen({super.key, required this.userId});

  @override
  State<MyCommitteesScreen> createState() => _MyCommitteesScreenState();
}

class _MyCommitteesScreenState extends State<MyCommitteesScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final p = context.read<CommitteesProvider>();
      if (p.committees.isEmpty) {
        p.fetchUserCommittees(widget.userId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return _CommitteesBody(userId: widget.userId);
  }
}

class _CommitteesBody extends StatelessWidget {
  final String userId;
  const _CommitteesBody({required this.userId});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CommitteesProvider>();

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: CustomAppBar(
        title: 'My Committees',
        showBackButton: false,
      ),
      body: _buildBody(context, provider),
    );
  }

  Widget _buildBody(BuildContext context, CommitteesProvider provider) {
    if (provider.isLoading && provider.committees.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AppColors.goldColor),
            SizedBox(height: 12),
            Text('Loading your committees...',
                style: TextStyle(
                    color: AppColors.textSecondary, fontSize: 14)),
          ],
        ),
      );
    }

    if (provider.error != null && provider.committees.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.wifi_off_rounded,
                  size: 48, color: AppColors.textSecondary),
              const SizedBox(height: 16),
              const Text('Could not load committees',
                  style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              Text(provider.error ?? '',
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 13),
                  textAlign: TextAlign.center),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => provider.fetchUserCommittees(userId),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Try Again'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.goldColor,
                  foregroundColor: AppColors.bg,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppColors.r12)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (provider.committees.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: AppColors.goldSoft,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.group_off_rounded,
                    size: 40, color: AppColors.goldColor),
              ),
              const SizedBox(height: 20),
              const Text('No Committees Found',
                  style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              const Text(
                'You have not joined or created any committees yet.',
                style: TextStyle(
                    color: AppColors.textSecondary, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    final active = provider.committees
        .where((c) => (c['status'] ?? '').toLowerCase() == 'active')
        .toList();
    final others = provider.committees
        .where((c) => (c['status'] ?? '').toLowerCase() != 'active')
        .toList();

    return RefreshIndicator(
      onRefresh: () async => provider.fetchUserCommittees(userId),
      color: AppColors.goldColor,
      backgroundColor: AppColors.surfaceDark,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          if (active.isNotEmpty) ...[
            _SectionLabel(label: 'Active (${active.length})'),
            ...active.map((c) =>
                _CommitteeCard(committee: c, userId: userId)),
          ],
          if (others.isNotEmpty) ...[
            _SectionLabel(label: 'Completed / Inactive'),
            ...others.map((c) =>
                _CommitteeCard(committee: c, userId: userId)),
          ],
        ],
      ),
    );
  }
}

// ── Section label ──────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(label,
          style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
              letterSpacing: .5)),
    );
  }
}

// ── Committee card ─────────────────────────────────────────────────────────

class _CommitteeCard extends StatelessWidget {
  final Map<String, dynamic> committee;
  final String userId;

  const _CommitteeCard({required this.committee, required this.userId});

  bool get _isActive =>
      (committee['status'] ?? '').toLowerCase() == 'active';
  bool get _isAdmin => userId == (committee['adminId'] ?? '');

  String _formatAmount(int amount) {
    if (amount >= 100000) {
      return 'Rs ${(amount / 100000).toStringAsFixed(1)} Lac';
    }
    if (amount >= 1000) {
      return 'Rs ${(amount / 1000).toStringAsFixed(0)}K';
    }
    return 'Rs $amount';
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':    return AppColors.green;
      case 'completed': return AppColors.blue;
      default:          return AppColors.red;
    }
  }

  @override
  Widget build(BuildContext context) {
    final name      = committee['name']           ?? 'Committee';
    final status    = committee['status']         ?? 'Inactive';
    final adminName = committee['adminName']      ?? 'Unknown';
    final code      = committee['committeeCode']  ?? 'N/A';
    final members   = committee['totalMembers']   ?? 0;
    final monthly   = (committee['monthlyAmount'] ?? 0).toInt();
    final total     = (committee['totalAmount']   ?? 0).toInt();
    final type      = committee['type']           ?? 'monthly';
    final initial   = name.isNotEmpty ? name[0].toUpperCase() : 'C';

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(AppColors.r16),
        border: Border.all(
          color: _isActive
              ? AppColors.goldColor.withOpacity(.4)
              : AppColors.border,
          width: _isActive ? 1 : 0.5,
        ),
      ),
      child: Column(
        children: [
          // ── Header ─────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: _isActive
                        ? AppColors.goldColor
                        : AppColors.surface2,
                    borderRadius: BorderRadius.circular(AppColors.r12),
                  ),
                  alignment: Alignment.center,
                  child: Text(initial,
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w500,
                          color: _isActive
                              ? Colors.white
                              : AppColors.textSecondary)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textPrimary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          const Icon(Icons.person_outline,
                              size: 12, color: AppColors.textSecondary),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              _isAdmin
                                  ? '$adminName · You are admin'
                                  : adminName,
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _statusColor(status).withOpacity(.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: _statusColor(status),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(status,
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: _statusColor(status))),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const Divider(
              height: 0.5, thickness: 0.5, color: AppColors.border),

          // ── Stats ───────────────────────────────────────────────────
          IntrinsicHeight(
            child: Row(
              children: [
                _Stat(
                  icon: Icons.people_outline,
                  value: '$members',
                  label: 'Members',
                ),
                const VerticalDivider(
                    width: 0.5,
                    thickness: 0.5,
                    color: AppColors.border),
                _Stat(
                  icon: Icons.payments_outlined,
                  value: _formatAmount(monthly),
                  label: type == 'daily' ? 'Per Day' : 'Per Month',
                ),
                const VerticalDivider(
                    width: 0.5,
                    thickness: 0.5,
                    color: AppColors.border),
                _Stat(
                  icon: Icons.account_balance_wallet_outlined,
                  value: _formatAmount(total),
                  label: 'Total Pool',
                ),
              ],
            ),
          ),

          const Divider(
              height: 0.5, thickness: 0.5, color: AppColors.border),

          // ── Committee code ──────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 10),
            child: Row(
              children: [
                const Icon(Icons.tag,
                    size: 15, color: AppColors.goldColor),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Committee Code',
                        style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary)),
                    const SizedBox(height: 1),
                    Text(code,
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textPrimary,
                            letterSpacing: 1)),
                  ],
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: code));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Code copied!'),
                        backgroundColor: AppColors.goldColor,
                        behavior: SnackBarBehavior.floating,
                        duration: const Duration(seconds: 2),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                                AppColors.r12)),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.goldSoft,
                      borderRadius:
                      BorderRadius.circular(AppColors.r8),
                    ),
                    child: const Text('Copy',
                        style: TextStyle(
                            fontSize: 12,
                            color: AppColors.goldColor,
                            fontWeight: FontWeight.w500)),
                  ),
                ),
              ],
            ),
          ),

          const Divider(
              height: 0.5, thickness: 0.5, color: AppColors.border),

          // ── Action buttons ──────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _ActionBtn(
                        icon: Icons.people_outline,
                        label: 'View Members',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => CommitteeMembersScreen(
                                  committeeId: committee['id'])),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _ActionBtn(
                        icon: Icons.calendar_month_outlined,
                        label: 'Assigned Months',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => CommitteeWinnerScreen(
                                  committeeId: committee['id'])),
                        ),
                      ),
                    ),
                  ],
                ),
                if (_isAdmin) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AddUserPayment(
                            committeeId: committee['id'],
                            currentUserId: userId,
                          ),
                        ),
                      ),
                      icon: const Icon(Icons.add_card_rounded,
                          size: 18),
                      label: const Text('Add Payment'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.goldColor,
                        foregroundColor: AppColors.bg,
                        padding: const EdgeInsets.symmetric(
                            vertical: 12),
                        textStyle: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                                AppColors.r12)),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}


class _Stat extends StatelessWidget {
  final IconData icon;
  final String   value;
  final String   label;

  const _Stat({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(
          children: [
            Icon(icon, size: 18, color: AppColors.goldColor),
            const SizedBox(height: 4),
            Text(value,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Text(label,
                style: const TextStyle(
                    fontSize: 11, color: AppColors.textSecondary),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}


class _ActionBtn extends StatelessWidget {
  final IconData     icon;
  final String       label;
  final VoidCallback onTap;

  const _ActionBtn({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppColors.r12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.surface2,
            borderRadius: BorderRadius.circular(AppColors.r12),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20, color: AppColors.textSecondary),
              const SizedBox(height: 4),
              Text(label,
                  style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500),
                  textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}