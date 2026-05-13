import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import 'package:sunmind_thebest/core/api/api_service.dart';
import 'package:sunmind_thebest/core/services/haptic_service.dart';
import 'package:sunmind_thebest/core/services/notification_provider.dart';
import 'package:sunmind_thebest/core/theme/app_theme.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final ApiService _api = ApiService();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscureText = true;
  bool _isLoading = false;
  bool _agreed = false;

  int _passwordStrength(String pw) {
    if (pw.length < 4) return 0;
    int score = 0;
    if (pw.length >= 8) score++;
    if (pw.contains(RegExp(r'[0-9]'))) score++;
    if (pw.contains(RegExp(r'[A-Z]'))) score++;
    return score;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _register() async {
    HapticService.medium();
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (name.isEmpty ||
        email.isEmpty ||
        password.isEmpty ||
        confirmPassword.isEmpty) {
      HapticService.error();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('register'.tr())));
      return;
    }

    if (password != confirmPassword) {
      HapticService.error();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Пароли не совпадают')));
      return;
    }

    if (password.length < 6) {
      HapticService.error();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Пароль должен быть не менее 6 символов')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await _api.register(name, email, password);
      await _api.login(email, password); // авто-вход
      if (!mounted) return;
      await context.read<NotificationProvider>().load();

      if (!mounted) return;
      HapticService.success();
      context.go('/home');
    } catch (e) {
      HapticService.error();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка регистрации: ${e.toString()}')),
      );
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
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
    final pw = _passwordController.text;
    final strength = _passwordStrength(pw);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Регистрация',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: text,
            letterSpacing: -0.3,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Создать аккаунт',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  color: text,
                  letterSpacing: -1.0,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Создайте профиль для управления системой SunMind.',
                style: TextStyle(fontSize: 14, color: muted),
              ),
              const SizedBox(height: 24),

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
                    TextField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        hintText: 'Имя',
                        prefixIcon: Icon(Icons.person_outline, size: 20),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        hintText: 'Email',
                        prefixIcon: Icon(Icons.email_outlined, size: 20),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _passwordController,
                      obscureText: _obscureText,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: 'Пароль',
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

                    // Password strength bar
                    if (pw.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Row(
                        children: List.generate(3, (i) {
                          Color segColor;
                          if (i < strength) {
                            segColor = strength == 1
                                ? kDanger
                                : strength == 2
                                    ? kWarn
                                    : kPositive;
                          } else {
                            segColor = isDark
                                ? const Color(0xFF26262D)
                                : const Color(0xFFE8E5DE);
                          }
                          return Expanded(
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              margin: EdgeInsets.only(right: i < 2 ? 6 : 0),
                              height: 4,
                              decoration: BoxDecoration(
                                color: segColor,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 8),
                      // Requirements
                      _PwRequirement(
                        met: pw.length >= 8,
                        label: 'Минимум 8 символов',
                        isDark: isDark,
                      ),
                      _PwRequirement(
                        met: pw.contains(RegExp(r'[0-9]')),
                        label: 'Содержит цифру',
                        isDark: isDark,
                      ),
                      _PwRequirement(
                        met: pw.contains(RegExp(r'[A-Z]')),
                        label: 'Заглавная буква',
                        isDark: isDark,
                      ),
                    ],

                    const SizedBox(height: 12),
                    TextField(
                      controller: _confirmPasswordController,
                      obscureText: _obscureText,
                      decoration: InputDecoration(
                        hintText: 'Подтверждение пароля',
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

                    const SizedBox(height: 14),

                    // Agreement checkbox
                    GestureDetector(
                      onTap: () => setState(() => _agreed = !_agreed),
                      child: Row(
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              color: _agreed ? kA2 : Colors.transparent,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: _agreed ? kA2 : border,
                                width: 1.5,
                              ),
                            ),
                            child: _agreed
                                ? const Icon(
                                    Icons.check,
                                    size: 14,
                                    color: Color(0xFF1A0F00),
                                  )
                                : null,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Согласен с условиями использования',
                              style: TextStyle(
                                fontSize: 13,
                                color: muted,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Sunrise CTA button
                    GestureDetector(
                      onTap: _isLoading ? null : _register,
                      child: Container(
                        width: double.infinity,
                        height: 52,
                        decoration: BoxDecoration(
                          gradient: _isLoading ? null : kSunriseGradient,
                          color: _isLoading
                              ? const Color(0xFF26262D)
                              : null,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: _isLoading
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
                        child: _isLoading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Создать аккаунт',
                                style: TextStyle(
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
              Center(
                child: GestureDetector(
                  onTap: () => context.go('/login'),
                  child: RichText(
                    text: TextSpan(
                      text: 'Уже есть аккаунт? ',
                      style: TextStyle(color: muted, fontSize: 14),
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
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PwRequirement extends StatelessWidget {
  final bool met;
  final String label;
  final bool isDark;
  const _PwRequirement({
    required this.met,
    required this.label,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(
            met ? Icons.check_circle_rounded : Icons.circle_outlined,
            size: 14,
            color: met ? kPositive : (isDark ? const Color(0xFF26262D) : const Color(0xFFE8E5DE)),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: met
                  ? kPositive
                  : (isDark ? const Color(0xFF6E6E75) : const Color(0xFF8E8E93)),
              fontWeight: met ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}
