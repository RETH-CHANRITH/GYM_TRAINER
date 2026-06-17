import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';

// ── Shared glass design tokens ─────────────────────────────────────────────────
const Color kInk = Color(0xFF07010E);
const Color kNeon = Color(0xFFC8FF33);
const Color kSky = Color(0xFF38C9FF);
const Color kCoral = Color(0xFFFF4F4F);
const Color kLilac = Color(0xFFAB7EFF);
const Color kPink = Color(0xFFFF55E8);
const Color kMuted = Color(0xFF8484A0);
const double kGlassBlurSigma = 14;
const double kAppBarBlurSigma = 16;

// ── Rich gradient background ───────────────────────────────────────────────────
/// Place as Positioned.fill at the bottom of every screen Stack.
Widget liquidBackground([BuildContext? context]) {
  final isDark = context == null ? true : Theme.of(context).brightness == Brightness.dark;
  if (isDark) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A0330), Color(0xFF03071C), Color(0xFF011525)],
          stops: [0.0, 0.5, 1.0],
        ),
      ),
    );
  } else {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFEDE9FE), Color(0xFFF3F4F6), Color(0xFFE0E7FF)],
          stops: [0.0, 0.5, 1.0],
        ),
      ),
    );
  }
}

/// Trainer background (simpler/darker, no glow orbs).
/// Place as Positioned.fill at the bottom of trainer screens.
Widget trainerBackground([BuildContext? context]) {
  final isDark = context == null ? true : Theme.of(context).brightness == Brightness.dark;
  if (isDark) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [kInk, Color.lerp(kInk, kMuted, 0.18) ?? kInk, kInk],
          stops: const [0.0, 0.55, 1.0],
        ),
      ),
    );
  } else {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFF3F4F6), Color(0xFFE5E7EB), Color(0xFFF3F4F6)],
          stops: [0.0, 0.55, 1.0],
        ),
      ),
    );
  }
}

// ── Glow orb ──────────────────────────────────────────────────────────────────
class GlowOrb extends StatelessWidget {
  final Color color;
  final double radius;
  const GlowOrb({super.key, required this.color, required this.radius});
  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: const Duration(milliseconds: 500),
    curve: Curves.easeInOut,
    width: radius * 2,
    height: radius * 2,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: RadialGradient(
        colors: [
          color.withOpacity(0.65),
          color.withOpacity(0.25),
          Colors.transparent,
        ],
        stops: const [0.0, 0.45, 1.0],
        radius: 0.65,
      ),
    ),
  );
}

// ── Grid painter ──────────────────────────────────────────────────────────────
class AppGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {}
  @override
  bool shouldRepaint(AppGridPainter _) => false;
}

// ── Liquid glass decoration ────────────────────────────────────────────────────
BoxDecoration glassDecoration({
  double radius = 20,
  bool selected = false,
  Color? accent,
  Color? glowColor,
  BuildContext? context,
}) {
  final isDark = context == null ? true : Theme.of(context).brightness == Brightness.dark;
  final resolvedAccent = accent ?? (context != null ? Theme.of(context).colorScheme.primary : kNeon);
  final glow = glowColor ?? resolvedAccent;

  if (isDark) {
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors:
            selected
                ? [resolvedAccent.withOpacity(0.42), resolvedAccent.withOpacity(0.10)]
                : [
                  Colors.white.withOpacity(0.18),
                  Colors.white.withOpacity(0.04),
                ],
      ),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color:
            selected ? resolvedAccent.withOpacity(0.85) : Colors.white.withOpacity(0.32),
        width: selected ? 1.5 : 1.0,
      ),
      boxShadow: [
        if (selected)
          BoxShadow(
            color: glow.withOpacity(0.40),
            blurRadius: 20,
            spreadRadius: -4,
          ),
        BoxShadow(
          color: Colors.black.withOpacity(0.30),
          blurRadius: 14,
          offset: const Offset(0, 6),
        ),
      ],
    );
  } else {
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors:
            selected
                ? [resolvedAccent.withOpacity(0.25), resolvedAccent.withOpacity(0.05)]
                : [
                  Colors.white.withOpacity(0.85),
                  Colors.white.withOpacity(0.45),
                ],
      ),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color:
            selected ? resolvedAccent.withOpacity(0.70) : Colors.black.withOpacity(0.08),
        width: selected ? 1.5 : 1.0,
      ),
      boxShadow: [
        if (selected)
          BoxShadow(
            color: glow.withOpacity(0.25),
            blurRadius: 20,
            spreadRadius: -4,
          ),
        BoxShadow(
          color: Colors.black.withOpacity(0.06),
          blurRadius: 14,
          offset: const Offset(0, 6),
        ),
      ],
    );
  }
}

