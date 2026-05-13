import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ── Design tokens ─────────────────────────────────────────────────────────────

// Accent "Amber"
const kA1 = Color(0xFFFFC44D);   // light
const kA2 = Color(0xFFF7931A);   // mid — primary accent
const kA3 = Color(0xFFE07A0E);   // dark
const kGlow = Color(0x8CF7931A); // rgba(247,147,26,0.55)

// Dark theme surfaces
const _kBg       = Color(0xFF0B0B0D);
const _kBgElev   = Color(0xFF111114);
const _kCard     = Color(0xFF17171B);
const _kCardElev = Color(0xFF1C1C22);
const _kBorder   = Color(0xFF26262D);
const _kText     = Color(0xFFF5F5F7);
const _kTextDim  = Color(0xFFB3B3B8);
const _kMuted    = Color(0xFF6E6E75);

// Status
const kPositive = Color(0xFF30D158);
const kWarn     = Color(0xFFFF9F0A);
const kDanger   = Color(0xFFFF453A);

// Light theme surfaces
const _kBgLight      = Color(0xFFF6F5F1);
const _kBgElevLight  = Color(0xFFFBFAF7);
const _kCardLight    = Color(0xFFFFFFFF);
const _kBorderLight  = Color(0xFFE8E5DE);
const _kTextLight    = Color(0xFF1A1A1E);
const _kTextDimLight = Color(0xFF56565C);

// Zone colors (per-room palette)
const kZoneColors = <Color>[
  Color(0xFFFFB340), // Гостиная
  Color(0xFFFF9F43), // Кухня
  Color(0xFF4A9CFF), // Кабинет
  Color(0xFFAB7BFF), // Спальня
  Color(0xFF30D158), // Балкон
  Color(0xFFFF6B35), // Коридор
  Color(0xFFFF453A),
  Color(0xFF42A5F5),
];

// Sunrise gradient — the brand gradient
const kSunriseGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [kA1, kA2, kA3],
  stops: [0.0, 0.55, 1.0],
);

const kSunriseGradientTL = LinearGradient(
  begin: Alignment(-1.0, -1.0),
  end: Alignment(1.0, 1.0),
  colors: [kA1, kA2, kA3],
  stops: [0.0, 0.55, 1.0],
);

// ── ThemeExtension ─────────────────────────────────────────────────────────────

class SMTheme extends ThemeExtension<SMTheme> {
  final Color bg;
  final Color bgElev;
  final Color card;
  final Color cardElev;
  final Color border;
  final Color hair;
  final Color text;
  final Color textDim;
  final Color muted;
  final Color a1;
  final Color a2;
  final Color a3;
  final Color glow;
  final Color positive;
  final Color warn;
  final Color danger;

  const SMTheme({
    required this.bg,
    required this.bgElev,
    required this.card,
    required this.cardElev,
    required this.border,
    required this.hair,
    required this.text,
    required this.textDim,
    required this.muted,
    required this.a1,
    required this.a2,
    required this.a3,
    required this.glow,
    required this.positive,
    required this.warn,
    required this.danger,
  });

  static const SMTheme dark = SMTheme(
    bg: _kBg,
    bgElev: _kBgElev,
    card: _kCard,
    cardElev: _kCardElev,
    border: _kBorder,
    hair: Color(0x0FFFFFFF),
    text: _kText,
    textDim: _kTextDim,
    muted: _kMuted,
    a1: kA1,
    a2: kA2,
    a3: kA3,
    glow: kGlow,
    positive: kPositive,
    warn: kWarn,
    danger: kDanger,
  );

  static const SMTheme light = SMTheme(
    bg: _kBgLight,
    bgElev: _kBgElevLight,
    card: _kCardLight,
    cardElev: Color(0xFFF2F1EE),
    border: _kBorderLight,
    hair: Color(0x0D000000),
    text: _kTextLight,
    textDim: _kTextDimLight,
    muted: Color(0xFF6E6E75),
    a1: kA1,
    a2: kA2,
    a3: kA3,
    glow: kGlow,
    positive: Color(0xFF30A84A),
    warn: kWarn,
    danger: kDanger,
  );

  @override
  SMTheme copyWith({
    Color? bg,
    Color? bgElev,
    Color? card,
    Color? cardElev,
    Color? border,
    Color? hair,
    Color? text,
    Color? textDim,
    Color? muted,
    Color? a1,
    Color? a2,
    Color? a3,
    Color? glow,
    Color? positive,
    Color? warn,
    Color? danger,
  }) {
    return SMTheme(
      bg: bg ?? this.bg,
      bgElev: bgElev ?? this.bgElev,
      card: card ?? this.card,
      cardElev: cardElev ?? this.cardElev,
      border: border ?? this.border,
      hair: hair ?? this.hair,
      text: text ?? this.text,
      textDim: textDim ?? this.textDim,
      muted: muted ?? this.muted,
      a1: a1 ?? this.a1,
      a2: a2 ?? this.a2,
      a3: a3 ?? this.a3,
      glow: glow ?? this.glow,
      positive: positive ?? this.positive,
      warn: warn ?? this.warn,
      danger: danger ?? this.danger,
    );
  }

