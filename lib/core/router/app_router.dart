import 'package:go_router/go_router.dart';
import 'package:sunmind_thebest/core/router/main_shell.dart';
import 'package:sunmind_thebest/features/profile/change_password_screen.dart';
import 'package:sunmind_thebest/features/profile/privacy_policy_screen.dart';
import 'package:sunmind_thebest/features/profile/profile.screen.dart';
import '../../features/analytics/analytics_screen.dart';
import '../../features/auth/login_screen.dart';
import '../../features/auth/register_screen.dart';
import '../../features/device/create_zone_screen.dart';
import '../../features/device/device_screen.dart';
import '../../features/device/scan_device_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/notifications/notifications_screen.dart';
import '../../features/onboarding/onboarding_screen.dart';
import '../../features/room/room_screen.dart';

class AppRouter {
  static GoRouter createRouter({required String initialLocation}) {
    return GoRouter(
      initialLocation: initialLocation,
      routes: [
        GoRoute(
          path: '/onboarding',
          builder: (context, state) => const OnboardingScreen(),
        ),
        GoRoute(
          path: '/login',
          builder: (context, state) => const LoginScreen(),
        ),
        GoRoute(
          path: '/register',
          builder: (context, state) => const RegisterScreen(),
        ),
        ShellRoute(
          builder: (context, state, child) {
            return MainShell(child: child);
          },
          routes: [
            GoRoute(
              path: '/home',
              builder: (context, state) => const HomeScreen(),
            ),
            GoRoute(
              path: '/analytics',
              builder: (context, state) => const AnalyticsScreen(),
            ),
            GoRoute(
              path: '/profile',
              builder: (context, state) => const ProfileScreen(),
            ),
          ],
        ),
        GoRoute(
          path: '/room/:id',
          builder: (context, state) {
            final roomId = state.pathParameters['id']!;
            final room = state.extra as Map<String, dynamic>?;
            return RoomScreen(roomId: roomId, roomData: room);
          },
        ),
        GoRoute(
          path: '/device/:id',
          builder: (context, state) {
            final deviceId = state.pathParameters['id'] ?? 'SMP-0001';
            return DeviceScreen(deviceId: deviceId);
          },
        ),
        GoRoute(
          path: '/scan-device',
          builder: (context, state) => const ScanDeviceScreen(),
        ),
        GoRoute(
          path: '/create-zone',
          builder: (context, state) {
            final deviceId = state.extra as String? ?? '';
            return CreateZoneScreen(deviceId: deviceId);
          },
        ),
        GoRoute(
          path: '/notifications',
          builder: (context, state) => const NotificationsScreen(),
        ),
        GoRoute(
          path: '/change-password',
          builder: (context, state) => const ChangePasswordScreen(),
        ),
        GoRoute(
          path: '/privacy-policy',
          builder: (context, state) => const PrivacyPolicyScreen(),
        ),
      ],
    );
  }
}
