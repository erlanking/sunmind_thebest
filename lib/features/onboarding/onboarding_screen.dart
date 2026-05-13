import 'dart:math';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sunmind_thebest/core/theme/app_theme.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  late final AnimationController _glowController;
  late final Animation<double> _glowAnim;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
    _glowAnim = CurvedAnimation(parent: _glowController, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  void _skip() => context.go('/login');

  void _next() {
    if (_currentPage == 2) {
      context.go('/login');
    } else {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView(
            controller: _pageController,
            onPageChanged: (i) => setState(() => _currentPage = i),
            children: [
              _Slide1(glowAnim: _glowAnim),
              const _Slide2(),
              const _Slide3(),
            ],
          ),

          // Skip button
          if (_currentPage < 2)
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              right: 16,
              child: TextButton(
                onPressed: _skip,
                child: Text(
                  'Пропустить',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),

          // Bottom controls
          Positioned(
            left: 0,
            right: 0,
            bottom: MediaQuery.of(context).padding.bottom + 20,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Dot indicators
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(3, (i) {
                      final active = i == _currentPage;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: active ? 22 : 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: active
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(12),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 18),

                  // CTA button
                  GestureDetector(
                    onTap: _next,
                    child: Container(
                      width: double.infinity,
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: _currentPage == 2
                            ? kSunriseGradient
                            : null,
                        color: _currentPage == 2
                            ? null
                            : Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(16),
                        border: _currentPage != 2
                            ? Border.all(
                                color: Colors.white.withValues(alpha: 0.2),
                              )
                            : null,
                        boxShadow: _currentPage == 2
                            ? [
                                BoxShadow(
                                  color: kA2.withValues(alpha: 0.45),
                                  blurRadius: 24,
                                  offset: const Offset(0, 8),
                                ),
                              ]
                            : null,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        _currentPage == 2 ? 'Начать' : 'Далее',
                        style: TextStyle(
                          color: _currentPage == 2
                              ? const Color(0xFF1A0F00)
                              : Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Slide 1 — "Солнечный свет. Умный дом." ────────────────────────────────────

class _Slide1 extends StatelessWidget {
  final Animation<double> glowAnim;
  const _Slide1({required this.glowAnim});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF3A1A00), Color(0xFF0B0B0D)],
          stops: [0.0, 0.7],
        ),
      ),
      child: Stack(
        children: [
          // Radial glow at top
          Positioned(
            top: -80,
            left: -80,
            right: -80,
            child: AnimatedBuilder(
              animation: glowAnim,
              builder: (context, child) => Container(
                height: 500,
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [
                      kA2.withValues(alpha: 0.35 + 0.15 * glowAnim.value),
                      kA3.withValues(alpha: 0.15),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.45, 1.0],
                  ),
                ),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 60),

                // Sun illustration
                AnimatedBuilder(
                  animation: glowAnim,
                  builder: (context, child) => _SunIllustration(pulse: glowAnim.value),
                ),

                const SizedBox(height: 48),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Column(
                    children: [
                      Text(
                        'Солнечный свет.\nУмный дом.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.manrope(
                          fontSize: 34,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          height: 1.1,
                          letterSpacing: -1.2,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Управляйте освещением интеллектуально.\nЭкономьте энергию каждый день.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 15,
                          color: Colors.white.withValues(alpha: 0.65),
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SunIllustration extends StatelessWidget {
  final double pulse;
  const _SunIllustration({required this.pulse});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 200,
      height: 200,
      child: CustomPaint(
        painter: _SunPainter(pulse: pulse),
      ),
    );
  }
}

class _SunPainter extends CustomPainter {
  final double pulse;
  _SunPainter({required this.pulse});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxR = size.width / 2;

    // Outer glow
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          kA1.withValues(alpha: 0.18 + 0.08 * pulse),
          kA2.withValues(alpha: 0.08),
          Colors.transparent,
        ],
        stops: const [0.0, 0.6, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: maxR));
    canvas.drawCircle(center, maxR, glowPaint);

    // Rays
    final rayPaint = Paint()
      ..color = kA1.withValues(alpha: 0.25 + 0.1 * pulse)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < 12; i++) {
      final angle = (i / 12) * 2 * pi;
      final inner = maxR * 0.48;
      final outer = maxR * (0.72 + 0.06 * pulse);
      final p1 = Offset(
        center.dx + inner * cos(angle),
        center.dy + inner * sin(angle),
      );
      final p2 = Offset(
        center.dx + outer * cos(angle),
        center.dy + outer * sin(angle),
      );
      canvas.drawLine(p1, p2, rayPaint);
    }

    // Core circle gradient
    final corePaint = Paint()
      ..shader = const RadialGradient(
        colors: [kA1, kA2, kA3],
        stops: [0.0, 0.5, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: maxR * 0.42));
    canvas.drawCircle(center, maxR * 0.42, corePaint);

    // House silhouette
    final housePaint = Paint()
      ..color = const Color(0xFF1A0F00)
      ..style = PaintingStyle.fill;

    const houseW = 46.0;
    const houseH = 38.0;
    final houseLeft = center.dx - houseW / 2;
    final houseTop = center.dy - houseH / 2 + 4;

    // Walls
    final wallRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(houseLeft + 6, houseTop + 16, houseW - 12, houseH - 16),
      const Radius.circular(2),
    );
    canvas.drawRRect(wallRect, housePaint);

    // Roof
    final roofPath = Path()
      ..moveTo(houseLeft, houseTop + 16)
      ..lineTo(center.dx, houseTop)
      ..lineTo(houseLeft + houseW, houseTop + 16)
      ..close();
    canvas.drawPath(roofPath, housePaint);

    // Door
    final doorPaint = Paint()
      ..color = kA3.withValues(alpha: 0.6)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(center.dx - 5, houseTop + 22, 10, 16),
        const Radius.circular(3),
      ),
      doorPaint,
    );
  }

  @override
  bool shouldRepaint(_SunPainter old) => old.pulse != pulse;
}

// ── Slide 2 — "Всё по зонам" ──────────────────────────────────────────────────

class _Slide2 extends StatelessWidget {
  const _Slide2();

  static const _rooms = [
    _RoomData('Гостиная', '🛋️', Color(0xFFFFB340), 0.78),
    _RoomData('Кухня', '🍳', Color(0xFFFF9F43), 0.55),
    _RoomData('Кабинет', '💼', Color(0xFF4A9CFF), 0.40),
    _RoomData('Спальня', '🌙', Color(0xFFAB7BFF), 0.20),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0B0B0D),
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 60),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                children: [
                  Text(
                    'Всё по зонам',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.manrope(
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -1.2,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Группируйте панели по комнатам и управляйте\nкаждой зоной отдельно.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.white.withValues(alpha: 0.6),
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),

            // Floor plan grid
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.2,
                children: _rooms.map(_RoomTile.new).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoomData {
  final String name;
  final String emoji;
  final Color color;
  final double brightness;
  const _RoomData(this.name, this.emoji, this.color, this.brightness);
}

class _RoomTile extends StatelessWidget {
  final _RoomData room;
  const _RoomTile(this.room, {super.key});

  @override
  Widget build(BuildContext context) {
    final isOn = room.brightness > 0.3;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isOn
            ? room.color.withValues(alpha: 0.15)
            : const Color(0xFF17171B),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isOn
              ? room.color.withValues(alpha: 0.4)
              : const Color(0xFF26262D),
        ),
        boxShadow: isOn
            ? [
                BoxShadow(
                  color: room.color.withValues(alpha: 0.25),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: room.color.withValues(alpha: isOn ? 0.25 : 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Text(room.emoji, style: const TextStyle(fontSize: 18)),
          ),
          const Spacer(),
          Text(
            room.name,
            style: GoogleFonts.manrope(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: isOn ? Colors.white : Colors.white54,
            ),
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: room.brightness,
              minHeight: 4,
              backgroundColor: Colors.white12,
              valueColor: AlwaysStoppedAnimation<Color>(
                isOn ? room.color : Colors.white24,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Slide 3 — "Видно каждый ватт" ─────────────────────────────────────────────

class _Slide3 extends StatelessWidget {
  const _Slide3();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0B0B0D),
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 60),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                children: [
                  Text(
                    'Видно каждый ватт',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.manrope(
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -1.2,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Отслеживайте потребление и снижайте\nрасходы на электроэнергию.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.white.withValues(alpha: 0.6),
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),

            // Savings hero card
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: kSunriseGradient,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: kA2.withValues(alpha: 0.45),
                      blurRadius: 40,
                      offset: const Offset(0, 16),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ЭКОНОМИЯ',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF1A0F00).withValues(alpha: 0.6),
                              letterSpacing: 1.4,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '−43%',
                            style: GoogleFonts.manrope(
                              fontSize: 56,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF1A0F00),
                              height: 1.0,
                              letterSpacing: -2,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'к прошлому месяцу',
                            style: TextStyle(
                              fontSize: 13,
                              color: const Color(0xFF1A0F00).withValues(alpha: 0.7),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Text('🌿', style: TextStyle(fontSize: 42)),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Mini chart placeholder
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                height: 80,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF17171B),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFF26262D)),
                ),
                child: CustomPaint(
                  size: const Size(double.infinity, 48),
                  painter: _MiniChartPainter(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniChartPainter extends CustomPainter {
  static const _data = [0.6, 0.75, 0.5, 0.9, 0.65, 0.4, 0.3];

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    final fillPath = Path();
    final pts = List.generate(_data.length, (i) {
      return Offset(
        i / (_data.length - 1) * size.width,
        size.height - _data[i] * size.height,
      );
    });

    path.moveTo(pts[0].dx, pts[0].dy);
    fillPath.moveTo(pts[0].dx, size.height);
    fillPath.lineTo(pts[0].dx, pts[0].dy);

    for (int i = 1; i < pts.length; i++) {
      final cp = Offset((pts[i - 1].dx + pts[i].dx) / 2, pts[i - 1].dy);
      final cp2 = Offset((pts[i - 1].dx + pts[i].dx) / 2, pts[i].dy);
      path.cubicTo(cp.dx, cp.dy, cp2.dx, cp2.dy, pts[i].dx, pts[i].dy);
      fillPath.cubicTo(cp.dx, cp.dy, cp2.dx, cp2.dy, pts[i].dx, pts[i].dy);
    }

    fillPath.lineTo(size.width, size.height);
    fillPath.close();

    canvas.drawPath(
      fillPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [kA2.withValues(alpha: 0.3), kA2.withValues(alpha: 0.0)],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );

    canvas.drawPath(
      path,
      Paint()
        ..color = kA2
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_MiniChartPainter _) => false;
}
