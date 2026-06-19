import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../config/glass_ui.dart';
import '../controllers/book_session_controller.dart';

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

class BookSessionView extends ConsumerStatefulWidget {
  final Map<String, dynamic>? arguments;
  const BookSessionView({super.key, this.arguments});

  @override
  ConsumerState<BookSessionView> createState() => _BookSessionViewState();
}

class _BookSessionViewState extends ConsumerState<BookSessionView> {
  final _promoController = TextEditingController();

  Color get ink => Theme.of(context).brightness == Brightness.dark ? const Color(0xFF0A0A0F) : const Color(0xFFF9F9FC);
  Color get surface => Theme.of(context).brightness == Brightness.dark ? const Color(0xFF111118) : const Color(0xFFE5E7EB);
  Color get card => Theme.of(context).brightness == Brightness.dark ? const Color(0xFF17171F) : const Color(0xFFFFFFFF);
  Color get raised => Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E1E28) : const Color(0xFFF0EFF5);
  Color get stroke => Theme.of(context).brightness == Brightness.dark ? const Color(0xFF2A2A36) : const Color(0xFFE5E7EB);
  Color get neon => Theme.of(context).colorScheme.primary;
  Color get muted => Theme.of(context).brightness == Brightness.dark ? const Color(0xFF6B6B7E) : Colors.black54;
  Color get text => Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87;

  @override
  void dispose() {
    _promoController.dispose();
    super.dispose();
  }

  String _uiDate(DateTime date) {
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${weekdays[date.weekday - 1]}, ${months[date.month - 1]} ${date.day}';
  }

  @override
  Widget build(BuildContext context) {
    Map<String, dynamic>? args = widget.arguments;
    if (args == null) {
      try {
        final extra = GoRouterState.of(context).extra;
        if (extra is Map<String, dynamic>) {
          args = extra;
        }
      } catch (_) {}
    }

    final state = ref.watch(bookSessionProvider(args));
    final controller = ref.read(bookSessionProvider(args).notifier);

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
          'Book a Session',
          style: TextStyle(color: text, fontWeight: FontWeight.w600),
        ),
      ),
      body: Stack(
        children: [
          Positioned.fill(child: trainerBackground(context)),
          SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTrainerCard(state),
                const SizedBox(height: 24),
                _buildSectionLabel('Session Type'),
                const SizedBox(height: 12),
                _buildSessionTypes(state, controller),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildSectionLabel('Select Date'),
                    if (controller.workingHours.isNotEmpty &&
                        controller.workingHours != 'Unavailable')
                      Text(
                        'Working Hours: ${controller.workingHours}',
                        style: TextStyle(
                          color: neon,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildDatePicker(context, state, controller),
                const SizedBox(height: 10),
                _buildQuickDateChips(state, controller),
                const SizedBox(height: 24),
                if (controller.morningSlots.isEmpty &&
                    controller.afternoonSlots.isEmpty &&
                    controller.eveningSlots.isEmpty) ...[
                  _buildNoSessionsBanner(),
                ] else ...[
                  _buildSectionLabel('Select Start Time'),
                  const SizedBox(height: 16),
                  if (controller.morningSlots.isNotEmpty) ...[
                    Text('Morning', style: TextStyle(color: muted, fontSize: 13, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    _buildSlots(controller.morningSlots, state, controller),
                    const SizedBox(height: 20),
                  ],
                  if (controller.afternoonSlots.isNotEmpty) ...[
                    Text('Afternoon', style: TextStyle(color: muted, fontSize: 13, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    _buildSlots(controller.afternoonSlots, state, controller),
                    const SizedBox(height: 20),
                  ],
                  if (controller.eveningSlots.isNotEmpty) ...[
                    Text('Evening', style: TextStyle(color: muted, fontSize: 13, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    _buildSlots(controller.eveningSlots, state, controller),
                  ],
                ],
                if (state.selectedSlot.isNotEmpty) ...[
                  const SizedBox(height: 28),
                  _buildSectionLabel('Select End Time'),
                  const SizedBox(height: 12),
                  _buildEndTimeSlots(state, controller),
                ],
                const SizedBox(height: 26),
                _buildPromoCodeField(context, state, controller),
                const SizedBox(height: 26),
                _buildBookingSummary(state, controller),
                const SizedBox(height: 32),
                _buildConfirmButton(context, state, controller),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrainerCard(BookSessionState state) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: stroke),
      ),
      child: Row(
        children: [
          _buildTrainerPortrait(state),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  state.trainerName,
                  style: TextStyle(
                    color: text,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  state.specialty,
                  style: TextStyle(color: muted, fontSize: 13),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(CupertinoIcons.star_fill, color: neon, size: 12),
                    const SizedBox(width: 4),
                    Text(
                      state.rating.toStringAsFixed(1),
                      style: TextStyle(
                        color: neon,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Icon(
                      CupertinoIcons.money_dollar_circle,
                      color: muted,
                      size: 12,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '\$${state.price}/session',
                      style: TextStyle(color: muted, fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrainerPortrait(BookSessionState state) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: raised,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: neon.withOpacity(0.3), width: 1.5),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12.5),
        child: PremiumAvatar(
          name: state.trainerName,
          customPhotoUrl: state.imageUrl,
          size: 56,
          borderRadius: 12.5,
          isTrainer: true,
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Text(
      label,
      style: TextStyle(
        color: text,
        fontWeight: FontWeight.w700,
        fontSize: 15,
      ),
    );
  }

  Widget _buildSessionTypes(BookSessionState state, BookSessionNotifier controller) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children:
            controller.sessionTypes.map((type) {
              final selected = state.selectedType == type;
              return Padding(
                padding: const EdgeInsets.only(right: 10),
                child: GestureDetector(
                  onTap: () => controller.pickType(type),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: selected ? neon.withValues(alpha: 0.15) : card,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: selected ? neon : stroke,
                        width: selected ? 2 : 1,
                      ),
                    ),
                    child: Text(
                      type,
                      style: TextStyle(
                        color: selected ? neon : muted,
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w400,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
      ),
    );
  }

  Widget _buildDatePicker(BuildContext context, BookSessionState state, BookSessionNotifier controller) {
    final picked = state.selectedDate;
    return GestureDetector(
      onTap: () async {
        final date = await showDatePicker(
          context: context,
          initialDate: DateTime.now().add(const Duration(days: 1)),
          firstDate: DateTime.now(),
          lastDate: DateTime.now().add(const Duration(days: 60)),
          builder:
              (ctx, child) => Theme(
                data: Theme.of(context).copyWith(
                  colorScheme: ColorScheme.fromSeed(
                    seedColor: neon,
                    brightness: Theme.of(context).brightness,
                  ),
                ),
                child: child!,
              ),
        );
        if (date != null) controller.pickDate(date);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: picked != null ? neon : stroke,
            width: picked != null ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              CupertinoIcons.calendar,
              color: picked != null ? neon : muted,
              size: 20,
            ),
            const SizedBox(width: 12),
            Text(
              picked != null
                  ? '${picked.day}/${picked.month}/${picked.year}'
                  : 'Tap to pick a date',
              style: TextStyle(
                color: picked != null ? text : muted,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSlots(List<Map<String, dynamic>> slots, BookSessionState state, BookSessionNotifier controller) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children:
          slots.map((slot) {
            final time = slot['time'] as String;
            final available = slot['available'] as bool;
            final selected = state.selectedSlot == time;
            return GestureDetector(
              onTap: available ? () => controller.pickSlot(time) : null,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color:
                      !available
                          ? raised.withOpacity(0.5)
                          : selected
                          ? neon.withOpacity(0.15)
                          : card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color:
                        !available
                            ? stroke.withOpacity(0.4)
                            : selected
                            ? neon
                            : stroke,
                    width: selected ? 2 : 1,
                  ),
                ),
                child: Text(
                  time,
                  style: TextStyle(
                    color:
                        !available
                            ? muted.withOpacity(0.4)
                            : selected
                            ? neon
                            : text,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                    fontSize: 13,
                    decoration:
                        !available
                            ? TextDecoration.lineThrough
                            : TextDecoration.none,
                  ),
                ),
              ),
            );
          }).toList(),
    );
  }

  Widget _buildQuickDateChips(BookSessionState state, BookSessionNotifier controller) {
    final options = [
      {'label': 'Today', 'days': 0},
      {'label': 'Tomorrow', 'days': 1},
      {'label': '+2 Days', 'days': 2},
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children:
          options.map((opt) {
            final date = DateTime.now().add(
              Duration(days: opt['days']! as int),
            );
            final selected =
                state.selectedDate != null &&
                state.selectedDate!.year == date.year &&
                state.selectedDate!.month == date.month &&
                state.selectedDate!.day == date.day;
            return GestureDetector(
              onTap: () => controller.pickQuickDate(opt['days']! as int),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: selected ? neon.withOpacity(0.16) : card,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: selected ? neon : stroke),
                ),
                child: Text(
                  opt['label']! as String,
                  style: TextStyle(
                    color: selected ? neon : muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            );
          }).toList(),
    );
  }



  Widget _buildEndTimeSlots(BookSessionState state, BookSessionNotifier controller) {
    final endTimes = controller.getAvailableEndTimes();
    if (endTimes.isEmpty) {
      return const Text(
        'No end times available. Try a different start time.',
        style: TextStyle(color: coral, fontSize: 13),
      );
    }

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: endTimes.map((time) {
        final selected = state.selectedEndTime == time;
        return GestureDetector(
          onTap: () => controller.pickEndTime(time),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 10,
            ),
            decoration: BoxDecoration(
              color: selected ? neon.withOpacity(0.15) : card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected ? neon : stroke,
                width: selected ? 2 : 1,
              ),
            ),
            child: Text(
              time,
              style: TextStyle(
                color: selected ? neon : text,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                fontSize: 13,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPromoCodeField(
    BuildContext context,
    BookSessionState state,
    BookSessionNotifier controller,
  ) {
    final hasPromo = state.appliedPromoCode.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionLabel('Promo Code'),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _promoController,
                enabled: !hasPromo,
                style: TextStyle(color: text),
                decoration: InputDecoration(
                  hintText: hasPromo ? 'Code "${state.appliedPromoCode}" Applied' : 'Enter code (e.g. FIT20)',
                  hintStyle: TextStyle(color: muted, fontSize: 14),
                  prefixIcon: Icon(CupertinoIcons.tag, color: muted, size: 20),
                  filled: true,
                  fillColor: card,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: stroke),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: neon),
                  ),
                  disabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: stroke),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: () async {
                  if (hasPromo) {
                    controller.removePromoCode();
                    _promoController.clear();
                  } else {
                    final code = _promoController.text.trim();
                    if (code.isEmpty) return;
                    try {
                      await controller.applyPromoCode(code);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Promo code "$code" applied!'),
                          backgroundColor: neon,
                        ),
                      );
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Invalid or inactive promo code.'),
                          backgroundColor: coral,
                        ),
                      );
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: hasPromo ? coral : neon,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  hasPromo ? 'Remove' : 'Apply',
                  style: TextStyle(
                    color: hasPromo ? text : ink,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBookingSummary(BookSessionState state, BookSessionNotifier controller) {
    final date = state.selectedDate;
    final slot = state.selectedSlot;
    final ready = controller.canConfirm;
    final totalPrice = state.price;
    
    final effectiveDiscount = state.promoDiscount > 0 ? state.promoDiscount : state.clientDiscount;
    final discountAmount = totalPrice * (effectiveDiscount / 100);
    final finalPrice = totalPrice - discountAmount;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ready ? neon.withOpacity(0.7) : stroke),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(CupertinoIcons.doc_text, color: sky, size: 16),
              const SizedBox(width: 8),
              Text(
                'Booking Summary',
                style: TextStyle(
                  color: text,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Subtotal', style: TextStyle(color: text.withOpacity(0.7), fontSize: 13)),
              Text('\$$totalPrice', style: TextStyle(color: text, fontSize: 13, fontWeight: FontWeight.w600)),
            ],
          ),
          if (effectiveDiscount > 0) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  state.promoDiscount > 0 
                      ? 'Discount (${state.appliedPromoCode})' 
                      : 'New User Discount', 
                  style: const TextStyle(color: coral, fontSize: 13)
                ),
                Text(
                  '-\$${discountAmount.toStringAsFixed(2)} ($effectiveDiscount%)', 
                  style: const TextStyle(color: coral, fontSize: 13, fontWeight: FontWeight.w600)
                ),
              ],
            ),
          ],
          const SizedBox(height: 8),
          Divider(color: stroke, thickness: 1),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Total Price', style: TextStyle(color: text, fontSize: 14, fontWeight: FontWeight.bold)),
              Text(
                '\$${finalPrice.toStringAsFixed(2)}',
                style: TextStyle(
                  color: neon,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(CupertinoIcons.calendar, color: muted, size: 14),
              const SizedBox(width: 8),
              Text(
                date != null ? _uiDate(date) : 'Select a date',
                style: TextStyle(
                  color: date != null ? text : muted,
                  fontSize: 13,
                ),
              ),
              const SizedBox(width: 16),
              Icon(CupertinoIcons.clock, color: muted, size: 14),
              const SizedBox(width: 8),
              Text(
                slot.isNotEmpty
                    ? (state.selectedEndTime.isNotEmpty
                        ? '$slot - ${state.selectedEndTime}'
                        : slot)
                    : 'Select time',
                style: TextStyle(
                  color: slot.isNotEmpty ? text : muted,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(CupertinoIcons.time, color: muted, size: 14),
              const SizedBox(width: 8),
              Text(
                'Duration: ${controller.sessionDurationHours} hour${controller.sessionDurationHours > 1 ? "s" : ""}',
                style: TextStyle(color: text, fontSize: 13),
              ),
              const SizedBox(width: 16),
              Icon(CupertinoIcons.person_2, color: muted, size: 14),
              const SizedBox(width: 8),
              Text(
                state.selectedType,
                style: TextStyle(color: text, fontSize: 13),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmButton(BuildContext context, BookSessionState state, BookSessionNotifier controller) {
    final enabled = controller.canConfirm && !state.isSubmitting;
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: enabled
            ? () async {
                await controller.confirmBooking(
                  onNotify: (title, message, {isError = false}) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('$title: $message'),
                        backgroundColor: isError ? coral : neon,
                      ),
                    );
                  },
                  onSuccess: () {
                    context.pushReplacement('/my-bookings', extra: {'tab': 0});
                  },
                );
              }
            : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: enabled ? neon : raised,
          disabledBackgroundColor: raised,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child:
            state.isSubmitting
                ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    valueColor: AlwaysStoppedAnimation<Color>(ink),
                  ),
                )
                : Text(
                  enabled ? 'Confirm Booking' : 'Select Date & Time',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: enabled ? ink : muted,
                  ),
                ),
      ),
    );
  }

  Widget _buildNoSessionsBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: stroke),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            CupertinoIcons.calendar_badge_minus,
            color: muted.withOpacity(0.8),
            size: 44,
          ),
          const SizedBox(height: 16),
          Text(
            'No Sessions Available',
            style: TextStyle(
              color: text,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'The trainer is not available or has no sessions scheduled for this day.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: muted,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
