import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../../config/glass_ui.dart';
import '../../controllers/admin_dashboard_controller.dart';
import '../components/admin_components.dart';

class SecurityTab extends ConsumerWidget {
  const SecurityTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(adminDashboardProvider);

    return RefreshIndicator(
      onRefresh: () => Future.wait([
        controller.loadAuditLogs(),
        Future.delayed(const Duration(milliseconds: 800)),
      ]),
      child: Obx(() {
        if (controller.auditLogs.isEmpty) {
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              SizedBox(
                height: MediaQuery.of(context).size.height * 0.7,
                child: Center(
                  child: EmptyStateWidget(
                    title: 'No Audit Logs',
                    message: 'No administrative actions recorded yet',
                    icon: Icons.history_rounded,
                  ),
                ),
              ),
            ],
          );
        }

        return ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: controller.auditLogs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder:
              (context, index) =>
                  _buildAuditLogCard(context, controller.auditLogs[index]),
        );
      }),
    );
  }

  Widget _buildAuditLogCard(BuildContext context, Map<String, dynamic> log) {
    final action = log['action'] as String? ?? 'unknown';
    final actorId = log['actorId'] as String? ?? 'system';
    final target = log['target'] as String? ?? log['targetId'] ?? 'N/A';
    final timestamp = log['timestamp'] as String? ?? 'N/A';
    final status = log['status'] as String? ?? 'completed';
    final requestId = log['requestId'] as String? ?? 'N/A';
    final accent = Theme.of(context).colorScheme.primary;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.white.withOpacity(0.08),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _formatAction(action),
                      style: GoogleFonts.dmSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'Target: $target',
                      style: GoogleFonts.dmSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w400,
                        color: kMuted,
                      ),
                    ),
                  ],
                ),
              ),
              StatusBadge(status, padding: 6),
            ],
          ),
          const SizedBox(height: 10),
          Divider(color: Colors.white.withOpacity(0.08)),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildLogField('Actor', _formatActorId(actorId)),
              _buildLogField('Status', status.toUpperCase()),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildLogField('Time', timestamp),
              _buildLogField('Request ID', _truncateIdForDisplay(requestId)),
            ],
          ),
          const SizedBox(height: 10),
          if (log['before'] != null || log['after'] != null)
            GestureDetector(
              onTap: () => _showLogDetails(context, log),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: accent.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.info_rounded, color: accent, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      'View Changes',
                      style: GoogleFonts.dmSans(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: accent,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLogField(String label, String value) {
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
        const SizedBox(height: 2),
        Text(
          value,
          style: GoogleFonts.dmSans(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  String _formatAction(String action) {
    return action
        .replaceAll('.', ' ')
        .split(' ')
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }

  String _formatActorId(String id) {
    if (id.length > 12) {
      return id.substring(0, 8) + '...';
    }
    return id;
  }

  String _truncateIdForDisplay(String id) {
    if (id.length > 10) {
      return id.substring(0, 8) + '...';
    }
    return id;
  }

  void _showLogDetails(BuildContext context, Map<String, dynamic> log) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1A0330),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(
            top: BorderSide(color: Colors.white.withOpacity(0.12)),
          ),
        ),
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Audit Log Details',
                    style: GoogleFonts.dmSans(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildDetailField('Action', log['action']),
              _buildDetailField('Actor', log['actorId']),
              _buildDetailField('Target', log['target'] ?? log['targetId']),
              _buildDetailField('Status', log['status']),
              _buildDetailField('Timestamp', log['timestamp']),
              _buildDetailField('Request ID', log['requestId']),
              const SizedBox(height: 16),
              if (log['before'] != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Before',
                      style: GoogleFonts.dmSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        log['before'].toString(),
                        style: GoogleFonts.dmSans(fontSize: 10, color: kMuted),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              if (log['after'] != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'After',
                      style: GoogleFonts.dmSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        log['after'].toString(),
                        style: GoogleFonts.dmSans(
                          fontSize: 10,
                          color: Theme.of(context).colorScheme.primary.withOpacity(0.7),
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailField(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.dmSans(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: kMuted,
            ),
          ),
          Expanded(
            child: Text(
              (value ?? 'N/A').toString(),
              textAlign: TextAlign.end,
              style: GoogleFonts.dmSans(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
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
