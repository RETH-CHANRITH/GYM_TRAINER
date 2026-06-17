import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../config/glass_ui.dart';
import '../controllers/trainer_availability_controller.dart';

class TrainerAvailabilityView extends ConsumerWidget {
  const TrainerAvailabilityView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(trainerAvailabilityProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = isDark ? const Color(0xFF0A0A0F) : const Color(0xFFF9F9FC);
    final text = isDark ? Colors.white : Colors.black87;
    final muted = isDark ? const Color(0xFF6B6B7E) : Colors.black54;
    final neon = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: ink,
      extendBodyBehindAppBar: true,
      appBar: glassAppBar(title: 'Availability', onBack: () => context.pop(), context: context),
      body: Stack(
        children: [
          Positioned.fill(child: trainerBackground(context)),
          SafeArea(
            child: Column(
              children: [
                // Header with active days counter
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Set Your Schedule',
                                style: GoogleFonts.bebasNeue(
                                  fontSize: 24,
                                  color: text,
                                  letterSpacing: 1,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Choose when you\'re available',
                                style: GoogleFonts.dmSans(
                                  fontSize: 11,
                                  color: muted,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              color: neon.withValues(alpha: 0.2),
                              border: Border.all(
                                color: neon.withValues(alpha: 0.5),
                              ),
                            ),
                            child: Text(
                              '${controller.activeCount} Active',
                              style: GoogleFonts.dmSans(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: neon,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Scrollable days grid
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.only(
                      left: 10,
                      right: 10,
                      bottom: 8,
                    ),
                    child: GridView.builder(
                      physics: const NeverScrollableScrollPhysics(),
                      shrinkWrap: true,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 1.25,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8,
                          ),
                      itemCount: controller.availability.length,
                      itemBuilder: (context, index) {
                        final entry =
                            controller.availability.entries.toList()[index];
                        final day = entry.key;
                        final dayData = entry.value;
                        return _DayAvailabilityCard(
                          day: day,
                          isActive: dayData['active'] as bool,
                          startTime: dayData['startTime'] as String,
                          endTime: dayData['endTime'] as String,
                          onToggle: () => controller.toggleDay(day),
                          onStartTimeChanged:
                              (time) => controller.setStartTime(day, time),
                          onEndTimeChanged:
                              (time) => controller.setEndTime(day, time),
                        );
                      },
                    ),
                  ),
                ),
                // Save button
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () {
                        controller.saveAvailability(
                          onNotify: (title, msg) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('$title: $msg'),
                                backgroundColor: neon,
                              ),
                            );
                          },
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: neon,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        'Save Schedule',
                        style: GoogleFonts.dmSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: isDark ? const Color(0xFF07010E) : Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Individual day card
class _DayAvailabilityCard extends StatefulWidget {
  final String day;
  final bool isActive;
  final String startTime;
  final String endTime;
  final VoidCallback onToggle;
  final Function(String) onStartTimeChanged;
  final Function(String) onEndTimeChanged;

  const _DayAvailabilityCard({
    required this.day,
    required this.isActive,
    required this.startTime,
    required this.endTime,
    required this.onToggle,
    required this.onStartTimeChanged,
    required this.onEndTimeChanged,
  });

  @override
  State<_DayAvailabilityCard> createState() => _DayAvailabilityCardState();
}

class _DayAvailabilityCardState extends State<_DayAvailabilityCard> {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final text = isDark ? Colors.white : Colors.black87;
    final muted = isDark ? const Color(0xFF6B6B7E) : Colors.black54;
    final neon = Theme.of(context).colorScheme.primary;
    final card = isDark ? const Color(0xFF17171F) : const Color(0xFFFFFFFF);
    final stroke = isDark ? const Color(0xFF2A2A36) : const Color(0xFFE5E7EB);

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: isDark ? Colors.white.withValues(alpha: 0.08) : card,
            border: Border.all(color: stroke),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Day header with toggle
              Padding(
                padding: const EdgeInsets.fromLTRB(6, 4, 6, 2),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.day,
                            style: GoogleFonts.dmSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: text,
                            ),
                          ),
                          Text(
                            widget.isActive ? 'Available' : 'Off',
                            style: GoogleFonts.dmSans(
                              fontSize: 8,
                              color: widget.isActive ? neon : muted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Transform.scale(
                      scale: 0.65,
                      child: Switch(
                        value: widget.isActive,
                        onChanged: (_) => widget.onToggle(),
                        activeThumbColor: neon,
                        inactiveTrackColor: muted.withValues(alpha: 0.3),
                      ),
                    ),
                  ],
                ),
              ),
              // Time pickers (collapsible)
              AnimatedSize(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                child: widget.isActive
                    ? Padding(
                        padding: const EdgeInsets.fromLTRB(5, 1, 5, 4),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              height: 0.5,
                              color: stroke,
                              margin: const EdgeInsets.only(bottom: 3),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Expanded(
                                  child: _CompactTimePicker(
                                    label: 'Start',
                                    time: widget.startTime,
                                    onTimeChanged: widget.onStartTimeChanged,
                                  ),
                                ),
                                const SizedBox(width: 3),
                                Expanded(
                                  child: _CompactTimePicker(
                                    label: 'End',
                                    time: widget.endTime,
                                    onTimeChanged: widget.onEndTimeChanged,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Compact time picker
class _CompactTimePicker extends StatelessWidget {
  final String label;
  final String time;
  final Function(String) onTimeChanged;

  const _CompactTimePicker({
    required this.label,
    required this.time,
    required this.onTimeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final text = isDark ? Colors.white : Colors.black87;
    final muted = isDark ? const Color(0xFF6B6B7E) : Colors.black54;
    final stroke = isDark ? const Color(0xFF2A2A36) : const Color(0xFFE5E7EB);
    final raised = isDark ? const Color(0xFF1E1E28) : const Color(0xFFF0EFF5);

    return GestureDetector(
      onTap: () => _showTimePicker(context),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 3),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          color: isDark ? Colors.white.withValues(alpha: 0.08) : raised,
          border: Border.all(color: stroke),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              label,
              style: GoogleFonts.dmSans(
                fontSize: 7,
                color: muted,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              time,
              style: GoogleFonts.dmSans(
                fontSize: 10,
                color: text,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showTimePicker(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _parseTime(time),
    );
    if (picked != null) {
      final hour = picked.hour.toString().padLeft(2, '0');
      final minute = picked.minute.toString().padLeft(2, '0');
      onTimeChanged('$hour:$minute');
    }
  }

  TimeOfDay _parseTime(String timeString) {
    final parts = timeString.split(':');
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }
}
