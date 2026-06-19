import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/global_providers.dart';

class BookSessionState {
  final DateTime? selectedDate;
  final String selectedSlot;
  final String selectedEndTime;
  final String selectedType;
  final String trainerName;
  final String trainerId;
  final String specialty;
  final int? portrait;
  final String imageUrl;
  final double rating;
  final int price;
  final bool isSubmitting;
  final Map<String, Map<String, dynamic>> trainerAvailability;
  final List<Map<String, dynamic>> trainerBookings;
  final int clientDiscount;
  final String appliedPromoCode;
  final int promoDiscount;

  BookSessionState({
    this.selectedDate,
    required this.selectedSlot,
    required this.selectedEndTime,
    required this.selectedType,
    required this.trainerName,
    required this.trainerId,
    required this.specialty,
    this.portrait,
    required this.imageUrl,
    required this.rating,
    required this.price,
    required this.isSubmitting,
    this.trainerAvailability = const {},
    this.trainerBookings = const [],
    this.clientDiscount = 0,
    this.appliedPromoCode = '',
    this.promoDiscount = 0,
  });

  BookSessionState copyWith({
    DateTime? selectedDate,
    String? selectedSlot,
    String? selectedEndTime,
    String? selectedType,
    String? trainerName,
    String? trainerId,
    String? specialty,
    int? portrait,
    String? imageUrl,
    double? rating,
    int? price,
    bool? isSubmitting,
    Map<String, Map<String, dynamic>>? trainerAvailability,
    List<Map<String, dynamic>>? trainerBookings,
    int? clientDiscount,
    String? appliedPromoCode,
    int? promoDiscount,
  }) {
    return BookSessionState(
      selectedDate: selectedDate ?? this.selectedDate,
      selectedSlot: selectedSlot ?? this.selectedSlot,
      selectedEndTime: selectedEndTime ?? this.selectedEndTime,
      selectedType: selectedType ?? this.selectedType,
      trainerName: trainerName ?? this.trainerName,
      trainerId: trainerId ?? this.trainerId,
      specialty: specialty ?? this.specialty,
      portrait: portrait ?? this.portrait,
      imageUrl: imageUrl ?? this.imageUrl,
      rating: rating ?? this.rating,
      price: price ?? this.price,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      trainerAvailability: trainerAvailability ?? this.trainerAvailability,
      trainerBookings: trainerBookings ?? this.trainerBookings,
      clientDiscount: clientDiscount ?? this.clientDiscount,
      appliedPromoCode: appliedPromoCode ?? this.appliedPromoCode,
      promoDiscount: promoDiscount ?? this.promoDiscount,
    );
  }
}

class BookSessionNotifier extends StateNotifier<BookSessionState> {
  final Ref ref;
  final Map<String, dynamic>? initialArgs;
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  final List<StreamSubscription<dynamic>> _subs = [];

  BookSessionNotifier(this.ref, this.initialArgs)
      : super(BookSessionState(
          selectedDate: DateTime.now(),
          selectedSlot: '',
          selectedEndTime: '',
          selectedType: '1-on-1',
          trainerName: 'Alex Carter',
          trainerId: '',
          specialty: 'Strength & HIIT',
          portrait: null,
          imageUrl: '',
          rating: 4.9,
          price: 65,
          isSubmitting: false,
          trainerAvailability: const {},
          trainerBookings: const [],
        )) {
    _initArgs();
    _listenRealtimeTrainer();
    _listenClientUser();
  }

  StreamSubscription<DocumentSnapshot>? _clientUserSub;

  void _listenClientUser() {
    _clientUserSub?.cancel();
    final clientUid = _auth.currentUser?.uid;
    if (clientUid != null && clientUid.isNotEmpty) {
      _clientUserSub = _firestore.collection('users').doc(clientUid).snapshots().listen((doc) {
        if (!doc.exists) return;
        final data = doc.data() ?? {};
        
        int discount = 0;
        if (data.containsKey('activeDiscount')) {
          discount = (data['activeDiscount'] as num?)?.toInt() ?? 0;
        } else {
          // New user has no activeDiscount field. We seed it with 50.
          discount = 50;
          _firestore.collection('users').doc(clientUid).set({
            'activeDiscount': 50,
          }, SetOptions(merge: true));
        }
        
        if (mounted) {
          state = state.copyWith(clientDiscount: discount);
        }
      }, onError: (_) {});
    }
  }

