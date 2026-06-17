import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';

class GlobalNotifBanner extends StatefulWidget {
  final String title;
  final String body;
  final Color accent;
  final IconData icon;
  final String senderPhotoUrl;
  final VoidCallback onDismiss;
  final VoidCallback onTap;

  const GlobalNotifBanner({
    super.key,
    required this.title,
    required this.body,
    required this.accent,
    required this.icon,
    required this.senderPhotoUrl,
    required this.onDismiss,
    required this.onTap,
  });

  @override
  State<GlobalNotifBanner> createState() => _GlobalNotifBannerState();
}

class _GlobalNotifBannerState extends State<GlobalNotifBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<Offset> _slide;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _slide = Tween<Offset>(
      begin: const Offset(0, -1.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);

    _ctrl.forward();

    // Auto-dismiss after 4 seconds
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) _dismiss();
    });
  }

  void _dismiss() {
    _ctrl.reverse().then((_) {
      if (mounted) widget.onDismiss();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).viewPadding.top + 12;
    return Positioned(
      top: top,
      left: 16,
      right: 16,
      child: SlideTransition(
        position: _slide,
        child: FadeTransition(
          opacity: _fade,
          child: GestureDetector(
            onTap: widget.onTap,
            onVerticalDragUpdate: (d) {
              if (d.primaryDelta != null && d.primaryDelta! < -4) _dismiss();
            },
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A24),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: widget.accent.withValues(alpha: 0.35)),
                  boxShadow: [
                    BoxShadow(
                      color: widget.accent.withValues(alpha: 0.18),
                      blurRadius: 24,
                      offset: const Offset(0, 6),
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.5),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    if (widget.senderPhotoUrl.isNotEmpty)
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: widget.accent.withValues(alpha: 0.35), width: 1.5),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10.5),
                          child: CachedNetworkImage(
                            imageUrl: widget.senderPhotoUrl,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => Container(
                              color: widget.accent.withValues(alpha: 0.15),
                              child: Icon(widget.icon, color: widget.accent, size: 22),
                            ),
                          ),
                        ),
                      )
                    else
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: widget.accent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: widget.accent.withValues(alpha: 0.3)),
                        ),
                        child: Icon(widget.icon, color: widget.accent, size: 22),
                      ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.title,
                            style: GoogleFonts.dmSans(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (widget.body.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              widget.body,
                              style: GoogleFonts.dmSans(
                                color: const Color(0xFF9090A0),
                                fontSize: 12,
                                height: 1.4,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _dismiss,
                      child: const Icon(
                        CupertinoIcons.xmark,
                        color: Color(0xFF6B6B7E),
                        size: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
