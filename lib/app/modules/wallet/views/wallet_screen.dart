import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../config/glass_ui.dart';
import '../../../providers/rx_compat.dart';
import '../controllers/wallet_controller.dart';
import '../../../services/bookings_service.dart';
import '../../home/controllers/home_controller.dart';
import '../../search/controllers/search_controller.dart';

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

class WalletScreen extends ConsumerWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(walletNotifierProvider);
    final controller = ref.read(walletNotifierProvider.notifier);

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = isDark ? const Color(0xFF0A0A0F) : const Color(0xFFF9F9FC);
    final card = isDark ? const Color(0xFF17171F) : const Color(0xFFFFFFFF);
    final raised = isDark ? const Color(0xFF1E1E28) : const Color(0xFFF0EFF5);
    final stroke = isDark ? const Color(0xFF2A2A36) : const Color(0xFFE5E7EB);
    final neonC = Theme.of(context).colorScheme.primary;
    final mutedC = isDark ? const Color(0xFF6B6B7E) : Colors.black45;
    final textC = isDark ? Colors.white : Colors.black87;

    return Scaffold(
      backgroundColor: ink,
      body: Stack(
        children: [
          Positioned.fill(child: trainerBackground(context)),
          SafeArea(
            bottom: false,
            child: ListView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(0, 0, 0, 100),
              children: [
                _buildHeader(context, textC, raised, stroke, mutedC),
                const SizedBox(height: 24),
                _buildBalanceCard(state, neonC, mutedC, stroke),
                const SizedBox(height: 24),
                _buildQuickActions(context, state, controller, card, stroke, mutedC),
                const SizedBox(height: 28),
                _buildTransactionList(context, state, ref, card, stroke, neonC, mutedC, textC),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, Color textC, Color raised, Color stroke, Color mutedC) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 24, 0),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => context.pop(),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: raised,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: stroke),
              ),
              child: Icon(
                CupertinoIcons.chevron_left,
                color: textC,
                size: 18,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'My Wallet',
                  style: TextStyle(
                    color: textC,
                    fontWeight: FontWeight.w800,
                    fontSize: 22,
                  ),
                ),
                Text(
                  'Manage your funds',
                  style: TextStyle(color: mutedC, fontSize: 12),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => context.push('/notifications'),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: raised,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: stroke),
              ),
              child: Icon(
                CupertinoIcons.bell,
                color: textC,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceCard(WalletState state, Color neonC, Color mutedC, Color stroke) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1E1E28), Color(0xFF14141C)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: neonC.withOpacity(0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: neonC.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: neonC.withOpacity(0.3)),
                  ),
                  child: Text(
                    'Available Balance',
                    style: TextStyle(
                      color: neonC,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              '\$${state.balance.toStringAsFixed(2)}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 40,
                letterSpacing: -1,
              ),
            ),
            // balance always on dark card so Colors.white is intentional
            const SizedBox(height: 4),
            Text(
              'Last updated just now',
              style: const TextStyle(color: Color(0xFF8484A0), fontSize: 12),
            ),
            const SizedBox(height: 20),
            Container(height: 1, color: const Color(0xFF2A2A36)),
            const SizedBox(height: 16),
            Row(
              children: [
                _miniStat('Spent this month', '\$${state.spentThisMonth.toStringAsFixed(0)}', const Color(0xFF8484A0)),
                Container(width: 1, height: 30, color: const Color(0xFF2A2A36), margin: const EdgeInsets.symmetric(horizontal: 16)),
                _miniStat('Total sessions', '${state.totalSessions}', const Color(0xFF8484A0)),
                Container(width: 1, height: 30, color: const Color(0xFF2A2A36), margin: const EdgeInsets.symmetric(horizontal: 16)),
                _miniStat('Top-ups', '${state.topUps}', const Color(0xFF8484A0)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniStat(String label, String value, Color mutedC) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white, // always on dark card background
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        Text(label, style: TextStyle(color: mutedC, fontSize: 10)),
      ],
    );
  }

  Widget _buildQuickActions(BuildContext context, WalletState state, WalletNotifier controller, Color card, Color stroke, Color mutedC) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Choose highly visible action colors in light mode
    final activeNeon = Theme.of(context).colorScheme.primary;
    final activeSky = isDark ? sky : const Color(0xFF0284C7);
    final activeLilac = isDark ? lilac : const Color(0xFF7C3AED);
    final activeCoral = isDark ? coral : const Color(0xFFDC2626);

    final actions = [
      {
        'label': 'Deposit',
        'icon': CupertinoIcons.plus,
        'color': activeNeon,
        'onTap': () => _showAddFundsSheet(context, controller),
      },
      {
        'label': 'Withdraw',
        'icon': CupertinoIcons.arrow_up,
        'color': activeSky,
        'onTap': () => _showWithdrawSheet(context, state, controller),
      },
      {
        'label': 'Pay',
        'icon': CupertinoIcons.qrcode,
        'color': activeLilac,
        'onTap': () => _showPaySheet(context),
      },
      {
        'label': 'History',
        'icon': CupertinoIcons.time,
        'color': activeCoral,
        'onTap': () => context.push('/tx-history'),
      },
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: actions.asMap().entries.map((entry) {
          final i = entry.key;
          final a = entry.value;
          final accent = a['color'] as Color;
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                right: i < actions.length - 1 ? 10 : 0,
              ),
              child: GestureDetector(
                onTap: a['onTap'] as VoidCallback,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: card,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: stroke),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: accent.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          a['icon'] as IconData,
                          color: accent,
                          size: 20,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        a['label'] as String,
                        style: TextStyle(
                          color: mutedC,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTransactionList(BuildContext context, WalletState state, WidgetRef ref, Color card, Color stroke, Color neonC, Color mutedC, Color textC) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Recent Transactions',
                  style: TextStyle(
                    color: textC,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => context.push('/tx-history', extra: {'filter': 'wallet'}),
                child: Text(
                  'See all',
                  style: TextStyle(color: neonC, fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...state.transactions.map((t) => _buildTxRow(t, ref, card, stroke, neonC, mutedC, textC)),
        ],
      ),
    );
  }

  Widget _buildTxRow(Map<String, dynamic> t, WidgetRef ref, Color card, Color stroke, Color neonC, Color mutedC, Color textC) {
    final isCredit = t['type'] == 'credit';
    final amount = ((t['amount'] as num?)?.toInt() ?? 0).abs();
    final title = t['title'] as String;

    final isSession = title.startsWith('Session — ');
    final trainerName = isSession ? title.replaceFirst('Session — ', '') : '';
    final displayTitle = isSession
        ? 'Transfer to ${trainerName.split(' ').map((w) => w.isNotEmpty ? w[0].toUpperCase() + w.substring(1) : '').join(' ')}'
        : title;
    final trainerPhotoUrl = t['trainerPhotoUrl'] as String?;
    final resolvedPhotoUrl = trainerPhotoUrl ?? (isSession ? _findTrainerPhotoUrl(trainerName, ref) : null);

    // Make coral red color theme-aware for better readability on light backgrounds
    final isDark = textC == Colors.white; // Or check using theme query, but textC is white only in dark mode
    final activeCoral = isDark ? coral : const Color(0xFFDC2626);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: stroke),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: isSession
                  ? (isCredit ? neonC : activeCoral).withOpacity(0.08)
                  : (isCredit ? neonC : activeCoral).withOpacity(0.12),
              borderRadius: isSession ? BorderRadius.circular(12) : BorderRadius.circular(21),
              border: isSession
                  ? Border.all(color: (isCredit ? neonC : activeCoral).withOpacity(0.25), width: 1.5)
                  : null,
            ),
            child: isSession
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: (resolvedPhotoUrl != null && resolvedPhotoUrl.isNotEmpty)
                        ? CachedNetworkImage(
                            imageUrl: resolvedPhotoUrl,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => InitialsAvatar(
                              name: trainerName,
                              size: 42,
                              fontSize: 13,
                              borderRadius: 10,
                            ),
                            errorWidget: (context, url, error) => InitialsAvatar(
                              name: trainerName,
                              size: 42,
                              fontSize: 13,
                              borderRadius: 10,
                            ),
                          )
                        : InitialsAvatar(
                            name: trainerName,
                            size: 42,
                            fontSize: 13,
                            borderRadius: 10,
                          ),
                  )
                : Icon(
                    isCredit
                        ? CupertinoIcons.arrow_down_circle_fill
                        : CupertinoIcons.arrow_up_circle_fill,
                    color: isCredit ? neonC : activeCoral,
                    size: 20,
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayTitle,
                  style: TextStyle(
                    color: textC,
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
                Text(
                  t['date'] as String,
                  style: TextStyle(color: mutedC, fontSize: 11),
                ),
              ],
            ),
          ),
          Text(
            '${isCredit ? '+' : '-'}\$$amount',
            style: TextStyle(
              color: isCredit ? neonC : activeCoral,
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }

  void _showAddFundsSheet(BuildContext context, WalletNotifier controller) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sheetBg = isDark ? const Color(0xFF17171F) : const Color(0xFFFFFFFF);
    final sheetStroke = isDark ? const Color(0xFF2A2A36) : const Color(0xFFE5E7EB);
    final sheetText = isDark ? Colors.white : Colors.black87;
    final sheetMuted = isDark ? const Color(0xFF6B6B7E) : Colors.black54;
    final activeNeon = Theme.of(context).colorScheme.primary;

    final amounts = [50, 100, 200, 500];
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
        decoration: BoxDecoration(
          color: sheetBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(top: BorderSide(color: sheetStroke)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: sheetStroke,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Deposit',
              style: TextStyle(
                color: sheetText,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Select an amount to top up your wallet.',
              style: TextStyle(color: sheetMuted, fontSize: 13),
            ),
            const SizedBox(height: 20),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 2.8,
              physics: const NeverScrollableScrollPhysics(),
              children: amounts
                  .map(
                    (amt) => GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                        controller.addFunds(amt.toDouble(), onNotifyUser: (msg) => showSnackbar('Wallet', msg));
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: activeNeon.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: activeNeon.withOpacity(0.35)),
                        ),
                        child: Center(
                          child: Text(
                            '+\$$amt',
                            style: TextStyle(
                              color: activeNeon,
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  void _showWithdrawSheet(BuildContext context, WalletState state, WalletNotifier controller) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sheetBg = isDark ? const Color(0xFF17171F) : const Color(0xFFFFFFFF);
    final sheetStroke = isDark ? const Color(0xFF2A2A36) : const Color(0xFFE5E7EB);
    final sheetText = isDark ? Colors.white : Colors.black87;
    final sheetMuted = isDark ? const Color(0xFF6B6B7E) : Colors.black54;
    final activeSky = isDark ? sky : const Color(0xFF0284C7);

    final amounts = [50, 100, 150, 200];
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
        decoration: BoxDecoration(
          color: sheetBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(top: BorderSide(color: sheetStroke)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: sheetStroke,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Withdraw Funds',
              style: TextStyle(
                color: sheetText,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Available: \$${state.balance.toStringAsFixed(2)}',
              style: TextStyle(color: sheetMuted, fontSize: 13),
            ),
            const SizedBox(height: 20),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 2.8,
              physics: const NeverScrollableScrollPhysics(),
              children: amounts
                  .map(
                    (amt) => GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                        controller.withdraw(amt.toDouble(), onNotifyUser: (msg) => showSnackbar('Wallet', msg));
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: activeSky.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: activeSky.withOpacity(0.35)),
                        ),
                        child: Center(
                          child: Text(
                            '\$$amt',
                            style: TextStyle(
                              color: activeSky,
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  void _showPaySheet(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sheetBg = isDark ? const Color(0xFF17171F) : const Color(0xFFFFFFFF);
    final sheetStroke = isDark ? const Color(0xFF2A2A36) : const Color(0xFFE5E7EB);
    final sheetText = isDark ? Colors.white : Colors.black87;
    final sheetMuted = isDark ? const Color(0xFF6B6B7E) : Colors.black54;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
        decoration: BoxDecoration(
          color: sheetBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(top: BorderSide(color: sheetStroke)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: sheetStroke,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Pay via QR',
              style: TextStyle(
                color: sheetText,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Let your trainer scan this to collect payment.',
              style: TextStyle(color: sheetMuted, fontSize: 13),
            ),
            const SizedBox(height: 24),
            Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Center(
                child: Icon(
                  CupertinoIcons.qrcode,
                  size: 130,
                  color: Colors.black,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'gymtrainer.app/pay/user123',
              style: TextStyle(color: sheetMuted, fontSize: 12),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  String? _findTrainerPhotoUrl(String name, WidgetRef ref) {
    try {
      final target = name.toLowerCase().trim();

      // 1. Search in current transactions
      final txs = ref.read(walletNotifierProvider).transactions;
      for (final t in txs) {
        final title = (t['title'] ?? '') as String;
        if (title.startsWith('Session — ')) {
          final tName = title.replaceFirst('Session — ', '').toLowerCase().trim();
          if (tName == target) {
            final url = t['trainerPhotoUrl'] as String?;
            if (url != null && url.isNotEmpty) {
              return url;
            }
          }
        }
      }

      // 2. Search in bookings
      final bookingsState = ref.read(bookingsServiceProvider);
      final allBookings = [...bookingsState.upcomingBookings, ...bookingsState.pastBookings];
      for (final b in allBookings) {
        final bName = ((b['trainerName'] ?? b['trainer'] ?? '') as String).toLowerCase().trim();
        if (bName == target) {
          final url = b['trainerPhotoUrl'] as String?;
          if (url != null && url.isNotEmpty) {
            return url;
          }
        }
      }

      // 3. Search in home state trainer catalogs
      try {
        final homeState = ref.read(homeNotifierProvider);
        final homeTrainers = [...homeState.trainerCatalog, ...homeState.featuredTrainers];
        for (final ht in homeTrainers) {
          final htName = ((ht['name'] ?? '') as String).toLowerCase().trim();
          if (htName == target) {
            final url = (ht['trainerPhotoUrl'] ?? ht['image'] ?? ht['imageUrl'] ?? '') as String;
            if (url.isNotEmpty) {
              return url;
            }
          }
        }
      } catch (_) {}

      // 4. Search in search state all trainers
      try {
        final searchState = ref.read(searchNotifierProvider);
        for (final st in searchState.allTrainers) {
          final stName = ((st['name'] ?? '') as String).toLowerCase().trim();
          if (stName == target) {
            final url = (st['trainerPhotoUrl'] ?? st['image'] ?? st['imageUrl'] ?? '') as String;
            if (url.isNotEmpty) {
              return url;
            }
          }
        }
      } catch (_) {}
    } catch (_) {}
    return null;
  }
}
