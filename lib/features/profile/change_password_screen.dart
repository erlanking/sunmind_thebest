import 'package:flutter/material.dart';
import 'package:sunmind_thebest/core/api/api_service.dart';
import 'package:sunmind_thebest/core/services/haptic_service.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final ApiService _api = ApiService();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _saving = false;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    HapticService.medium();
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) return;

    setState(() => _saving = true);
    try {
      await _api.changePassword(
        currentPassword: _currentPasswordController.text.trim(),
        newPassword: _newPasswordController.text.trim(),
        confirmPassword: _confirmPasswordController.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Пароль успешно изменён'),
        ),
      );
      Navigator.of(context).pop();
    } on UnsupportedError {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Функция смены пароля пока недоступна на сервере'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось изменить пароль: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF112135) : Colors.white;
    final inputColor = isDark ? const Color(0xFF0D1B2E) : const Color(0xFFF2F4F8);
    final textColor = isDark ? Colors.white : const Color(0xFF161A22);
    final mutedColor = isDark ? Colors.white70 : const Color(0xFF6D7481);

    return Scaffold(
      appBar: AppBar(title: const Text('Изменить пароль'), centerTitle: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Обновите пароль для входа в аккаунт SunMind.',
                  style: TextStyle(color: mutedColor, height: 1.45),
                ),
                const SizedBox(height: 24),
                _PasswordField(
                  controller: _currentPasswordController,
                  label: 'Текущий пароль',
                  textColor: textColor,
                  fillColor: inputColor,
                  obscureText: _obscureCurrent,
                  onToggle: () {
                    setState(() => _obscureCurrent = !_obscureCurrent);
                  },
                  validator: (value) {
                    if ((value ?? '').trim().isEmpty) {
                      return 'Введите текущий пароль';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                _PasswordField(
                  controller: _newPasswordController,
                  label: 'Новый пароль',
                  textColor: textColor,
                  fillColor: inputColor,
                  obscureText: _obscureNew,
                  onToggle: () {
                    setState(() => _obscureNew = !_obscureNew);
                  },
                  validator: (value) {
                    final trimmed = (value ?? '').trim();
                    if (trimmed.isEmpty) {
                      return 'Введите новый пароль';
                    }
                    if (trimmed.length < 6) {
                      return 'Новый пароль должен быть не менее 6 символов';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                _PasswordField(
                  controller: _confirmPasswordController,
                  label: 'Подтверждение нового пароля',
                  textColor: textColor,
                  fillColor: inputColor,
                  obscureText: _obscureConfirm,
                  onToggle: () {
                    setState(() => _obscureConfirm = !_obscureConfirm);
                  },
                  validator: (value) {
                    final confirm = (value ?? '').trim();
                    if (confirm.isEmpty) {
                      return 'Подтвердите новый пароль';
                    }
                    if (confirm != _newPasswordController.text.trim()) {
                      return 'Подтверждение пароля не совпадает';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF7931A),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.black,
                            ),
                          )
                        : const Text(
                            'Сохранить',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PasswordField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool obscureText;
  final VoidCallback onToggle;
  final String? Function(String?) validator;
  final Color textColor;
  final Color fillColor;

  const _PasswordField({
    required this.controller,
    required this.label,
    required this.obscureText,
    required this.onToggle,
    required this.validator,
    required this.textColor,
    required this.fillColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          validator: validator,
          decoration: InputDecoration(
            filled: true,
            fillColor: fillColor,
            hintText: '••••••••',
            prefixIcon: const Icon(Icons.lock_outline),
            suffixIcon: IconButton(
              onPressed: onToggle,
              icon: Icon(
                obscureText
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
              ),
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }
}
