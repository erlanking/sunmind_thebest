import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import 'package:sunmind_thebest/core/api/mqtt_service.dart';
import 'package:sunmind_thebest/core/theme/theme_controller.dart';
import 'package:sunmind_thebest/core/api/api_service.dart';
import 'package:sunmind_thebest/core/services/haptic_service.dart';
import 'package:sunmind_thebest/core/services/notification_provider.dart';
import 'package:sunmind_thebest/features/auth/controllers/auth_controller.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ApiService _api = ApiService();
  final AuthController _authController = AuthController();
  bool autoModeOnStart = false;
  String? _name;
  String? _email;
  bool _loadingProfile = false;
  bool _loggingOut = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<NotificationProvider>().loadSettings();
    });
  }

  @override
  void dispose() {
    _authController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() => _loadingProfile = true);
    try {
      final me = await _api.me();
      if (!mounted) return;
      setState(() {
        _name = me['name'] as String? ?? _name;
        _email = me['email'] as String? ?? _email;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Не удалось загрузить профиль: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingProfile = false);
    }
  }

  String get selectedLanguage {
    final locale = context.locale; // из EasyLocalization
    switch (locale.languageCode) {
      case 'ru':
        return 'Русский';
      case 'en':
        return 'English';
      case 'ky':
        return 'Кыргызча';
      default:
        return 'Русский';
    }
  }

  void _showLanguageDialog() {
    HapticService.light();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sheetColor = isDark ? const Color(0xFF112135) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF161A22);
    final mutedColor = isDark ? Colors.white54 : const Color(0xFF6D7481);
    showModalBottomSheet(
      context: context,
      backgroundColor: sheetColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        final languages = [
          {'title': 'Русский', 'locale': Locale('ru'), 'flag': '🇷🇺'},
          {'title': 'English', 'locale': Locale('en'), 'flag': '🇬🇧'},
          {'title': 'Кыргызча', 'locale': Locale('ky'), 'flag': '🇰🇬'},
        ];

        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'language'.tr(),
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close, color: mutedColor),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ...languages.map((item) {
                final locale = item['locale'] as Locale;
                final title = item['title'] as String;
                final flag = item['flag'] as String;
                final isSelected = context.locale == locale;
                return InkWell(
                  onTap: () {
                    HapticService.success();
                    context.setLocale(locale);
                    Navigator.pop(context);
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFFF7931A).withValues(alpha: 0.15)
                          : null,
                      borderRadius: BorderRadius.circular(12),
                      border: isSelected
                          ? Border.all(
                              color: const Color(
                                0xFFF7931A,
                              ).withValues(alpha: 0.5),
                            )
                          : null,
                    ),
                    child: Row(
                      children: [
                        Text(flag, style: const TextStyle(fontSize: 24)),
                        const SizedBox(width: 12),
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.normal,
                            color: isSelected
                                ? const Color(0xFFF7931A)
                                : textColor,
                          ),
                        ),
                        const Spacer(),
                        if (isSelected)
                          const Icon(
                            Icons.check_circle,
                            color: Color(0xFFF7931A),
                            size: 20,
                          ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  Future<void> _logout() async {
    if (_loggingOut) return;

    HapticService.medium();
    setState(() => _loggingOut = true);

    try {
      await _authController.logout(
        notificationProvider: context.read<NotificationProvider>(),
        mqttService: MqttService(),
      );
      if (!mounted) return;
      context.go('/login');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось выйти из аккаунта: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _loggingOut = false);
      }
    }
  }

  String _getInitials(String? name) {
    if (name == null || name.isEmpty) return '👤';
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name[0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final themeController = Provider.of<AppThemeController>(context);
    final notificationProvider = context.watch<NotificationProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF112135) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF161A22);
    final mutedColor = isDark ? Colors.white70 : const Color(0xFF6D7481);
    return Scaffold(
      appBar: AppBar(title: Text('profile'.tr()), centerTitle: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFFF7931A), Color(0xFFFFB74D)],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFF7931A).withValues(alpha: 0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        _getInitials(_name),
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _loadingProfile
                        ? const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            ],
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _name ?? 'Профиль',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: textColor,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _email ?? 'email не указан',
                                style: TextStyle(color: mutedColor),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  _MiniBadge(
                                    text: 'Pro',
                                    color: const Color(0xFFF7931A),
                                  ),
                                  const SizedBox(width: 8),
                                  const _MiniBadge(text: 'Умный дом'),
                                ],
                              ),
                            ],
                          ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            _SectionCard(
              title: 'notifications'.tr(),
              color: cardColor,
              titleColor: textColor,
              children: [
                _SettingSwitchTile(
                  icon: Icons.notifications_outlined,
                  title: 'push_notifications'.tr(),
                  value: notificationProvider.pushNotificationsEnabled,
                  iconColor: mutedColor,
                  textColor: textColor,
                  onChanged: (value) async {
                    await context.read<NotificationProvider>()
                        .setPushNotificationsEnabled(value);
                  },
                ),
                const SizedBox(height: 12),
                _SettingSwitchTile(
                  icon: Icons.warning_amber_rounded,
                  title: 'emergency_signals'.tr(),
                  value: notificationProvider.emergencyAlertsEnabled,
                  iconColor: mutedColor,
                  textColor: textColor,
                  onChanged: (value) async {
                    await context.read<NotificationProvider>()
                        .setEmergencyAlertsEnabled(value);
                  },
                ),
              ],
            ),

            const SizedBox(height: 16),

            _SectionCard(
              title: 'application'.tr(),
              color: cardColor,
              titleColor: textColor,
              children: [
                _SettingSwitchTile(
                  icon: Icons.dark_mode_outlined,
                  title: 'dark_theme'.tr(),
                  value: themeController.isDark,
                  iconColor: mutedColor,
                  textColor: textColor,
                  onChanged: (value) {
                    context.read<AppThemeController>().toggleTheme(value);
                  },
                ),

                const SizedBox(height: 12),
                _ActionTile(
                  icon: Icons.language,
                  title: 'Язык',
                  subtitle: selectedLanguage,
                  iconColor: mutedColor,
                  textColor: textColor,
                  subtitleColor: mutedColor,
                  onTap: _showLanguageDialog,
                ),
              ],
            ),

            const SizedBox(height: 16),

            _SectionCard(
              title: 'account'.tr(),
              color: cardColor,
              titleColor: textColor,
              children: [
                _ActionTile(
                  icon: Icons.lock_outline,
                  title: 'change_password'.tr(),
                  iconColor: mutedColor,
                  textColor: textColor,
                  onTap: () => context.push('/change-password'),
                ),
                const SizedBox(height: 12),
                _ActionTile(
                  icon: Icons.privacy_tip_outlined,
                  title: 'privacy_policy'.tr(),
                  iconColor: mutedColor,
                  textColor: textColor,
                  onTap: () => context.push('/privacy-policy'),
                ),
              ],
            ),

            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _loggingOut ? null : _logout,
                icon: _loggingOut
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.logout),
                label: Text(_loggingOut ? 'Выход...' : 'logout'.tr()),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent.withValues(alpha: 0.15),
                  foregroundColor: Colors.redAccent,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final Color color;
  final Color titleColor;

  const _SectionCard({
    required this.title,
    required this.children,
    required this.color,
    required this.titleColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: titleColor,
            ),
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
}

