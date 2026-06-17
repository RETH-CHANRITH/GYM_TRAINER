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

    return Column(
      children: [
        // Action Button Header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
          child: AdminActionButton(
            label: 'Refresh Applications',
            icon: Icons.refresh_rounded,
            onPressed: () => controller.loadTrainerApplications(),
            width: double.infinity,
          ),
        ),

        // Search Input
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: AdminSearchBar(
            controller: _searchController,
            hintText: 'Search by name, email or specialty...',
            onSearch: () {
              setState(() {
                _searchQuery = _searchController.text;
              });
            },
          ),
        ),

        const SizedBox(height: 10),

        // Custom Filter Tabs
        _buildFilterTabs(controller.trainerApplications),

        const SizedBox(height: 10),

        // Dynamic Applications List
        Expanded(
          child: Obx(() {
            if (controller.loadingApplications.value) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: Theme.of(context).colorScheme.primary),
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
            
            // Filter by status tab
            var filtered = allApps.toList();
            if (_selectedStatus != 'all') {
              filtered = filtered.where((app) => (app['status'] ?? 'pending').toString().toLowerCase() == _selectedStatus).toList();
            }
            
            // Filter by search query
            if (_searchQuery.isNotEmpty) {
              final q = _searchQuery.toLowerCase();
              filtered = filtered.where((app) {
                final name = (app['fullName'] ?? '').toString().toLowerCase();
                final email = (app['email'] ?? '').toString().toLowerCase();
                final specialty = (app['specialty'] ?? '').toString().toLowerCase();
                return name.contains(q) || email.contains(q) || specialty.contains(q);
              }).toList();
            }

            if (filtered.isEmpty) {
              final statusLabel = _selectedStatus == 'all' 
                  ? 'Applications' 
                  : '${_selectedStatus[0].toUpperCase()}${_selectedStatus.substring(1)} Applications';
              return EmptyStateWidget(
                title: _searchQuery.isNotEmpty 
                    ? 'No matching results' 
                    : 'No $statusLabel',
                message: _searchQuery.isNotEmpty
                    ? 'Try adjusting your search terms'
                    : 'All trainer applications in this section are up to date',
                icon: _selectedStatus == 'approved' 
                    ? Icons.check_circle_outline_rounded 
                    : _selectedStatus == 'rejected' 
                        ? Icons.cancel_outlined 
                        : Icons.done_all_rounded,
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: filtered.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) => _buildApplicationCard(
                context, 
                controller, 
                filtered[index],
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildFilterTabs(List<Map<String, dynamic>> allApps) {
    final pendingCount = allApps.where((a) => (a['status'] ?? 'pending').toString().toLowerCase() == 'pending').length;
    final approvedCount = allApps.where((a) => (a['status'] ?? '').toString().toLowerCase() == 'approved').length;
    final rejectedCount = allApps.where((a) => (a['status'] ?? '').toString().toLowerCase() == 'rejected').length;
    final totalCount = allApps.length;

    final tabs = [
      {'status': 'pending', 'label': 'Pending', 'count': pendingCount, 'color': Colors.orange},
      {'status': 'approved', 'label': 'Approved', 'count': approvedCount, 'color': Colors.green},
      {'status': 'rejected', 'label': 'Rejected', 'count': rejectedCount, 'color': Colors.red},
      {'status': 'all', 'label': 'All', 'count': totalCount, 'color': Theme.of(context).colorScheme.primary},
    ];

    return SizedBox(
      height: 38,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: tabs.length,
        itemBuilder: (context, i) {
          final tab = tabs[i];
          final status = tab['status'] as String;
          final isActive = _selectedStatus == status;
          final color = tab['color'] as Color;

          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedStatus = status;
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: isActive ? color.withValues(alpha: 0.12) : Colors.white.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isActive ? color.withValues(alpha: 0.35) : Colors.white.withValues(alpha: 0.08),
                  width: 1,
                ),
              ),
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${tab['label']} (${tab['count']})',
                      style: GoogleFonts.dmSans(
                        fontSize: 12,
                        fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                        color: isActive ? Colors.white : kMuted,
                      ),
                    ),
                  ],
                ),
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
    final specialty = app['specialty'] as String? ?? 'Not specified';
    final experience = app['yearsOfExperience'] as String? ?? '0';
    final status = (app['status'] ?? 'pending').toString().toLowerCase();
    final photoUrl = app['photoUrl'] as String? ?? '';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.white.withValues(alpha: 0.08),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: photoUrl.isEmpty
                      ? LinearGradient(
                          colors: [
                            Colors.white.withValues(alpha: 0.08),
                            Colors.white.withValues(alpha: 0.15),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.12),
                  ),
                  image: photoUrl.isNotEmpty
                      ? DecorationImage(
                          image: CachedNetworkImageProvider(photoUrl),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: photoUrl.isEmpty
                    ? const Center(
                        child: Icon(
                          Icons.person_rounded,
                          color: Colors.white,
                          size: 28,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: GoogleFonts.dmSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      email,
                      style: GoogleFonts.dmSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w400,
                        color: kMuted,
                      ),
                    ),
                  ],
                ),
              ),
              StatusBadge(status),
            ],
          ),
          const SizedBox(height: 12),
          Divider(color: Colors.white.withValues(alpha: 0.08)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildInfoField('Specialty', specialty)),
              Expanded(
                child: _buildInfoField('Experience', '$experience years'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (app['certifications'] != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Certifications:',
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  (app['certifications'] as String? ?? 'None')
                      .split(',')
                      .join('\n'),
                  style: GoogleFonts.dmSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w400,
                    color: kMuted,
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          
          // Action Buttons or Audit Info Row depending on Status
          if (status == 'pending')
            Row(
              children: [
                Expanded(
                  child: Obx(
                    () => AdminActionButton(
                      label: 'Reject',
                      icon: Icons.close_rounded,
                      isDestructive: true,
                      isLoading: controller.actionLoading.value,
                      onPressed: appId.isNotEmpty
                          ? () => _showRejectDialog(context, appId, controller)
                          : null,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Obx(
                    () => AdminActionButton(
                      label: 'Approve',
                      icon: Icons.check_rounded,
                      isLoading: controller.actionLoading.value,
                      onPressed: appId.isNotEmpty && userId.isNotEmpty
                          ? () => controller.approveTrainerApplication(
                                appId,
                                userId,
                              )
                          : null,
                    ),
                  ),
                ),
              ],
            )
          else if (status == 'approved')
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.withValues(alpha: 0.25)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: Colors.green, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    'Approved on ${_formatDate(app['reviewedAt'])}',
                    style: GoogleFonts.dmSans(
                      fontSize: 11,
                      color: Colors.green,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            )
          else if (status == 'rejected')
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.cancel_rounded, color: Colors.red, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        'Rejected on ${_formatDate(app['reviewedAt'])}',
                        style: GoogleFonts.dmSans(
                          fontSize: 11,
                          color: Colors.red,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  if (app['rejectionNotes'] != null && app['rejectionNotes'].toString().isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Feedback: ${app['rejectionNotes']}',
                      style: GoogleFonts.dmSans(
                        fontSize: 11,
                        color: kMuted,
                        height: 1.35,
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
        Text(
          label,
          style: GoogleFonts.dmSans(
            fontSize: 10,
            fontWeight: FontWeight.w500,
            color: kMuted,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.dmSans(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
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