  Future<void> applyPromoCode(String code) async {
    final cleanCode = code.trim().toUpperCase();
    if (cleanCode.isEmpty) return;

    try {
      final snap = await _firestore
          .collection('promotions')
          .where('code', isEqualTo: cleanCode)
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get();

      if (snap.docs.isEmpty) {
        state = state.copyWith(appliedPromoCode: '', promoDiscount: 0);
        throw Exception('Invalid or inactive promo code');
      }

      final data = snap.docs.first.data();
      final discount = (data['discount'] as num?)?.toInt() ?? 0;

      if (mounted) {
        state = state.copyWith(
          appliedPromoCode: cleanCode,
          promoDiscount: discount,
        );
      }
    } catch (e) {
      rethrow;
    }
  }

  void removePromoCode() {
    if (mounted) {
      state = state.copyWith(
        appliedPromoCode: '',
        promoDiscount: 0,
      );
    }
  }

  void _listenRealtimeTrainer() {
    for (final sub in _subs) {
      sub.cancel();
    }
    _subs.clear();

    final uid = state.trainerId.trim();
    if (uid.isNotEmpty) {
      // Listen to users collection for name, photo, rating
      _subs.add(
        _firestore.collection('users').doc(uid).snapshots().listen((doc) {
          if (!doc.exists) return;
          final data = doc.data() ?? {};
          final name = (data['name'] ?? data['fullName'] ?? data['displayName'] ?? '').toString().trim();
          final photo = (data['photoUrl'] ?? '').toString().trim();
          final ratingVal = (data['rating'] as num?)?.toDouble() ?? 4.9;

          state = state.copyWith(
            trainerName: name.isNotEmpty ? name : state.trainerName,
            imageUrl: photo.isNotEmpty ? photo : state.imageUrl,
            rating: ratingVal > 0 ? ratingVal : state.rating,
          );
        }, onError: (_) {}),
      );

      // Listen to reviews collection for dynamic rating
      _subs.add(
        _firestore
            .collection('reviews')
            .where('trainerId', isEqualTo: uid)
            .snapshots()
            .listen((snap) {
          final vals = snap.docs
              .map((d) => (d.data()['rating'] as num?)?.toDouble() ?? 0.0)
              .where((v) => v > 0)
              .toList();
          final avg = vals.isEmpty
              ? 0.0
              : vals.reduce((a, b) => a + b) / vals.length;
          if (avg > 0 && mounted) {
            state = state.copyWith(
              rating: avg,
            );
          }
        }, onError: (_) {}),
      );

      // Listen to trainerProfiles collection for price, specialty, and availability
      _subs.add(
        _firestore.collection('trainerProfiles').doc(uid).snapshots().listen((doc) {
          if (!doc.exists) return;
          final data = doc.data() ?? {};
          final priceVal = data['sessionPrice'];
          final specs = data['specializations'];
          final photo = (data['photoUrl'] ?? '').toString().trim();

          String specialtyVal = state.specialty;
          if (specs is List && specs.isNotEmpty) {
            specialtyVal = specs.first.toString();
          }

          final rawAvailability = data['availability'];
          Map<String, Map<String, dynamic>> availMap = {};
          if (rawAvailability is Map) {
            availMap = rawAvailability.map((key, value) {
              final dayKey = key.toString();
              final dayValue = value is Map
                  ? Map<String, dynamic>.from(value)
                  : <String, dynamic>{};
              return MapEntry(dayKey, dayValue);
            });
          }

          state = state.copyWith(
            price: (priceVal is num && priceVal > 0) ? priceVal.toInt() : state.price,
            specialty: specialtyVal,
            imageUrl: photo.isNotEmpty ? photo : state.imageUrl,
            trainerAvailability: availMap,
          );
        }, onError: (_) {}),
      );

      // Listen to bookings collection for this trainer to show availability dynamically
      _subs.add(
        _firestore
            .collection('bookings')
            .where('trainerId', isEqualTo: uid)
            .snapshots()
            .listen((snap) {
          final bookingsList = snap.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
          state = state.copyWith(trainerBookings: bookingsList);
        }, onError: (_) {}),
      );
    } else if (state.trainerName.isNotEmpty && state.trainerName != 'Trainer') {
      // Fallback name-based lookup for mock data sessions
      _firestore
          .collection('users')
          .where('role', isEqualTo: 'trainer')
          .get()
          .then((snap) {
        String? foundUid;
        for (final doc in snap.docs) {
          final data = doc.data();
          final name = (data['name'] ?? data['fullName'] ?? data['displayName'] ?? '').toString().trim().toLowerCase();
          if (name == state.trainerName.trim().toLowerCase()) {
            foundUid = doc.id;
            break;
          }
        }
        if (foundUid != null && mounted) {
          state = state.copyWith(trainerId: foundUid);
          _listenRealtimeTrainer(); // Listen to found document
        }
      }).catchError((_) {});
    }
  }

