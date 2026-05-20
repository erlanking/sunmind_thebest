import 'dart:async';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sunmind_thebest/core/theme/app_theme.dart';

class OtpScreen extends StatefulWidget {
  final String email;
  const OtpScreen({super.key, required this.email});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final List<TextEditingController> _controllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focuses = List.generate(6, (_) => FocusNode());

  int _secondsLeft = 42;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_secondsLeft <= 0) {
        t.cancel();
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  void _resend() {
    if (_secondsLeft > 0) return;
    setState(() => _secondsLeft = 42);
    _startTimer();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('auth.resend'.tr())),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focuses) {
      f.dispose();
    }
    super.dispose();
  }

  void _onChanged(int index, String value) {
    if (value.length == 1 && index < 5) {
      _focuses[index + 1].requestFocus();
    }
    if (value.isEmpty && index > 0) {
      _focuses[index - 1].requestFocus();
    }
    // Auto-submit when all 6 filled
    final code = _controllers.map((c) => c.text).join();
    if (code.length == 6) {
      _verify(code);
    }
  }

  void _verify(String code) {
    // TODO: wire up to real OTP verification
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Код: $code — верификация...')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0B0B0D) : const Color(0xFFF6F5F1);
    final text = isDark ? const Color(0xFFF5F5F7) : const Color(0xFF1A1A1E);
    final muted = isDark ? const Color(0xFF6E6E75) : const Color(0xFF56565C);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'auth.enter_code'.tr(),
          style: GoogleFonts.manrope(
            fontWeight: FontWeight.w800,
            fontSize: 17,
            color: text,
            letterSpacing: -0.3,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 24),

            Text(
              'auth.code_sent_to'.tr(),
              style: TextStyle(fontSize: 15, color: muted),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              widget.email,
              style: TextStyle(
                fontSize: 15,
                color: kA2,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 44),

            // OTP boxes
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(6, (i) => _OtpBox(
                controller: _controllers[i],
                focusNode: _focuses[i],
                isDark: isDark,
                onChanged: (v) => _onChanged(i, v),
              )),
            ),

            const SizedBox(height: 40),

            // Resend
            GestureDetector(
              onTap: _secondsLeft == 0 ? _resend : null,
              child: AnimatedOpacity(
                opacity: _secondsLeft == 0 ? 1.0 : 0.5,
                duration: const Duration(milliseconds: 200),
                child: Text(
                  _secondsLeft > 0
                      ? '${'auth.resend'.tr()} 0:${_secondsLeft.toString().padLeft(2, '0')}'
                      : 'auth.resend'.tr(),
                  style: TextStyle(
                    color: _secondsLeft == 0 ? kA2 : muted,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OtpBox extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isDark;
  final ValueChanged<String> onChanged;

  const _OtpBox({
    required this.controller,
    required this.focusNode,
    required this.isDark,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final filled = value.text.isNotEmpty;
        final focused = focusNode.hasFocus;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 48,
          height: 58,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF17171B) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: focused
                  ? kA2
                  : filled
                      ? kA2.withValues(alpha: 0.4)
                      : (isDark
                          ? const Color(0xFF26262D)
                          : const Color(0xFFE8E5DE)),
              width: focused ? 2.0 : 1.2,
            ),
            boxShadow: focused
                ? [
                    BoxShadow(
                      color: kA2.withValues(alpha: 0.25),
                      blurRadius: 12,
                      spreadRadius: 0,
                    ),
                  ]
                : null,
          ),
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            maxLength: 1,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: onChanged,
            style: GoogleFonts.manrope(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: isDark
                  ? const Color(0xFFF5F5F7)
                  : const Color(0xFF1A1A1E),
            ),
            decoration: const InputDecoration(
              counterText: '',
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        );
      },
    );
  }
}