  @override
  SMTheme lerp(ThemeExtension<SMTheme>? other, double t) {
    if (other is! SMTheme) return this;
    return SMTheme(
      bg: Color.lerp(bg, other.bg, t)!,
      bgElev: Color.lerp(bgElev, other.bgElev, t)!,
      card: Color.lerp(card, other.card, t)!,
      cardElev: Color.lerp(cardElev, other.cardElev, t)!,
      border: Color.lerp(border, other.border, t)!,
      hair: Color.lerp(hair, other.hair, t)!,
      text: Color.lerp(text, other.text, t)!,
      textDim: Color.lerp(textDim, other.textDim, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      a1: Color.lerp(a1, other.a1, t)!,
      a2: Color.lerp(a2, other.a2, t)!,
      a3: Color.lerp(a3, other.a3, t)!,
      glow: Color.lerp(glow, other.glow, t)!,
      positive: Color.lerp(positive, other.positive, t)!,
      warn: Color.lerp(warn, other.warn, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
    );
  }
}

// ── AppTheme ───────────────────────────────────────────────────────────────────

class AppTheme {
  // Backward-compat constants
  static const Color accentColor = kA2;
  static const Color darkBg = _kBg;
  static const Color darkCard = _kCard;
  static const Color darkBorder = _kBorder;
  static const Color mutedText = _kMuted;

  static TextTheme _buildTextTheme(TextTheme base) {
    return GoogleFonts.manropeTextTheme(base);
  }

  static ThemeData get darkTheme {
    final base = _buildTextTheme(ThemeData.dark().textTheme);
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: GoogleFonts.manrope().fontFamily,
      scaffoldBackgroundColor: _kBg,
      textTheme: base,
      colorScheme: ColorScheme.dark(
        primary: kA2,
        surface: _kCard,
        secondary: kA1,
        onSurface: _kText,
        surfaceContainerHighest: _kCardElev,
        onPrimary: Colors.black,
        error: kDanger,
      ),
      extensions: const [SMTheme.dark],
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.manrope(
          fontSize: 17,
          fontWeight: FontWeight.w800,
          color: _kText,
          letterSpacing: -0.3,
        ),
        iconTheme: const IconThemeData(color: _kText),
      ),
      cardTheme: CardThemeData(
        color: _kCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        elevation: 0,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: kA2,
          foregroundColor: Colors.black,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: GoogleFonts.manrope(
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: _kText,
          side: const BorderSide(color: _kBorder),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: kA2,
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _kCardElev,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: _kBorder, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: _kBorder, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: kA2, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: kDanger, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: kDanger, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        hintStyle: const TextStyle(color: _kMuted, fontSize: 14),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: _kCardElev,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        contentTextStyle: const TextStyle(color: _kText),
      ),
      dividerTheme: const DividerThemeData(color: _kBorder, thickness: 1),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected)
              ? const Color(0xFF1A0F00)
              : Colors.white54;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected) ? kA2 : Colors.white24;
        }),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }

  static ThemeData get lightTheme {
    final base = _buildTextTheme(ThemeData.light().textTheme);
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      fontFamily: GoogleFonts.manrope().fontFamily,
      scaffoldBackgroundColor: _kBgLight,
      textTheme: base,
      colorScheme: const ColorScheme.light(
        primary: kA2,
        surface: _kCardLight,
        secondary: kA1,
        onSurface: _kTextLight,
        surfaceContainerHighest: Color(0xFFF2F1EE),
        onPrimary: Colors.black,
        error: kDanger,
      ),
      extensions: const [SMTheme.light],
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.manrope(
          fontSize: 17,
          fontWeight: FontWeight.w800,
          color: _kTextLight,
          letterSpacing: -0.3,
        ),
        iconTheme: const IconThemeData(color: _kTextLight),
      ),
      cardTheme: CardThemeData(
        color: _kCardLight,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        elevation: 0,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: kA2,
          foregroundColor: Colors.black,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: GoogleFonts.manrope(
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: _kTextLight,
          side: const BorderSide(color: _kBorderLight),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: kA2,
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _kBgElevLight,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: _kBorderLight, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: _kBorderLight, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: kA2, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: kDanger, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: kDanger, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        hintStyle: const TextStyle(color: Color(0xFF8E8E93), fontSize: 14),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: _kTextLight,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        contentTextStyle: const TextStyle(color: Colors.white),
      ),
      dividerTheme: const DividerThemeData(color: _kBorderLight, thickness: 1),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected)
              ? const Color(0xFF1A0F00)
              : Colors.grey;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected)
              ? kA2
              : Colors.grey.withValues(alpha: 0.3);
        }),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }
}
