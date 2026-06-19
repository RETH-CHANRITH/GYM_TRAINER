import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app/routes/app_router.dart';
import 'app/providers/global_providers.dart';
import 'app/providers/rx_compat.dart';
import 'package:flutter/cupertino.dart';
import 'app/modules/notifications/controllers/notifications_controller.dart';
import 'app/widgets/global_notif_banner.dart';
import 'app/services/notification_service.dart';
import 'app/providers/theme_provider.dart';
import 'app/providers/appearance_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase with error handling and retry for iOS
  bool firebaseInitialized = false;
  int retryCount = 0;
  while (!firebaseInitialized && retryCount < 3) {
    try {
      await Firebase.initializeApp();
      firebaseInitialized = true;
      debugPrint('✅ Firebase initialized successfully');
    } catch (e) {
      retryCount++;
      debugPrint('⚠️ Firebase init attempt $retryCount failed: $e');
      if (retryCount < 3) {
        await Future.delayed(const Duration(milliseconds: 500));
      }
    }
  }

  if (!firebaseInitialized) {
    debugPrint('❌ Firebase initialization failed after 3 attempts');
  }

  try {
    await Supabase.initialize(
      url: 'https://wrnimhuovvyhysiufffd.supabase.co',
      anonKey:
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6IndybmltaHVvdnZ5aHlzaXVmZmZkIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzMzNjQ5MDAsImV4cCI6MjA4ODk0MDkwMH0.e475CUbWI2J6avGJWQsm2oG6QhRLXCRL5eHXbbQD_DU',
    );
    debugPrint('✅ Supabase initialized successfully');
  } catch (e) {
    debugPrint('⚠️ Supabase initialization error: $e');
  }



  // Initialize native device notification service
  await NotificationService.instance.initialize();

  // Set preferred orientations
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Set system UI overlay style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF1E1C26),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

final newNotificationStreamProvider = StreamProvider.autoDispose<NewNotificationEvent>((ref) {
  final notifier = ref.watch(notificationsNotifierProvider.notifier);
  return notifier.newNotificationStream;
});



// Class MyApp definition follows below:
class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  static OverlayEntry? _globalAlertEntry;

  static void _showGlobalNotifBanner(BuildContext context, NewNotificationEvent event) {
    _globalAlertEntry?.remove();
    _globalAlertEntry = null;

    final Color accent = event.colorKey == 'coral' || event.colorKey == 'like'
        ? const Color(0xFFFF5C5C)
        : event.colorKey == 'sky' || event.colorKey == 'booking'
            ? const Color(0xFF5CE8FF)
            : event.colorKey == 'gold' || event.colorKey == 'payment'
                ? const Color(0xFFFFBB33)
                : const Color(0xFFA78BFA);

    final IconData icon = event.iconKey == 'calendar' || event.iconKey == 'booking'
        ? CupertinoIcons.calendar
        : event.iconKey == 'chat' || event.iconKey == 'comment'
            ? CupertinoIcons.chat_bubble_fill
            : event.iconKey == 'payment'
                ? CupertinoIcons.creditcard_fill
                : CupertinoIcons.bell_fill;

    _globalAlertEntry = OverlayEntry(
      builder: (ctx) => GlobalNotifBanner(
        title: event.title,
        body: event.body,
        accent: accent,
        icon: icon,
        senderPhotoUrl: event.senderPhotoUrl,
        onDismiss: () {
          _globalAlertEntry?.remove();
          _globalAlertEntry = null;
        },
        onTap: () {
          _globalAlertEntry?.remove();
          _globalAlertEntry = null;
          NotificationService.instance.navigateFromPayload(event.routePayload);
        },
      ),
    );

    final overlay = rootNavigatorKey.currentState?.overlay;
    if (overlay != null) {
      overlay.insert(_globalAlertEntry!);
    }
  }

  static void _showTrainerApprovedDialog(BuildContext context, WidgetRef ref) {
    final router = ref.read(routerProvider);
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1A0F2E), Color(0xFF0D1B3E)],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: const Color(0xFFCBFF47).withOpacity(0.35),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFCBFF47).withOpacity(0.15),
                blurRadius: 40,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Trophy icon with glow
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: const Color(0xFFCBFF47).withOpacity(0.12),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFCBFF47).withOpacity(0.3),
                      blurRadius: 24,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.workspace_premium_rounded,
                  color: Color(0xFFCBFF47),
                  size: 36,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                '🎉 Congratulations!',
                textAlign: TextAlign.center,
                style: GoogleFonts.dmSans(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 22,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Your trainer application has been approved! Sign in again to start your trainer journey.',
                textAlign: TextAlign.center,
                style: GoogleFonts.dmSans(
                  color: Colors.white.withOpacity(0.75),
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    Navigator.of(dialogCtx).pop();
                    await FirebaseAuth.instance.signOut();
                    router.go(Routes.LOGIN);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFCBFF47),
                    foregroundColor: const Color(0xFF0A0A0F),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    'Sign In as Trainer',
                    style: GoogleFonts.dmSans(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeProvider);
    final appearance = ref.watch(appearanceProvider);

    // Listen to new notifications globally at root
    ref.listen<AsyncValue<NewNotificationEvent>>(newNotificationStreamProvider, (prev, next) {
      next.whenData((event) {
        _showGlobalNotifBanner(context, event);
      });
    });

    // ── Trainer approval listener ─────────────────────────────────────────────
    // When the admin approves a pending trainer application, detect the
    // pending → approved transition and force a re-login so the user
    // comes back through the trainer onboarding flow.
    ref.listen<AsyncValue<Map<String, dynamic>?>>(userTrainerApplicationProvider, (prev, next) {
      final prevStatus = prev?.asData?.value?['status']?.toString().toLowerCase();
      final nextStatus = next.asData?.value?['status']?.toString().toLowerCase();
      if (prevStatus == 'pending' && nextStatus == 'approved') {
        _showTrainerApprovedDialog(context, ref);
      }
    });

    return MaterialApp.router(
      scaffoldMessengerKey: scaffoldMessengerKey,
      routerConfig: router,
      title: 'Gym Trainer',
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFF9F9FC),
        fontFamily: GoogleFonts.poppins().fontFamily,
        textTheme: GoogleFonts.poppinsTextTheme(ThemeData(brightness: Brightness.light).textTheme),
        colorScheme: ColorScheme.light(
          primary: appearance.accentColor.lightColor,
          secondary: const Color(0xFF8C9B0F),
          surface: const Color(0xFFFFFFFF),
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF121217),
        fontFamily: GoogleFonts.poppins().fontFamily,
        textTheme: GoogleFonts.poppinsTextTheme(ThemeData(brightness: Brightness.dark).textTheme),
        colorScheme: ColorScheme.dark(
          primary: appearance.accentColor.darkColor,
          secondary: const Color(0xFFE2F163),
          surface: const Color(0xFF1E1C26),
        ),
      ),
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(appearance.fontSize.scaleFactor),
          ),
          child: child!,
        );
      },
    );
  }
}
