import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Brand Colors (Synced with Parent & Student App)
  static const Color primary = Color(0xFF6C3CE9); // Modern Royal Purple
  static const Color primaryLight = Color(0xFFEDE7F6);
  static const Color primaryDark = Color(0xFF4A148C);
  static const Color secondary = Color(0xFF8E24AA); // Electric Magenta
  static const Color accent = Color(0xFF00D2D3); // Radiant Cyan/Teal

  // Neutral Colors
  static const Color dark = Color(0xFF13132B);
  static const Color grey = Color(0xFF8A94A6);
  static const Color greyLight = Color(0xFFF1F3F6);
  static const Color lightBg = Color(0xFFF7F8FC);
  static const Color cardBg = Colors.white;

  // Status & Accent Colors
  static const Color green = Color(0xFF05C46B);
  static const Color greenLight = Color(0xFFE8F8F0);
  static const Color orange = Color(0xFFFF9F1A);
  static const Color orangeLight = Color(0xFFFFF4E5);
  static const Color blue = Color(0xFF2E86DE);
  static const Color blueLight = Color(0xFFE8F1FC);
  static const Color purple = Color(0xFF9B59B6);
  static const Color purpleLight = Color(0xFFF5EEF8);
  static const Color teal = Color(0xFF00B894);
  static const Color tealLight = Color(0xFFE6F8F4);
  static const Color red = Color(0xFFFF3838);
  static const Color redLight = Color(0xFFFFECEC);
  static const Color amber = Color(0xFFFF9F1A);
  static const Color amberLight = Color(0xFFFFF4E5);
  static const Color gold = Color(0xFFFFC048);
  static const Color goldLight = Color(0xFFFFF4E5);
  static const Color coral = Color(0xFFFF6F61);
  static const Color coralLight = Color(0xFFFFECE9);

  // Admin Theme Mappings (100% Backward Compatibility)
  static const Color royalBlue = primary; // Unified Modern Royal Purple
  static const Color emerald = green;
  static const Color emeraldLight = greenLight;
  static const Color crimson = red;
  static const Color crimsonLight = redLight;
  static const Color rose = coral;
  static const Color roseLight = coralLight;
  static const Color violet = secondary;
  static const Color violetLight = purpleLight;
  static const Color background = lightBg;
  static const Color cardSurface = cardBg;
  static const Color textMain = dark;
  static const Color textPrimary = dark;
  static const Color textMuted = grey;
  static const Color border = Color(0xFFEFF2F7);
  static const Color borderLight = Color(0xFFEFF2F7);
  static const Color glassBorder = Color(0xFFEFF2F7);
  static const Color primaryNavy = Color(0xFF151528);

  // Gray Hierarchy
  static const Color iosGray1 = grey;
  static const Color iosGray2 = Color(0xFFA0ABC0);
  static const Color iosGray3 = Color(0xFFCBD5E1);
  static const Color iosGray4 = Color(0xFFE2E8F0);
  static const Color iosGray5 = Color(0xFFEFF2F7);
  static const Color iosGray6 = Color(0xFFF7F8FC);

  // Dark Mode Palette
  static const Color darkBg = Color(0xFF0A0A16);
  static const Color darkCard = Color(0xFF151528);
  static const Color darkSurface = Color(0xFF1E1E38);
  static const Color darkBorder = Color(0xFF282846);

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, Color(0xFF8E24AA)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cyanGradient = LinearGradient(
    colors: [Color(0xFF00D2D3), Color(0xFF2E86DE)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient amberGradient = LinearGradient(
    colors: [Color(0xFFFF9F1A), Color(0xFFFF6B6B)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient greenGradient = LinearGradient(
    colors: [Color(0xFF05C46B), Color(0xFF00B894)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient darkCardGradient = LinearGradient(
    colors: [Color(0xFF1A1A32), Color(0xFF121224)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Clean Component Decorators
  static BoxDecoration iosCard({
    Color? color,
    BorderRadius? borderRadius,
    Border? border,
  }) {
    return BoxDecoration(
      color: color ?? cardSurface,
      borderRadius: borderRadius ?? BorderRadius.circular(20),
      border: border ?? Border.all(color: borderLight, width: 1.2),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.04),
          blurRadius: 14,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  static Widget iosHandle() {
    return Center(
      child: Container(
        width: 36,
        height: 5,
        decoration: BoxDecoration(
          color: const Color(0xFFD1D1D6),
          borderRadius: BorderRadius.circular(2.5),
        ),
      ),
    );
  }

  // Light Theme Builder
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      textTheme: GoogleFonts.plusJakartaSansTextTheme().apply(
        bodyColor: textMain,
        displayColor: textMain,
      ),
      scaffoldBackgroundColor: lightBg,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        brightness: Brightness.light,
        primary: primary,
        secondary: secondary,
        surface: cardBg,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: lightBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.plusJakartaSans(
          color: textMain,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
        iconTheme: const IconThemeData(color: primary),
      ),
      cardTheme: CardThemeData(
        color: cardBg,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: borderLight, width: 1.2),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 14),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          side: const BorderSide(color: borderLight, width: 1.2),
          textStyle: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: borderLight, width: 1.2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: borderLight, width: 1.2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: primary, width: 2),
        ),
        hintStyle: GoogleFonts.plusJakartaSans(color: grey, fontSize: 13),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: primary,
        unselectedLabelColor: grey,
        indicatorColor: primary,
        indicatorSize: TabBarIndicatorSize.label,
        labelStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 13),
        unselectedLabelStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, fontSize: 13),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        titleTextStyle: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w800, color: dark),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        contentTextStyle: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white),
      ),
      dividerTheme: const DividerThemeData(
        color: borderLight,
        thickness: 0.8,
        space: 1,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white.withOpacity(0.96),
        elevation: 0,
        indicatorColor: primaryLight,
        labelTextStyle: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: primary);
          }
          return const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: textMuted);
        }),
        iconTheme: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return const IconThemeData(color: primary, size: 24);
          }
          return const IconThemeData(color: textMuted, size: 24);
        }),
      ),
    );
  }

  // Dark Theme Builder
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      textTheme: GoogleFonts.plusJakartaSansTextTheme(ThemeData.dark().textTheme),
      scaffoldBackgroundColor: darkBg,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        brightness: Brightness.dark,
        primary: primary,
        secondary: secondary,
        surface: darkCard,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: darkBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.plusJakartaSans(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      cardTheme: CardThemeData(
        color: darkCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: darkBorder, width: 1.2),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 14),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkCard,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: darkBorder, width: 1.2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: darkBorder, width: 1.2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: primary, width: 2),
        ),
        hintStyle: GoogleFonts.plusJakartaSans(color: grey, fontSize: 13),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: primary,
        unselectedLabelColor: grey,
        indicatorColor: primary,
        indicatorSize: TabBarIndicatorSize.label,
        labelStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 13),
        unselectedLabelStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, fontSize: 13),
      ),
    );
  }

  static ThemeData get theme => lightTheme;
}
