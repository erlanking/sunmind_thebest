import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import 'package:sunmind_thebest/core/api/api_service.dart';
import 'package:sunmind_thebest/core/services/haptic_service.dart';
import 'package:sunmind_thebest/core/services/notification_provider.dart';

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
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final card = isDark ? const Color(0xFF112135) : Colors.white;
    final field = isDark ? const Color(0xFF0D1B2E) : const Color(0xFFF2F4F8);
    final text = isDark ? Colors.white : const Color(0xFF161A22);
    final muted = isDark
        ? Colors.white.withValues(alpha: 0.7)
        : const Color(0xFF6D7481);

    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Создать аккаунт',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                  color: text,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Создай профиль для управления системой SunMind.',
                style: TextStyle(fontSize: 15, color: muted),
              ),
              const SizedBox(height: 28),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: card,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  children: [
                    TextField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        hintText: 'Имя',
                        prefixIcon: const Icon(Icons.person_outline),
                        filled: true,
                        fillColor: field,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _emailController,
                      decoration: InputDecoration(
                        hintText: 'Email',
                        prefixIcon: const Icon(Icons.email_outlined),
                        filled: true,
                        fillColor: field,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _passwordController,
                      obscureText: _obscureText,
                      decoration: InputDecoration(
                        hintText: 'Пароль',
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
                    TextField(
                      controller: _confirmPasswordController,
                      obscureText: _obscureText,
                      decoration: InputDecoration(
                        hintText: 'Подтверждение пароля',
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
                    const SizedBox(height: 22),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _register,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colorScheme.primary,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.black,
                                ),
                              )
                            : const Text(
                                'Создать аккаунт',
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
              const SizedBox(height: 24),
              Center(
                child: Wrap(
                  children: [
                    Text('Уже есть аккаунт? ', style: TextStyle(color: muted)),
                    GestureDetector(
                      onTap: () => context.go('/login'),
                      child: const Text(
                        'Войти',
                        style: TextStyle(
                          color: Color(0xFFF7931A),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
