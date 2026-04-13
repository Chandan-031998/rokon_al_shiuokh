import 'package:flutter/material.dart';

class AppColors {
  static const Color background = Color(0xFFF6F1EA);
  static const Color surface = Color(0xFFFFFBF7);
  static const Color primaryDark = Color(0xFF3B1F14);
  static const Color primary = Color(0xFF5A2E1F);
  static const Color secondary = Color(0xFF8B5E34);
  static const Color accentGold = Color(0xFFC89B5A);
  static const Color accentLightGold = Color(0xFFE8CFA4);
  static const Color muted = Color(0xFFBFA58A);
  static const Color headingText = Color(0xFF2B1A12);
  static const Color bodyText = Color(0xFF6A5446);
  static const Color white = Color(0xFFFFFFFF);
  static const Color surfaceRaised = Color(0xFFF9F2E8);
  static const Color surfaceSoft = Color(0xFFF2E5D3);
  static const Color border = Color(0xFFE4D3BF);
  static const Color borderStrong = Color(0xFFD3B489);
  static const Color glassLight = Color(0x52FFFFFF);
  static const Color glassDark = Color(0x142B1A12);

  static const Color brownDeep = primaryDark;
  static const Color brown = primary;
  static const Color brownSoft = secondary;
  static const Color gold = accentGold;
  static const Color goldMuted = secondary;
  static const Color cream = background;
  static const Color creamSoft = surfaceSoft;
  static const Color textDark = headingText;
  static const Color textMuted = bodyText;

  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF2F170F),
      Color(0xFF5A2E1F),
      Color(0xFF8B5E34),
      Color(0xFFC89B5A),
    ],
    stops: [0.0, 0.34, 0.72, 1.0],
  );

  static const LinearGradient surfaceGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFFFFCF9),
      Color(0xFFF8F0E4),
    ],
  );

  static const LinearGradient softPanelGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFFFFFCF8),
      Color(0xFFF5ECE1),
    ],
  );

  static const LinearGradient goldGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFEBD6AE),
      Color(0xFFC89B5A),
    ],
  );

  static const LinearGradient logoBackgroundGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFFFF9F1),
      Color(0xFFF2E1C4),
    ],
  );

  static const List<BoxShadow> softShadow = [
    BoxShadow(
      color: Color(0x122B1A12),
      blurRadius: 18,
      offset: Offset(0, 8),
    ),
  ];

  static const List<BoxShadow> panelShadow = [
    BoxShadow(
      color: Color(0x1A2B1A12),
      blurRadius: 28,
      offset: Offset(0, 14),
    ),
  ];

  static const List<BoxShadow> strongShadow = [
    BoxShadow(
      color: Color(0x262B1A12),
      blurRadius: 36,
      offset: Offset(0, 18),
    ),
  ];
}