  @override
  void dispose() {
    _clientUserSub?.cancel();
    for (final sub in _subs) {
      sub.cancel();
    }
    super.dispose();
  }

  final List<String> sessionTypes = const [
    '1-on-1',
    'Group',
    'Online',
    'Home Training',
    'Outdoor',
  ];

  String get workingHours {
    if (state.selectedDate == null) return '';
    final setting = _getAvailabilityForDate(state.selectedDate);
    if (setting == null) return 'Unavailable';
    
    final startStr = (setting['start'] ?? '09:00').toString();
    final endStr = (setting['end'] ?? '18:00').toString();

    final startParts = startStr.split(':');
    final startHour = int.tryParse(startParts.first) ?? 9;
    final startMinute = (startParts.length > 1 ? int.tryParse(startParts[1]) : null) ?? 0;
    final startAmPm = startHour >= 12 ? 'PM' : 'AM';
    final startDisplayHour = startHour % 12 == 0 ? 12 : startHour % 12;
    final startFormatted = '${startDisplayHour.toString().padLeft(2, '0')}:${startMinute.toString().padLeft(2, '0')} $startAmPm';

    final endParts = endStr.split(':');
    final endHour = int.tryParse(endParts.first) ?? 18;
    final endMinute = (endParts.length > 1 ? int.tryParse(endParts[1]) : null) ?? 0;
    final endAmPm = endHour >= 12 ? 'PM' : 'AM';
    final endDisplayHour = endHour % 12 == 0 ? 12 : endHour % 12;
    final endFormatted = '${endDisplayHour.toString().padLeft(2, '0')}:${endMinute.toString().padLeft(2, '0')} $endAmPm';

    return '$startFormatted - $endFormatted';
  }

  Map<String, dynamic>? _getAvailabilityForDate(DateTime? date) {
    if (date == null) return null;
    final weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final weekday = weekdays[date.weekday - 1];
    
    final setting = state.trainerAvailability[weekday];
    if (setting == null) return null;

    final enabled = setting['enabled'] == true;

    if (enabled) {
      return setting;
    }
    return null;
  }

  List<Map<String, dynamic>> _generateAllSlots(DateTime date) {
    final setting = _getAvailabilityForDate(date);
    if (setting == null) return const [];

    final startStr = (setting['start'] ?? '09:00').toString();
    final endStr = (setting['end'] ?? '18:00').toString();

    final startParts = startStr.split(':');
    final endParts = endStr.split(':');

    final startHour = int.tryParse(startParts.first) ?? 9;
    final startMinute = (startParts.length > 1 ? int.tryParse(startParts[1]) : null) ?? 0;

    final endHour = int.tryParse(endParts.first) ?? 18;
    final endMinute = (endParts.length > 1 ? int.tryParse(endParts[1]) : null) ?? 0;

    final List<Map<String, dynamic>> slots = [];

    var currentHour = startHour;
    var currentMinute = startMinute;

    final formattedDate = _formatBookingDate(date);

    while (true) {
      if (currentHour > endHour || (currentHour == endHour && currentMinute >= endMinute)) {
        break;
      }

      final ampm = currentHour >= 12 ? 'PM' : 'AM';
      final displayHour = currentHour % 12 == 0 ? 12 : currentHour % 12;
      final hourStr = displayHour.toString().padLeft(2, '0');
      final minuteStr = currentMinute.toString().padLeft(2, '0');
      final timeSlotStr = '$hourStr:$minuteStr $ampm';

      final isBooked = state.trainerBookings.any((booking) {
        final bDate = (booking['date'] ?? '').toString();
        final bTime = (booking['time'] ?? '').toString();
        final status = (booking['status'] ?? '').toString().toLowerCase();
        
        if (status == 'cancelled' || status == 'rejected') {
          return false;
        }
        
        return bDate == formattedDate && bTime == timeSlotStr;
      });

      slots.add({
        'time': timeSlotStr,
        'available': !isBooked,
        'hour': currentHour,
      });

      currentHour += 1;
    }

    return slots;
  }

