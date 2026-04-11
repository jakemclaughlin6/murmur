// D-18/D-19 locked color palette. "Quiet library" aesthetic — cream paper,
// oat borders, warm neutrals, no vivid accents. The Clay swatch palette
// (Matcha/Slushie/Lemon/Ube/etc) is NOT adopted — only the neutral base.
import 'package:flutter/material.dart';

/// Clay-neutrals palette for Phase 1's 4 themes.
/// LOCKED values — do not edit without a new CONTEXT.md decision.
class ClayColors {
  ClayColors._();

  // === Light theme (D-18, LOCKED) ===
  static const background = Color(0xFFFAF9F7);       // warm cream — page canvas
  static const surface = Color(0xFFFFFFFF);          // pure white — cards
  static const borderDefault = Color(0xFFDAD4C8);    // oat border
  static const borderSubtle = Color(0xFFEEE9DF);     // oat light
  static const textPrimary = Color(0xFF000000);      // black
  static const textSecondary = Color(0xFF55534E);    // warm charcoal
  static const textTertiary = Color(0xFF9F9B93);     // warm silver

  /// D-18 accent — planner LOCKED to matcha-800 (`#02492A`) per research recommendation.
  /// Rationale: warmer and harmonizes with cream background; blueberry-800 (#01418D)
  /// is cooler and fights the warm-neutral ecosystem.
  static const accent = Color(0xFF02492A);           // Clay matcha-800

  // === Sepia theme (D-19 constraints, planner-locked values) ===
  static const sepiaBackground = Color(0xFFF4ECD8);  // warm paper
  static const sepiaSurface = Color(0xFFFAF4E1);
  static const sepiaTextPrimary = Color(0xFF4A3E2A); // warm dark brown
  static const sepiaTextSecondary = Color(0xFF6B5C42);
  static const sepiaBorder = Color(0xFFD9CDB1);
  static const sepiaAccent = Color(0xFF8B6F3F);      // warm amber-ink

  // === Dark theme (D-19 constraints, planner-locked values) ===
  static const darkBackground = Color(0xFF121212);   // near-black, not pure
  static const darkSurface = Color(0xFF1C1C1C);
  static const darkTextPrimary = Color(0xFFF5EFE2);  // warm off-white
  static const darkTextSecondary = Color(0xFFB3AA9A);
  static const darkBorder = Color(0xFF2A2A2A);
  static const darkAccent = Color(0xFF4A8F5F);       // warm muted matcha echo

  // === OLED theme (D-19 constraints, planner-locked values) ===
  static const oledBackground = Color(0xFF000000);   // true black for AMOLED
  static const oledSurface = Color(0xFF0A0A0A);
  static const oledTextPrimary = Color(0xFFEDE6D4);  // slightly cooler than dark
  static const oledTextSecondary = Color(0xFFA39C8C);
  static const oledBorder = Color(0xFF1A1A1A);       // near-invisible hairline
  static const oledAccent = Color(0xFF4A8F5F);
}