class _SettingSwitchTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;
  final Color iconColor;
  final Color textColor;

  const _SettingSwitchTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
    required this.iconColor,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: iconColor),
        const SizedBox(width: 12),
        Expanded(
          child: Text(title, style: TextStyle(fontSize: 16, color: textColor)),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: const Color(0xFFF7931A),
        ),
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final Color iconColor;
  final Color textColor;
  final Color? subtitleColor;

  const _ActionTile({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
    required this.iconColor,
    required this.textColor,
    this.subtitleColor,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Icon(icon, color: iconColor),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(fontSize: 16, color: textColor),
              ),
            ),
            if (subtitle != null)
              Text(
                subtitle!,
                style: TextStyle(color: subtitleColor ?? textColor),
              ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right, color: subtitleColor ?? textColor),
          ],
        ),
      ),
    );
  }
}

class _MiniBadge extends StatelessWidget {
  final String text;
  final Color? color;

  const _MiniBadge({required this.text, this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color?.withValues(alpha: 0.15) ?? const Color(0xFF0D1B2E),
        borderRadius: BorderRadius.circular(12),
        border: color != null
            ? Border.all(color: color!.withValues(alpha: 0.3))
            : null,
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          color: color ?? Colors.white70,
          fontWeight: color != null ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
    );
  }
}