// ── Liquid tile widget (blur + glass decoration all-in-one) ───────────────────
class LiquidTile extends StatelessWidget {
  final Widget child;
  final bool selected;
  final Color? accent;
  final double radius;
  final EdgeInsetsGeometry padding;

  const LiquidTile({
    super.key,
    required this.child,
    this.selected = false,
    this.accent,
    this.radius = 20,
    this.padding = const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
  });

  @override
  Widget build(BuildContext context) {
    final activeAccent = accent ?? Theme.of(context).colorScheme.primary;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: kGlassBlurSigma,
          sigmaY: kGlassBlurSigma,
        ),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeInOut,
          padding: padding,
          decoration: glassDecoration(
            selected: selected,
            accent: activeAccent,
            radius: radius,
            context: context,
          ),
          child: child,
        ),
      ),
    );
  }
}

// ── Glass text field decoration ───────────────────────────────────────────────
InputDecoration glassFieldDecoration({
  required String hint,
  IconData? icon,
  Color? accent,
  BuildContext? context,
}) {
  final isDark = context == null ? true : Theme.of(context).brightness == Brightness.dark;
  final resolvedAccent = accent ?? (context != null ? Theme.of(context).colorScheme.primary : kNeon);
  return InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(color: isDark ? kMuted : Colors.black45, fontSize: 14),
    prefixIcon: icon != null ? Icon(icon, color: isDark ? kMuted : Colors.black45, size: 20) : null,
    filled: true,
    fillColor: isDark ? Colors.white.withOpacity(0.09) : Colors.black.withOpacity(0.04),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: isDark ? Colors.white.withOpacity(0.30) : Colors.black.withOpacity(0.12)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: isDark ? Colors.white.withOpacity(0.30) : Colors.black.withOpacity(0.12)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: resolvedAccent, width: 2),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
  );
}

// ── Liquid pill CTA button ─────────────────────────────────────────────────────
Widget neonButton({
  required String label,
  required VoidCallback onPressed,
  Widget? child,
  Color? accent,
}) {
  return SizedBox(
    width: double.infinity,
    height: 56,
    child: Builder(
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final resolvedAccent = accent ?? Theme.of(context).colorScheme.primary;
        
        // Dynamically choose highly visible contrast text color based on accent brightness
        final useWhiteText = ThemeData.estimateBrightnessForColor(resolvedAccent) == Brightness.dark;
        final textColor = useWhiteText ? Colors.white : Colors.black87;

        return DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [resolvedAccent, Color.alphaBlend(Colors.white38, resolvedAccent)],
            ),
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: isDark ? resolvedAccent.withOpacity(0.50) : resolvedAccent.withOpacity(0.20),
                blurRadius: isDark ? 20 : 12,
                offset: isDark ? const Offset(0, 8) : const Offset(0, 4),
              ),
              if (isDark)
                BoxShadow(
                  color: resolvedAccent.withOpacity(0.20),
                  blurRadius: 28,
                  spreadRadius: 1,
                ),
            ],
          ),
          child: ElevatedButton(
            onPressed: onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
            ),
            child:
                child ??
                Text(
                  label,
                  style: GoogleFonts.dmSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
          ),
        );
      },
    ),
  );
}

