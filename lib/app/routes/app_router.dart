import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../modules/splash/views/splash_view.dart';
import '../modules/onboarding/views/onboarding_view.dart';
import '../modules/favorite/views/favorite_view.dart';
import '../modules/home/views/home_view.dart';
import '../modules/login/views/login_view.dart';
import '../modules/forgot_password/views/forgot_password_view.dart';
import '../modules/message_screen/views/message_screen_view.dart';
import '../modules/profile/views/profile_screen.dart';
import '../modules/sign_up/views/sign_up_view.dart';
import '../modules/trainer/views/trainer_details_view.dart';
import '../modules/wallet/views/wallet_screen.dart';
import '../modules/welcome/views/welcome_view.dart';
import '../modules/get_started/views/get_started_view.dart';
import '../modules/gender_selection/views/gender_selection_view.dart';
import '../modules/age_input/views/age_input_view.dart';
import '../modules/weight_input/views/weight_input_view.dart';
import '../modules/height_input/views/height_input_view.dart';
import '../modules/fitness_goal/views/fitness_goal_view.dart';
import '../modules/activity_level/views/activity_level_view.dart';
import '../modules/fitness_level/views/fitness_level_view.dart';
import '../modules/notification_permission/views/notification_permission_view.dart';
import '../modules/profile_summary/views/profile_summary_view.dart';
import '../modules/book_session/views/book_session_view.dart';
import '../modules/my_bookings/views/my_bookings_view.dart';
import '../modules/home/views/all_sessions_view.dart';
import '../modules/home/views/all_feeds_view.dart';
import '../modules/search/views/search_view.dart';
import '../modules/settings/views/settings_view.dart';
import '../modules/settings/views/appearance_settings_view.dart';
import '../modules/notifications/views/notifications_view.dart';
import '../modules/wallet/views/transaction_history_screen.dart';
import '../modules/trainer_dashboard/views/trainer_dashboard_view.dart';
import '../modules/trainer_availability/views/trainer_availability_view.dart';
import '../modules/admin_dashboard/views/admin_dashboard_view.dart';
import '../modules/streak_details/views/streak_details_view.dart';
import '../modules/goals_details/views/goals_details_view.dart';
import '../modules/trainer_onboarding/views/trainer_onboarding_view.dart';
import '../modules/settings/views/trainer_application_form_view.dart';

