import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../config/glass_ui.dart';
import '../../../services/user_profile_service.dart';
import '../../../routes/app_router.dart' show Routes;

const Color ink = Color(0xFF0A0A0F);
const Color surface = Color(0xFF111118);
const Color card = Color(0xFF17171F);
const Color raised = Color(0xFF1E1E28);
const Color stroke = Color(0xFF2A2A36);
const Color neon = Color(0xFFCBFF47);
const Color coral = Color(0xFFFF5C5C);
const Color sky = Color(0xFF5CE8FF);
const Color lilac = Color(0xFFA78BFA);
const Color muted = Color(0xFF6B6B7E);

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  void _softTap() => HapticFeedback.selectionClick();

  Color get ink => Theme.of(context).brightness == Brightness.dark ? const Color(0xFF0A0A0F) : const Color(0xFFF9F9FC);
  Color get card => Theme.of(context).brightness == Brightness.dark ? const Color(0xFF17171F) : const Color(0xFFFFFFFF);
  Color get raised => Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E1E28) : const Color(0xFFF0EFF5);
  Color get stroke => Theme.of(context).brightness == Brightness.dark ? const Color(0xFF2A2A36) : const Color(0xFFE5E7EB);
  Color get neon => Theme.of(context).colorScheme.primary;
  Color get muted => Theme.of(context).brightness == Brightness.dark ? const Color(0xFF6B6B7E) : Colors.black54;
  Color get text => Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87;

  Future<void> _showInfoSheet({
    required String title,
    required String message,
  }) async {
    _softTap();
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder:
          (_) => Container(
            decoration: BoxDecoration(
              color: card,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
            ),
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: stroke,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  title,
                  style: TextStyle(
                    color: text,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(message, style: TextStyle(color: muted, fontSize: 13)),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: neon,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Got it',
                      style: TextStyle(color: ink, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ),
    );
  }

  Future<void> _handleMenuTap(String label) async {
    _softTap();
    switch (label) {
      case 'Edit Profile':
        context.push(Routes.PROFILE_SUMMARY);
        return;
      case 'Subscription':
        context.push(Routes.WALLET);
        return;
      case 'Notifications':
        context.push(Routes.NOTIFICATIONS);
        return;
      case 'Privacy & Security':
        context.push(Routes.SETTINGS);
        return;
      case 'Help & Support':
        await _showInfoSheet(
          title: 'Help & Support',
          message:
              'Need help with your account, booking, or payment? Open Settings and tap Help & Support to submit a ticket directly.',
        );
        return;
      case 'Log Out':
        await _handleLogout(context);
        return;
      default:
        return;
    }
  }

  void _handleStatsTap(String type) {
    _softTap();
    switch (type) {
      case 'sessions':
        context.push(Routes.MY_BOOKINGS);
        break;
      case 'trainers':
        context.push(Routes.FAVORITE);
        break;
      case 'workout':
        context.push(Routes.ALL_SESSIONS);
        break;
    }
  }

  Future<void> _showAllGoals() async {
    await _showInfoSheet(
      title: 'My Goals',
      message:
          'You are tracking 4 goals: Lose Weight, Build Muscle, Flexibility, and Endurance. Goal editing and custom goals are coming next.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final profileState = ref.watch(userProfileServiceProvider);

    return Scaffold(
      backgroundColor: ink,
      body: Stack(
        children: [
          Positioned.fill(child: trainerBackground(context)),
          SafeArea(
            child: ListView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(0, 0, 0, 100),
              children: [
                _buildHeader(),
                const SizedBox(height: 24),
                _buildProfileCard(profileState),
                const SizedBox(height: 24),
                _buildQuickStats(),
                const SizedBox(height: 24),
                _buildGoalsSection(),
                const SizedBox(height: 24),
                _buildMenuSection(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [lilac.withOpacity(0.2), lilac.withOpacity(0.05)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: lilac.withOpacity(0.3)),
            ),
            child: const Icon(
              CupertinoIcons.person_fill,
              color: lilac,
              size: 22,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'My Profile',
                  style: TextStyle(
                    color: text,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Manage your account',
                  style: TextStyle(color: muted, fontSize: 13),
                ),
              ],
            ),
          ),
          _iconButton(CupertinoIcons.settings, () => context.push(Routes.SETTINGS)),
        ],
      ),
    );
  }

  Widget _iconButton(IconData icon, VoidCallback onTap) {
    return Material(
      color: card,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: stroke),
          ),
          child: Icon(icon, color: text.withOpacity(0.7), size: 20),
        ),
      ),
    );
  }

  Widget _buildProfileCard(UserProfileState profileState) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [neon.withOpacity(0.08), Colors.transparent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: neon.withOpacity(0.2)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () => _handleMenuTap('Edit Profile'),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                // Avatar
                Stack(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [neon, neon.withOpacity(0.5)],
                        ),
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(19),
                        child: SizedBox(
                          width: 72,
                          height: 72,
                          child: profileState.photoUrl.isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: profileState.photoUrl,
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => InitialsAvatar(
                                    name: profileState.name,
                                    size: 72,
                                    fontSize: 26,
                                    borderRadius: 19,
                                  ),
                                  errorWidget: (context, url, error) => InitialsAvatar(
                                    name: profileState.name,
                                    size: 72,
                                    fontSize: 26,
                                    borderRadius: 19,
                                  ),
                                )
                              : InitialsAvatar(
                                  name: profileState.name,
                                  size: 72,
                                  fontSize: 26,
                                  borderRadius: 19,
                                ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: card,
                          shape: BoxShape.circle,
                        ),
                        child: Container(
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            color: neon,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            CupertinoIcons.checkmark_alt,
                            color: ink,
                            size: 12,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 16),
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profileState.name,
                        style: TextStyle(
                          color: text,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        profileState.email.isNotEmpty
                            ? profileState.email
                            : 'No email linked',
                        style: TextStyle(color: muted, fontSize: 12),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              neon.withOpacity(0.15),
                              neon.withOpacity(0.05),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: neon.withOpacity(0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              CupertinoIcons.rosette,
                              color: neon,
                              size: 14,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              'Premium',
                              style: TextStyle(
                                color: neon,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(CupertinoIcons.pencil, color: muted, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickStats() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          _statBox(
            '12',
            'Sessions',
            CupertinoIcons.sportscourt,
            neon,
            onTap: () => _handleStatsTap('sessions'),
          ),
          const SizedBox(width: 12),
          _statBox(
            '3',
            'Trainers',
            CupertinoIcons.person_2,
            sky,
            onTap: () => _handleStatsTap('trainers'),
          ),
          const SizedBox(width: 12),
          _statBox(
            '24h',
            'Workout',
            CupertinoIcons.timer,
            lilac,
            onTap: () => _handleStatsTap('workout'),
          ),
        ],
      ),
    );
  }

  Widget _statBox(
    String value,
    String label,
    IconData icon,
    Color color, {
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Ink(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: card,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: stroke),
            ),
            child: Column(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        color.withOpacity(0.15),
                        color.withOpacity(0.05),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 18),
                ),
                const SizedBox(height: 12),
                Text(
                  value,
                  style: TextStyle(
                    color: color,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(label, style: TextStyle(color: muted, fontSize: 11)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGoalsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'My Goals',
                style: TextStyle(
                  color: text,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              GestureDetector(
                onTap: _showAllGoals,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: neon.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'View All',
                    style: TextStyle(
                      color: neon,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 100,
          child: ListView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            children: [
              _goalCard(
                'Lose Weight',
                '5 lbs to go',
                0.7,
                coral,
                CupertinoIcons.gauge,
              ),
              _goalCard(
                'Build Muscle',
                '3/5 weeks',
                0.6,
                neon,
                CupertinoIcons.sportscourt,
              ),
              _goalCard(
                'Flexibility',
                '80% done',
                0.8,
                sky,
                CupertinoIcons.person,
              ),
              _goalCard(
                'Endurance',
                '50% done',
                0.5,
                lilac,
                CupertinoIcons.bolt,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _goalCard(
    String title,
    String subtitle,
    double progress,
    Color color,
    IconData icon,
  ) {
    return Container(
      width: 150,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.1), color.withOpacity(0.02)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: text,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(subtitle, style: TextStyle(color: muted, fontSize: 11)),
          const Spacer(),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: color.withOpacity(0.2),
              valueColor: AlwaysStoppedAnimation(color),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 14),
            child: Text(
              'Settings',
              style: TextStyle(
                color: text,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          ..._menuItems().asMap().entries.map((e) => _menuTile(e.value, e.key)),
        ],
      ),
    );
  }

  Future<void> _handleLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (_) => AlertDialog(
            backgroundColor: card,
            title: Text('Log Out', style: TextStyle(color: text)),
            content: Text(
              'Are you sure you want to log out?',
              style: TextStyle(color: muted),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('Cancel', style: TextStyle(color: muted)),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text(
                  'Log Out',
                  style: TextStyle(color: Color(0xFFFF5C5C)),
                ),
              ),
            ],
          ),
    );
    if (confirmed != true) return;
    await FirebaseAuth.instance.signOut();
    if (context.mounted) {
      context.go(Routes.LOGIN);
    }
  }

  Widget _menuTile(Map<String, dynamic> item, int index) {
    final bool isDanger = item['danger'] == true;
    final Color color = item['color'] as Color;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 300 + (index * 60)),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 15 * (1 - value)),
          child: Opacity(opacity: value, child: child),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: isDanger ? coral.withOpacity(0.08) : card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isDanger ? coral.withOpacity(0.3) : stroke),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => _handleMenuTap(item['label'] as String),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          color.withOpacity(0.15),
                          color.withOpacity(0.05),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      item['icon'] as IconData,
                      color: color,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item['label'] as String,
                          style: TextStyle(
                            color: isDanger ? coral : text,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (item['subtitle'] != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              item['subtitle'] as String,
                              style: TextStyle(color: muted, fontSize: 11),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Icon(
                    CupertinoIcons.chevron_right,
                    color: isDanger ? coral.withOpacity(0.5) : muted,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _menuItems() => [
    {
      'icon': CupertinoIcons.person,
      'label': 'Edit Profile',
      'subtitle': 'Update your information',
      'color': neon,
      'danger': false,
    },
    {
      'icon': CupertinoIcons.creditcard,
      'label': 'Subscription',
      'subtitle': 'Premium - Renews Mar 15',
      'color': sky,
      'danger': false,
    },
    {
      'icon': CupertinoIcons.bell,
      'label': 'Notifications',
      'subtitle': 'Manage alerts',
      'color': lilac,
      'danger': false,
    },
    {
      'icon': CupertinoIcons.shield,
      'label': 'Privacy & Security',
      'subtitle': null,
      'color': lilac,
      'danger': false,
    },
    {
      'icon': CupertinoIcons.question_circle,
      'label': 'Help & Support',
      'subtitle': null,
      'color': sky,
      'danger': false,
    },
    {
      'icon': CupertinoIcons.square_arrow_right,
      'label': 'Log Out',
      'subtitle': null,
      'color': coral,
      'danger': true,
    },
  ];
}
