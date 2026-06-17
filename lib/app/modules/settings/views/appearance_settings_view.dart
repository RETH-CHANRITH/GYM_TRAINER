import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../config/glass_ui.dart';
import '../../../providers/appearance_provider.dart';

class AppearanceSettingsView extends ConsumerWidget {
  const AppearanceSettingsView({super.key});

  Color _darkBg() => const Color(0xFF0F172A);
  Color _cardBg(BuildContext context) => Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E293B).withOpacity(0.4) : const Color(0xFFFFFFFF).withOpacity(0.7);
  Color _stroke(BuildContext context) => Theme.of(context).brightness == Brightness.dark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.08);
  Color _text(BuildContext context) => Theme.of(context).brightness == Brightness.dark ? Colors.white : const Color(0xFF0F172A);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appearanceState = ref.watch(appearanceProvider);
    final appearanceNotifier = ref.read(appearanceProvider.notifier);

    final activeAccent = appearanceState.accentColor.color(context);
    final activeFontPreset = appearanceState.fontSize;

    return Scaffold(
      backgroundColor: _darkBg(),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(CupertinoIcons.back, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        centerTitle: true,
        title: Text(
          'Appearance & Design',
          style: GoogleFonts.dmSans(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
      ),
      body: Stack(
        children: [
          // Background Gradient & Glow Orbs
          Positioned.fill(
            child: Container(
              color: const Color(0xFF0F172A),
            ),
          ),
          // Dynamic Glowing Orbs
          Positioned(
            top: -100,
            right: -100,
            child: GlowOrb(
              color: activeAccent,
              radius: 200,
            ),
          ),
          Positioned(
            bottom: -50,
            left: -100,
            child: GlowOrb(
              color: activeAccent,
              radius: 180,
            ),
          ),
          // Scrollable Settings Layout
          SafeArea(
            bottom: false,
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              physics: const BouncingScrollPhysics(),
              children: [
                // 1. Live Sandbox Preview Card
                _buildLivePreviewCard(context, activeAccent, activeFontPreset),
                const SizedBox(height: 24),

                // 2. Appearance Options Card (Accent Preset + Dynamic Mode)
                _buildAppearanceCard(context, ref, appearanceState, appearanceNotifier, activeAccent),
                const SizedBox(height: 20),

                // 3. Font Size Slider Card
                _buildFontSliderCard(context, appearanceState, appearanceNotifier, activeAccent),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Real-time Visual Sandbox Preview
  Widget _buildLivePreviewCard(BuildContext context, Color accentColor, FontSizePreset fontPreset) {
    final double textScale = MediaQuery.textScalerOf(context).scale(1.0);
    return LiquidTile(
      radius: 24,
      selected: true,
      accent: accentColor,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'LIVE PREVIEW',
                  style: GoogleFonts.dmSans(
                    color: accentColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  ),
                ),
              ),
              const Spacer(),
              Icon(CupertinoIcons.device_phone_portrait, color: Colors.white70.withOpacity(0.5), size: 16 * textScale),
            ],
          ),
          const SizedBox(height: 16),
          // Mock App Navigation UI
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.35),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.06)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Mock Top Bar
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Preview UI',
                      style: GoogleFonts.dmSans(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Icon(CupertinoIcons.bell_fill, color: accentColor, size: 18 * textScale),
                  ],
                ),
                const SizedBox(height: 12),
                // Mock Subtitle & Body
                Text(
                  'Fintech & Fitness UI',
                  style: GoogleFonts.dmSans(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Feel the responsive typography spacing & custom accent color controls.',
                  style: GoogleFonts.dmSans(
                    color: Colors.white38,
                    fontSize: 11,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 14),
                // Mock Progress Bar
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Weekly Workout Goal',
                          style: GoogleFonts.dmSans(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w600),
                        ),
                        Text(
                          '70%',
                          style: GoogleFonts.dmSans(color: accentColor, fontSize: 10, fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: Container(
                        height: 6,
                        color: Colors.white.withOpacity(0.08),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 7,
                              child: Container(color: accentColor),
                            ),
                            const Expanded(
                              flex: 3,
                              child: SizedBox.shrink(),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                // Mock Button and Switch Row
                Row(
                  children: [
                    // Mock Switch Toggled ON
                    CupertinoSwitch(
                      value: true,
                      onChanged: (v) {},
                      activeColor: accentColor,
                      trackColor: Colors.white.withOpacity(0.12),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        height: 38,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [accentColor, accentColor.withOpacity(0.8)],
                          ),
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: accentColor.withOpacity(0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'Action Button',
                          style: GoogleFonts.dmSans(
                            color: Colors.black87,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
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

  // Appearance Customization Card
  Widget _buildAppearanceCard(
    BuildContext context,
    WidgetRef ref,
    AppearanceState state,
    AppearanceNotifier notifier,
    Color activeAccent,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withOpacity(0.4),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header of Card (Collapsible style matching the image chevron)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: activeAccent.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(CupertinoIcons.paintbrush_fill, color: activeAccent, size: 18),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Accent Color',
                        style: GoogleFonts.dmSans(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        'Choose your favorite color',
                        style: GoogleFonts.dmSans(
                          color: Colors.white38,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  CupertinoIcons.chevron_up,
                  color: Colors.white70.withOpacity(0.4),
                  size: 16,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Presets row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: AccentColorPreset.values.map((preset) {
                final isSelected = state.accentColor == preset && !state.dynamicMode;
                final presetColor = preset.color(context);

                return Expanded(
                  child: GestureDetector(
                    onTap: () => notifier.setAccentColor(preset),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Swatch circle with border decoration
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              width: isSelected ? 42 : 28,
                              height: isSelected ? 42 : 28,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSelected ? presetColor : Colors.transparent,
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  if (isSelected)
                                    BoxShadow(
                                      color: presetColor.withOpacity(0.35),
                                      blurRadius: 8,
                                      spreadRadius: 1,
                                    ),
                                ],
                              ),
                            ),
                            Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: presetColor,
                                border: Border.all(
                                  color: isSelected ? const Color(0xFF0F172A) : Colors.transparent,
                                  width: 2.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          preset.name,
                          style: GoogleFonts.dmSans(
                            color: isSelected ? activeAccent : Colors.white70,
                            fontSize: 11,
                            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),

          // Divider
          Container(
            height: 1,
            color: Colors.white.withOpacity(0.06),
            margin: const EdgeInsets.symmetric(horizontal: 16),
          ),

          // Dynamic Mode Toggle
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(CupertinoIcons.device_desktop, color: Colors.white70.withOpacity(0.6), size: 17),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Dynamic Wallpaper Mode',
                        style: GoogleFonts.dmSans(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 13.5,
                        ),
                      ),
                      Text(
                        'Adapt color key to device theme & system default',
                        style: GoogleFonts.dmSans(
                          color: Colors.white38,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                CupertinoSwitch(
                  value: state.dynamicMode,
                  onChanged: (val) => notifier.setDynamicMode(val),
                  activeColor: activeAccent,
                  trackColor: Colors.white.withOpacity(0.08),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Font Size customization Card
  Widget _buildFontSliderCard(
    BuildContext context,
    AppearanceState state,
    AppearanceNotifier notifier,
    Color activeAccent,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withOpacity(0.4),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: activeAccent.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(CupertinoIcons.textformat_size, color: activeAccent, size: 18),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Font Size',
                      style: GoogleFonts.dmSans(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      'Adjust app font size',
                      style: GoogleFonts.dmSans(
                        color: Colors.white38,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                state.fontSize.name,
                style: GoogleFonts.dmSans(
                  color: activeAccent,
                  fontWeight: FontWeight.w700,
                  fontSize: 13.5,
                ),
              ),
              const SizedBox(width: 6),
              Icon(CupertinoIcons.chevron_right, color: Colors.white38.withOpacity(0.4), size: 15),
            ],
          ),
          const SizedBox(height: 20),

          // Font Scale Slider
          SliderTheme(
            data: SliderThemeData(
              trackHeight: 4,
              activeTrackColor: activeAccent,
              inactiveTrackColor: Colors.white.withOpacity(0.08),
              thumbColor: Colors.white,
              overlayColor: activeAccent.withOpacity(0.12),
              valueIndicatorColor: activeAccent,
              valueIndicatorTextStyle: GoogleFonts.dmSans(color: Colors.black, fontWeight: FontWeight.bold),
              showValueIndicator: ShowValueIndicator.always,
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10, pressedElevation: 6),
            ),
            child: Slider(
              value: FontSizePreset.values.indexOf(state.fontSize).toDouble(),
              min: 0,
              max: (FontSizePreset.values.length - 1).toDouble(),
              divisions: FontSizePreset.values.length - 1,
              onChanged: (val) {
                final preset = FontSizePreset.values[val.toInt()];
                notifier.setFontSize(preset);
              },
            ),
          ),

          // Labels under the slider
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: FontSizePreset.values.map((preset) {
                final isSelected = state.fontSize == preset;
                return Text(
                  preset.name.split(' ').first, // just first word (e.g. Extra)
                  style: GoogleFonts.dmSans(
                    color: isSelected ? activeAccent : Colors.white38,
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
