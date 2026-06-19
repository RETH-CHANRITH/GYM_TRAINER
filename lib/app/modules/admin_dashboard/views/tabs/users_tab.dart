import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../../config/glass_ui.dart';
import '../../controllers/admin_dashboard_controller.dart';
import '../components/admin_components.dart';

class UsersTab extends ConsumerWidget {
  const UsersTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(adminDashboardProvider);
    final accent = Theme.of(context).colorScheme.primary;

    return Column(
      children: [
        // ─── Toolbar ───────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Search & Filter Row
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      onChanged: (value) {
                        controller.searchUsersQuery.value = value;
                      },
                      style: GoogleFonts.dmSans(
                        fontSize: 14,
                        color: Colors.white,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Search by name or email...',
                        hintStyle: GoogleFonts.dmSans(
                          fontSize: 14,
                          color: kMuted,
                        ),
                        prefixIcon: Icon(Icons.search_rounded, color: accent),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(
                            color: Colors.white.withValues(alpha: 0.12),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(
                            color: Colors.white.withValues(alpha: 0.12),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: accent.withValues(alpha: 0.5)),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 0,
                          vertical: 12,
                        ),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.05),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.12),
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Obx(
                      () => DropdownButton<String>(
                        value: controller.filterUsersStatus.value,
                        items:
                            ['active', 'suspended', 'pending']
                                .map(
                                  (status) => DropdownMenuItem(
                                    value: status,
                                    child: Text(
                                      status.toUpperCase(),
                                      style: GoogleFonts.dmSans(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            controller.filterUsersStatus.value = value;
                          }
                        },
                        underline: const SizedBox(),
                        dropdownColor: const Color(0xFF1A0330),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        // ─── List ───────────────────────────────────────────────────────────
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => Future<void>.delayed(const Duration(milliseconds: 800)),
            child: Obx(() {
              if (controller.loadingUsers.value) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(color: accent),
                      const SizedBox(height: 16),
                      Text(
                        'Loading users...',
                        style: GoogleFonts.dmSans(fontSize: 13, color: kMuted),
                      ),
                    ],
                  ),
                );
              }

              final allUsers = controller.users;
              final selectedStatus = controller.filterUsersStatus.value.toLowerCase();
              final query = controller.searchUsersQuery.value.trim().toLowerCase();

              // 1. Filter by Status
              var filtered = allUsers.where((u) {
                final status = (u['accountStatus'] ?? 'active').toString().toLowerCase();
                return status == selectedStatus;
              }).toList();

              // 2. Filter by Search Query (Name or Email)
              if (query.isNotEmpty) {
                filtered = filtered.where((u) {
                  final name = (u['name'] ?? '').toString().toLowerCase();
                  final email = (u['email'] ?? '').toString().toLowerCase();
                  return name.contains(query) || email.contains(query);
                }).toList();
              }

              if (filtered.isEmpty) {
                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    SizedBox(
                      height: MediaQuery.of(context).size.height * 0.5,
                      child: Center(
                        child: EmptyStateWidget(
                          title: 'No Users Found',
                          message: 'No users match your search criteria',
                          icon: Icons.person_off_rounded,
                        ),
                      ),
                    ),
                  ],
                );
              }

              return ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: filtered.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final user = filtered[index];
                  return _buildUserCard(context, controller, user);
                },
              );
            }),
          ),
        ),
      ],
    );
  }

  Widget _buildUserCard(BuildContext context, AdminDashboardController controller, Map<String, dynamic> user) {
    final userId = user['id'] as String?;
    final rawName = user['name'] as String? ?? '';
    final email = user['email'] as String? ?? 'N/A';
    final role = user['role'] as String? ?? 'user';
    final status = user['accountStatus'] as String? ?? 'active';
    final photoUrl = user['photoUrl'] as String? ?? '';
    final createdAt = _formatProfileValue(user['createdAt']);

    // Dynamic name healing and fallback formatting
    String name = rawName.trim();
    if (name.isEmpty || name == 'User' || name == 'Unknown') {
      if (email != 'N/A' && email.isNotEmpty) {
        final prefix = email.split('@').first;
        name = prefix.split(RegExp(r'[\._-]')).map((s) => s.isNotEmpty ? '${s[0].toUpperCase()}${s.substring(1)}' : '').join(' ');
      } else {
        name = 'Unknown';
      }
      
      // Auto-heal the database record in the background
      if (userId != null && name != 'Unknown') {
        FirebaseFirestore.instance.collection('users').doc(userId).update({
          'name': name,
          'updatedAt': FieldValue.serverTimestamp(),
        }).catchError((_) {});
      }
    }

    return GestureDetector(
      onTap: () => _showUserProfile(context, user),
      child: Container(
        padding: const EdgeInsets.all(12),
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
                  width: 48,
                  height: 48,
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
                            size: 24,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: GoogleFonts.dmSans(
                          fontSize: 13,
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => _showChangeRoleDialog(context, userId, role, name, controller),
                    behavior: HitTestBehavior.opaque,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Role',
                          style: GoogleFonts.dmSans(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: kMuted,
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              role.toUpperCase(),
                              style: GoogleFonts.dmSans(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.edit_rounded,
                              size: 11,
                              color: kMuted,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Joined',
                        style: GoogleFonts.dmSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: kMuted,
                        ),
                      ),
                      Text(
                        createdAt,
                        style: GoogleFonts.dmSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                if (status == 'active')
                  Expanded(
                    child: AdminActionButton(
                      label: 'Suspend',
                      icon: Icons.block_rounded,
                      isDestructive: true,
                      onPressed:
                          () => _showSuspendDialog(context, userId, name, controller),
                    ),
                  )
                else if (status == 'suspended')
                  Expanded(
                    child: Obx(
                      () => AdminActionButton(
                        label: 'Reactivate',
                        icon: Icons.check_rounded,
                        isLoading: controller.actionLoading.value,
                        onPressed:
                            userId != null
                                ? () => controller.reactivateUser(userId)
                                : null,
                      ),
                    ),
                  ),
                const SizedBox(width: 8),
                Expanded(
                  child: AdminActionButton(
                    label: 'View Profile',
                    icon: Icons.person_rounded,
                    isOutlined: true,
                    onPressed: () => _showUserProfile(context, user),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showChangeRoleDialog(
    BuildContext context,
    String? userId,
    String currentRole,
    String name,
    AdminDashboardController controller,
  ) {
    if (userId == null) return;

    showDialog(
      context: context,
      builder: (context) {
        final roles = ['user', 'trainer', 'admin'];
        return AlertDialog(
          backgroundColor: kInk,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'Change Role',
            style: GoogleFonts.dmSans(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Select a new role for $name:',
                style: GoogleFonts.dmSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: kMuted,
                ),
              ),
              const SizedBox(height: 16),
              ...roles.map((r) {
                final isSelected = r.toLowerCase() == currentRole.toLowerCase();
                final accent = Theme.of(context).colorScheme.primary;
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: isSelected ? accent.withValues(alpha: 0.1) : Colors.white.withValues(alpha: 0.03),
                    border: Border.all(
                      color: isSelected ? accent.withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                    title: Text(
                      r.toUpperCase(),
                      style: GoogleFonts.dmSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? accent : Colors.white,
                      ),
                    ),
                    subtitle: Text(
                      r == 'user'
                          ? 'Standard client account'
                          : r == 'trainer'
                              ? 'Professional coach / instructor'
                              : 'System administrator staff',
                      style: GoogleFonts.dmSans(
                        fontSize: 11,
                        color: kMuted,
                      ),
                    ),
                    trailing: isSelected
                        ? Icon(Icons.check_circle_rounded, color: accent, size: 20)
                        : null,
                    onTap: () {
                      Navigator.pop(context);
                      controller.changeUserRole(userId, r);
                    },
                  ),
                );
              }),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: GoogleFonts.dmSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showSuspendDialog(BuildContext context, String? userId, String name, AdminDashboardController controller) {
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: kInk,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Suspend User',
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
              'You are about to suspend $name\'s account.',
              style: GoogleFonts.dmSans(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: kMuted,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              maxLines: 3,
              style: GoogleFonts.dmSans(fontSize: 13, color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Reason for suspension...',
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
                    label: 'Suspend',
                    isDestructive: true,
                    isLoading: controller.actionLoading.value,
                    onPressed:
                        userId != null
                            ? () {
                              controller.suspendUser(
                                userId,
                                reasonController.text.isEmpty
                                    ? 'No reason provided'
                                    : reasonController.text,
                              );
                              Navigator.pop(context);
                            }
                            : null,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showUserProfile(BuildContext context, Map<String, dynamic> user) {
    final userId = user['id'] as String?;
    final rawName = (user['name'] ?? '').toString();
    final email = (user['email'] ?? '').toString();

    // Dynamic name healing and fallback formatting
    String displayName = rawName.trim();
    if (displayName.isEmpty || displayName == 'User' || displayName == 'Unknown') {
      if (email.isNotEmpty) {
        final prefix = email.split('@').first;
        displayName = prefix.split(RegExp(r'[\._-]')).map((s) => s.isNotEmpty ? '${s[0].toUpperCase()}${s.substring(1)}' : '').join(' ');
      } else {
        displayName = 'Unknown';
      }
      
      // Auto-heal the database record in the background
      if (userId != null && displayName != 'Unknown') {
        FirebaseFirestore.instance.collection('users').doc(userId).update({
          'name': displayName,
          'updatedAt': FieldValue.serverTimestamp(),
        }).catchError((_) {});
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SafeArea(
        top: false,
        child: Container(
          decoration: BoxDecoration(
            color: kInk,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border(
              top: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
            ),
          ),
          padding: EdgeInsets.fromLTRB(
            20,
            12,
            20,
            20 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.82,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.topRight,
                  child: IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Colors.white,
                    ),
                    tooltip: 'Close',
                  ),
                ),
                Center(
                  child: Column(
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: (user['photoUrl'] == null || user['photoUrl'].toString().isEmpty)
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
                            color: Colors.white.withValues(alpha: 0.15),
                            width: 2,
                          ),
                          image: user['photoUrl'] != null && user['photoUrl'].toString().isNotEmpty
                              ? DecorationImage(
                                  image: CachedNetworkImageProvider(user['photoUrl'].toString()),
                                  fit: BoxFit.cover,
                                )
                              : null,
                        ),
                        child: (user['photoUrl'] == null || user['photoUrl'].toString().isEmpty)
                            ? const Center(
                                child: Icon(
                                  Icons.person_rounded,
                                  color: Colors.white,
                                  size: 40,
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        displayName.toUpperCase(),
                        style: GoogleFonts.dmSans(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        email.isEmpty ? '—' : email,
                        style: GoogleFonts.dmSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: kMuted,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'User profile summary and questionnaire answers',
                        style: GoogleFonts.dmSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w400,
                          color: kMuted.withValues(alpha: 0.8),
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      children: [
                        _buildProfileCard(
                          'Role',
                          user['role']?.toString().toUpperCase(),
                          icon: Icons.badge_outlined,
                          iconColor: const Color(0xFF9E9E9E),
                        ),
                        _buildProfileCard(
                          'Account Status',
                          user['accountStatus']?.toString().toUpperCase(),
                          icon: Icons.verified_user_outlined,
                          iconColor: Theme.of(context).colorScheme.primary,
                        ),
                        _buildProfileCard(
                          'Joined Date',
                          user['createdAt'],
                          icon: Icons.calendar_today_rounded,
                          iconColor: kLilac,
                        ),
                        if (user['accountStatus'] == 'suspended')
                          _buildProfileCard(
                            'Suspension Reason',
                            user['suspendReason'] ?? user['suspensionReason'],
                            icon: Icons.block_rounded,
                            iconColor: const Color(0xFFFF5C5C),
                          ),
                        const SizedBox(height: 12),
                        // Questionnaire Cards
                        _buildProfileCard(
                          'Gender',
                          user['gender'],
                          icon: Icons.wc_rounded,
                          iconColor: const Color(0xFFF48FB1),
                        ),
                        _buildProfileCard(
                          'Age',
                          user['age'],
                          icon: Icons.cake_rounded,
                          iconColor: const Color(0xFFFFAB91),
                          suffix: 'years',
                        ),
                        _buildProfileCard(
                          'Weight',
                          user['weight'],
                          icon: Icons.monitor_weight_outlined,
                          iconColor: const Color(0xFF90CAF9),
                          suffix: 'kg',
                        ),
                        _buildProfileCard(
                          'Height',
                          user['height'],
                          icon: Icons.height_rounded,
                          iconColor: const Color(0xFFB39DDB),
                          suffix: 'cm',
                        ),
                        _buildProfileCard(
                          'Fitness Goal',
                          user['fitnessGoal'],
                          icon: Icons.emoji_events_outlined,
                          iconColor: const Color(0xFFA5D6A7),
                        ),
                        _buildProfileCard(
                          'Activity Level',
                          user['activityLevel'],
                          icon: Icons.flash_on_rounded,
                          iconColor: const Color(0xFFFFE082),
                        ),
                        _buildProfileCard(
                          'Fitness Level',
                          user['fitnessLevel'],
                          icon: Icons.fitness_center_rounded,
                          iconColor: const Color(0xFF80CBC4),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileCard(
    String label,
    dynamic value, {
    required IconData icon,
    required Color iconColor,
    String? suffix,
  }) {
    final formattedValue = _formatProfileValue(value);
    if (formattedValue == 'N/A' || formattedValue == '—') return const SizedBox();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: kMuted,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  suffix != null ? '$formattedValue $suffix' : formattedValue,
                  style: GoogleFonts.dmSans(
                    fontSize: 15,
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
  }

  String _formatProfileValue(dynamic value) {
    if (value == null) return 'N/A';
    if (value is Timestamp) return _formatDateTime(value.toDate().toLocal());
    if (value is DateTime) return _formatDateTime(value.toLocal());

    final text = value.toString();
    
    // Fallback parsing for stringified timestamps
    final secMatch = RegExp(r'seconds[=:]\s*(\d+)').firstMatch(text);
    if (secMatch != null) {
      final seconds = int.tryParse(secMatch.group(1) ?? '');
      if (seconds != null) {
        final dt = DateTime.fromMillisecondsSinceEpoch(seconds * 1000).toLocal();
        return _formatDateTime(dt);
      }
    }
    
    // Also try to parse as ISO8601 string or ordinary date string
    final parsed = DateTime.tryParse(text);
    if (parsed != null) {
      return _formatDateTime(parsed.toLocal());
    }

    return text.isEmpty ? '—' : text;
  }

  String _formatDateTime(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $hh:$mm';
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
