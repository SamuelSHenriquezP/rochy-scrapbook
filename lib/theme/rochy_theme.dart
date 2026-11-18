import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/bento_node.dart';

/// Definición de temas editoriales para "Rochy".
@immutable
class RochyThemeData {
  const RochyThemeData({
    required this.id,
    required this.name,
    required this.description,
    required this.brightness,
    required this.canvasBackground,
    required this.canvasSecondary,
    required this.navBarBackground,
    required this.ivorySurface,
    required this.sandSurface,
    required this.terracotta,
    required this.sage,
    required this.espresso,
    required this.charcoal,
    required this.inkPrimary,
    required this.inkSecondary,
    required this.brandAccent,
    required this.haloColor,
    required this.borderTint,
  });

  final String id;
  final String name;
  final String description;
  final Brightness brightness;
  final Color canvasBackground;
  final Color canvasSecondary;
  final Color navBarBackground;
  final Color ivorySurface;
  final Color sandSurface;
  final Color terracotta;
  final Color sage;
  final Color espresso;
  final Color charcoal;
  final Color inkPrimary;
  final Color inkSecondary;
  final Color brandAccent;
  final Color haloColor;
  final Color borderTint;

  /// Resuelve el color de fondo de una tarjeta según su [BentoColorTheme].
  Color cardSurface(BentoColorTheme theme) {
    return switch (theme) {
      BentoColorTheme.ivory => ivorySurface,
      BentoColorTheme.sand => sandSurface,
      BentoColorTheme.espresso => espresso,
      BentoColorTheme.terracotta => terracotta,
      BentoColorTheme.sage => sage,
      BentoColorTheme.charcoal => charcoal,
    };
  }

  /// Determina si el fondo de la tarjeta requiere tinta clara (crema/marfil).
  bool usesLightInk(BentoColorTheme theme) {
    return switch (theme) {
      BentoColorTheme.espresso ||
      BentoColorTheme.terracotta ||
      BentoColorTheme.sage ||
      BentoColorTheme.charcoal =>
        true,
      BentoColorTheme.ivory || BentoColorTheme.sand => brightness == Brightness.dark,
    };
  }

  Color cardPrimaryText(BentoColorTheme theme) {
    return usesLightInk(theme) ? const Color(0xFFFAF7F2) : inkPrimary;
  }

  Color cardSecondaryText(BentoColorTheme theme) {
    return usesLightInk(theme)
        ? const Color(0xFFFAF7F2).withValues(alpha: 0.80)
        : inkSecondary;
  }

  /// Resuelve el color de fondo real de un nodo (personalizado o por tema).
  Color resolveNodeBackground(BentoNode node) {
    if (node.customBgColorHex != null) {
      return Color(node.customBgColorHex!);
    }
    return cardSurface(node.colorTheme);
  }

  /// Calcula contraste legible automático incluso cuando el usuario elige color propio.
  bool nodeUsesLightInk(BentoNode node) {
    if (node.customBgColorHex != null) {
      return Color(node.customBgColorHex!).computeLuminance() < 0.38;
    }
    return usesLightInk(node.colorTheme);
  }

  Color resolveNodePrimaryInk(BentoNode node) {
    if (node.customTextColorHex != null) {
      return Color(node.customTextColorHex!);
    }
    return nodeUsesLightInk(node) ? const Color(0xFFFAF7F2) : inkPrimary;
  }

  Color resolveNodeSecondaryInk(BentoNode node) {
    final base = resolveNodePrimaryInk(node);
    return nodeUsesLightInk(node)
        ? base.withValues(alpha: 0.82)
        : inkSecondary;
  }

  ThemeData toMaterialTheme() {
    final base = brightness == Brightness.dark
        ? ThemeData.dark(useMaterial3: true)
        : ThemeData.light(useMaterial3: true);

    return base.copyWith(
      scaffoldBackgroundColor: canvasBackground,
      colorScheme: base.colorScheme.copyWith(
        primary: brandAccent,
        secondary: sage,
        surface: ivorySurface,
        onSurface: inkPrimary,
      ),
      textTheme: GoogleFonts.plusJakartaSansTextTheme(base.textTheme).apply(
        bodyColor: inkPrimary,
        displayColor: inkPrimary,
      ),
      splashFactory: InkSparkle.splashFactory,
    );
  }
}

