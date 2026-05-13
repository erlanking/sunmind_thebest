import 'dart:developer';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:sunmind_thebest/core/services/haptic_service.dart';
import 'package:sunmind_thebest/core/services/notification_provider.dart';
import 'package:sunmind_thebest/core/theme/app_theme.dart';
import 'package:sunmind_thebest/features/auth/controllers/auth_controller.dart';

class AuthHubScreen extends StatefulWidget {
  const AuthHubScreen({super.key});

  @override
  State<AuthHubScreen> createState() => _AuthHubScreenState();
}

class _AuthHubScreenState extends State<AuthHubScreen> {
  final AuthController _authController = AuthController();

  @override
  void initState() {
    super.initState();
    _authController.addListener(_rebuild);
  }

  @override
  void dispose() {
    _authController.removeListener(_rebuild);
    _authController.dispose();
    super.dispose();
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  Future<void> _loginWithGoogle() async {
    HapticService.medium();
    try {
      await _authController.loginWithGoogle();
      if (!mounted) return;
      await context.read<NotificationProvider>().load();
      if (!mounted) return;
      HapticService.success();
      context.go('/home');
    } catch (e) {
      HapticService.error();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _authController.errorMessage ??
                'Не удалось войти через Google. Попробуйте ещё раз.',
          ),
        ),
      );
      if (kDebugMode) log('Google auth error: $e', name: 'AuthHubScreen');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isLoading = _authController.isLoading;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B0B0D) : const Color(0xFFF6F5F1),
      body: Stack(
        children: [
          // Background radial glow
          if (isDark)
            Positioned(
              top: -120,
              left: -100,
              right: -100,
              child: Container(
                height: 400,
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [
                      kA2.withValues(alpha: 0.18),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 1.0],
                  ),
                ),
              ),
            ),

          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 56),

                  // Logo
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      gradient: kSunriseGradient,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: kA2.withValues(alpha: 0.45),
                          blurRadius: 32,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.wb_sunny_rounded,
                      color: Color(0xFF1A0F00),
                      size: 38,
                    ),
                  ),

                  const SizedBox(height: 14),

                  Text(
                    'SunMind',
                    style: GoogleFonts.manrope(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF1A1A1E),
                      letterSpacing: -0.5,
                    ),
                  ),

                  const SizedBox(height: 48),

                  Text(
                    'Управляйте светом\nлегко',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.manrope(
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF1A1A1E),
                      height: 1.15,
                      letterSpacing: -1.0,
                    ),
                  ),

                  const SizedBox(height: 10),

                  Text(
                    'Умная экосистема освещения в вашем кармане',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark
                          ? const Color(0xFFB3B3B8)
                          : const Color(0xFF56565C),
                    ),
                  ),

                  const SizedBox(height: 52),

                  // Continue with Apple
                  _AuthButton(
                    icon: Icons.apple,
                    label: 'Continue with Apple',
                    bg: isDark ? const Color(0xFF1C1C22) : Colors.black,
                    fg: Colors.white,
                    border: isDark ? const Color(0xFF26262D) : Colors.black,
                    onTap: () {
                      HapticService.light();
                      // Apple sign-in not yet implemented
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Apple Sign-In скоро будет добавлен')),
                      );
                    },
                  ),

                  const SizedBox(height: 10),

                  // Continue with Google
                  _AuthButton(
                    icon: Icons.g_mobiledata,
                    iconSize: 28,
                    label: 'Continue with Google',
                    bg: isDark ? const Color(0xFF1C1C22) : Colors.white,
                    fg: isDark ? Colors.white : const Color(0xFF1A1A1E),
                    border: isDark
                        ? const Color(0xFF26262D)
                        : const Color(0xFFE8E5DE),
                    loading: isLoading,
                    onTap: _loginWithGoogle,
                  ),

                  const SizedBox(height: 10),

                  // Continue with Email (primary — sunrise gradient)
                  _SunriseAuthButton(
                    label: 'Continue with Email',
                    onTap: () => context.push('/login'),
                  ),

                  const SizedBox(height: 36),

                  // Already have an account
                  GestureDetector(
                    onTap: () => context.push('/login'),
                    child: RichText(
                      text: TextSpan(
                        text: 'Уже есть аккаунт? ',
                        style: TextStyle(
                          color: isDark
                              ? const Color(0xFF6E6E75)
                              : const Color(0xFF56565C),
                          fontSize: 14,
                        ),
                        children: [
                          TextSpan(
                            text: 'Войти',
                            style: TextStyle(
                              color: kA2,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  if (_authController.errorMessage != null) ...[
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: kDanger.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: kDanger.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Text(
                        _authController.errorMessage!,
                        style: TextStyle(
                          color: isDark
                              ? Colors.red.shade200
                              : Colors.red.shade800,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AuthButton extends StatelessWidget {
  final IconData icon;
  final double iconSize;
  final String label;
  final Color bg;
  final Color fg;
  final Color border;
  final bool loading;
  final VoidCallback onTap;

  const _AuthButton({
    required this.icon,
    this.iconSize = 22,
    required this.label,
    required this.bg,
    required this.fg,
    required this.border,
    this.loading = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: Container(
        width: double.infinity,
        height: 54,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: border),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (loading)
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: fg,
                ),
              )
            else ...[
              Icon(icon, color: fg, size: iconSize),
              const SizedBox(width: 10),
              Text(
                label,
                style: TextStyle(
                  color: fg,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SunriseAuthButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _SunriseAuthButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 54,
        decoration: BoxDecoration(
          gradient: kSunriseGradient,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: kA2.withValues(alpha: 0.4),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.email_outlined, color: Color(0xFF1A0F00), size: 20),
            const SizedBox(width: 10),
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFF1A0F00),
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