// ── Liquid glass AppBar ───────────────────────────────────────────────────────
PreferredSizeWidget glassAppBar({
  required String title,
  VoidCallback? onBack,
  BuildContext? context,
}) {
  final isDark = context == null ? true : Theme.of(context).brightness == Brightness.dark;
  final textColor = isDark ? Colors.white : Colors.black87;
  final iconColor = isDark ? Colors.white : Colors.black87;
  final bgColors = isDark
      ? [Colors.white.withOpacity(0.14), Colors.white.withOpacity(0.03)]
      : [Colors.black.withOpacity(0.05), Colors.black.withOpacity(0.01)];
  final borderColor = isDark ? Colors.white.withOpacity(0.15) : Colors.black.withOpacity(0.08);

  return PreferredSize(
    preferredSize: const Size.fromHeight(64),
    child: ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: kAppBarBlurSigma,
          sigmaY: kAppBarBlurSigma,
        ),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: bgColors,
            ),
            border: Border(
              bottom: BorderSide(
                color: borderColor,
                width: 0.5,
              ),
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  if (onBack != null)
                    GestureDetector(
                      onTap: onBack,
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isDark ? Colors.white.withOpacity(0.12) : Colors.black.withOpacity(0.05),
                          border: Border.all(
                            color: isDark ? Colors.white.withOpacity(0.22) : Colors.black.withOpacity(0.10),
                          ),
                        ),
                        child: Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: iconColor,
                          size: 17,
                        ),
                      ),
                    ),
                  Expanded(
                    child: Text(
                      title,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.dmSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                  ),
                  if (onBack != null) const SizedBox(width: 38),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

// ── Initials Avatar widget (premium fallback) ──────────────────────────────────
class InitialsAvatar extends StatelessWidget {
  final String name;
  final double size;
  final double fontSize;
  final double borderRadius;

  const InitialsAvatar({
    super.key,
    required this.name,
    required this.size,
    this.fontSize = 16,
    this.borderRadius = 12,
  });

  @override
  Widget build(BuildContext context) {
    final initials = _getInitials(name);
    final hash = name.hashCode.abs();
    final gradients = [
      [const Color(0xFF896CFE), const Color(0xFF5CE8FF)], // Purple to Sky
      [const Color(0xFFFF5C5C), const Color(0xFFF59E0B)], // Coral to Orange
      [const Color(0xFF10B981), const Color(0xFF3B82F6)], // Emerald to Blue
      [const Color(0xFFEC4899), const Color(0xFF8B5CF6)], // Pink to Violet
    ];
    final selectedGradient = gradients[hash % gradients.length];

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: selectedGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: GoogleFonts.dmSans(
          color: Colors.white,
          fontSize: fontSize,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
        ),
      ),
    );
  }

  String _getInitials(String name) {
    if (name.isEmpty) return '?';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      final first = parts[0].isNotEmpty ? parts[0][0] : '';
      final second = parts[1].isNotEmpty ? parts[1][0] : '';
      return (first + second).toUpperCase();
    }
    return parts[0].isNotEmpty ? parts[0][0].toUpperCase() : '?';
  }
}

// ── Realistic fallback portrait generator ─────────────────────────────────────
String getTrainerFallbackImageUrl(String name) {
  final nameLower = name.toLowerCase();
  String gender = 'men';
  if (nameLower.contains('kaiya') ||
      nameLower.contains('kaya') ||
      nameLower.contains('lisa') ||
      nameLower.contains('sara') ||
      nameLower.contains('anna') ||
      nameLower.contains('maria') ||
      nameLower.contains('emma') ||
      nameLower.contains('sofia') ||
      nameLower.contains('julia') ||
      nameLower.contains('lucy') ||
      nameLower.contains('charlotte') ||
      nameLower.contains('popy') ||
      nameLower.contains('rose')) {
    gender = 'women';
  }
  final int portraitIdx = name.isNotEmpty ? (name.hashCode.abs() % 90 + 10) : 10;
  return 'https://randomuser.me/api/portraits/$gender/$portraitIdx.jpg';
}

// ── Premium avatar wrapper with realistic fallback support ────────────────────
class PremiumAvatar extends StatelessWidget {
  final String name;
  final String? customPhotoUrl;
  final double size;
  final double? borderRadius;
  final double? fontSize;
  final bool isTrainer;

  const PremiumAvatar({
    super.key,
    required this.name,
    this.customPhotoUrl,
    required this.size,
    this.borderRadius,
    this.fontSize,
    this.isTrainer = true,
  });

  @override
  Widget build(BuildContext context) {
    final double br = borderRadius ?? 12;
    final double fs = fontSize ?? (size * 0.38);

    if (customPhotoUrl != null && customPhotoUrl!.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: customPhotoUrl!,
        width: size,
        height: size,
        fit: BoxFit.cover,
        placeholder: (context, url) => InitialsAvatar(
          name: name,
          size: size,
          fontSize: fs,
          borderRadius: br,
        ),
        errorWidget: (context, url, error) => InitialsAvatar(
          name: name,
          size: size,
          fontSize: fs,
          borderRadius: br,
        ),
      );
    }

    if (isTrainer) {
      final fallbackUrl = getTrainerFallbackImageUrl(name);
      return CachedNetworkImage(
        imageUrl: fallbackUrl,
        width: size,
        height: size,
        fit: BoxFit.cover,
        placeholder: (context, url) => InitialsAvatar(
          name: name,
          size: size,
          fontSize: fs,
          borderRadius: br,
        ),
        errorWidget: (context, url, error) => InitialsAvatar(
          name: name,
          size: size,
          fontSize: fs,
          borderRadius: br,
        ),
      );
    }

    return InitialsAvatar(
      name: name,
      size: size,
      fontSize: fs,
      borderRadius: br,
    );
  }
}

