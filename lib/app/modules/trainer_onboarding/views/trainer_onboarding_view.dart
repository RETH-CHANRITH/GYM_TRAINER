import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../../config/glass_ui.dart';
import '../../../providers/global_providers.dart';
import '../../../routes/app_router.dart';

class TrainerOnboardingView extends ConsumerStatefulWidget {
  const TrainerOnboardingView({super.key});

  @override
  ConsumerState<TrainerOnboardingView> createState() => _TrainerOnboardingViewState();
}

class _TrainerOnboardingViewState extends ConsumerState<TrainerOnboardingView> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  final int _totalPages = 9;

  // Dynamic accent colour — follows the user's chosen theme.
  Color get _accent => Theme.of(context).colorScheme.primary;

  // Form State
  late final TextEditingController _nameController;
  late final TextEditingController _priceInputController;
  int _sessionPrice = 40;
  int _age = 29;
  int _height = 170;
  int _experienceYears = 5;
  final TextEditingController _bioController = TextEditingController();
  final Set<String> _selectedSpecs = {};
  final Set<String> _selectedLanguages = {'English'};
  final Set<String> _selectedLocations = {};
  String? _photoUrl;
  bool _isSaving = false;

  final List<String> _specOptions = [
    'Strength Training',
    'Cardio & HIIT',
    'Yoga & Pilates',
    'Crossfit & Functional',
    'Powerlifting',
    'Calisthenics',
    'Nutrition Coaching',
    'Weight Loss',
  ];

  final List<String> _languageOptions = [
    'English',
    'Khmer',
    'French',
    'Chinese',
  ];

  final List<String> _locationOptions = [
    'Gym',
    'Online',
    'Home',
    'Outdoor',
  ];

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    _nameController = TextEditingController(text: user?.displayName ?? '');
    _priceInputController = TextEditingController(text: _sessionPrice.toString());
    _photoUrl = user?.photoURL;

    _nameController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _priceInputController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage == 0 && _nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your full name')),
      );
      return;
    }
    // _currentPage == 1 is the new Personal Details step (no validation needed).
    // _currentPage == 2 is Photo (no validation needed).
    // _currentPage == 3 is Price (no validation needed).
    if (_currentPage == 4 && _selectedSpecs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one specialization')),
      );
      return;
    }
    if (_currentPage == 5 && _bioController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please write a short bio about yourself')),
      );
      return;
    }
    if (_currentPage == 6 && _selectedLanguages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one language')),
      );
      return;
    }
    if (_currentPage == 7 && _selectedLocations.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one training location')),
      );
      return;
    }

    if (_currentPage < _totalPages - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _prevPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _pickAndUploadPhoto() async {
    try {
      final profileService = ref.read(userProfileServiceProvider.notifier);
      final ok = await profileService.pickAndUploadProfilePhoto(
        onNotification: (title, message) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$title: $message')),
          );
        },
      );
      if (ok) {
        final newUrl = ref.read(userProfileServiceProvider).photoUrl;
        setState(() {
          _photoUrl = newUrl;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to upload photo: $e')),
      );
    }
  }

  Future<void> _submitOnboarding() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _isSaving) return;

    setState(() => _isSaving = true);

    try {
      final uid = user.uid;
      final nameText = _nameController.text.trim();

      // 1. Update Firebase Auth display name and photoUrl
      if (nameText.isNotEmpty) {
        await user.updateDisplayName(nameText);
      }
      if (_photoUrl != null && _photoUrl!.isNotEmpty) {
        await user.updatePhotoURL(_photoUrl);
      }

      // 2. Save to trainerProfiles
      await FirebaseFirestore.instance.collection('trainerProfiles').doc(uid).set({
        'bio': _bioController.text.trim(),
        'sessionPrice': _sessionPrice.toDouble(),
        'specializations': _selectedSpecs.toList(),
        'languages': _selectedLanguages.toList(),
        'sessionLocations': _selectedLocations.toList(),
        'experienceYears': _experienceYears,
        if (_photoUrl != null && _photoUrl!.isNotEmpty) 'photoUrl': _photoUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // 3. Update users doc and mark profile complete
      final roleService = ref.read(userRoleServiceProvider);
      await roleService.markTrainerProfileComplete(user);

      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'name': nameText,
        'fullName': nameText,
        'age': _age,
        'height': _height,
        if (_photoUrl != null && _photoUrl!.isNotEmpty) 'photoUrl': _photoUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        context.go(Routes.TRAINER_DASHBOARD);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save profile: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  String _getInitials(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return 'U';
    final parts = trimmed.split(' ');
    if (parts.length > 1) {
      final p1 = parts[0];
      final p2 = parts[1];
      if (p1.isNotEmpty && p2.isNotEmpty) {
        return (p1[0] + p2[0]).toUpperCase();
      }
    }
    if (trimmed.isNotEmpty) {
      return trimmed[0].toUpperCase();
    }
    return 'U';
  }

  // UI builders for each step
  Widget _buildStepIndicator() {
    final initials = _getInitials(_nameController.text);
    final accent = _accent;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: List.generate(_totalPages, (index) {
                final isCompleted = index < _currentPage;
                final isActive = index == _currentPage;
                return Expanded(
                  child: Container(
                    height: 4,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      color: isCompleted
                          ? accent
                          : isActive
                              ? accent.withOpacity(0.5)
                              : Colors.white.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(width: 16),
          GestureDetector(
            onTap: _pickAndUploadPhoto,
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withOpacity(0.24),
                  width: 1.5,
                ),
                gradient: LinearGradient(
                  colors: [accent, kSky],
                ),
              ),
              child: ClipOval(
                child: _photoUrl != null && _photoUrl!.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: _photoUrl!,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => _buildInitialsAvatar(initials),
                      )
                    : _buildInitialsAvatar(initials),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInitialsAvatar(String initials) {
    return Container(
      color: Colors.white,
      alignment: Alignment.center,
      child: Text(
        initials,
        style: GoogleFonts.dmSans(
          color: kInk,
          fontWeight: FontWeight.w800,
          fontSize: 13,
        ),
      ),
    );
  }

  Widget _buildStepHeader({required String title, required String subtitle}) {
    final accent = _accent;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ShaderMask(
          shaderCallback:
              (b) => LinearGradient(
                colors: [Colors.white, accent],
              ).createShader(b),
          child: Text(
            title,
            style: GoogleFonts.bebasNeue(
              fontSize: 40,
              color: Colors.white,
              height: 1.05,
              letterSpacing: 1.5,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: GoogleFonts.dmSans(fontSize: 13, color: kMuted),
        ),
      ],
    );
  }

  Widget _buildNameStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStepHeader(
          title: "What is your\nfull name?",
          subtitle: "This will be displayed on your public trainer profile.",
        ),
        const Spacer(),
        LiquidTile(
          padding: EdgeInsets.zero,
          child: TextField(
            controller: _nameController,
            style: GoogleFonts.dmSans(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
            decoration: const InputDecoration(
              hintText: "Enter your name",
              hintStyle: TextStyle(color: kMuted),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              prefixIcon: Icon(Icons.person_rounded, color: kMuted),
            ),
          ),
        ),
        const Spacer(),
      ],
    );
  }

  Widget _buildPersonalDetailsStep() {
    final accent = _accent;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStepHeader(
          title: "Tell us about\nyourself",
          subtitle: "Provide your age, height, and coaching experience.",
        ),
        const Spacer(),
        Text(
          "Age: $_age years old",
          style: GoogleFonts.dmSans(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: accent,
            inactiveTrackColor: Colors.white.withOpacity(0.12),
            thumbColor: accent,
            overlayColor: accent.withOpacity(0.15),
            trackHeight: 4,
          ),
          child: Slider(
            value: _age.toDouble(),
            min: 18,
            max: 80,
            onChanged: (val) {
              setState(() {
                _age = val.round();
              });
            },
          ),
        ),
        const SizedBox(height: 16),
        Text(
          "Height: $_height cm",
          style: GoogleFonts.dmSans(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: accent,
            inactiveTrackColor: Colors.white.withOpacity(0.12),
            thumbColor: accent,
            overlayColor: accent.withOpacity(0.15),
            trackHeight: 4,
          ),
          child: Slider(
            value: _height.toDouble(),
            min: 120,
            max: 220,
            onChanged: (val) {
              setState(() {
                _height = val.round();
              });
            },
          ),
        ),
        const SizedBox(height: 16),
        Text(
          "Years of Experience: $_experienceYears yrs",
          style: GoogleFonts.dmSans(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: accent,
            inactiveTrackColor: Colors.white.withOpacity(0.12),
            thumbColor: accent,
            overlayColor: accent.withOpacity(0.15),
            trackHeight: 4,
          ),
          child: Slider(
            value: _experienceYears.toDouble(),
            min: 0,
            max: 50,
            onChanged: (val) {
              setState(() {
                _experienceYears = val.round();
              });
            },
          ),
        ),
        const Spacer(),
      ],
    );
  }

  Widget _buildPhotoStep() {
    final initials = _getInitials(_nameController.text);
    final accent = _accent;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStepHeader(
          title: "Upload your\nprofile photo",
          subtitle: "A professional photo helps you stand out and build trust with clients.",
        ),
        const Spacer(),
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: _pickAndUploadPhoto,
                child: Stack(
                  children: [
                    Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: accent,
                          width: 2.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: accent.withOpacity(0.3),
                            blurRadius: 24,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: _photoUrl != null && _photoUrl!.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: _photoUrl!,
                                fit: BoxFit.cover,
                                errorWidget: (_, __, ___) => _buildLargeInitials(initials),
                              )
                            : _buildLargeInitials(initials),
                      ),
                    ),
                    Positioned(
                      right: 4,
                      bottom: 4,
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: accent,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: kInk,
                            width: 2.5,
                          ),
                        ),
                        child: const Icon(
                          Icons.camera_alt_rounded,
                          color: kInk,
                          size: 18,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              GestureDetector(
                onTap: _pickAndUploadPhoto,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.14),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.cloud_upload_rounded, color: accent, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        _photoUrl != null && _photoUrl!.isNotEmpty
                            ? 'Change Photo'
                            : 'Upload Photo',
                        style: GoogleFonts.dmSans(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const Spacer(),
      ],
    );
  }

  Widget _buildLargeInitials(String initials) {
    final accent = _accent;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [accent, kSky],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: GoogleFonts.dmSans(
          color: kInk,
          fontWeight: FontWeight.w900,
          fontSize: 48,
        ),
      ),
    );
  }

  Widget _buildPriceStep() {
    final accent = _accent;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStepHeader(
          title: "Set your\nsession price",
          subtitle: "Select your hourly rate in USD. Drag the slider or type your price.",
        ),
        const Spacer(),
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ShaderMask(
                shaderCallback:
                    (b) => LinearGradient(
                      colors: [Colors.white, accent],
                    ).createShader(b),
                child: Text(
                  '\$$_sessionPrice',
                  style: GoogleFonts.bebasNeue(
                    fontSize: 100,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 4,
                  ),
                ),
              ),
              Text(
                'per hour',
                style: GoogleFonts.dmSans(
                  color: kMuted,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 30),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: accent,
                  inactiveTrackColor: Colors.white.withOpacity(0.10),
                  thumbColor: accent,
                  overlayColor: accent.withOpacity(0.15),
                  trackHeight: 6,
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 14,
                  ),
                ),
                child: Slider(
                  value: _sessionPrice.toDouble().clamp(5, 1000),
                  min: 5,
                  max: 1000,
                  divisions: 995,
                  onChanged: (v) {
                    setState(() {
                      _sessionPrice = v.round();
                      _priceInputController.text = _sessionPrice.toString();
                    });
                  },
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: 200,
                child: LiquidTile(
                  padding: EdgeInsets.zero,
                  child: TextField(
                    controller: _priceInputController,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.dmSans(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                    onChanged: (v) {
                      final n = int.tryParse(v);
                      if (n != null) {
                        setState(() {
                          _sessionPrice = n.clamp(5, 1000);
                        });
                      }
                    },
                    decoration: const InputDecoration(
                      hintText: 'Or type price',
                      hintStyle: TextStyle(color: kMuted),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      prefixIcon: Icon(Icons.attach_money_rounded, color: kMuted, size: 18),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const Spacer(),
      ],
    );
  }

  Widget _buildSpecsStep() {
    final accent = _accent;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStepHeader(
          title: "Select your\nspecialties",
          subtitle: "What fitness disciplines do you focus on?",
        ),
        const SizedBox(height: 24),
        Expanded(
          child: SingleChildScrollView(
            child: Wrap(
              spacing: 10,
              runSpacing: 12,
              children: _specOptions.map((spec) {
                final isSelected = _selectedSpecs.contains(spec);
                return SelectableChip(
                  label: spec,
                  isSelected: isSelected,
                  accentColor: accent,
                  onTap: () {
                    setState(() {
                      if (isSelected) {
                        _selectedSpecs.remove(spec);
                      } else {
                        _selectedSpecs.add(spec);
                      }
                    });
                  },
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBioStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStepHeader(
          title: "Write a short\nprofile bio",
          subtitle: "Describe your experience, approach, and target audience.",
        ),
        const Spacer(),
        LiquidTile(
          padding: EdgeInsets.zero,
          child: TextField(
            controller: _bioController,
            maxLines: 5,
            maxLength: 350,
            style: GoogleFonts.dmSans(
              color: Colors.white,
              fontSize: 15,
            ),
            decoration: const InputDecoration(
              hintText: "E.g., I've been a strength coach for 5 years, helping people build lean muscle and form healthy habits...",
              hintStyle: TextStyle(color: kMuted),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            ),
          ),
        ),
        const Spacer(),
      ],
    );
  }

  Widget _buildLanguagesStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStepHeader(
          title: "Select your\nlanguages",
          subtitle: "What languages can you communicate in?",
        ),
        const SizedBox(height: 24),
        Expanded(
          child: SingleChildScrollView(
            child: Wrap(
              spacing: 10,
              runSpacing: 12,
              children: _languageOptions.map((lang) {
                final isSelected = _selectedLanguages.contains(lang);
                return SelectableChip(
                  label: lang,
                  isSelected: isSelected,
                  accentColor: kLilac,
                  onTap: () {
                    setState(() {
                      if (isSelected) {
                        _selectedLanguages.remove(lang);
                      } else {
                        _selectedLanguages.add(lang);
                      }
                    });
                  },
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLocationsStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStepHeader(
          title: "Where can you\ntrain clients?",
          subtitle: "Select all session locations that apply.",
        ),
        const SizedBox(height: 24),
        Expanded(
          child: SingleChildScrollView(
            child: Wrap(
              spacing: 10,
              runSpacing: 12,
              children: _locationOptions.map((loc) {
                final isSelected = _selectedLocations.contains(loc);
                return SelectableChip(
                  label: loc,
                  isSelected: isSelected,
                  accentColor: kSky,
                  onTap: () {
                    setState(() {
                      if (isSelected) {
                        _selectedLocations.remove(loc);
                      } else {
                        _selectedLocations.add(loc);
                      }
                    });
                  },
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryInitials(String initials) {
    final accent = _accent;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [accent, kSky],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: GoogleFonts.dmSans(
          color: kInk,
          fontWeight: FontWeight.w900,
          fontSize: 28,
        ),
      ),
    );
  }

  Widget _buildSummaryStep() {
    final initials = _getInitials(_nameController.text);
    final accent = _accent;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStepHeader(
          title: "Trainer Profile\nSummary",
          subtitle: "Review your details before going to the Dashboard.",
        ),
        const SizedBox(height: 20),
        Expanded(
          child: ListView(
            physics: const BouncingScrollPhysics(),
            children: [
              LiquidTile(
                radius: 24,
                accent: accent,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Profile Header Row (Avatar + Name + Price)
                    Row(
                      children: [
                        Stack(
                          children: [
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: accent, width: 2),
                                boxShadow: [
                                  BoxShadow(
                                    color: accent.withOpacity(0.15),
                                    blurRadius: 10,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                              child: ClipOval(
                                child: _photoUrl != null && _photoUrl!.isNotEmpty
                                    ? CachedNetworkImage(
                                        imageUrl: _photoUrl!,
                                        fit: BoxFit.cover,
                                        errorWidget: (_, __, ___) => _buildSummaryInitials(initials),
                                      )
                                    : _buildSummaryInitials(initials),
                              ),
                            ),
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: GestureDetector(
                                onTap: () {
                                  _pageController.animateToPage(
                                    2,
                                    duration: const Duration(milliseconds: 300),
                                    curve: Curves.easeInOut,
                                  );
                                },
                                child: Container(
                                  width: 26,
                                  height: 26,
                                  decoration: BoxDecoration(
                                    color: accent,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: kInk,
                                      width: 2,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.camera_alt_rounded,
                                    color: kInk,
                                    size: 13,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _nameController.text,
                                style: GoogleFonts.dmSans(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.verified_user_rounded,
                                    color: kSky,
                                    size: 14,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Professional Trainer',
                                    style: GoogleFonts.dmSans(
                                      color: kSky,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '\$$_sessionPrice / hour',
                                style: GoogleFonts.bebasNeue(
                                  color: accent,
                                  fontSize: 20,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Divider(color: Colors.white12, height: 32),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildSummaryStat("Age", "$_age yrs"),
                        _buildSummaryStat("Height", "${_height}cm"),
                        _buildSummaryStat("Experience", "$_experienceYears yrs"),
                      ],
                    ),
                    const Divider(color: Colors.white12, height: 32),
                    // Bio Section
                    Text('BIO', style: GoogleFonts.dmSans(color: kMuted, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.0)),
                    const SizedBox(height: 6),
                    Text(
                      _bioController.text.isNotEmpty ? _bioController.text : "No bio provided.",
                      style: GoogleFonts.dmSans(
                        color: Colors.white.withOpacity(0.85),
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                    const Divider(color: Colors.white12, height: 32),

                    // Specialties Section
                    Text('SPECIALTIES', style: GoogleFonts.dmSans(color: kMuted, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.0)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: _selectedSpecs.map((spec) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: accent.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: accent.withOpacity(0.24)),
                        ),
                        child: Text(
                          spec,
                          style: GoogleFonts.dmSans(
                            color: accent,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      )).toList(),
                    ),
                    const Divider(color: Colors.white12, height: 32),

                    // Languages Section
                    Text('LANGUAGES', style: GoogleFonts.dmSans(color: kMuted, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.0)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: _selectedLanguages.map((lang) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: kLilac.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: kLilac.withOpacity(0.24)),
                        ),
                        child: Text(
                          lang,
                          style: GoogleFonts.dmSans(
                            color: kLilac,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      )).toList(),
                    ),
                    const Divider(color: Colors.white12, height: 32),

                    // Locations Section
                    Text('TRAINING LOCATIONS', style: GoogleFonts.dmSans(color: kMuted, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.0)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: _selectedLocations.map((loc) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: kSky.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: kSky.withOpacity(0.24)),
                        ),
                        child: Text(
                          loc,
                          style: GoogleFonts.dmSans(
                            color: kSky,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      )).toList(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kInk,
      extendBodyBehindAppBar: true,
      appBar: glassAppBar(
        title: "Trainer Profile Setup",
        onBack: _currentPage > 0 ? _prevPage : null,
      ),
      body: Stack(
        children: [
          Positioned.fill(child: trainerBackground()),
          Positioned(
            top: -120,
            left: -100,
            child: GlowOrb(color: _accent, radius: 240),
          ),
          Positioned(
            bottom: -100,
            right: -100,
            child: const GlowOrb(color: kSky, radius: 220),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                children: [
                  _buildStepIndicator(),
                  const SizedBox(height: 24),
                  Expanded(
                    child: PageView(
                      controller: _pageController,
                      physics: const NeverScrollableScrollPhysics(),
                      onPageChanged: (page) {
                        setState(() {
                          _currentPage = page;
                        });
                      },
                      children: [
                        _buildNameStep(),
                        _buildPersonalDetailsStep(),
                        _buildPhotoStep(),
                        _buildPriceStep(),
                        _buildSpecsStep(),
                        _buildBioStep(),
                        _buildLanguagesStep(),
                        _buildLocationsStep(),
                        _buildSummaryStep(),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_currentPage < _totalPages - 1)
                    neonButton(
                      label: 'Continue',
                      onPressed: _nextPage,
                    )
                  else
                    neonButton(
                      label: _isSaving ? 'Saving Profile...' : 'Complete Setup',
                      onPressed: _isSaving ? () {} : _submitOnboarding,
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: GoogleFonts.dmSans(color: kMuted, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.8),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.dmSans(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

// ── Custom Selectable Chip Widget ───────────────────────────────────────────────
class SelectableChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final Color accentColor;

  const SelectableChip({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.accentColor = kNeon, // default fallback only; callers pass dynamic accent
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? accentColor.withOpacity(0.16) : Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? accentColor.withOpacity(0.8) : Colors.white.withOpacity(0.15),
            width: isSelected ? 1.5 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: accentColor.withOpacity(0.24),
                    blurRadius: 10,
                    spreadRadius: -2,
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSelected) ...[
              Icon(
                Icons.check_circle_rounded,
                size: 16,
                color: accentColor,
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: GoogleFonts.dmSans(
                color: isSelected ? Colors.white : Colors.white70,
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