  List<Map<String, dynamic>> _getSlotsForPeriod(String period) {
    if (state.selectedDate == null) return const [];
    final allSlots = _generateAllSlots(state.selectedDate!);

    return allSlots.where((slot) {
      final hour = slot['hour'] as int;
      if (period == 'morning') {
        return hour < 12;
      } else if (period == 'afternoon') {
        return hour >= 12 && hour < 17;
      } else {
        return hour >= 17;
      }
    }).toList();
  }

  List<Map<String, dynamic>> get morningSlots => _getSlotsForPeriod('morning');
  List<Map<String, dynamic>> get afternoonSlots => _getSlotsForPeriod('afternoon');
  List<Map<String, dynamic>> get eveningSlots => _getSlotsForPeriod('evening');

  void _initArgs() {
    if (initialArgs != null) {
      final name = initialArgs!['name'] as String?;
      final id = (initialArgs!['trainerId'] ?? initialArgs!['id'] ?? '') as String;
      final spec = initialArgs!['specialty'] as String?;
      final port = initialArgs!['portrait'] as int?;
      final img = (initialArgs!['image'] ?? initialArgs!['imageUrl'] ?? initialArgs!['photoUrl'] ?? '') as String;
      final rate = (initialArgs!['rating'] as num?)?.toDouble() ?? 4.9;
      final pr = (initialArgs!['price'] ?? initialArgs!['pricePerHour']) as int?;
      final initialType = initialArgs!['type'] as String?;
      final initialTime = initialArgs!['time'] as String?;

      String startSlot = initialTime ?? state.selectedSlot;
      if (initialTime != null && initialTime.contains(' - ')) {
        final times = initialTime.split(' - ');
        startSlot = times[0];
      }
      String endSlot = '';
      if (startSlot.isNotEmpty) {
        endSlot = _calculateEndTime(startSlot);
      }

      state = state.copyWith(
        trainerName: name ?? state.trainerName,
        trainerId: id,
        specialty: spec ?? state.specialty,
        portrait: port,
        imageUrl: img,
        rating: rate,
        price: pr ?? state.price,
        selectedType: (initialType != null && sessionTypes.contains(initialType))
            ? initialType
            : state.selectedType,
        selectedSlot: startSlot,
        selectedEndTime: endSlot,
      );
    }
  }

  String _calculateEndTime(String startSlot) {
    if (startSlot.isEmpty) return '';
    final parsed = _parseTimeStr(startSlot);
    int hour = parsed['hour'] ?? 9;
    int minute = parsed['minute'] ?? 0;
    
    hour = (hour + 1) % 24;
    
    final ampm = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour % 12 == 0 ? 12 : hour % 12;
    final hourStr = displayHour.toString().padLeft(2, '0');
    final minuteStr = minute.toString().padLeft(2, '0');
    
    return '$hourStr:$minuteStr $ampm';
  }

  void pickDate(DateTime date) {
    state = state.copyWith(
      selectedDate: date,
      selectedSlot: '',
      selectedEndTime: '',
    );
  }

  void pickQuickDate(int daysFromNow) {
    state = state.copyWith(
      selectedDate: DateTime.now().add(Duration(days: daysFromNow)),
      selectedSlot: '',
      selectedEndTime: '',
    );
  }

  void pickSlot(String slot) {
    state = state.copyWith(
      selectedSlot: slot,
      selectedEndTime: _calculateEndTime(slot),
    );
  }

