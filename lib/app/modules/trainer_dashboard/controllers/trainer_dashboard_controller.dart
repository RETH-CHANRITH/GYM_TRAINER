import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../routes/app_router.dart';
import '../../../services/user_profile_service.dart';
import '../../../providers/rx_compat.dart';

class TrainerDashboardController extends ChangeNotifier {
  final Ref ref;
  final FirebaseFirestore _firestore;

  TrainerDashboardController({required this.ref, FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance {
    
    displayName.addListener(notifyListeners);
    profilePhotoUrl.addListener(notifyListeners);
    currentTabIndex.addListener(notifyListeners);
    isLoading.addListener(notifyListeners);
    isSavingProfile.addListener(notifyListeners);
    isActionLoading.addListener(notifyListeners);
    profile.addListener(notifyListeners);
    bookings.addListener(notifyListeners);
    reviews.addListener(notifyListeners);
    payouts.addListener(notifyListeners);
    refunds.addListener(notifyListeners);
    posts.addListener(notifyListeners);
    pendingBookingsCount.addListener(notifyListeners);
    todaySessionsCount.addListener(notifyListeners);
    monthlyIncome.addListener(notifyListeners);
    totalIncome.addListener(notifyListeners);
    avgRating.addListener(notifyListeners);
    totalReviews.addListener(notifyListeners);
    isUploadingPostImage.addListener(notifyListeners);
    isCreatingPost.addListener(notifyListeners);
    draftPostImageUrl.addListener(notifyListeners);
    selectedPostCategory.addListener(notifyListeners);
    availability.addListener(notifyListeners);

    final user = FirebaseAuth.instance.currentUser;
    final name = user?.displayName?.trim();
    if (name != null && name.isNotEmpty) {
      displayName.value = name;
      displayNameController.text = name;
    }
    profilePhotoUrl.value = user?.photoURL?.trim() ?? '';

    _listenTrainerData();
  }

  final displayName = 'Trainer'.obs;
  final profilePhotoUrl = ''.obs;
  final currentTabIndex = 0.obs;
  final isLoading = true.obs;
  final isSavingProfile = false.obs;
  final isActionLoading = false.obs;

  final profile = <String, dynamic>{}.obs;
  final bookings = <Map<String, dynamic>>[].obs;
  final reviews = <Map<String, dynamic>>[].obs;
  final payouts = <Map<String, dynamic>>[].obs;
  final refunds = <Map<String, dynamic>>[].obs;
  final posts = <Map<String, dynamic>>[].obs;
  final promotions = <Map<String, dynamic>>[].obs;

  final pendingBookingsCount = 0.obs;
  final todaySessionsCount = 0.obs;
  final monthlyIncome = 0.0.obs;
  final totalIncome = 0.0.obs;
  final avgRating = 0.0.obs;
  final totalReviews = 0.obs;

  /// Money received so far minus already-requested/paid payouts
  double get availableBalance {
    final alreadyPaidOut = payouts.fold(0.0, (acc, p) {
      final status = (p['status'] ?? '').toString().toLowerCase();
      // Count requested, approved, and paid payouts as deducted
      if (status == 'requested' || status == 'approved' || status == 'paid') {
        return acc + _toDouble(p['amount']);
      }
      return acc;
    });
    return (totalIncome.value - alreadyPaidOut).clamp(0.0, double.infinity);
  }

  final displayNameController = TextEditingController();
  final sessionPriceController = TextEditingController();
  final bioController = TextEditingController();
  final specializationController = TextEditingController();
  final languagesController = TextEditingController();
  final sessionLocationController = TextEditingController();
  final ageController = TextEditingController();
  final heightController = TextEditingController();
  final experienceYearsController = TextEditingController();
  final payoutAmountController = TextEditingController();
  final postTitleController = TextEditingController();
  final postCaptionController = TextEditingController();
  final postTagsController = TextEditingController();

  final isUploadingPostImage = false.obs;
  final isCreatingPost = false.obs;
  final draftPostImageUrl = ''.obs;
  final selectedPostCategory = 'Workout'.obs;

  static const List<String> postCategories = [
    'Workout',
    'Nutrition',
    'Mindset',
    'Progress',
    'Announcement',
  ];

  final availability = <String, Map<String, dynamic>>{}.obs;
  final _subs = <StreamSubscription<dynamic>>[];
  final _picker = ImagePicker();
  final _supabase = Supabase.instance.client;

  @override
  void dispose() {
    for (final sub in _subs) {
      sub.cancel();
    }
    displayNameController.dispose();
    sessionPriceController.dispose();
    bioController.dispose();
    specializationController.dispose();
    languagesController.dispose();
    sessionLocationController.dispose();
    ageController.dispose();
    heightController.dispose();
    experienceYearsController.dispose();
    payoutAmountController.dispose();
    postTitleController.dispose();
    postCaptionController.dispose();
    postTagsController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get pendingBookings {
    return bookings.where((b) {
      final status = (b['status'] ?? '').toString().toLowerCase();
      return status == 'pending' || status == 'requested';
    }).toList();
  }

  List<Map<String, dynamic>> get upcomingBookings {
    final now = DateTime.now();
    return bookings.where((b) {
        final status = (b['status'] ?? '').toString().toLowerCase();
        if (status == 'cancelled' || status == 'rejected') return false;
        final scheduledAt = _toDateTime(
          b['scheduledAt'] ?? b['sessionAt'] ?? b['dateTime'],
          b,
        );
        return scheduledAt != null && scheduledAt.isAfter(now);
      }).toList()
      ..sort((a, b) {
        final aDate =
            _toDateTime(a['scheduledAt'] ?? a['sessionAt'] ?? a['dateTime'], a) ??
            DateTime.now();
        final bDate =
            _toDateTime(b['scheduledAt'] ?? b['sessionAt'] ?? b['dateTime'], b) ??
            DateTime.now();
        return aDate.compareTo(bDate);
      });
  }

  List<Map<String, dynamic>> get recentPosts {
    final sorted = posts.toList(growable: false);
    sorted.sort(
      (a, b) => _toEpochMs(
        b['createdAt'] ?? b['createdAtClient'],
      ).compareTo(_toEpochMs(a['createdAt'] ?? a['createdAtClient'])),
    );
    return sorted;
  }

  List<Map<String, dynamic>> get bookingRequests {
    return bookings.where((b) {
        final status = (b['status'] ?? '').toString().toLowerCase();
        return status == 'pending' || status == 'requested';
      }).toList()
      ..sort((a, b) {
        final aDate =
            _toDateTime(a['scheduledAt'] ?? a['sessionAt'] ?? a['dateTime'], a) ??
            DateTime.now();
        final bDate =
            _toDateTime(b['scheduledAt'] ?? b['sessionAt'] ?? b['dateTime'], b) ??
            DateTime.now();
        return aDate.compareTo(bDate);
      });
  }

  List<Map<String, dynamic>> get confirmedUpcomingBookings {
    return bookings.where((b) {
        final status = (b['status'] ?? '').toString().toLowerCase();
        if (status != 'confirmed' && status != 'accepted') return false;
        final scheduledAt = _toDateTime(
          b['scheduledAt'] ?? b['sessionAt'] ?? b['dateTime'],
          b,
        );
        return scheduledAt != null;
      }).toList()
      ..sort((a, b) {
        final aDate =
            _toDateTime(a['scheduledAt'] ?? a['sessionAt'] ?? a['dateTime'], a) ??
            DateTime.now();
        final bDate =
            _toDateTime(b['scheduledAt'] ?? b['sessionAt'] ?? b['dateTime'], b) ??
            DateTime.now();
        return aDate.compareTo(bDate);
      });
  }

  List<Map<String, dynamic>> get pastBookingsHistory {
    return bookings.where((b) {
      final status = (b['status'] ?? '').toString().toLowerCase();
      return status == 'completed' || status == 'cancelled' || status == 'rejected';
    }).toList()
      ..sort((a, b) {
        final aDate =
            _toDateTime(a['scheduledAt'] ?? a['sessionAt'] ?? a['dateTime'], a) ??
            DateTime.now();
        final bDate =
            _toDateTime(b['scheduledAt'] ?? b['sessionAt'] ?? b['dateTime'], b) ??
            DateTime.now();
        return bDate.compareTo(aDate); // Sort newest first for history
      });
  }

  int get activeAvailabilityDays {
    return availability.values.where((day) => day['enabled'] == true).length;
  }

  int get activePostsCount {
    return posts.where((post) => post['isActive'] != false).length;
  }

  Future<void> saveProfile() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    if (isSavingProfile.value) return;

    isSavingProfile.value = true;
    try {
      final nameText = displayNameController.text.trim();
      if (nameText.isNotEmpty) {
        await FirebaseAuth.instance.currentUser?.updateDisplayName(nameText);
        displayName.value = nameText;
      }

      await _firestore.collection('trainerProfiles').doc(uid).set({
        'bio': bioController.text.trim(),
        'sessionPrice':
            double.tryParse(sessionPriceController.text.trim()) ?? 0,
        'specializations': _splitCsv(specializationController.text),
        'languages': _splitCsv(languagesController.text),
        'sessionLocations': _splitCsv(sessionLocationController.text),
        'experienceYears': int.tryParse(experienceYearsController.text.trim()) ?? 0,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await _firestore.collection('users').doc(uid).set({
        'trainerProfileComplete': true,
        if (nameText.isNotEmpty) 'name': nameText,
        if (nameText.isNotEmpty) 'fullName': nameText,
        'age': int.tryParse(ageController.text.trim()) ?? 0,
        'height': int.tryParse(heightController.text.trim()) ?? 0,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      showSnackbar('Profile saved', 'Trainer profile updated successfully.');
    } catch (_) {
      showSnackbar('Save failed', 'Could not update trainer profile.');
    } finally {
      isSavingProfile.value = false;
    }
  }

  Future<void> saveProfileDraft({
    required String name,
    required String sessionPrice,
    required String bio,
    required String specializations,
    required String languages,
    required String locations,
    required String age,
    required String height,
    required String experienceYears,
  }) async {
    displayNameController.text = name;
    sessionPriceController.text = sessionPrice;
    bioController.text = bio;
    specializationController.text = specializations;
    languagesController.text = languages;
    sessionLocationController.text = locations;
    ageController.text = age;
    heightController.text = height;
    experienceYearsController.text = experienceYears;
    await saveProfile();
  }

  Future<void> updateDayAvailability({
    required String day,
    required bool enabled,
    String? date,
    String? start,
    String? end,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final current = Map<String, dynamic>.from(availability[day] ?? {});
    current['enabled'] = enabled;
    current['date'] = date ?? (current['date'] ?? '');
    current['start'] = start ?? (current['start'] ?? '09:00');
    current['end'] = end ?? (current['end'] ?? '18:00');
    availability[day] = current;

    await _firestore.collection('trainerProfiles').doc(uid).set({
      'availability': availability,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> acceptBooking(Map<String, dynamic> booking) async {
    await _setBookingStatus(booking, 'confirmed');
  }

  Future<void> rejectBooking(Map<String, dynamic> booking) async {
    await _setBookingStatus(booking, 'rejected');
  }

  Future<void> cancelBooking(Map<String, dynamic> booking) async {
    await _setBookingStatus(
      booking,
      'cancelled',
      reason: 'Cancelled by trainer',
    );
  }

  Future<void> completeBooking(Map<String, dynamic> booking) async {
    await _setBookingStatus(booking, 'completed');
  }

  Future<void> requestPayout() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final amount = double.tryParse(payoutAmountController.text.trim()) ?? 0;
    if (amount <= 0) {
      showSnackbar('Invalid amount', 'Enter a valid payout amount.');
      return;
    }

    final balance = availableBalance;
    if (amount > balance + 0.01) {
      showSnackbar(
        'Amount too high',
        'You can only request up to \$${balance.toStringAsFixed(2)}.',
      );
      return;
    }

    try {
      await _firestore.collection('payouts').add({
        'trainerId': uid,
        'trainerName': displayName.value,
        'amount': amount,
        'status': 'requested',
        'requestedAt': FieldValue.serverTimestamp(),
      });
      payoutAmountController.clear();
      showSnackbar(
        'Payout requested',
        'Your withdrawal request for \$${amount.toStringAsFixed(2)} was submitted.',
      );
    } catch (_) {
      showSnackbar('Request failed', 'Could not submit payout request.');
    }
  }


  Future<void> logout() async {
    await FirebaseAuth.instance.signOut();
    ref.read(routerProvider).go(Routes.LOGIN);
  }

  Future<void> pickAndUploadPostImage() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || isUploadingPostImage.value) return;

    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1600,
      maxHeight: 1600,
    );

    if (picked == null) return;

    isUploadingPostImage.value = true;
    try {
      final bytes = await picked.readAsBytes();
      final ext = picked.path.split('.').last.toLowerCase();
      final safeExt = ext.isEmpty ? 'jpg' : ext;
      final path =
          'trainer-posts/${uid}_${DateTime.now().millisecondsSinceEpoch}.$safeExt';

      await _supabase.storage
          .from('images')
          .uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(
              upsert: true,
              contentType: _contentTypeFor(safeExt),
            ),
          );

      draftPostImageUrl.value = _supabase.storage
          .from('images')
          .getPublicUrl(path);
      showSnackbar('Image uploaded', 'Post image is ready.');
    } catch (_) {
      showSnackbar('Upload failed', 'Could not upload the post image.');
    } finally {
      isUploadingPostImage.value = false;
    }
  }

  void clearPostDraft() {
    postTitleController.clear();
    postCaptionController.clear();
    postTagsController.clear();
    selectedPostCategory.value = postCategories.first;
    draftPostImageUrl.value = '';
  }

  Future<bool> createPostDraft({
    required String title,
    required String caption,
    required String tags,
    required String category,
    DateTime? selectedDate,
  }) async {
    postTitleController.text = title;
    postCaptionController.text = caption;
    postTagsController.text = tags;
    selectedPostCategory.value = category;
    return createPost(selectedDate: selectedDate);
  }

  Future<bool> createPost({DateTime? selectedDate}) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || isCreatingPost.value) return false;

    final title = postTitleController.text.trim();
    final caption = postCaptionController.text.trim();
    if (title.isEmpty && caption.isEmpty) {
      showSnackbar('Missing content', 'Add a title or caption for your post.');
      return false;
    }

    isCreatingPost.value = true;
    try {
      final date = selectedDate ?? DateTime.now();
      await _firestore.collection('trainerPosts').add({
        'trainerId': uid,
        'trainerName': displayName.value,
        'trainerPhotoUrl': profilePhotoUrl.value,
        'title': title,
        'caption': caption,
        'category': selectedPostCategory.value,
        'tags': _splitCsv(postTagsController.text),
        'imageUrl': draftPostImageUrl.value,
        'likesCount': 0,
        'commentsCount': 0,
        'isActive': true,
        'date': _formatDateIso(date),
        'postDate': _formatDateIso(date),
        'postDay': date.day,
        'postMonth': date.month,
        'postYear': date.year,
        'createdAt': FieldValue.serverTimestamp(),
        'createdAtClient': Timestamp.now(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      clearPostDraft();
      showSnackbar('Post published', 'Your trainer post is now live.');
      return true;
    } catch (_) {
      showSnackbar('Post failed', 'Could not publish this post.');
      return false;
    } finally {
      isCreatingPost.value = false;
    }
  }

  Future<void> togglePostVisibility(Map<String, dynamic> post) async {
    if (isActionLoading.value) return;
    final postId = post['id']?.toString();
    if (postId == null || postId.isEmpty) return;

    isActionLoading.value = true;
    try {
      final isActive = post['isActive'] != false;
      await _firestore.collection('trainerPosts').doc(postId).set({
        'isActive': !isActive,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      showSnackbar(
        isActive ? 'Post archived' : 'Post activated',
        isActive
            ? 'This post is now hidden from your public feed.'
            : 'This post is visible again.',
      );
    } catch (_) {
      showSnackbar('Update failed', 'Could not update post visibility.');
    } finally {
      isActionLoading.value = false;
    }
  }

  Future<void> deletePost(Map<String, dynamic> post) async {
    if (isActionLoading.value) return;
    final postId = post['id']?.toString();
    if (postId == null || postId.isEmpty) return;

    isActionLoading.value = true;
    try {
      await _firestore.collection('trainerPosts').doc(postId).delete();
      showSnackbar('Post deleted', 'Trainer post removed successfully.');
    } catch (_) {
      showSnackbar('Delete failed', 'Could not delete this post.');
    } finally {
      isActionLoading.value = false;
    }
  }

  Future<void> updateProfilePhoto() async {
    try {
      final profileService = ref.read(userProfileServiceProvider.notifier);
      final ok = await profileService.pickAndUploadProfilePhoto(
        onNotification: (title, message) => showSnackbar(title, message),
      );
      if (ok) {
        profilePhotoUrl.value = ref.read(userProfileServiceProvider).photoUrl;
        final uid = FirebaseAuth.instance.currentUser?.uid;
        if (uid != null && uid.isNotEmpty) {
          await _firestore.collection('trainerProfiles').doc(uid).set({
            'photoUrl': profilePhotoUrl.value,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }
      }
    } catch (_) {
      showSnackbar('Photo update failed', 'Could not update trainer photo.');
    }
  }

  void changeTab(int index) {
    currentTabIndex.value = index;
  }

  Future<Map<String, dynamic>> loadReviewerProfile(
    Map<String, dynamic> review,
  ) async {
    final merged = Map<String, dynamic>.from(review);
    final reviewerId = _extractReviewerId(review);
    if (reviewerId.isEmpty) {
      return {
        ...merged,
        'reviewerId': '',
        'reviewerName': _extractReviewerName(review),
        'reviewerPhotoUrl': _extractReviewerPhoto(review),
      };
    }

    try {
      final doc = await _firestore.collection('users').doc(reviewerId).get();
      final data = doc.data() ?? const <String, dynamic>{};
      return {
        ...merged,
        ...data,
        'reviewerId': reviewerId,
        'reviewerName':
            (data['name'] ??
                    data['fullName'] ??
                    data['displayName'] ??
                    _extractReviewerName(review))
                .toString(),
        'reviewerPhotoUrl':
            (data['photoUrl'] ??
                    data['avatarUrl'] ??
                    data['profileImage'] ??
                    _extractReviewerPhoto(review))
                .toString(),
      };
    } catch (_) {
      return {
        ...merged,
        'reviewerId': reviewerId,
        'reviewerName': _extractReviewerName(review),
        'reviewerPhotoUrl': _extractReviewerPhoto(review),
      };
    }
  }

  String _extractReviewerId(Map<String, dynamic> review) {
    const keys = [
      'userId',
      'reviewerId',
      'clientId',
      'memberId',
      'fromUserId',
      'authorId',
    ];
    for (final key in keys) {
      final value = (review[key] ?? '').toString().trim();
      if (value.isNotEmpty) return value;
    }
    return '';
  }

  String _extractReviewerName(Map<String, dynamic> review) {
    const keys = [
      'userName',
      'reviewerName',
      'clientName',
      'authorName',
      'name',
    ];
    for (final key in keys) {
      final value = (review[key] ?? '').toString().trim();
      if (value.isNotEmpty) return value;
    }
    return 'User';
  }

  String _extractReviewerPhoto(Map<String, dynamic> review) {
    const keys = [
      'userPhotoUrl',
      'reviewerPhotoUrl',
      'clientPhotoUrl',
      'authorPhotoUrl',
      'photoUrl',
      'avatarUrl',
    ];
    for (final key in keys) {
      final value = (review[key] ?? '').toString().trim();
      if (value.isNotEmpty) return value;
    }
    return '';
  }

  void _listenTrainerData() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      isLoading.value = false;
      return;
    }

    _subs.add(
      _firestore.collection('users').doc(uid).snapshots().listen((doc) {
        if (!doc.exists) return;
        final data = doc.data() ?? {};
        final name = (data['name'] ?? data['fullName'] ?? '').toString().trim();
        if (name.isNotEmpty) {
          displayName.value = name;
          displayNameController.text = name;
        }
        final docPhoto = (data['photoUrl'] ?? '').toString().trim();
        if (docPhoto.isNotEmpty) {
          profilePhotoUrl.value = docPhoto;
        }
        final age = data['age'] != null ? data['age'].toString() : '';
        final height = data['height'] != null ? data['height'].toString() : '';
        if (age.isNotEmpty) ageController.text = age;
        if (height.isNotEmpty) heightController.text = height;
      }),
    );

    _subs.add(
      _firestore.collection('trainerProfiles').doc(uid).snapshots().listen((
        doc,
      ) {
        final data = doc.data() ?? {};
        profile.assignAll(data);
        final profilePhoto = (data['photoUrl'] ?? '').toString().trim();
        if (profilePhoto.isNotEmpty) {
          profilePhotoUrl.value = profilePhoto;
        }
        bioController.text = (data['bio'] ?? '').toString();
        sessionPriceController.text = (data['sessionPrice'] ?? '').toString();
        specializationController.text = _joinCsv(data['specializations']);
        languagesController.text = _joinCsv(data['languages']);
        sessionLocationController.text = _joinCsv(data['sessionLocations']);
        final exp = data['experienceYears'] != null ? data['experienceYears'].toString() : '';
        if (exp.isNotEmpty) experienceYearsController.text = exp;

        final rawAvailability = data['availability'];
        if (rawAvailability is Map) {
          availability.assignAll(
            rawAvailability.map((key, value) {
              final dayKey = key.toString();
              final dayValue =
                  value is Map
                      ? Map<String, dynamic>.from(value)
                      : <String, dynamic>{};
              return MapEntry(dayKey, dayValue);
            }),
          );
        }
      }),
    );

    _subs.add(
      _firestore
          .collection('bookings')
          .where('trainerId', isEqualTo: uid)
          .limit(200)
          .snapshots()
          .listen((snap) {
            bookings.assignAll(snap.docs.map((d) => {'id': d.id, ...d.data()}));
            _recomputeBookingKpis();
          }, onError: (_) {}),
    );

    _subs.add(
      _firestore
          .collection('reviews')
          .where('trainerId', isEqualTo: uid)
          .limit(100)
          .snapshots()
          .listen((snap) {
            reviews.assignAll(snap.docs.map((d) => {'id': d.id, ...d.data()}));
            _recomputeRatings();
          }, onError: (_) {}),
    );

    _subs.add(
      _firestore
          .collection('payouts')
          .where('trainerId', isEqualTo: uid)
          .limit(100)
          .snapshots()
          .listen((snap) {
            payouts.assignAll(snap.docs.map((d) => {'id': d.id, ...d.data()}));
            _recomputeBookingKpis();
          }, onError: (_) {}),
    );

    _subs.add(
      _firestore
          .collection('refunds')
          .where('trainerId', isEqualTo: uid)
          .limit(100)
          .snapshots()
          .listen((snap) {
            refunds.assignAll(snap.docs.map((d) => {'id': d.id, ...d.data()}));
            _recomputeBookingKpis();
          }, onError: (_) {}),
    );

    _subs.add(
      _firestore
          .collection('trainerPosts')
          .where('trainerId', isEqualTo: uid)
          .limit(100)
          .snapshots()
          .listen((snap) {
            final mapped = snap.docs
                .map((d) => {'id': d.id, ...d.data()})
                .toList(growable: false);
            mapped.sort(
              (a, b) => _toEpochMs(
                b['createdAt'] ?? b['createdAtClient'],
              ).compareTo(_toEpochMs(a['createdAt'] ?? a['createdAtClient'])),
            );
            posts.assignAll(mapped);
          }, onError: (_) {}),
    );

    _subs.add(
      _firestore
          .collection('promotions')
          .where('trainerId', isEqualTo: uid)
          .snapshots()
          .listen((snap) {
            promotions.assignAll(snap.docs.map((d) => {'id': d.id, ...d.data()}));
          }, onError: (_) {}),
    );

    Future<void>.delayed(const Duration(milliseconds: 500), () {
      isLoading.value = false;
    });
  }

  void _recomputeBookingKpis() {
    pendingBookingsCount.value =
        bookings.where((b) {
          final status = (b['status'] ?? '').toString().toLowerCase();
          return status == 'pending' || status == 'requested';
        }).length;

    final now = DateTime.now();
    todaySessionsCount.value =
        bookings.where((b) {
          final dt = _toDateTime(b['scheduledAt'] ?? b['sessionAt'], b);
          if (dt == null) return false;
          return dt.year == now.year &&
              dt.month == now.month &&
              dt.day == now.day;
        }).length;

    final startOfMonth = DateTime(now.year, now.month, 1);

    // Compute all-time total income (money actually received from clients)
    double allTimeIncome = 0.0;
    double currentMonthIncome = 0.0;

    for (final booking in bookings) {
      final status = (booking['status'] ?? '').toString().toLowerCase();
      // Skip rejected bookings — no payment was ever made for these
      if (status == 'rejected') continue;

      final paymentStatus = (booking['paymentStatus'] ?? '').toString().toLowerCase();
      final isPaid = booking['paid'] == true ||
                     paymentStatus == 'fully_paid' ||
                     paymentStatus == 'partially_paid' ||
                     paymentStatus == 'completed' ||
                     (paymentStatus.isEmpty && status == 'completed');

      if (!isPaid) continue;

      // For cancelled bookings with payments, the money was still received.
      // Refunds are tracked separately in the 'refunds' collection.
      double amount = _toDouble(booking['amountPaid']);
      if (amount <= 0) {
        amount = _toDouble(booking['paymentAmount']);
      }
      if (amount <= 0) {
        if (booking['paid'] == true || paymentStatus == 'completed' ||
            paymentStatus == 'fully_paid' ||
            (paymentStatus.isEmpty && status == 'completed')) {
          amount = _toDouble(booking['price'] ?? booking['amount']);
        }
      }

      if (amount <= 0) continue;

      allTimeIncome += amount;

      // Also compute this month's income
      final dt = _toDateTime(booking['scheduledAt'] ?? booking['sessionAt'], booking);
      if (dt == null || !dt.isBefore(startOfMonth)) {
        currentMonthIncome += amount;
      }
    }

    // Subtract refunds that have been approved/processed
    for (final r in refunds) {
      final rStatus = (r['status'] ?? '').toString().toLowerCase();
      if (rStatus == 'approved' || rStatus == 'processed' || rStatus == 'completed') {
        final refundAmount = _toDouble(r['amount']);
        allTimeIncome -= refundAmount;
        currentMonthIncome -= refundAmount;
      }
    }

    totalIncome.value = allTimeIncome.clamp(0.0, double.infinity);
    monthlyIncome.value = currentMonthIncome.clamp(0.0, double.infinity);
  }

  void _recomputeRatings() {
    totalReviews.value = reviews.length;
    if (reviews.isEmpty) {
      avgRating.value = 0;
      return;
    }

    final values =
        reviews.map((r) => _toDouble(r['rating'])).where((v) => v > 0).toList();
    if (values.isEmpty) {
      avgRating.value = 0;
      return;
    }

    avgRating.value = values.reduce((a, b) => a + b) / values.length;
  }

  Future<void> _setBookingStatus(
    Map<String, dynamic> booking,
    String status, {
    String? reason,
  }) async {
    if (isActionLoading.value) return;
    final bookingId = booking['id']?.toString();
    if (bookingId == null || bookingId.isEmpty) return;

    isActionLoading.value = true;
    try {
      await _firestore.collection('bookings').doc(bookingId).set({
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': FirebaseAuth.instance.currentUser?.uid,
        if (reason != null) 'statusReason': reason,
      }, SetOptions(merge: true));

      // Increment client's sessions count & streak dynamically when marked completed
      if (status == 'completed') {
        final clientUid = booking['userId']?.toString() ?? '';
        if (clientUid.isNotEmpty) {
          await _firestore.collection('users').doc(clientUid).set({
            'totalSessions': FieldValue.increment(1),
            'streak': FieldValue.increment(1),
          }, SetOptions(merge: true)).catchError((_) {});
        }
      }

      final clientUid = booking['userId']?.toString() ?? '';
      final trainerUid = booking['trainerId']?.toString() ?? FirebaseAuth.instance.currentUser?.uid ?? '';

      if (status == 'cancelled') {
        final isPaid = booking['paid'] == true ||
                       booking['paymentStatus'] == 'fully_paid' ||
                       booking['paymentStatus'] == 'partially_paid';
        if (isPaid) {
          double amountPaid = (booking['amountPaid'] as num?)?.toDouble() ?? 0.0;
          if (amountPaid == 0.0) {
            amountPaid = (booking['price'] as num?)?.toDouble() ?? 0.0;
          }
          final clientName = (booking['clientName'] ?? booking['userName'] ?? 'Client').toString();
          if (clientUid.isNotEmpty && amountPaid > 0) {
            await _firestore.collection('refunds').add({
              'bookingId': bookingId,
              'userId': clientUid,
              'clientName': clientName,
              'trainerId': trainerUid,
              'trainerName': displayName.value,
              'amount': amountPaid,
              'status': 'pending',
              'createdAt': FieldValue.serverTimestamp(),
              'sessionDate': (booking['date'] ?? '').toString(),
              'sessionTime': (booking['time'] ?? '').toString(),
              'sessionType': (booking['type'] ?? booking['sessionType'] ?? 'Session').toString(),
            });
          }
        }
      }

      if (clientUid.isNotEmpty && clientUid != trainerUid) {
        String title = 'Booking Updated';
        String body = 'Your session status was updated to $status.';
        String color = 'sky';
        
        final sessionType = (booking['type'] ?? booking['sessionType'] ?? 'Session').toString();
        final formattedDate = (booking['date'] ?? '').toString();
        final selectedSlot = (booking['time'] ?? '').toString();

        if (status == 'confirmed') {
          title = 'Booking Confirmed';
          body = 'Your $sessionType session with ${displayName.value} on $formattedDate at $selectedSlot has been confirmed.';
          color = 'sky';
        } else if (status == 'rejected') {
          title = 'Booking Request Declined';
          body = 'Your request for a $sessionType session with ${displayName.value} on $formattedDate at $selectedSlot was declined.';
          color = 'coral';
        } else if (status == 'cancelled') {
          title = 'Booking Cancelled';
          body = 'Your $sessionType session with ${displayName.value} on $formattedDate at $selectedSlot was cancelled.';
          color = 'coral';
        } else if (status == 'completed') {
          title = 'Session Completed';
          body = 'Your $sessionType session with ${displayName.value} on $formattedDate at $selectedSlot has been completed. Keep up the great work!';
          color = 'sky';
        }

        await _firestore
            .collection('notifications')
            .doc(clientUid)
            .collection('items')
            .add({
          'title': title,
          'body': body,
          'type': 'booking',
          'color': color,
          'icon': 'calendar',
          'read': false,
          'createdAt': FieldValue.serverTimestamp(),
          'senderId': trainerUid,
          'senderName': displayName.value,
          'senderPhotoUrl': profilePhotoUrl.value,
        });
      }

      showSnackbar('Booking updated', 'Status set to $status.');
    } catch (_) {
      showSnackbar('Action failed', 'Could not update this booking.');
    } finally {
      isActionLoading.value = false;
    }
  }

  DateTime? _toDateTime(dynamic raw, [Map<String, dynamic>? booking]) {
    if (raw is Timestamp) return raw.toDate();
    if (raw is DateTime) return raw;
    if (raw is String) return DateTime.tryParse(raw);
    
    // Fallback: parse from date & time strings
    if (booking != null) {
      final dateStr = booking['date']?.toString() ?? '';
      final timeStr = booking['time']?.toString() ?? '';
      if (dateStr.isNotEmpty) {
        try {
          final clean = dateStr.replaceAll(',', '').trim();
          final parts = clean.split(' '); // ["Wed", "Jun", "10", "2026"]
          if (parts.length >= 4) {
            final monthStr = parts[1];
            final dayVal = int.parse(parts[2]);
            final yearVal = int.parse(parts[3]);

            const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
            final monthVal = months.indexOf(monthStr) + 1;

            int hourVal = 9;
            int minVal = 0;
            if (timeStr.isNotEmpty) {
              final tParts = timeStr.trim().split(' ');
              final timeParts = tParts[0].split(':');
              hourVal = int.parse(timeParts[0]);
              minVal = int.parse(timeParts[1]);
              if (tParts.length > 1) {
                final ampm = tParts[1].toLowerCase();
                if (ampm == 'pm' && hourVal < 12) {
                  hourVal += 12;
                } else if (ampm == 'am' && hourVal == 12) {
                  hourVal = 0;
                }
              }
            }
            if (monthVal > 0) {
              return DateTime(yearVal, monthVal, dayVal, hourVal, minVal);
            }
          }
        } catch (_) {}
      }
    }
    return null;
  }

  double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0;
    return 0;
  }

  String _joinCsv(dynamic raw) {
    if (raw is List) {
      return raw.map((e) => e.toString()).where((e) => e.isNotEmpty).join(', ');
    }
    return '';
  }

  List<String> _splitCsv(String text) {
    return text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  int _toEpochMs(dynamic raw) {
    if (raw is Timestamp) return raw.millisecondsSinceEpoch;
    if (raw is DateTime) return raw.millisecondsSinceEpoch;
    if (raw is int) return raw;
    if (raw is String) {
      final parsed = DateTime.tryParse(raw);
      if (parsed != null) return parsed.millisecondsSinceEpoch;
    }
    return 0;
  }

  String _formatDateIso(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  String _contentTypeFor(String ext) {
    switch (ext) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'heic':
        return 'image/heic';
      case 'jpeg':
      case 'jpg':
      default:
        return 'image/jpeg';
    }
  }

  List<Map<String, dynamic>> get earningsHistory {
    final history = <Map<String, dynamic>>[];

    // 1. Add payments from bookings (all bookings where money was received)
    for (final b in bookings) {
      final status = (b['status'] ?? '').toString().toLowerCase();
      // Skip rejected bookings — no payment ever made
      if (status == 'rejected') continue;

      final clientName = (b['clientName'] ?? b['userName'] ?? 'Client').toString();
      final sessionType = (b['type'] ?? b['sessionType'] ?? 'Session').toString();
      final date = (b['date'] ?? '').toString();
      final time = (b['time'] ?? '').toString();
      
      final paymentStatus = (b['paymentStatus'] ?? '').toString().toLowerCase();
      final isPaid = b['paid'] == true ||
                     paymentStatus == 'fully_paid' ||
                     paymentStatus == 'partially_paid' ||
                     paymentStatus == 'completed' ||
                     (paymentStatus.isEmpty && status == 'completed');

      if (!isPaid) continue;

      double amountPaid = _toDouble(b['amountPaid']);
      if (amountPaid <= 0) {
        amountPaid = _toDouble(b['paymentAmount']);
      }
      if (amountPaid <= 0) {
        if (b['paid'] == true || paymentStatus == 'completed' ||
            paymentStatus == 'fully_paid' ||
            (paymentStatus.isEmpty && status == 'completed')) {
          amountPaid = _toDouble(b['price'] ?? b['amount']);
        }
      }

      if (amountPaid <= 0) continue;

      // Use payment/update timestamp for sorting
      final updatedAtRaw = b['updatedAt'] ?? b['createdAt'] ?? b['scheduledAt'] ?? b['sessionAt'];
      final DateTime dt = _toDateTime(updatedAtRaw, b) ?? DateTime.now();

      final paymentLabel = paymentStatus == 'partially_paid'
          ? 'Deposit from $clientName'
          : 'Payment from $clientName';
      final paymentSubtitle = status == 'cancelled'
          ? '$sessionType on $date at $time (Cancelled)'
          : '$sessionType on $date at $time';

      history.add({
        'type': 'payment',
        'title': paymentLabel,
        'subtitle': paymentSubtitle,
        'amount': amountPaid,
        'dateTime': dt,
        'status': status == 'cancelled' ? 'cancelled' : 'completed',
      });
    }

    // 2. Add refunds from the Firestore refunds collection
    for (final r in refunds) {
      final rStatus = (r['status'] ?? 'pending').toString();
      final rAmount = _toDouble(r['amount']);
      final clientName = (r['clientName'] ?? 'Client').toString();
      final sessionType = (r['sessionType'] ?? 'Session').toString();
      final sessionDate = (r['sessionDate'] ?? '').toString();
      final sessionTime = (r['sessionTime'] ?? '').toString();
      final createdAtRaw = r['createdAt'];
      final DateTime dt = _toDateTime(createdAtRaw) ?? DateTime.now();

      history.add({
        'type': 'refund',
        'title': 'Refund — $clientName Session',
        'subtitle': '$sessionType on $sessionDate at $sessionTime',
        'amount': -rAmount,
        'dateTime': dt,
        'status': rStatus,
      });
    }

    // 2. Add payouts
    for (final p in payouts) {
      final status = (p['status'] ?? 'requested').toString();
      final amount = _toDouble(p['amount']);
      final reqAtRaw = p['requestedAt'] ?? p['approvedAt'];
      DateTime dt = _toDateTime(reqAtRaw) ?? DateTime.now();

      history.add({
        'type': 'payout',
        'title': 'Payout Request',
        'subtitle': 'Withdrawal to Bank Account',
        'amount': -amount,
        'dateTime': dt,
        'status': status,
      });
    }

    // Sort by date descending
    history.sort((a, b) {
      final dtA = a['dateTime'] as DateTime;
      final dtB = b['dateTime'] as DateTime;
      return dtB.compareTo(dtA);
    });

    return history;
  }

  Future<void> addPromoCode(String code, int discount) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) return;
    if (code.isEmpty || discount <= 0 || discount > 100) {
      showSnackbar('Invalid Promo', 'Please enter a valid code and discount percentage (1-100).');
      return;
    }

    try {
      await _firestore.collection('promotions').add({
        'code': code.trim().toUpperCase(),
        'discount': discount,
        'trainerId': uid,
        'trainerName': displayName.value,
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
      });
      showSnackbar('Promotion Created', 'Promo code $code ($discount% off) is now active.');
    } catch (_) {
      showSnackbar('Error', 'Failed to create promotion.');
    }
  }

  Future<void> deletePromoCode(String id) async {
    try {
      await _firestore.collection('promotions').doc(id).delete();
      showSnackbar('Deleted', 'Promotion has been deleted.');
    } catch (_) {
      showSnackbar('Error', 'Failed to delete promotion.');
    }
  }
}

final trainerDashboardProvider = ChangeNotifierProvider((ref) {
  return TrainerDashboardController(ref: ref);
});