abstract class Routes {
  static const SPLASH = '/splash';
  static const ONBOARDING = '/onboarding';
  static const HOME = '/home';
  static const FAVORITE = '/favorite';
  static const FAVOURITE = '/favourite';
  static const ALL_FEEDS = '/all-feeds';
  static const WALLET = '/wallet';
  static const PROFILE = '/profile';
  static const TRAINER_DETAILS = '/trainer-details';
  static const MESSAGE_SCREEN = '/message-screen';
  static const LOGIN = '/login';
  static const FORGOT_PASSWORD = '/forgot-password';
  static const SIGN_UP = '/sign-up';
  static const WELCOME = '/welcome';
  static const GET_STARTED = '/get-started';
  static const GENDER_SELECTION = '/gender-selection';
  static const AGE_INPUT = '/age-input';
  static const WEIGHT_INPUT = '/weight-input';
  static const HEIGHT_INPUT = '/height-input';
  static const FITNESS_GOAL = '/fitness-goal';
  static const ACTIVITY_LEVEL = '/activity-level';
  static const FITNESS_LEVEL = '/fitness-level';
  static const NOTIFICATION_PERMISSION = '/notification-permission';
  static const PROFILE_SUMMARY = '/profile-summary';
  static const BOOK_SESSION = '/book-session';
  static const MY_BOOKINGS = '/my-bookings';
  static const ALL_SESSIONS = '/all-sessions';
  static const SEARCH = '/search';
  static const SETTINGS = '/settings';
  static const APPEARANCE = '/settings/appearance';
  static const NOTIFICATIONS = '/notifications';
  static const TX_HISTORY = '/tx-history';
  static const TRAINER_DASHBOARD = '/trainer-dashboard';
  static const TRAINER_AVAILABILITY = '/trainer-availability';
  static const TRAINER_ONBOARDING = '/trainer-onboarding';
  static const TRAINER_APPLICATION = '/trainer-application';
  static const ADMIN_DASHBOARD = '/admin-dashboard';
  static const STREAK_DETAILS = '/streak-details';
  static const GOALS_DETAILS = '/goals-details';
}

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: Routes.SPLASH,
    routes: [
      GoRoute(
        path: Routes.SPLASH,
        builder: (context, state) => const SplashView(),
      ),
      GoRoute(
        path: Routes.ONBOARDING,
        builder: (context, state) => const OnboardingView(),
      ),
      GoRoute(
        path: Routes.HOME,
        builder: (context, state) {
          final postId = state.uri.queryParameters['postId'];
          final trainerName = state.uri.queryParameters['trainerName'];
          return HomeView(autoOpenPostId: postId, autoOpenTrainerName: trainerName);
        },
      ),
      GoRoute(
        path: Routes.FAVORITE,
        builder: (context, state) => const FavouriteView(),
      ),
      GoRoute(
        path: Routes.FAVOURITE,
        builder: (context, state) => const FavouriteView(),
      ),
      GoRoute(
        path: Routes.WALLET,
        builder: (context, state) => WalletScreen(),
      ),
      GoRoute(
        path: Routes.PROFILE,
        builder: (context, state) => ProfileScreen(),
      ),
      GoRoute(
        path: Routes.TRAINER_DETAILS,
        builder: (context, state) => TrainerDetailsView(arguments: state.extra as Map<String, dynamic>?),
      ),
      GoRoute(
        path: Routes.MESSAGE_SCREEN,
        builder: (context, state) {
          final Map<String, dynamic> args = {};
          if (state.extra is Map<String, dynamic>) {
            args.addAll(state.extra as Map<String, dynamic>);
          } else {
            args['otherId'] = state.uri.queryParameters['otherId'];
            args['name'] = state.uri.queryParameters['name'];
            args['photoUrl'] = state.uri.queryParameters['photoUrl'];
            args['convId'] = state.uri.queryParameters['convId'];
          }
          return MessagingScreen(arguments: args);
        },
      ),
      GoRoute(
        path: Routes.LOGIN,
        builder: (context, state) => const LoginView(),
      ),
      GoRoute(
        path: Routes.FORGOT_PASSWORD,
        builder: (context, state) => const ForgotPasswordView(),
      ),
      GoRoute(
        path: Routes.SIGN_UP,
        builder: (context, state) => const SignUpView(),
      ),
      GoRoute(
        path: Routes.WELCOME,
        builder: (context, state) => const WelcomeView(),
      ),
      GoRoute(
        path: Routes.GET_STARTED,
        builder: (context, state) => const GetStartedView(),
      ),
      GoRoute(
        path: Routes.GENDER_SELECTION,
        builder: (context, state) => const GenderSelectionView(),
      ),
      GoRoute(
        path: Routes.AGE_INPUT,
        builder: (context, state) => const AgeInputView(),
      ),
      GoRoute(
        path: Routes.WEIGHT_INPUT,
        builder: (context, state) => const WeightInputView(),
      ),
      GoRoute(
        path: Routes.HEIGHT_INPUT,
        builder: (context, state) => const HeightInputView(),
      ),
      GoRoute(
        path: Routes.FITNESS_GOAL,
        builder: (context, state) => const FitnessGoalView(),
      ),
      GoRoute(
        path: Routes.ACTIVITY_LEVEL,
        builder: (context, state) => const ActivityLevelView(),
      ),
      GoRoute(
        path: Routes.FITNESS_LEVEL,
        builder: (context, state) => const FitnessLevelView(),
      ),
      GoRoute(
        path: Routes.NOTIFICATION_PERMISSION,
        builder: (context, state) => const NotificationPermissionView(),
      ),
      GoRoute(
        path: Routes.PROFILE_SUMMARY,
        builder: (context, state) => const ProfileSummaryView(),
      ),
      GoRoute(
        path: Routes.BOOK_SESSION,
        builder: (context, state) => BookSessionView(arguments: state.extra as Map<String, dynamic>?),
      ),
      GoRoute(
        path: Routes.MY_BOOKINGS,
        builder: (context, state) => const MyBookingsView(),
      ),
      GoRoute(
        path: Routes.ALL_SESSIONS,
        builder: (context, state) => const AllSessionsView(),
      ),
      GoRoute(
        path: Routes.ALL_FEEDS,
        builder: (context, state) => const AllFeedsView(),
      ),
      GoRoute(
        path: Routes.SEARCH,
        builder: (context, state) => const SearchView(),
      ),
      GoRoute(
        path: Routes.SETTINGS,
        builder: (context, state) => const SettingsView(),
      ),
      GoRoute(
        path: Routes.APPEARANCE,
        builder: (context, state) => const AppearanceSettingsView(),
      ),
      GoRoute(
        path: Routes.NOTIFICATIONS,
        builder: (context, state) => const NotificationsView(),
      ),
      GoRoute(
        path: Routes.TX_HISTORY,
        builder: (context, state) => TransactionHistoryScreen(arguments: state.extra as Map<String, dynamic>?),
      ),
      GoRoute(
        path: Routes.TRAINER_DASHBOARD,
        builder: (context, state) {
          final postId = state.uri.queryParameters['postId'];
          final trainerName = state.uri.queryParameters['trainerName'];
          final initialTab = state.uri.queryParameters['tab'];
          return TrainerDashboardView(
            autoOpenPostId: postId,
            autoOpenTrainerName: trainerName,
            initialTab: initialTab,
          );
        },
      ),
      GoRoute(
        path: Routes.TRAINER_AVAILABILITY,
        builder: (context, state) => const TrainerAvailabilityView(),
      ),
      GoRoute(
        path: Routes.TRAINER_ONBOARDING,
        builder: (context, state) => const TrainerOnboardingView(),
      ),
      GoRoute(
        path: Routes.TRAINER_APPLICATION,
        builder: (context, state) => const TrainerApplicationFormView(),
      ),
      GoRoute(
        path: Routes.ADMIN_DASHBOARD,
        builder: (context, state) => const AdminDashboardView(),
      ),
      GoRoute(
        path: Routes.STREAK_DETAILS,
        builder: (context, state) => const StreakDetailsView(),
      ),
      GoRoute(
        path: Routes.GOALS_DETAILS,
        builder: (context, state) => const GoalsDetailsView(),
      ),
    ],
  );
});