  void pickEndTime(String endTime) {
    state = state.copyWith(selectedEndTime: endTime);
  }

  void pickType(String type) => state = state.copyWith(selectedType: type);

  bool get canConfirm =>
      state.selectedDate != null &&
      state.selectedSlot.isNotEmpty &&
      state.selectedEndTime.isNotEmpty;

  String _formatBookingDate(DateTime date) {
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final weekday = weekdays[date.weekday - 1];
    final month = months[date.month - 1];
    return '$weekday, $month ${date.day}, ${date.year}';
  }

  Map<String, int> _parseTimeStr(String timeStr) {
    int hour = 9;
    int minute = 0;
    try {
      final parts = timeStr.trim().split(' ');
      final timeParts = parts[0].split(':');
      hour = int.parse(timeParts[0]);
      minute = int.parse(timeParts[1]);
      if (parts.length > 1) {
        final ampm = parts[1].toLowerCase();
        if (ampm == 'pm' && hour < 12) {
          hour += 12;
        } else if (ampm == 'am' && hour == 12) {
          hour = 0;
        }
      }
    } catch (_) {}
    return {'hour': hour, 'minute': minute};
  }

  List<String> getAvailableEndTimes() {
    if (state.selectedSlot.isEmpty || state.selectedDate == null) return const [];
    
    final allSlots = _generateAllSlots(state.selectedDate!);
    final startIdx = allSlots.indexWhere((slot) => slot['time'] == state.selectedSlot);
    if (startIdx == -1) return const [];

    final setting = _getAvailabilityForDate(state.selectedDate);
    if (setting == null) return const [];
    final endStr = (setting['end'] ?? '18:00').toString();
    final endParts = endStr.split(':');
    final endHour = int.tryParse(endParts.first) ?? 18;

    final List<String> endTimes = [];
    
    for (int i = startIdx + 1; i < allSlots.length; i++) {
      final slot = allSlots[i];
      final isAvailable = slot['available'] as bool;
      
      if (!isAvailable) {
        endTimes.add(slot['time'] as String);
        break;
      }
      
      endTimes.add(slot['time'] as String);
    }
    
    bool reachedEndWithoutBooking = true;
    for (int i = startIdx + 1; i < allSlots.length; i++) {
      if (allSlots[i]['available'] == false) {
        reachedEndWithoutBooking = false;
        break;
      }
    }
    if (reachedEndWithoutBooking) {
      final endAmpm = endHour >= 12 ? 'PM' : 'AM';
      final endDisplayHour = endHour % 12 == 0 ? 12 : endHour % 12;
      final endStrFormatted = '${endDisplayHour.toString().padLeft(2, '0')}:00 $endAmpm';
      if (!endTimes.contains(endStrFormatted)) {
        endTimes.add(endStrFormatted);
      }
    }

    return endTimes;
  }

  int get sessionDurationHours {
    if (state.selectedSlot.isEmpty || state.selectedEndTime.isEmpty) return 1;
    final startParsed = _parseTimeStr(state.selectedSlot);
    final endParsed = _parseTimeStr(state.selectedEndTime);
    final startHour = startParsed['hour']!;
    final endHour = endParsed['hour']!;
    final duration = endHour - startHour;
    return duration > 0 ? duration : 1;
  }

