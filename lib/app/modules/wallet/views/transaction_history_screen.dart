import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../config/glass_ui.dart';
import '../../../services/bookings_service.dart';
import '../controllers/wallet_controller.dart';
import '../../home/controllers/home_controller.dart';
import '../../search/controllers/search_controller.dart';

class TransactionHistoryScreen extends ConsumerWidget {
  final Map<String, dynamic>? arguments;
  const TransactionHistoryScreen({super.key, this.arguments});

  Color _ink(BuildContext context) => Theme.of(context).brightness == Brightness.dark ? const Color(0xFF0A0A0F) : const Color(0xFFF9F9FC);
  Color _surface(BuildContext context) => Theme.of(context).brightness == Brightness.dark ? const Color(0xFF111118) : const Color(0xFFE5E7EB);
  Color _card(BuildContext context) => Theme.of(context).brightness == Brightness.dark ? const Color(0xFF17171F) : const Color(0xFFFFFFFF);
  Color _raised(BuildContext context) => Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E1E28) : const Color(0xFFF0EFF5);
  Color _stroke(BuildContext context) => Theme.of(context).brightness == Brightness.dark ? const Color(0xFF2A2A36) : const Color(0xFFE5E7EB);
  Color _neon(BuildContext context) => Theme.of(context).colorScheme.primary;
  Color _coral(BuildContext context) => Theme.of(context).brightness == Brightness.dark ? const Color(0xFFFF5C5C) : const Color(0xFFFF4F4F);
  Color _muted(BuildContext context) => Theme.of(context).brightness == Brightness.dark ? const Color(0xFF6B6B7E) : Colors.black54;
  Color _text(BuildContext context) => Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87;

  String _getFormattedTxDateTime(Map<String, dynamic> t) {
    final createdAt = t['createdAt'];
    if (createdAt is Timestamp) {
      final dt = createdAt.toDate();
      const months = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
      final amPm = dt.hour >= 12 ? 'PM' : 'AM';
      final minute = dt.minute.toString().padLeft(2, '0');
      return '${months[dt.month]} ${dt.day}, ${dt.year} at ${hour.toString().padLeft(2, '0')}:$minute $amPm';
    }
    return (t['date'] ?? '').toString();
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

  bool _isWalletOnly(BuildContext context) {
    final args = arguments ?? GoRouterState.of(context).extra as Map<String, dynamic>?;
    return args?['filter'] == 'wallet';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(walletNotifierProvider);
    final controller = ref.read(walletNotifierProvider.notifier);
    ref.watch(bookingsServiceProvider); // watch to remain reactive to booking changes
    final walletOnly = _isWalletOnly(context);

    return Scaffold(
      backgroundColor: _ink(context),
      body: Stack(
        children: [
          Positioned.fill(child: trainerBackground(context)),
          SafeArea(
            bottom: false,
            child: ListView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(0, 0, 0, 100),
              children: [
                _buildHeader(context, walletOnly),
                const SizedBox(height: 24),
                if (!walletOnly) ...[
                  _buildTrainerSummary(context, ref, state, controller),
                  const SizedBox(height: 28),
                ],
                _buildFullList(context, ref, state, walletOnly),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Header ───────────────────────────────────────────────────────────────
  Widget _buildHeader(BuildContext context, bool walletOnly) {
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
                color: _raised(context),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _stroke(context)),
              ),
              child: Icon(
                CupertinoIcons.chevron_left,
                color: _text(context),
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
                  walletOnly ? 'Deposits & Withdrawals' : 'Payment History',
                  style: TextStyle(
                    color: _text(context),
                    fontWeight: FontWeight.w800,
                    fontSize: 22,
                  ),
                ),
                Text(
                  walletOnly
                      ? 'Your top-ups and withdrawals'
                      : 'All your trainer payments',
                  style: TextStyle(color: _muted(context), fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Trainer Summary Cards ────────────────────────────────────────────────
  Widget _buildTrainerSummary(BuildContext context, WidgetRef ref, WalletState state, WalletNotifier controller) {
    final summary = controller.trainerSummary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            'Paid to Trainers',
            style: TextStyle(
              color: _text(context),
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 195,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: summary.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, i) => _buildTrainerCard(context, ref, state, controller, summary[i]),
          ),
        ),
      ],
    );
  }

  Widget _buildTrainerCard(BuildContext context, WidgetRef ref, WalletState state, WalletNotifier controller, Map<String, dynamic> s) {
    final portrait = s['portrait'] as int?;
    final trainerPhotoUrl = s['trainerPhotoUrl'] as String?;
    final name = s['name'] as String;
    final total = (s['total'] as num?)?.toInt() ?? 0;
    final count = (s['count'] as num?)?.toInt() ?? 0;
    final resolvedPhotoUrl = trainerPhotoUrl ?? _findTrainerPhotoUrl(name, ref);

    return GestureDetector(
      onTap: () => _showTrainerDetail(context, ref, state, controller, s),
      child: Container(
        width: 152,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              _raised(context),
              _card(context),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _stroke(context), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Avatar & Outbound Icon
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: _neon(context).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _neon(context).withValues(alpha: 0.25), width: 1.5),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: (resolvedPhotoUrl != null && resolvedPhotoUrl.isNotEmpty)
                        ? CachedNetworkImage(
                            imageUrl: resolvedPhotoUrl,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => InitialsAvatar(
                              name: name,
                              size: 52,
                              fontSize: 16,
                              borderRadius: 14,
                            ),
                            errorWidget: (context, url, error) => InitialsAvatar(
                              name: name,
                              size: 52,
                              fontSize: 16,
                              borderRadius: 14,
                            ),
                          )
                        : portrait != null
                            ? CachedNetworkImage(
                                imageUrl: 'https://randomuser.me/api/portraits/men/$portrait.jpg',
                                fit: BoxFit.cover,
                                placeholder: (context, url) => InitialsAvatar(
                                  name: name,
                                  size: 52,
                                  fontSize: 16,
                                  borderRadius: 14,
                                ),
                                errorWidget: (context, url, error) => InitialsAvatar(
                                  name: name,
                                  size: 52,
                                  fontSize: 16,
                                  borderRadius: 14,
                                ),
                              )
                            : InitialsAvatar(
                                name: name,
                                size: 52,
                                fontSize: 16,
                                borderRadius: 14,
                              ),
                  ),
                ),
                // Outbound arrow indicator
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark ? Colors.white.withValues(alpha: 0.04) : _raised(context),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    CupertinoIcons.arrow_up_right,
                    color: _coral(context).withValues(alpha: 0.7),
                    size: 14,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            // Trainer Name
            Text(
              name,
              style: TextStyle(
                color: _text(context),
                fontWeight: FontWeight.w800,
                fontSize: 14,
                letterSpacing: -0.3,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            // Sessions Pill
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark ? Colors.white.withValues(alpha: 0.04) : _raised(context),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _stroke(context)),
              ),
              child: Text(
                '$count session${count > 1 ? 's' : ''}',
                style: TextStyle(
                  color: _muted(context),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.1,
                ),
              ),
            ),
            const Spacer(),
            // Paid Info Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PAID OUT',
                      style: TextStyle(
                        color: _muted(context),
                        fontSize: 8,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '-\$$total',
                      style: TextStyle(
                        color: _coral(context),
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ],
                ),
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: _coral(context).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    CupertinoIcons.arrow_up_right,
                    color: _coral(context),
                    size: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showTrainerDetail(BuildContext context, WidgetRef ref, WalletState state, WalletNotifier controller, Map<String, dynamic> s) {
    final name = s['name'] as String;
    final portrait = s['portrait'] as int?;
    final trainerPhotoUrl = s['trainerPhotoUrl'] as String?;
    final total = (s['total'] as num?)?.toInt() ?? 0;
    final count = (s['count'] as num?)?.toInt() ?? 0;
    final resolvedPhotoUrl = trainerPhotoUrl ?? _findTrainerPhotoUrl(name, ref);
    // Get all sessions for this trainer
    final sessions = state.transactions
        .where((t) => t['title'] == 'Session — $name')
        .toList();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
        decoration: BoxDecoration(
          color: _card(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: _stroke(context),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            // Avatar + name row
            Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: _neon(context).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _neon(context).withValues(alpha: 0.25), width: 1.5),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: (resolvedPhotoUrl != null && resolvedPhotoUrl.isNotEmpty)
                        ? CachedNetworkImage(
                            imageUrl: resolvedPhotoUrl,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => InitialsAvatar(
                              name: name,
                              size: 56,
                              fontSize: 18,
                              borderRadius: 14,
                            ),
                            errorWidget: (context, url, error) => InitialsAvatar(
                              name: name,
                              size: 56,
                              fontSize: 18,
                              borderRadius: 14,
                            ),
                          )
                        : portrait != null
                            ? CachedNetworkImage(
                                imageUrl: 'https://randomuser.me/api/portraits/men/$portrait.jpg',
                                fit: BoxFit.cover,
                                placeholder: (context, url) => InitialsAvatar(
                                  name: name,
                                  size: 56,
                                  fontSize: 18,
                                  borderRadius: 14,
                                ),
                                errorWidget: (context, url, error) => InitialsAvatar(
                                  name: name,
                                  size: 56,
                                  fontSize: 18,
                                  borderRadius: 14,
                                ),
                              )
                            : InitialsAvatar(
                                name: name,
                                size: 56,
                                fontSize: 18,
                                borderRadius: 14,
                              ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: TextStyle(
                          color: _text(context),
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$count session${count > 1 ? 's' : ''} · Total paid: \$$total',
                        style: TextStyle(color: _muted(context), fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Container(height: 1, color: _stroke(context)),
            const SizedBox(height: 16),
            // Session breakdown
            ...sessions.map((t) {
              final amount = ((t['amount'] as num?)?.toInt() ?? 0).abs();
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: _coral(context).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        CupertinoIcons.creditcard_fill,
                        color: _coral(context),
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Session Payment',
                            style: TextStyle(
                              color: _text(context),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            _getFormattedTxDateTime(t),
                            style: TextStyle(color: _muted(context), fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '-\$$amount',
                      style: TextStyle(
                        color: _coral(context),
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  // ─── Full Transaction List ────────────────────────────────────────────────
  Widget _buildFullList(BuildContext context, WidgetRef ref, WalletState state, bool walletOnly) {
    final allTxs = state.transactions;
    final txs = walletOnly
        ? allTxs
            .where((t) => t['type'] == 'credit' || !(t['title'] as String).startsWith('Session'))
            .toList()
        : allTxs;

    final label = walletOnly ? 'Deposits & Withdrawals' : 'All Transactions';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: _text(context),
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 14),
          if (txs.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 20),
              child: Center(
                child: Text(
                  'No transactions yet',
                  style: TextStyle(color: _muted(context), fontSize: 14),
                ),
              ),
            )
          else
            ...txs.map((t) => _buildTxRow(context, ref, t)),
        ],
      ),
    );
  }

  Widget _buildTxRow(BuildContext context, WidgetRef ref, Map<String, dynamic> t) {
    final isCredit = t['type'] == 'credit';
    final isSession = !isCredit && (t['title'] as String).startsWith('Session');
    final amount = ((t['amount'] as num?)?.toInt() ?? 0).abs();
    final portrait = t['portrait'] as int?;
    final trainerPhotoUrl = t['trainerPhotoUrl'] as String?;
    final title = t['title'] as String;
    final trainerName = isSession ? title.replaceFirst('Session — ', '') : '';
    final displayTitle = isSession
        ? 'Transfer to ${trainerName.split(' ').map((w) => w.isNotEmpty ? w[0].toUpperCase() + w.substring(1) : '').join(' ')}'
        : title;
    final resolvedPhotoUrl = trainerPhotoUrl ?? (isSession ? _findTrainerPhotoUrl(trainerName, ref) : null);

    return GestureDetector(
      onTap: () => _showTxDetail(context, ref, t),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_card(context), _card(context).withValues(alpha: 0.75)],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _stroke(context)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            // Avatar / icon
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: (isCredit ? _neon(context) : _coral(context)).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(13),
              ),
              child: isSession && (resolvedPhotoUrl != null && resolvedPhotoUrl.isNotEmpty)
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(13),
                      child: CachedNetworkImage(
                        imageUrl: resolvedPhotoUrl,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => InitialsAvatar(
                          name: trainerName,
                          size: 44,
                          fontSize: 14,
                          borderRadius: 13,
                        ),
                        errorWidget: (context, url, error) => InitialsAvatar(
                          name: trainerName,
                          size: 44,
                          fontSize: 14,
                          borderRadius: 13,
                        ),
                      ),
                    )
                  : isSession && portrait != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(13),
                          child: CachedNetworkImage(
                            imageUrl: 'https://randomuser.me/api/portraits/men/$portrait.jpg',
                            fit: BoxFit.cover,
                            placeholder: (context, url) => InitialsAvatar(
                              name: trainerName,
                              size: 44,
                              fontSize: 14,
                              borderRadius: 13,
                            ),
                            errorWidget: (context, url, error) => InitialsAvatar(
                              name: trainerName,
                              size: 44,
                              fontSize: 14,
                              borderRadius: 13,
                            ),
                          ),
                        )
                      : Icon(
                          isCredit
                              ? CupertinoIcons.arrow_down_circle_fill
                              : CupertinoIcons.arrow_up_circle_fill,
                          color: isCredit ? _neon(context) : _coral(context),
                          size: 20,
                        ),
            ),
            const SizedBox(width: 12),
            // Title + date
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayTitle,
                    style: TextStyle(
                      color: _text(context),
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _getFormattedTxDateTime(t),
                    style: TextStyle(color: _muted(context), fontSize: 11, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
            // Amount
            Text(
              '${isCredit ? '+' : '-'}\$$amount',
              style: TextStyle(
                color: isCredit ? _neon(context) : _coral(context),
                fontWeight: FontWeight.w900,
                fontSize: 16,
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showTxDetail(BuildContext context, WidgetRef ref, Map<String, dynamic> t) {
    final isCredit = t['type'] == 'credit';
    final isSession = !isCredit && (t['title'] as String).startsWith('Session');
    final isWithdrawal = !isCredit && (t['title'] as String) == 'Withdrawal';
    final amount = ((t['amount'] as num?)?.toInt() ?? 0).abs();
    final portrait = t['portrait'] as int?;
    final trainerPhotoUrl = t['trainerPhotoUrl'] as String?;
    final accent = isCredit ? _neon(context) : _coral(context);
    final title = t['title'] as String;
    final dateStr = _getFormattedTxDateTime(t);
    final trainerName = isSession ? title.replaceFirst('Session — ', '') : '';
    final displayTitle = isSession
        ? 'Transfer to ${trainerName.split(' ').map((w) => w.isNotEmpty ? w[0].toUpperCase() + w.substring(1) : '').join(' ')}'
        : title;
    final resolvedPhotoUrl = trainerPhotoUrl ?? (isSession ? _findTrainerPhotoUrl(trainerName, ref) : null);

    // Deterministic reference number from transaction data
    final rawSeed = '$amount$dateStr$title'.hashCode.abs();
    final refStr = '100${(rawSeed % 10000000000).toString().padLeft(10, '0')}';

    final fromLabel = isCredit ? 'Bank Account' : 'My Wallet';
    final toLabel = isSession
        ? trainerName.split(' ').map((w) => w.isNotEmpty ? w[0].toUpperCase() + w.substring(1) : '').join(' ')
        : isCredit
            ? 'My Wallet'
            : 'Bank Account';
    final statusLabel = isWithdrawal ? 'Processing' : 'Completed';
    final statusColor = isWithdrawal ? const Color(0xFF5CE8FF) : _neon(context);

    // Initials for avatar fallback
    final initials = toLabel
        .split(' ')
        .take(2)
        .map((w) => w.isNotEmpty ? w[0] : '')
        .join()
        .toUpperCase();

    Widget avatar = Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.35), width: 2),
      ),
      child: isSession && (resolvedPhotoUrl != null && resolvedPhotoUrl.isNotEmpty)
          ? ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CachedNetworkImage(
                imageUrl: resolvedPhotoUrl,
                fit: BoxFit.cover,
                placeholder: (context, url) => InitialsAvatar(
                  name: trainerName,
                  size: 56,
                  fontSize: 18,
                  borderRadius: 12,
                ),
                errorWidget: (context, url, error) => InitialsAvatar(
                  name: trainerName,
                  size: 56,
                  fontSize: 18,
                  borderRadius: 12,
                ),
              ),
            )
          : isSession && portrait != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: CachedNetworkImage(
                    imageUrl: 'https://randomuser.me/api/portraits/men/$portrait.jpg',
                    fit: BoxFit.cover,
                    placeholder: (context, url) => InitialsAvatar(
                      name: trainerName,
                      size: 56,
                      fontSize: 18,
                      borderRadius: 12,
                    ),
                    errorWidget: (context, url, error) => InitialsAvatar(
                      name: trainerName,
                      size: 56,
                      fontSize: 18,
                      borderRadius: 12,
                    ),
                  ),
                )
              : isSession
                  ? Center(
                      child: Text(
                        initials,
                        style: TextStyle(
                          color: accent,
                          fontWeight: FontWeight.w800,
                          fontSize: 20,
                        ),
                      ),
                    )
                  : Icon(
                      isCredit
                          ? CupertinoIcons.arrow_down_circle_fill
                          : isWithdrawal
                              ? CupertinoIcons.arrow_up_circle_fill
                              : CupertinoIcons.creditcard_fill,
                      color: accent,
                      size: 26,
                    ),
    );

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: _card(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Handle ──────────────────────────────────────────────────────
            const SizedBox(height: 16),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: _stroke(context),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),

            // ── Header: avatar + amount (bank receipt style) ─────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  // Avatar with debit badge overlay
                  Stack(
                     clipBehavior: Clip.none,
                    children: [
                      avatar,
                      if (!isCredit)
                        Positioned(
                          bottom: -2,
                          right: -2,
                          child: Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              color: _coral(context),
                              shape: BoxShape.circle,
                              border: Border.all(color: _card(context), width: 2),
                            ),
                            child: const Icon(
                              CupertinoIcons.arrow_up,
                              color: Colors.white,
                              size: 10,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${isCredit ? '+' : '-'}\$$amount.00',
                        style: TextStyle(
                          color: accent,
                          fontWeight: FontWeight.w900,
                          fontSize: 28,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        displayTitle,
                        style: TextStyle(
                          color: _text(context),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ── Dashed receipt tear line with notch circles ───────────────
            SizedBox(
              height: 24,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  Padding(
                     padding: const EdgeInsets.symmetric(horizontal: 12),
                     child: LayoutBuilder(
                       builder: (context, constraints) {
                         final count = (constraints.maxWidth / 10).floor();
                         return Row(
                           mainAxisAlignment: MainAxisAlignment.spaceBetween,
                           children: List.generate(
                             count,
                             (_) => Container(
                               width: 5,
                               height: 1.5,
                               color: _stroke(context),
                             ),
                           ),
                         );
                       },
                     ),
                  ),
                  // Left notch
                  Positioned(
                    left: -12,
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: _ink(context),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  // Right notch
                  Positioned(
                    right: -12,
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: _ink(context),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Receipt detail rows ───────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 36),
              child: Column(
                children: [
                  _receiptRow(context, 'Reference #', refStr),
                  _receiptDivider(context),
                  _receiptRow(context, 'From', fromLabel),
                  _receiptDivider(context),
                  _receiptRow(context, 'Original amount', '\$$amount.00'),
                  _receiptDivider(context),
                  _receiptRow(context, 'To', toLabel),
                  _receiptDivider(context),
                  _receiptRow(context, 'Transaction date', dateStr),
                  _receiptDivider(context),
                  _receiptRow(context, 'Status', statusLabel, valueColor: statusColor),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _receiptRow(BuildContext context, String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: _muted(context), fontSize: 13)),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: valueColor ?? _text(context),
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _receiptDivider(BuildContext context) => Container(height: 1, color: _stroke(context).withValues(alpha: 0.5));
}