/// Catálogo curado de temas táctiles para Rochy (finito y coherente).
abstract final class RochyThemes {
  static const arenaCalida = RochyThemeData(
    id: 'arena_calida',
    name: 'Arena Cálida',
    description: 'Papel marfil, café tostado y terracota de mañana.',
    brightness: Brightness.light,
    canvasBackground: Color(0xFFFBF8F5),
    canvasSecondary: Color(0xFFF5F0EA),
    navBarBackground: Color(0xFFFAF6F0),
    ivorySurface: Color(0xFFF5F1EB),
    sandSurface: Color(0xFFEFE8DF),
    terracotta: Color(0xFFA85338),
    sage: Color(0xFF5B6E58),
    espresso: Color(0xFF6B3D22),
    charcoal: Color(0xFF382923),
    inkPrimary: Color(0xFF2E221D),
    inkSecondary: Color(0xFF705E54),
    brandAccent: Color(0xFFA85338),
    haloColor: Color(0xFFD5835B),
    borderTint: Color(0x66FFFFFF),
  );

  static const atardecerTerracota = RochyThemeData(
    id: 'atardecer_terracota',
    name: 'Atardecer Baloco',
    description: 'Luz dorada de tarde con arcilla tibia y lino tostado.',
    brightness: Brightness.light,
    canvasBackground: Color(0xFFF8F1EA),
    canvasSecondary: Color(0xFFF0E4D8),
    navBarBackground: Color(0xFFFBF6F0),
    ivorySurface: Color(0xFFFAF4EC),
    sandSurface: Color(0xFFEDDCD0),
    terracotta: Color(0xFFB55A3C),
    sage: Color(0xFF65765C),
    espresso: Color(0xFF573322),
    charcoal: Color(0xFF34241E),
    inkPrimary: Color(0xFF32211A),
    inkSecondary: Color(0xFF7A6155),
    brandAccent: Color(0xFFB55A3C),
    haloColor: Color(0xFFE09169),
    borderTint: Color(0x70FFFFFF),
  );

  static const bosqueSalvia = RochyThemeData(
    id: 'bosque_salvia',
    name: 'Hojas de Salvia',
    description: 'Calma botánica en tonos olivo suave y papel algodón.',
    brightness: Brightness.light,
    canvasBackground: Color(0xFFF6F7F2),
    canvasSecondary: Color(0xFFECEFE6),
    navBarBackground: Color(0xFFFAFBF7),
    ivorySurface: Color(0xFFF2F4EC),
    sandSurface: Color(0xFFE4E8DC),
    terracotta: Color(0xFF9E5A44),
    sage: Color(0xFF4F644C),
    espresso: Color(0xFF5C4435),
    charcoal: Color(0xFF2D352C),
    inkPrimary: Color(0xFF252D24),
    inkSecondary: Color(0xFF606D5E),
    brandAccent: Color(0xFF4F644C),
    haloColor: Color(0xFF8AA484),
    borderTint: Color(0x66FFFFFF),
  );

  static const papelNocturno = RochyThemeData(
    id: 'papel_nocturno',
    name: 'Tinta de Noche',
    description: 'Modo íntimo nocturno en café profundo y latón cálido.',
    brightness: Brightness.dark,
    canvasBackground: Color(0xFF1E1815),
    canvasSecondary: Color(0xFF271F1B),
    navBarBackground: Color(0xFF231C18),
    ivorySurface: Color(0xFF2C231E),
    sandSurface: Color(0xFF352A24),
    terracotta: Color(0xFF9F5036),
    sage: Color(0xFF4E604B),
    espresso: Color(0xFF553321),
    charcoal: Color(0xFF3E3029),
    inkPrimary: Color(0xFFF5EFE7),
    inkSecondary: Color(0xFFC2B2A6),
    brandAccent: Color(0xFFD27D5E),
    haloColor: Color(0xFFE59A78),
    borderTint: Color(0x24FFFFFF),
  );