  Future<void> confirmBooking({
    required void Function(String title, String message, {bool isError}) onNotify,
    required void Function() onSuccess,
  }) async {
    if (state.isSubmitting) return;
    if (state.selectedDate == null || state.selectedSlot.isEmpty || state.selectedEndTime.isEmpty) {
      onNotify('Incomplete', 'Please select a date, start time, and end time', isError: true);
      return;
    }

    final user = _auth.currentUser;
    if (user == null) {
      onNotify('Not logged in', 'Please log in to book a session', isError: true);
      return;
    }

    final bookingsService = ref.read(bookingsServiceProvider.notifier);
    final formattedDate = _formatBookingDate(state.selectedDate!);
    final timeString = '${state.selectedSlot} - ${state.selectedEndTime}';

    int hour = 9;
    int minute = 0;
    try {
      final slot = state.selectedSlot.trim();
      final parts = slot.split(' ');
      final timeParts = parts[0].split(':');
      hour = int.parse(timeParts[0]);
      minute = int.parse(timeParts[1]);
      if (parts.length > 1) {
        final ampm = parts[1].toLowerCase();
        if (ampm == 'pm' && hour < 12) {
          hour += 12;
        } else if (ampm == 'am' && hour == 12) {
          hour = 0;
        }
      }
    } catch (_) {}

    final scheduledDateTime = DateTime(
      state.selectedDate!.year,
      state.selectedDate!.month,
      state.selectedDate!.day,
      hour,
      minute,
    );

    final hasConflict = bookingsService.hasUpcomingConflict(
      trainer: state.trainerName,
      date: formattedDate,
      time: timeString,
    );
    if (hasConflict) {
      onNotify(
        'Already Booked',
        'You already have this session in upcoming bookings.',
        isError: true,
      );
      return;
    }

    state = state.copyWith(isSubmitting: true);
    final totalPrice = state.price;
    final effectiveDiscount = state.promoDiscount > 0 ? state.promoDiscount : state.clientDiscount;
    final amountPaid = totalPrice * (1 - (effectiveDiscount / 100));

    try {
      await _firestore.collection('bookings').add({
        'userId': user.uid,
        'trainerId': state.trainerId,
        'trainerName': state.trainerName,
        'trainer': state.trainerName, // legacy field for UI compatibility
        'specialty': state.specialty,
        'date': formattedDate,
        'time': timeString,
        'scheduledAt': Timestamp.fromDate(scheduledDateTime),
        'type': state.selectedType,
        'status': 'pending',
        'portrait': state.portrait,
        'trainerPhotoUrl': state.imageUrl,
        'clientName': (user.displayName ?? user.email?.split('@').first ?? 'Client').trim(),
        'clientPhotoUrl': user.photoURL ?? '',
        'price': totalPrice,
        'discountApplied': effectiveDiscount,
        'amountPaid': 0,
        'paymentStatus': 'unpaid',
        'paid': false,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (effectiveDiscount == state.clientDiscount && state.clientDiscount > 0) {
        await _firestore.collection('users').doc(user.uid).set({
          'activeDiscount': 0,
        }, SetOptions(merge: true));
      }

      if (state.trainerId.isNotEmpty && state.trainerId != user.uid) {
        final userName = (user.displayName ?? user.email?.split('@').first ?? 'Someone').trim();
        // Notify trainer about new booking
        await _firestore
            .collection('notifications')
            .doc(state.trainerId)
            .collection('items')
            .add({
          'title': 'New Booking',
          'body': '$userName booked a ${state.selectedType} session on $formattedDate at $timeString',
          'type': 'booking',
          'color': 'sky',
          'icon': 'calendar',
          'read': false,
          'createdAt': FieldValue.serverTimestamp(),
          'senderId': user.uid,
          'senderName': userName,
          'senderPhotoUrl': user.photoURL ?? '',
        });

        // Notify user that booking request has been sent
        await _firestore
            .collection('notifications')
            .doc(user.uid)
            .collection('items')
            .add({
          'title': 'Booking Request Sent',
          'body': 'Your request for a ${state.selectedType} session with ${state.trainerName} on $formattedDate at $timeString has been sent and is pending approval.',
          'type': 'booking',
          'color': 'sky',
          'icon': 'calendar',
          'read': false,
          'createdAt': FieldValue.serverTimestamp(),
          'senderId': state.trainerId,
          'senderName': state.trainerName,
          'senderPhotoUrl': state.imageUrl.isNotEmpty ? state.imageUrl : (state.portrait ?? 32).toString(),
        });
      }

      onNotify(
        'Booking Confirmed',
        '${state.trainerName} has been added to your upcoming bookings.',
        isError: false,
      );
      onSuccess();
    } catch (e) {
      onNotify('Error', 'Failed to create booking. Please try again.', isError: true);
    } finally {
      state = state.copyWith(isSubmitting: false);
    }
  }
}

final bookSessionProvider = StateNotifierProvider.family<
    BookSessionNotifier, BookSessionState, Map<String, dynamic>?>(
  (ref, args) => BookSessionNotifier(ref, args),
);
