import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../../config/glass_ui.dart';

/// Reusable KPI card for dashboard metrics
class KpiCard extends StatelessWidget {
  final String title;
  final String value;
  final String? change;
  final IconData icon;
  final Color accentColor;
  final VoidCallback? onTap;

  const KpiCard({
    super.key,
    required this.title,
    required this.value,
    this.change,
    required this.icon,
    this.accentColor = kNeon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Colors.white.withOpacity(0.08),
          border: Border.all(color: Colors.white.withOpacity(0.12)),
          boxShadow: [
            BoxShadow(
              color: accentColor.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: accentColor, size: 24),
                if (change != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: accentColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      change!,
                      style: GoogleFonts.dmSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: accentColor,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: GoogleFonts.dmSans(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: GoogleFonts.dmSans(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: kMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Status badge for various statuses
class StatusBadge extends StatelessWidget {
  final String status;
  final double? padding;

  const StatusBadge(this.status, {super.key, this.padding = 8});

  Color get _backgroundColor {
    final s = status.toLowerCase();
    if (s == 'active' ||
        s == 'approved' ||
        s == 'confirmed' ||
        s == 'paid' ||
        s == 'completed' ||
        s == 'resolved') {
      return Colors.green.withOpacity(0.15);
    }
    if (s == 'suspended' ||
        s == 'rejected' ||
        s == 'cancelled' ||
        s == 'failed') {
      return Colors.red.withOpacity(0.15);
    }
    if (s == 'pending' || s == 'requested' || s == 'in_progress') {
      return Colors.orange.withOpacity(0.15);
    }
    return Colors.blue.withOpacity(0.15);
  }

  Color get _textColor {
    final s = status.toLowerCase();
    if (s == 'active' ||
        s == 'approved' ||
        s == 'confirmed' ||
        s == 'paid' ||
        s == 'completed' ||
        s == 'resolved') {
      return Colors.green;
    }
    if (s == 'suspended' ||
        s == 'rejected' ||
        s == 'cancelled' ||
        s == 'failed') {
      return Colors.red;
    }
    if (s == 'pending' || s == 'requested' || s == 'in_progress') {
      return Colors.orange;
    }
    return Colors.blue;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: padding!,
        vertical: padding! / 2,
      ),
      decoration: BoxDecoration(
        color: _backgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _textColor.withOpacity(0.3)),
      ),
      child: Text(
        status.replaceAll('_', ' ').toUpperCase(),
        style: GoogleFonts.dmSans(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: _textColor,
        ),
      ),
    );
  }
}

/// Action button for admin actions
class AdminActionButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isDestructive;
  final bool isOutlined;
  final IconData? icon;
  final double? width;

  const AdminActionButton({
    super.key,
    required this.label,
    this.onPressed,
    this.isLoading = false,
    this.isDestructive = false,
    this.isOutlined = false,
    this.icon,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final color = isDestructive ? Colors.red : accent;

    return SizedBox(
      width: width,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: (isLoading || onPressed == null) ? null : onPressed,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color: isOutlined ? Colors.transparent : color.withOpacity(0.2),
              border: Border.all(color: color, width: 1.5),
              borderRadius: BorderRadius.circular(10),
            ),
            child:
                isLoading
                    ? SizedBox(
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(
                          isDestructive ? Colors.red : accent,
                        ),
                      ),
                    )
                    : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (icon != null) ...[
                          Icon(icon, color: color, size: 16),
                          const SizedBox(width: 8),
                        ],
                        Text(
                          label,
                          style: GoogleFonts.dmSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: color,
                          ),
                        ),
                      ],
                    ),
          ),
        ),
      ),
    );
  }
}

/// Activity timeline item
class ActivityItem extends StatelessWidget {
  final String title;
  final String subtitle;
  final String time;
  final IconData icon;

  const ActivityItem({
    super.key,
    required this.title,
    required this.subtitle,
    required this.time,
    this.icon = Icons.circle_notifications_rounded,
  });

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: accent.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: accent, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                    color: kMuted,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            time,
            style: GoogleFonts.dmSans(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: kMuted,
            ),
          ),
        ],
      ),
    );
  }
}

/// Loading skeleton for lists
class SkeletonLoader extends StatelessWidget {
  final double height;
  final double? width;
  final double borderRadius;

  const SkeletonLoader({
    super.key,
    this.height = 16,
    this.width,
    this.borderRadius = 8,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}

/// Error state widget
class ErrorStateWidget extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const ErrorStateWidget({
    super.key,
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline_rounded, color: Colors.red, size: 48),
          const SizedBox(height: 16),
          Text(
            'Something went wrong',
            style: GoogleFonts.dmSans(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: GoogleFonts.dmSans(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: kMuted,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          AdminActionButton(
            label: 'Retry',
            icon: Icons.refresh_rounded,
            onPressed: onRetry,
          ),
        ],
      ),
    );
  }
}

/// Empty state widget
class EmptyStateWidget extends StatelessWidget {
  final String title;
  final String message;
  final IconData icon;

  const EmptyStateWidget({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.inbox_rounded,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: kMuted, size: 64),
          const SizedBox(height: 16),
          Text(
            title,
            style: GoogleFonts.dmSans(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: GoogleFonts.dmSans(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: kMuted,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// Search bar with filters
class AdminSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final VoidCallback onSearch;
  final List<String>? filterOptions;
  final ValueChanged<String?>? onFilterChanged;
  final String? selectedFilter;

  const AdminSearchBar({
    super.key,
    required this.controller,
    this.hintText = 'Search...',
    required this.onSearch,
    this.filterOptions,
    this.onFilterChanged,
    this.selectedFilter,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: (_) => onSearch(),
              style: GoogleFonts.dmSans(fontSize: 14, color: Colors.white),
              decoration: InputDecoration(
                hintText: hintText,
                hintStyle: GoogleFonts.dmSans(fontSize: 14, color: kMuted),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 4),
              ),
            ),
          ),
          Icon(Icons.search_rounded, color: Theme.of(context).colorScheme.primary, size: 20),
        ],
      ),
    );
  }
}
