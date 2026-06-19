import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../../config/glass_ui.dart';
import '../../controllers/admin_dashboard_controller.dart';
import '../components/admin_components.dart';

class TrainerApplicationsTab extends ConsumerStatefulWidget {
  const TrainerApplicationsTab({super.key});

  @override
  ConsumerState<TrainerApplicationsTab> createState() => _TrainerApplicationsTabState();
}

class _TrainerApplicationsTabState extends ConsumerState<TrainerApplicationsTab> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedStatus = 'pending';
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }



  String _formatDate(dynamic value) {
    if (value == null) return 'N/A';
    DateTime? dt;
    if (value is Timestamp) {
      dt = value.toDate();
    } else if (value is DateTime) {
      dt = value;
    } else if (value is String) {
      dt = DateTime.tryParse(value);
      if (dt == null) {
        final secMatch = RegExp(r'seconds[=:]\s*(\d+)').firstMatch(value);
        if (secMatch != null) {
          final seconds = int.tryParse(secMatch.group(1) ?? '');
          if (seconds != null) {
            dt = DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
          }
        }
      }
    }
    if (dt == null) return 'N/A';
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(adminDashboardProvider);
    final accent = Theme.of(context).colorScheme.primary;

    return Column(
      children: [
        // ── Header bar with search ───────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
          child: Container(
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _searchQuery = v),
              style: GoogleFonts.dmSans(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Search applicant...',
                hintStyle: GoogleFonts.dmSans(color: kMuted, fontSize: 13),
                prefixIcon: const Icon(Icons.search_rounded, color: kMuted, size: 18),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ),

        // ── Status filter chips ────────────────────────────────────────
        Obx(() => _buildFilterTabs(controller.trainerApplications)),
        const SizedBox(height: 12),

        // ── List ──────────────────────────────────────────────────────
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => Future.wait([
              controller.loadTrainerApplications(),
              Future.delayed(const Duration(milliseconds: 800)),
            ]),
            child: Obx(() {
              if (controller.loadingApplications.value) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 36,
                        height: 36,
                        child: CircularProgressIndicator(
                          color: accent,
                          strokeWidth: 2,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Loading applications...',
                        style: GoogleFonts.dmSans(fontSize: 13, color: kMuted),
                      ),
                    ],
                  ),
                );
              }

              final allApps = controller.trainerApplications;
              var filtered = allApps.toList();
              if (_selectedStatus != 'all') {
                filtered = filtered
                    .where((a) =>
                        (a['status'] ?? 'pending').toString().toLowerCase() ==
                        _selectedStatus)
                    .toList();
              }
              if (_searchQuery.isNotEmpty) {
                final q = _searchQuery.toLowerCase();
                filtered = filtered.where((a) {
                  final name = (a['fullName'] ?? '').toString().toLowerCase();
                  final email = (a['email'] ?? '').toString().toLowerCase();
                  return name.contains(q) || email.contains(q);
                }).toList();
              }

              if (filtered.isEmpty) {
                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    SizedBox(
                      height: MediaQuery.of(context).size.height * 0.5,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 72,
                              height: 72,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.04),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white.withOpacity(0.08)),
                              ),
                              child: Icon(
                                _selectedStatus == 'approved'
                                    ? Icons.verified_rounded
                                    : _selectedStatus == 'rejected'
                                        ? Icons.block_rounded
                                        : Icons.inbox_rounded,
                                color: kMuted,
                                size: 32,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _searchQuery.isNotEmpty ? 'No results found' : 'No applications here',
                              style: GoogleFonts.dmSans(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _searchQuery.isNotEmpty
                                  ? 'Try a different name or email'
                                  : 'Everything is up to date',
                              style: GoogleFonts.dmSans(fontSize: 12, color: kMuted),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              }

              return ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                itemCount: filtered.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, i) =>
                    _buildApplicationCard(context, controller, filtered[i]),
              );
            }),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterTabs(List<Map<String, dynamic>> allApps) {
    final pendingCount = allApps.where((a) => (a['status'] ?? 'pending').toString().toLowerCase() == 'pending').length;
    final approvedCount = allApps.where((a) => (a['status'] ?? '').toString().toLowerCase() == 'approved').length;
    final rejectedCount = allApps.where((a) => (a['status'] ?? '').toString().toLowerCase() == 'rejected').length;

    final tabs = [
      {'status': 'pending', 'label': 'Pending', 'count': pendingCount, 'color': const Color(0xFFFFBB33)},
      {'status': 'approved', 'label': 'Approved', 'count': approvedCount, 'color': const Color(0xFF4ADE80)},
      {'status': 'rejected', 'label': 'Rejected', 'count': rejectedCount, 'color': const Color(0xFFFF5C5C)},
      {'status': 'all', 'label': 'All', 'count': allApps.length, 'color': Theme.of(context).colorScheme.primary},
    ];

    return SizedBox(
      height: 36,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        itemCount: tabs.length,
        itemBuilder: (context, i) {
          final tab = tabs[i];
          final status = tab['status'] as String;
          final isActive = _selectedStatus == status;
          final color = tab['color'] as Color;
          final count = tab['count'] as int;

          return GestureDetector(
            onTap: () => setState(() => _selectedStatus = status),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: isActive ? color.withOpacity(0.15) : Colors.white.withOpacity(0.04),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isActive ? color.withOpacity(0.5) : Colors.white.withOpacity(0.08),
                  width: isActive ? 1.5 : 1,
                ),
                boxShadow: isActive
                    ? [
                        BoxShadow(
                          color: color.withOpacity(0.2),
                          blurRadius: 12,
                          spreadRadius: 0,
                        )
                      ]
                    : [],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isActive)
                    Container(
                      width: 6,
                      height: 6,
                      margin: const EdgeInsets.only(right: 6),
                      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                    ),
                  Text(
                    tab['label'] as String,
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                      color: isActive ? color : kMuted,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: isActive ? color.withOpacity(0.2) : Colors.white.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$count',
                      style: GoogleFonts.dmSans(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: isActive ? color : kMuted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildApplicationCard(
    BuildContext context,
    AdminDashboardController controller,
    Map<String, dynamic> app,
  ) {
    final appId = app['id'] as String? ?? '';
    final userId = app['userId'] as String? ?? '';
    final name = app['fullName'] as String? ?? 'Unknown';
    final email = app['email'] as String? ?? 'N/A';
    final status = (app['status'] ?? 'pending').toString().toLowerCase();
    final photoUrl = app['photoUrl'] as String? ?? '';
    final submittedAt = _formatDate(app['submittedAt']);

    // Status visual tokens
    final statusColor = status == 'approved'
        ? const Color(0xFF4ADE80)
        : status == 'rejected'
            ? const Color(0xFFFF5C5C)
            : const Color(0xFFFFBB33);
    final statusIcon = status == 'approved'
        ? Icons.verified_rounded
        : status == 'rejected'
            ? Icons.cancel_rounded
            : Icons.hourglass_top_rounded;
    final statusLabel = status == 'approved'
        ? 'Approved'
        : status == 'rejected'
            ? 'Rejected'
            : 'Pending';

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: const Color(0xFF12001E),
        border: Border.all(
          color: statusColor.withOpacity(status == 'pending' ? 0.18 : 0.12),
        ),
        boxShadow: [
          BoxShadow(
            color: statusColor.withOpacity(0.06),
            blurRadius: 20,
            spreadRadius: 0,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── Top section ─────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Avatar with gradient ring
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFFCBFF47), Color(0xFF5CE8FF)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(2.5),
                    child: ClipOval(
                      child: photoUrl.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: photoUrl,
                              fit: BoxFit.cover,
                            )
                          : Container(
                              color: const Color(0xFF1E0040),
                              child: Center(
                                child: Text(
                                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                                  style: GoogleFonts.dmSans(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                // Name + email + date
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: GoogleFonts.dmSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        email,
                        style: GoogleFonts.dmSans(
                          fontSize: 11,
                          color: kMuted,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          Icon(Icons.calendar_today_rounded,
                              size: 10, color: kMuted),
                          const SizedBox(width: 4),
                          Text(
                            'Applied $submittedAt',
                            style: GoogleFonts.dmSans(
                              fontSize: 10,
                              color: kMuted,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Status badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: statusColor.withOpacity(0.35)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 10, color: statusColor),
                      const SizedBox(width: 5),
                      Text(
                        statusLabel.toUpperCase(),
                        style: GoogleFonts.dmSans(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: statusColor,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Divider ─────────────────────────────────────────────────
          Divider(height: 1, color: Colors.white.withOpacity(0.07)),

          // ── Action area ─────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                // Preview button
                GestureDetector(
                  onTap: () => _showPreviewDialog(context, app),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.person_search_rounded,
                            size: 15, color: Colors.white70),
                        const SizedBox(width: 8),
                        Text(
                          'View Full Profile',
                          style: GoogleFonts.dmSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Pending action buttons
                if (status == 'pending') ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      // Reject
                      Expanded(
                        child: Obx(
                          () => GestureDetector(
                            onTap: appId.isNotEmpty && !controller.actionLoading.value
                                ? () => _showRejectDialog(context, appId, controller)
                                : null,
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFF5C5C).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: const Color(0xFFFF5C5C).withOpacity(0.3)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  controller.actionLoading.value
                                      ? const SizedBox(
                                          width: 14,
                                          height: 14,
                                          child: CircularProgressIndicator(
                                              color: Color(0xFFFF5C5C),
                                              strokeWidth: 2),
                                        )
                                      : const Icon(Icons.close_rounded,
                                          size: 14, color: Color(0xFFFF5C5C)),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Reject',
                                    style: GoogleFonts.dmSans(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFFFF5C5C),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Approve
                      Expanded(
                        child: Obx(
                          () => GestureDetector(
                            onTap: appId.isNotEmpty &&
                                    userId.isNotEmpty &&
                                    !controller.actionLoading.value
                                ? () => controller.approveTrainerApplication(
                                    appId, userId)
                                : null,
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFFCBFF47), Color(0xFFA8E63D)],
                                ),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFCBFF47).withOpacity(0.3),
                                    blurRadius: 12,
                                    spreadRadius: 0,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  controller.actionLoading.value
                                      ? const SizedBox(
                                          width: 14,
                                          height: 14,
                                          child: CircularProgressIndicator(
                                              color: Color(0xFF0A0A0F),
                                              strokeWidth: 2),
                                        )
                                      : const Icon(Icons.check_rounded,
                                          size: 14,
                                          color: Color(0xFF0A0A0F)),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Approve',
                                    style: GoogleFonts.dmSans(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: const Color(0xFF0A0A0F),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],

                // Approved / Rejected audit row
                if (status == 'approved') ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4ADE80).withOpacity(0.07),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: const Color(0xFF4ADE80).withOpacity(0.2)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.verified_rounded,
                            color: Color(0xFF4ADE80), size: 15),
                        const SizedBox(width: 8),
                        Text(
                          'Approved on ${_formatDate(app['reviewedAt'])}',
                          style: GoogleFonts.dmSans(
                              fontSize: 12,
                              color: const Color(0xFF4ADE80),
                              fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ],

                if (status == 'rejected') ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF5C5C).withOpacity(0.06),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: const Color(0xFFFF5C5C).withOpacity(0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.cancel_rounded,
                                color: Color(0xFFFF5C5C), size: 14),
                            const SizedBox(width: 8),
                            Text(
                              'Rejected ${_formatDate(app['reviewedAt'])}',
                              style: GoogleFonts.dmSans(
                                  fontSize: 12,
                                  color: const Color(0xFFFF5C5C),
                                  fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                        if (app['rejectionNotes'] != null &&
                            app['rejectionNotes'].toString().isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            'Reason: ${app['rejectionNotes']}',
                            style: GoogleFonts.dmSans(
                                fontSize: 11, color: kMuted, height: 1.4),
                          ),
                        ],
                      ],
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

  Widget _buildInfoField(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: GoogleFonts.dmSans(
                fontSize: 10, fontWeight: FontWeight.w500, color: kMuted)),
        const SizedBox(height: 4),
        Text(value,
            style: GoogleFonts.dmSans(
                fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
      ],
    );
  }

  void _showRejectDialog(BuildContext context, String appId, AdminDashboardController controller) {
    final notesController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A0330),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Reject Application',
          style: GoogleFonts.dmSans(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Provide feedback for the applicant.',
              style: GoogleFonts.dmSans(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: kMuted,
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: notesController,
              maxLines: 4,
              style: GoogleFonts.dmSans(fontSize: 13, color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Rejection reason...',
                hintStyle: GoogleFonts.dmSans(color: kMuted),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
                ),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.05),
              ),
            ),
          ],
        ),
        actions: [
          Row(
            children: [
              Expanded(
                child: AdminActionButton(
                  label: 'Cancel',
                  isOutlined: true,
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Obx(
                  () => AdminActionButton(
                    label: 'Reject',
                    isDestructive: true,
                    isLoading: controller.actionLoading.value,
                    onPressed: () {
                      controller.rejectTrainerApplication(
                        appId,
                        notesController.text.isEmpty
                            ? 'No feedback provided'
                            : notesController.text,
                      );
                      Navigator.pop(context);
                    },
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showPreviewDialog(BuildContext context, Map<String, dynamic> app) {
    final userId = app['userId'] as String? ?? '';
    final name = app['fullName'] as String? ?? 'Unknown';
    final email = app['email'] as String? ?? 'N/A';
    final photoUrl = app['photoUrl'] as String? ?? '';
    final submittedAt = _formatDate(app['submittedAt']);
    final status = (app['status'] ?? 'pending').toString().toLowerCase();

    final specialty = app['specialty'] as String? ?? '';
    final yearsOfExperience = app['yearsOfExperience'] as String? ?? '0';
    final hourlyRate = app['hourlyRate']?.toString() ?? '0.0';
    final certifications = app['certifications'] as String? ?? '';
    final bio = app['bio'] as String? ?? '';
    final statusColor = status == 'approved'
        ? const Color(0xFF4ADE80)
        : status == 'rejected'
            ? const Color(0xFFFF5C5C)
            : const Color(0xFFFFBB33);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.92,
        maxChildSize: 0.97,
        minChildSize: 0.5,
        builder: (_, scrollCtrl) => ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          child: Container(
            color: const Color(0xFF0D0020),
            child: FutureBuilder<DocumentSnapshot>(
              future: userId.isNotEmpty
                  ? FirebaseFirestore.instance.collection('users').doc(userId).get()
                  : Future.value(null as dynamic),
              builder: (_, snap) {
                Map<String, dynamic> u = {};
                if (snap.hasData && snap.data != null && snap.data!.exists) {
                  u = snap.data!.data() as Map<String, dynamic>? ?? {};
                }

                final gender       = u['gender'] as String? ?? '—';
                final age          = u['age']?.toString() ?? '—';
                final weight       = u['weight']?.toString() ?? '—';
                final height       = u['height']?.toString() ?? '—';
                final fitnessGoal  = u['fitnessGoal'] as String? ?? '—';
                final activityLvl  = u['activityLevel'] as String? ?? '—';
                final fitnessLvl   = u['fitnessLevel'] as String? ?? '—';
                final isLoading    = snap.connectionState == ConnectionState.waiting;

                return CustomScrollView(
                  controller: scrollCtrl,
                  slivers: [
                    // ── Hero photo section ────────────────────────────────
                    SliverToBoxAdapter(
                      child: Stack(
                        children: [
                          // Background gradient hero
                          Container(
                            height: 220,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  statusColor.withOpacity(0.25),
                                  const Color(0xFF0D0020),
                                ],
                              ),
                            ),
                          ),
                          // Close button
                          Positioned(
                            top: 16,
                            right: 16,
                            child: GestureDetector(
                              onTap: () => Navigator.pop(ctx),
                              child: Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.3),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: Colors.white.withOpacity(0.15)),
                                ),
                                child: const Icon(Icons.close_rounded,
                                    color: Colors.white, size: 18),
                              ),
                            ),
                          ),
                          // Avatar + identity
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 0,
                            child: Column(
                              children: [
                                // Avatar
                                Container(
                                  width: 90,
                                  height: 90,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: LinearGradient(
                                      colors: [
                                        statusColor,
                                        statusColor.withOpacity(0.5),
                                      ],
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: statusColor.withOpacity(0.4),
                                        blurRadius: 24,
                                        spreadRadius: 0,
                                      ),
                                    ],
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(3),
                                    child: ClipOval(
                                      child: photoUrl.isNotEmpty
                                          ? CachedNetworkImage(
                                              imageUrl: photoUrl,
                                              fit: BoxFit.cover,
                                            )
                                          : Container(
                                              color: const Color(0xFF1E0040),
                                              child: Center(
                                                child: Text(
                                                  name.isNotEmpty
                                                      ? name[0].toUpperCase()
                                                      : '?',
                                                  style: GoogleFonts.dmSans(
                                                    fontSize: 34,
                                                    fontWeight: FontWeight.w900,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ),
                                            ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 14),
                                // Name
                                Text(
                                  name,
                                  style: GoogleFonts.dmSans(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                // Email
                                Text(
                                  email,
                                  style: GoogleFonts.dmSans(
                                    fontSize: 13,
                                    color: kMuted,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                // Status + applied date chips
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: statusColor.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                            color: statusColor.withOpacity(0.4)),
                                      ),
                                      child: Text(
                                        status.toUpperCase(),
                                        style: GoogleFonts.dmSans(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800,
                                          color: statusColor,
                                          letterSpacing: 0.6,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.06),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                            color: Colors.white.withOpacity(0.1)),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(
                                              Icons.calendar_today_rounded,
                                              size: 10,
                                              color: kMuted),
                                          const SizedBox(width: 5),
                                          Text(
                                            'Applied $submittedAt',
                                            style: GoogleFonts.dmSans(
                                              fontSize: 10,
                                              color: kMuted,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 24),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // ── Loading shimmer ───────────────────────────────────
                    if (isLoading)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Center(
                            child: Column(
                              children: [
                                SizedBox(
                                  width: 32,
                                  height: 32,
                                  child: CircularProgressIndicator(
                                    color: statusColor,
                                    strokeWidth: 2,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text('Loading profile...',
                                    style: GoogleFonts.dmSans(
                                        fontSize: 12, color: kMuted)),
                              ],
                            ),
                          ),
                        ),
                      ),

                    // ── Body Stats ────────────────────────────────────────
                    if (!isLoading)
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                        sliver: SliverToBoxAdapter(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _sectionLabel('BODY STATS'),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  _statCard(
                                    icon: Icons.wc_rounded,
                                    iconColor: const Color(0xFF5CE8FF),
                                    label: 'Gender',
                                    value: gender,
                                  ),
                                  const SizedBox(width: 10),
                                  _statCard(
                                    icon: Icons.cake_rounded,
                                    iconColor: const Color(0xFFFFBB33),
                                    label: 'Age',
                                    value: '$age yrs',
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  _statCard(
                                    icon: Icons.monitor_weight_rounded,
                                    iconColor: const Color(0xFFCBFF47),
                                    label: 'Weight',
                                    value: '${weight} kg',
                                  ),
                                  const SizedBox(width: 10),
                                  _statCard(
                                    icon: Icons.height_rounded,
                                    iconColor: const Color(0xFFA78BFA),
                                    label: 'Height',
                                    value: '${height} cm',
                                  ),
                                ],
                              ),
                              const SizedBox(height: 28),

                              // ── Trainer Credentials ───────────────────
                              _sectionLabel('TRAINER PROFILE'),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  _statCard(
                                    icon: Icons.sports_gymnastics_rounded,
                                    iconColor: const Color(0xFF5CE8FF),
                                    label: 'Specialty',
                                    value: specialty.trim().isNotEmpty ? specialty : 'General Fitness',
                                  ),
                                  const SizedBox(width: 10),
                                  _statCard(
                                    icon: Icons.work_history_rounded,
                                    iconColor: const Color(0xFFFFBB33),
                                    label: 'Experience',
                                    value: yearsOfExperience.trim().isNotEmpty && yearsOfExperience != '0'
                                        ? '$yearsOfExperience yrs'
                                        : 'Entry Level',
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  _statCard(
                                    icon: Icons.attach_money_rounded,
                                    iconColor: const Color(0xFFCBFF47),
                                    label: 'Hourly Rate',
                                    value: hourlyRate.trim().isNotEmpty && hourlyRate != '0.0' && hourlyRate != '0'
                                        ? '\$$hourlyRate/hr'
                                        : 'To be decided',
                                  ),
                                  const SizedBox(width: 10),
                                  _statCard(
                                    icon: Icons.verified_user_rounded,
                                    iconColor: const Color(0xFFA78BFA),
                                    label: 'Applicant Role',
                                    value: 'Trainer Applicant',
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              _buildPreviewField(
                                'Bio / Philosophy',
                                bio.trim().isNotEmpty ? bio : 'No biography or training philosophy provided yet.',
                              ),
                              const SizedBox(height: 14),
                              _buildPreviewField(
                                'Certifications',
                                certifications.trim().isNotEmpty ? certifications : 'No professional certifications listed.',
                              ),
                              const SizedBox(height: 28),

                              // ── Fitness Profile ────────────────────────
                              _sectionLabel('FITNESS PROFILE'),
                              const SizedBox(height: 12),
                              _infoTile(
                                icon: Icons.flag_rounded,
                                iconColor: const Color(0xFFCBFF47),
                                label: 'Fitness Goal',
                                value: fitnessGoal,
                              ),
                              const SizedBox(height: 10),
                              _infoTile(
                                icon: Icons.bolt_rounded,
                                iconColor: const Color(0xFFFFBB33),
                                label: 'Activity Level',
                                value: activityLvl,
                              ),
                              const SizedBox(height: 10),
                              _infoTile(
                                icon: Icons.fitness_center_rounded,
                                iconColor: const Color(0xFF5CE8FF),
                                label: 'Fitness Level',
                                value: fitnessLvl,
                              ),
                              const SizedBox(height: 28),

                              // ── Contact ────────────────────────────────
                              _sectionLabel('CONTACT'),
                              const SizedBox(height: 12),
                              _infoTile(
                                icon: Icons.email_rounded,
                                iconColor: const Color(0xFFA78BFA),
                                label: 'Email Address',
                                value: email,
                              ),
                              const SizedBox(height: 32),

                              // Close button
                              GestureDetector(
                                onTap: () => Navigator.pop(ctx),
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(vertical: 15),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.05),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                        color: Colors.white.withOpacity(0.1)),
                                  ),
                                  child: Text(
                                    'Close',
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.dmSans(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white70,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),
                            ],
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  // ── Helpers for the profile sheet ─────────────────────────────────────────

  Widget _sectionLabel(String text) => Text(
        text,
        style: GoogleFonts.dmSans(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: kMuted,
          letterSpacing: 1.2,
        ),
      );

  Widget _statCard({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
  }) =>
      Expanded(
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.04),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: GoogleFonts.dmSans(
                          fontSize: 10, color: kMuted),
                    ),
                    Text(
                      value,
                      style: GoogleFonts.dmSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );

  Widget _infoTile({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
  }) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 18),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.dmSans(
                        fontSize: 10, color: kMuted),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: GoogleFonts.dmSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );


  Widget _buildStatChip(BuildContext context, String emoji, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 4),
            Text(
              value,
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildPreviewField(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: GoogleFonts.dmSans(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: kMuted,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.03),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white.withOpacity(0.06)),
          ),
          child: Text(
            value,
            style: GoogleFonts.dmSans(
              fontSize: 12,
              color: Colors.white.withOpacity(0.9),
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }
}

class Obx extends ConsumerWidget {
  final Widget Function() builder;
  const Obx(this.builder, {super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(adminDashboardProvider);
    return builder();
  }
}
