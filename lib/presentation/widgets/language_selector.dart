import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../domain/entities/language_model.dart';
import '../providers/detection_provider.dart';

/// Sélecteur de langue flottant — pill horizontal.
///
/// - Langue active : highlight cyan + animation d'entrée.
/// - Langues "coming soon" : grisées avec badge "Soon".
/// - Tap sur "coming soon" → snackbar informatif (simulation).
class LanguageSelector extends StatelessWidget {
  const LanguageSelector({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DetectionProvider>();

    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(40),
          color: Colors.black.withValues(alpha: 0.55),
          border: Border.all(color: AppTheme.glassBorder, width: 1),
          boxShadow: [
            BoxShadow(
              color: AppTheme.neon.withValues(alpha: 0.08),
              blurRadius: 20,
              spreadRadius: -2,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: provider.availableModels.map((model) {
            final isSelected =
                model.code == provider.selectedLanguageCode;
            return _LanguageChip(
              model: model,
              isSelected: isSelected,
              onTap: () => _onTap(context, provider, model),
            );
          }).toList(),
        ),
      ).animate().fadeIn(delay: 300.ms, duration: 400.ms).slideY(begin: 0.4),
    );
  }

  void _onTap(
    BuildContext context,
    DetectionProvider provider,
    LanguageModel model,
  ) {
    if (model.isComingSoon) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppTheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: AppTheme.glassBorder),
          ),
          content: Row(
            children: [
              Text(model.flag, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${model.displayName} model coming soon',
                  style: GoogleFonts.inter(
                    color: AppTheme.textPrimary,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }
    provider.selectLanguage(model.code);
  }
}

class _LanguageChip extends StatelessWidget {
  const _LanguageChip({
    required this.model,
    required this.isSelected,
    required this.onTap,
  });

  final LanguageModel model;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDisabled = model.isComingSoon;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(32),
          color: isSelected
              ? AppTheme.neon.withValues(alpha: 0.18)
              : Colors.transparent,
          border: Border.all(
            color: isSelected
                ? AppTheme.neon.withValues(alpha: 0.5)
                : Colors.transparent,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drapeau
            Text(model.flag, style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 6),

            // Code langue
            Text(
              model.code.toUpperCase(),
              style: GoogleFonts.jetBrainsMono(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isSelected
                    ? AppTheme.neon
                    : isDisabled
                        ? AppTheme.textDisabled
                        : AppTheme.textSecondary,
                letterSpacing: 1,
              ),
            ),

            // Badge "Soon"
            if (isDisabled) ...[
              const SizedBox(width: 5),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  color: AppTheme.warning.withValues(alpha: 0.15),
                  border: Border.all(
                    color: AppTheme.warning.withValues(alpha: 0.35),
                    width: 0.8,
                  ),
                ),
                child: Text(
                  'Soon',
                  style: GoogleFonts.inter(
                    fontSize: 8,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.warning,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ],

            // Dot actif
            if (isSelected) ...[
              const SizedBox(width: 6),
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.neon,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
