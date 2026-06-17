import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../config/glass_ui.dart';
import '../controllers/streak_details_controller.dart';

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

class StreakDetailsView extends ConsumerWidget {
  const StreakDetailsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(streakDetailsNotifierProvider);
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
          'Workout Streak',
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
                // ─── Streak Counter ────────────────────────────────────────
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 32),
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
                          const Icon(
                            CupertinoIcons.flame,
                            color: coral,
                            size: 32,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            '${state.streak}',
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
                        state.streak == 1 ? 'Day Streak' : 'Days Streak',
                        style: const TextStyle(color: coral, fontSize: 18),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Keep it up! ',
                            style: TextStyle(color: muted, fontSize: 14),
                          ),
                          const Icon(
                            CupertinoIcons.flame_fill,
                            color: coral,
                            size: 14,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // ─── Streak History ────────────────────────────────────────
                Text(
                  'Last 7 Days',
                  style: TextStyle(
                    color: text,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: List.generate(
                    state.streakHistory.length > 7 ? 7 : state.streakHistory.length,
                    (index) {
                      final item = state.streakHistory[
                          state.streakHistory.length -
                              (state.streakHistory.length > 7 ? 7 : state.streakHistory.length) +
                              index];
                      return Container(
                        width: 45,
                        height: 60,
                        decoration: BoxDecoration(
                          color: item['completed'] ? coral : raised,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: stroke),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              item['dayOfWeek'],
                              style: TextStyle(
                                color: item['completed'] ? Colors.white : text,
                                fontSize: 10,
                              ),
                            ),
                            const SizedBox(height: 4),
                            if (item['completed'])
                              const Icon(
                                CupertinoIcons.checkmark_circle_fill,
                                color: Colors.white,
                                size: 20,
                              )
                            else
                              Icon(
                                CupertinoIcons.circle,
                                color: muted,
                                size: 20,
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