  static const List<RochyThemeData> all = [
    arenaCalida,
    atardecerTerracota,
    bosqueSalvia,
    papelNocturno,
  ];

  static RochyThemeData byId(String id) {
    return all.firstWhere(
      (t) => t.id == id,
      orElse: () => arenaCalida,
    );
  }
}

/// Tipografías editoriales contrastadas (Serif + Manuscrita + Sans-Serif).
abstract final class RochyTypography {
  static TextStyle brandTitle(Color color) => GoogleFonts.playfairDisplay(
        fontSize: 28,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.4,
        color: color,
      );

  static TextStyle cardSerifTitle(
    Color color, {
    double fontSize = 17,
    FontWeight fontWeight = FontWeight.w600,
    FontStyle fontStyle = FontStyle.normal,
    double height = 1.22,
  }) =>
      GoogleFonts.playfairDisplay(
        fontSize: fontSize,
        fontWeight: fontWeight,
        fontStyle: fontStyle,
        height: height,
        color: color,
      );

  static TextStyle editorialQuote(
    Color color, {
    double fontSize = 20,
  }) =>
      GoogleFonts.playfairDisplay(
        fontSize: fontSize,
        fontWeight: FontWeight.w500,
        fontStyle: FontStyle.italic,
        height: 1.30,
        letterSpacing: -0.2,
        color: color,
      );

  static TextStyle handwrittenTitle(
    Color color, {
    double fontSize = 24,
  }) =>
      GoogleFonts.caveat(
        fontSize: fontSize,
        fontWeight: FontWeight.w600,
        height: 1.05,
        color: color,
      );

  static TextStyle sansTitle(
    Color color, {
    double fontSize = 14.5,
    FontWeight fontWeight = FontWeight.w700,
    double height = 1.25,
  }) =>
      GoogleFonts.plusJakartaSans(
        fontSize: fontSize,
        fontWeight: fontWeight,
        height: height,
        letterSpacing: -0.15,
        color: color,
      );

  static TextStyle sansBody(
    Color color, {
    double fontSize = 13,
    FontWeight fontWeight = FontWeight.w400,
    double height = 1.38,
  }) =>
      GoogleFonts.plusJakartaSans(
        fontSize: fontSize,
        fontWeight: fontWeight,
        height: height,
        color: color,
      );

  static TextStyle metadata(
    Color color, {
    double fontSize = 11.5,
    FontWeight fontWeight = FontWeight.w500,
  }) =>
      GoogleFonts.inter(
        fontSize: fontSize,
        fontWeight: fontWeight,
        letterSpacing: 0.15,
        color: color,
      );

  /// Resuelve dinámicamente el estilo tipográfico elegido por tarjeta.
  static TextStyle resolveCardTitle(
    BentoFontStyle style,
    Color color, {
    double fontSize = 16.5,
    FontWeight fontWeight = FontWeight.w600,
    FontStyle fontStyle = FontStyle.normal,
  }) {
    return switch (style) {
      BentoFontStyle.editorialSerif => cardSerifTitle(
          color,
          fontSize: fontSize,
          fontWeight: fontWeight,
          fontStyle: fontStyle,
        ),
      BentoFontStyle.handwritten => handwrittenTitle(
          color,
          fontSize: fontSize + 4.5,
        ),
      BentoFontStyle.cleanSans => sansTitle(
          color,
          fontSize: fontSize - 1.5,
          fontWeight: fontWeight,
        ),
      BentoFontStyle.monoTypewriter => GoogleFonts.spaceMono(
          fontSize: fontSize - 2.2,
          fontWeight: fontWeight,
          height: 1.24,
          letterSpacing: -0.3,
          color: color,
        ),
    };
  }

  static TextAlign toFlutterTextAlign(BentoTextAlign align) {
    return switch (align) {
      BentoTextAlign.left => TextAlign.left,
      BentoTextAlign.center => TextAlign.center,
      BentoTextAlign.right => TextAlign.right,
    };
  }
}
