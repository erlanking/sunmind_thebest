import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<_OnboardingPage> _pages = const [
    _OnboardingPage(
      title: 'Умная автоматизация',
      subtitle: 'Свет реагирует на движение и окружающую среду',
      icon: '🏠',
      accent: Color(0xFF4FA3FF),
      glow: Color(0xFF4FA3FF),
    ),
    _OnboardingPage(
      title: 'Подключай устройства',
      subtitle: 'Сканируй QR-код на лампе или хабе за пару секунд',
      icon: '🔲',
      accent: Color(0xFF7C8CFF),
      glow: Color(0xFF7C8CFF),
      showScannerPanel: true,
      ctaLabel: 'Сканировать',
      ctaIcon: Icons.add,
    ),
    _OnboardingPage(
      title: 'Экономь энергию',
      subtitle: 'Отслеживай потребление и снижай расходы на электроэнергию',
      icon: '⚡',
      accent: Color(0xFF6DD400),
      glow: Color(0xFF6DD400),
    ),
    _OnboardingPage(
      title: 'Управляй освещением отовсюду',
      subtitle: 'Управляй светом из телефона',
      icon: '💡',
      accent: Color(0xFFFFCC4A),
      glow: Color(0xFFFFCC4A),
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _skip() {
    context.go('/login');
  }

  void _next() {
    if (_currentPage == _pages.length - 1) {
      context.go('/login');
    } else {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final page = _pages[_currentPage];

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            PageView.builder(
              controller: _pageController,
              itemCount: _pages.length,
              onPageChanged: (index) => setState(() => _currentPage = index),
              itemBuilder: (context, index) =>
                  _OnboardingContent(page: _pages[index]),
            ),
            Positioned(
              top: 8,
              right: 12,
              child: TextButton(
                onPressed: _skip,
                child: const Text(
                  'Пропустить',
                  style: TextStyle(color: Colors.white70),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 16,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        _pages.length,
                        (index) => _Dot(
                          isActive: _currentPage == index,
                          color: _pages[index].accent,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _next,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: page.accent,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (page.ctaIcon != null) ...[
                              Icon(page.ctaIcon, size: 18),
                              const SizedBox(width: 8),
                            ],
                            Text(
                              page.ctaLabel ??
                                  (_currentPage == _pages.length - 1
                                      ? 'Начать →'
                                      : 'Далее'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingContent extends StatelessWidget {
  final _OnboardingPage page;

  const _OnboardingContent({required this.page});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: RadialGradient(
          colors: [page.glow.withValues(alpha: 0.25), Colors.black],
          radius: 0.8,
          center: Alignment.topCenter,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black,
              boxShadow: [
                BoxShadow(
                  color: page.glow.withValues(alpha: 0.45),
                  blurRadius: 36,
                  spreadRadius: 4,
                ),
              ],
              border: Border.all(color: page.accent.withValues(alpha: 0.15)),
            ),
            alignment: Alignment.center,
            child: Text(page.icon, style: const TextStyle(fontSize: 60)),
          ),
          const SizedBox(height: 32),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                Text(
                  page.title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  page.subtitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withValues(alpha: 0.75),
                  ),
                ),
                if (page.showScannerPanel) ...[
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.03),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: page.accent.withValues(alpha: 0.25)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: page.accent.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.qr_code_2,
                            color: Colors.white,
                            size: 26,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'QR-сканер',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Нажми “Сканировать”, наведи камеру на код на устройстве.',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(Icons.add, color: page.accent),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  final bool isActive;
  final Color color;

  const _Dot({required this.isActive, required this.color});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      width: isActive ? 18 : 7,
      height: 7,
      decoration: BoxDecoration(
        color: isActive ? color : Colors.white24,
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }
}

class _OnboardingPage {
  final String title;
  final String subtitle;
  final String icon;
  final Color accent;
  final Color glow;
  final bool showScannerPanel;
  final String? ctaLabel;
  final IconData? ctaIcon;

  const _OnboardingPage({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.glow,
    this.showScannerPanel = false,
    this.ctaLabel,
    this.ctaIcon,
  });
}
