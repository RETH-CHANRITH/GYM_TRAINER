import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../config/glass_ui.dart';
import '../../../providers/global_providers.dart';

class TrainerApplicationFormView extends ConsumerStatefulWidget {
  const TrainerApplicationFormView({super.key});

  @override
  ConsumerState<TrainerApplicationFormView> createState() => _TrainerApplicationFormViewState();
}

class _TrainerApplicationFormViewState extends ConsumerState<TrainerApplicationFormView> {
  final _formKey = GlobalKey<FormState>();
  final _bioController = TextEditingController();
  final _certsController = TextEditingController();

  final Set<String> _selectedSpecs = {};
  int _yearsOfExperience = 3;
  double _hourlyRate = 40.0;
  bool _isSubmitting = false;

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

  @override
  void dispose() {
    _bioController.dispose();
    _certsController.dispose();
    super.dispose();
  }

  Future<void> _submitApplication() async {
    if (_selectedSpecs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one specialty'),
          backgroundColor: Color(0xFFFF5C5C),
        ),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not logged in');

      final profile = ref.read(userProfileServiceProvider);

      final appData = {
        'userId': user.uid,
        'fullName': profile.name,
        'email': profile.email,
        'photoUrl': profile.photoUrl,
        'specialty': _selectedSpecs.join(', '),
        'yearsOfExperience': _yearsOfExperience.toString(),
        'hourlyRate': _hourlyRate,
        'certifications': _certsController.text.trim(),
        'bio': _bioController.text.trim(),
        'status': 'pending',
        'submittedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // Create a document using the user's UID to enforce single-application constraint
      await FirebaseFirestore.instance
          .collection('trainerApplications')
          .doc(user.uid)
          .set(appData, SetOptions(merge: true));

      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            backgroundColor: const Color(0xFF1E0735),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text(
              'Application Submitted',
              style: GoogleFonts.dmSans(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            content: Text(
              'Your trainer application has been submitted successfully! The admin team will review it shortly.',
              style: GoogleFonts.dmSans(color: Colors.white.withOpacity(0.85)),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context); // Pop dialog
                  context.pop(); // Pop application screen
                },
                child: Text(
                  'OK',
                  style: GoogleFonts.dmSans(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit application: $e'),
            backgroundColor: const Color(0xFFFF5C5C),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: kInk,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        centerTitle: true,
        title: Text(
          'Register as Trainer',
          style: GoogleFonts.dmSans(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
      body: Stack(
        children: [
          Positioned.fill(child: trainerBackground()),
          Positioned(
            top: -120,
            left: -100,
            child: GlowOrb(color: accent, radius: 240),
          ),
          Positioned(
            bottom: -100,
            right: -100,
            child: const GlowOrb(color: kSky, radius: 220),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              physics: const BouncingScrollPhysics(),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Intro card
                    LiquidTile(
                      radius: 16,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: accent.withOpacity(0.12),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.star_rounded, color: accent, size: 24),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Join Our Trainer Network',
                                    style: GoogleFonts.dmSans(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    'Share your expertise, set your own rates, and connect with clients nearby.',
                                    style: GoogleFonts.dmSans(
                                      color: kMuted,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Specialty section
                    _buildSectionHeader('Select Your Specialties'),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _specOptions.map((spec) {
                        final isSelected = _selectedSpecs.contains(spec);
                        return ChoiceChip(
                          label: Text(spec),
                          selected: isSelected,
                          onSelected: (val) {
                            setState(() {
                              if (val) {
                                _selectedSpecs.add(spec);
                              } else {
                                _selectedSpecs.remove(spec);
                              }
                            });
                          },
                          backgroundColor: Colors.white.withOpacity(0.04),
                          selectedColor: accent.withOpacity(0.16),
                          labelStyle: GoogleFonts.dmSans(
                            color: isSelected ? Colors.white : Colors.white70,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            fontSize: 13,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: isSelected ? accent.withOpacity(0.7) : Colors.white.withOpacity(0.12),
                              width: isSelected ? 1.5 : 1.0,
                            ),
                          ),
                          showCheckmark: false,
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),

                    // Slider section: Experience
                    _buildSectionHeader('Years of Coaching Experience: $_yearsOfExperience yrs'),
                    const SizedBox(height: 8),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: accent,
                        inactiveTrackColor: Colors.white.withOpacity(0.1),
                        thumbColor: accent,
                        overlayColor: accent.withOpacity(0.15),
                        trackHeight: 4,
                      ),
                      child: Slider(
                        value: _yearsOfExperience.toDouble(),
                        min: 0,
                        max: 30,
                        divisions: 30,
                        onChanged: (val) {
                          setState(() {
                            _yearsOfExperience = val.round();
                          });
                        },
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Slider section: Hourly Rate
                    _buildSectionHeader('Proposed Hourly Rate: \$${_hourlyRate.round()}/hr'),
                    const SizedBox(height: 8),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: kSky,
                        inactiveTrackColor: Colors.white.withOpacity(0.1),
                        thumbColor: kSky,
                        overlayColor: kSky.withOpacity(0.15),
                        trackHeight: 4,
                      ),
                      child: Slider(
                        value: _hourlyRate,
                        min: 10,
                        max: 250,
                        divisions: 48,
                        onChanged: (val) {
                          setState(() {
                            _hourlyRate = val;
                          });
                        },
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Bio text field
                    _buildSectionHeader('About/Bio'),
                    const SizedBox(height: 10),
                    LiquidTile(
                      padding: EdgeInsets.zero,
                      child: TextFormField(
                        controller: _bioController,
                        maxLines: 4,
                        maxLength: 350,
                        style: GoogleFonts.dmSans(color: Colors.white, fontSize: 14),
                        decoration: const InputDecoration(
                          hintText: 'Describe your training philosophy, experience, and what clients can expect...',
                          hintStyle: TextStyle(color: kMuted),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.all(16),
                          counterStyle: TextStyle(color: kMuted, fontSize: 10),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Please tell us a bit about yourself';
                          }
                          if (val.trim().length < 20) {
                            return 'Bio must be at least 20 characters long';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Certifications text field
                    _buildSectionHeader('Certifications & Credentials'),
                    const SizedBox(height: 10),
                    LiquidTile(
                      padding: EdgeInsets.zero,
                      child: TextFormField(
                        controller: _certsController,
                        maxLines: 3,
                        style: GoogleFonts.dmSans(color: Colors.white, fontSize: 14),
                        decoration: const InputDecoration(
                          hintText: 'List your training certifications (e.g., NASM, ACE, CrossFit L1, CPR/AED)...',
                          hintStyle: TextStyle(color: kMuted),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.all(16),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Please enter your professional certifications';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(height: 36),

                    // Submit button
                    SizedBox(
                      width: double.infinity,
                      child: neonButton(
                        label: _isSubmitting ? 'Submitting Application...' : 'Submit Application',
                        onPressed: _isSubmitting ? () {} : _submitApplication,
                      ),
                    ),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: GoogleFonts.dmSans(
        fontSize: 14,
        fontWeight: FontWeight.bold,
        color: Colors.white,
        letterSpacing: 0.2,
      ),
    );
  }
}
