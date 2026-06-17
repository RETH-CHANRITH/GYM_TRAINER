import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../config/glass_ui.dart';
import '../controllers/goals_details_controller.dart';

// ─── Design Tokens ──────────────────────────────────────────────────────────
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

class GoalsDetailsView extends ConsumerWidget {
  const GoalsDetailsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(goalsDetailsNotifierProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = isDark ? const Color(0xFF0A0A0F) : const Color(0xFFF9F9FC);
    final surface = isDark ? const Color(0xFF111118) : const Color(0xFFE5E7EB);
    final card = isDark ? const Color(0xFF17171F) : const Color(0xFFFFFFFF);
    final raised = isDark ? const Color(0xFF1E1E28) : const Color(0xFFF0EFF5);
    final stroke = isDark ? const Color(0xFF2A2A36) : const Color(0xFFE5E7EB);
    final neon = Theme.of(context).colorScheme.primary;
    final muted = isDark ? const Color(0xFF6B6B7E) : Colors.black54;
    final text = isDark ? Colors.white : Colors.black87;

    return Scaffold(
      backgroundColor: ink,
      appBar: AppBar(
        backgroundColor: surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(CupertinoIcons.back, color: text),
          onPressed: () => context.pop(),
        ),
        centerTitle: true,
        title: Text(
          'Fitness Goals',
          style: TextStyle(color: text, fontWeight: FontWeight.w600),
        ),
      ),
      body: Stack(
        children: [
          Positioned.fill(child: trainerBackground(context)),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                // ─── Goals Count ──────────────────────────────────────────
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  decoration: BoxDecoration(
                    color: card,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: stroke),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            CupertinoIcons.rosette,
                            color: neon,
                            size: 32,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            '${state.goalsCount}',
                            style: TextStyle(
                              color: text,
                              fontSize: 48,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Active Goals',
                        style: TextStyle(color: neon, fontSize: 18),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // ─── Goals List ──────────────────────────────────────────
                Text(
                  'Your Goals',
                  style: TextStyle(
                    color: text,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView.builder(
                    itemCount: state.goals.length,
                    itemBuilder: (context, index) {
                      final goal = state.goals[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: card,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: stroke),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: neon.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: neon.withValues(alpha: 0.24),
                                      width: 1,
                                    ),
                                  ),
                                  child: Icon(
                                    goal['icon'] as IconData,
                                    color: neon,
                                    size: 22,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        goal['title'],
                                        style: TextStyle(
                                          color: text,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        goal['description'],
                                        style: TextStyle(
                                          color: muted,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            // Progress Bar
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: LinearProgressIndicator(
                                value: (goal['progress'] as num) / 100,
                                minHeight: 8,
                                backgroundColor: raised,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  (goal['progress'] as num) >= 75 ? neon : sky,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${(goal['progress'] as num).toInt()}% Complete',
                              style: TextStyle(color: muted, fontSize: 12),
                            ),
                          ],
                        ),
                      );
                    },
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
