import 'dart:developer';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import 'package:sunmind_thebest/core/theme/app_theme.dart';
import 'package:sunmind_thebest/features/auth/controllers/auth_controller.dart';
import 'package:sunmind_thebest/core/services/haptic_service.dart';
import 'package:sunmind_thebest/core/services/notification_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthController _authController = AuthController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscureText = true;

  @override
  void initState() {
    super.initState();
    _authController.addListener(_handleAuthStateChanged);
  }

  @override
  void dispose() {
    _authController.removeListener(_handleAuthStateChanged);
    _authController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleAuthStateChanged() {
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _login() async {
    HapticService.medium();
    if (_emailController.text.trim().isEmpty ||
        _passwordController.text.trim().isEmpty) {
      HapticService.error();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('login'.tr())));
      return;
    }

    try {
      await _authController.loginWithEmail(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      if (!mounted) return;
      await context.read<NotificationProvider>().load();

      if (!mounted) return;
      HapticService.success();
      context.go('/home');
    } catch (e) {
      HapticService.error();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        SnackBar(
          content: Text(
            _authController.errorMessage ?? 'errors.login_failed'.tr(),
          ),
        ),
      );
    }
  }

  Future<void> _loginWithGoogle() async {
    HapticService.medium();
    _debugLog('Google sign-in button tapped');
    try {
      await _authController.loginWithGoogle();
      if (!mounted) return;
      await context.read<NotificationProvider>().load();

      if (!mounted) return;
      _debugLog('Google sign-in completed. Navigating to /home');
      HapticService.success();
      context.go('/home');
    } catch (e) {
      _debugLog('Google sign-in failed on UI layer: $e');
      HapticService.error();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _authController.errorMessage ?? 'errors.google_login'.tr(),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0B0B0D) : const Color(0xFFF6F5F1);
    final card = isDark ? const Color(0xFF17171B) : Colors.white;
    final border = isDark ? const Color(0xFF26262D) : const Color(0xFFE8E5DE);
    final text = isDark ? const Color(0xFFF5F5F7) : const Color(0xFF1A1A1E);
    final muted = isDark ? const Color(0xFF6E6E75) : const Color(0xFF56565C);
    final isLoading = _authController.isLoading;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              // Back / logo row
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: kSunriseGradient,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: kA2.withValues(alpha: 0.35),
                          blurRadius: 14,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.wb_sunny_rounded,
                      color: Color(0xFF1A0F00),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'SunMind',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: text,
                      letterSpacing: -0.4,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 36),
              Text(
                'auth.welcome_back'.tr(),
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  color: text,
                  letterSpacing: -1.0,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'onboarding.login_hint'.tr(),
                style: TextStyle(fontSize: 14, color: muted),
              ),
              const SizedBox(height: 28),

              // Form card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: card,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _FieldLabel('Email', text),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      onChanged: (_) => _authController.clearError(),
                      decoration: const InputDecoration(
                        hintText: 'example@mail.com',
                        prefixIcon: Icon(Icons.email_outlined, size: 20),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _FieldLabel('auth.password'.tr(), text),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _passwordController,
                      obscureText: _obscureText,
                      onChanged: (_) => _authController.clearError(),
                      decoration: InputDecoration(
                        hintText: '••••••••',
                        prefixIcon: const Icon(Icons.lock_outline, size: 20),
                        suffixIcon: IconButton(
                          onPressed: () =>
                              setState(() => _obscureText = !_obscureText),
                          icon: Icon(
                            _obscureText
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () {},
                        child: Text('auth.forgot_password'.tr()),
                      ),
                    ),
                    // Sunrise gradient login button
                    GestureDetector(
                      onTap: isLoading ? null : _login,
                      child: Container(
                        width: double.infinity,
                        height: 52,
                        decoration: BoxDecoration(
                          gradient: isLoading ? null : kSunriseGradient,
                          color: isLoading
                              ? const Color(0xFF26262D)
                              : null,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: isLoading
                              ? null
                              : [
                                  BoxShadow(
                                    color: kA2.withValues(alpha: 0.4),
                                    blurRadius: 20,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                        ),
                        alignment: Alignment.center,
                        child: isLoading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                'auth.login'.tr(),
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1A0F00),
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Divider
              Row(
                children: [
                  Expanded(child: Divider(color: border)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      'auth.or'.tr(),
                      style: TextStyle(color: muted, fontSize: 13),
                    ),
                  ),
                  Expanded(child: Divider(color: border)),
                ],
              ),

              const SizedBox(height: 16),

              // Google sign-in
              OutlinedButton.icon(
                onPressed: isLoading ? null : _loginWithGoogle,
                icon: const Icon(Icons.g_mobiledata, size: 26),
                label: Text('auth.login_with_google'.tr()),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 52),
                  side: BorderSide(color: border),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),

              if (_authController.errorMessage != null) ...[
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: kDanger.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: kDanger.withValues(alpha: 0.35)),
                  ),
                  child: Text(
                    _authController.errorMessage!,
                    style: TextStyle(
                      color: isDark ? Colors.red.shade100 : Colors.red.shade800,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 28),
              Center(
                child: GestureDetector(
                  onTap: () => context.go('/register'),
                  child: RichText(
                    text: TextSpan(
                      text: '${'auth.no_account'.tr()} ',
                      style: TextStyle(color: muted, fontSize: 14),
                      children: [
                        TextSpan(
                          text: 'auth.register_action'.tr(),
                          style: TextStyle(
                            color: kA2,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  void _debugLog(String message) {
    if (!kDebugMode) return;
    log(message, name: 'LoginScreen');
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  final Color color;
  const _FieldLabel(this.text, this.color);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: color,
        letterSpacing: -0.1,
      ),
    );
  }
}
