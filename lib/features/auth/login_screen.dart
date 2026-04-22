import 'dart:developer';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
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
            _authController.errorMessage ?? 'Ошибка входа: ${e.toString()}',
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
            _authController.errorMessage ?? 'Ошибка входа через Google: $e',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final card = isDark ? const Color(0xFF112135) : Colors.white;
    final field = isDark ? const Color(0xFF0D1B2E) : const Color(0xFFF2F4F8);
    final text = isDark ? Colors.white : const Color(0xFF161A22);
    final muted = isDark
        ? Colors.white.withValues(alpha: 0.7)
        : const Color(0xFF6D7481);
    final isLoading = _authController.isLoading;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: const LinearGradient(
                        colors: [Color(0xFFF7931A), Color(0xFFFFB74D)],
                      ),
                    ),
                    child: const Icon(
                      Icons.wb_sunny_rounded,
                      color: Colors.black,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'SunMind',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: text,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 36),
              Text(
                'С возвращением',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                  color: text,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Войди в систему и управляй освещением.',
                style: TextStyle(fontSize: 15, color: muted),
              ),
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: card,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Email',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: text,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      onChanged: (_) => _authController.clearError(),
                      decoration: InputDecoration(
                        hintText: 'example@mail.com',
                        prefixIcon: const Icon(Icons.email_outlined),
                        filled: true,
                        fillColor: field,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Пароль',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: text,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _passwordController,
                      obscureText: _obscureText,
                      onChanged: (_) => _authController.clearError(),
                      decoration: InputDecoration(
                        hintText: '••••••••',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          onPressed: () {
                            setState(() {
                              _obscureText = !_obscureText;
                            });
                          },
                          icon: Icon(
                            _obscureText
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                          ),
                        ),
                        filled: true,
                        fillColor: field,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () {},
                        child: const Text('Забыли пароль?'),
                      ),
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: isLoading ? null : _login,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colorScheme.primary,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        child: isLoading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.black,
                                ),
                              )
                            : const Text(
                                'Войти',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  Expanded(
                    child: Divider(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.15)
                          : const Color(0xFFE2E6EF),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      'или продолжить через',
                      style: TextStyle(color: muted),
                    ),
                  ),
                  Expanded(
                    child: Divider(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.15)
                          : const Color(0xFFE2E6EF),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: isLoading ? null : _loginWithGoogle,
                      icon: const Icon(Icons.g_mobiledata, size: 28),
                      label: isLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Sign in with Google'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.15)
                              : const Color(0xFFE2E6EF),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                    ),
                  ),
                ],
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
                    color: Colors.redAccent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.redAccent.withValues(alpha: 0.35),
                    ),
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
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text('Нет аккаунта? ', style: TextStyle(color: muted)),
                    GestureDetector(
                      onTap: () => context.go('/register'),
                      child: const Text(
                        'Зарегистрироваться',
                        style: TextStyle(
                          color: Color(0xFFF7931A),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
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
