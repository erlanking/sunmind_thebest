import 'package:flutter/material.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final background = isDark ? const Color(0xFF0D0F14) : const Color(0xFFF6F7FB);
    final cardColor = isDark ? const Color(0xFF112135) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF161A22);
    final mutedColor = isDark ? Colors.white70 : const Color(0xFF6D7481);

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        title: const Text('Политика конфиденциальности'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'SunMind уважает вашу конфиденциальность и обрабатывает данные только в объёме, необходимом для работы умного освещения и уведомлений.',
                style: TextStyle(color: mutedColor, height: 1.5),
              ),
              const SizedBox(height: 24),
              _PolicySection(
                title: 'Какие данные собираются',
                text:
                    'Приложение может хранить адрес электронной почты, имя профиля, идентификаторы устройств, зоны, историю уведомлений и технические данные, необходимые для отображения статуса системы и аналитики.',
                textColor: textColor,
                mutedColor: mutedColor,
              ),
              _PolicySection(
                title: 'Как используются данные',
                text:
                    'Собранные данные используются для авторизации, загрузки профиля, отображения подключённых устройств, показа аналитики, истории событий и персональных настроек внутри приложения.',
                textColor: textColor,
                mutedColor: mutedColor,
              ),
              _PolicySection(
                title: 'Уведомления',
                text:
                    'Push-уведомления и локальные уведомления используются для информирования о событиях системы, изменениях состояния устройств и аварийных сигналах. Вы можете отключить их в настройках профиля.',
                textColor: textColor,
                mutedColor: mutedColor,
              ),
              _PolicySection(
                title: 'Безопасность',
                text:
                    'SunMind стремится защищать данные пользователя с помощью механизмов авторизации и локального хранения только необходимых настроек. Рекомендуется использовать надёжный пароль и не передавать доступ третьим лицам.',
                textColor: textColor,
                mutedColor: mutedColor,
              ),
              _PolicySection(
                title: 'Контакты',
                text:
                    'Если у вас есть вопросы по обработке данных или работе приложения, свяжитесь с командой SunMind через официальный канал поддержки, указанный в вашем проекте или магазине приложения.',
                textColor: textColor,
                mutedColor: mutedColor,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PolicySection extends StatelessWidget {
  final String title;
  final String text;
  final Color textColor;
  final Color mutedColor;

  const _PolicySection({
    required this.title,
    required this.text,
    required this.textColor,
    required this.mutedColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: textColor,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            text,
            style: TextStyle(color: mutedColor, height: 1.55),
          ),
        ],
      ),
    );
  }
}
