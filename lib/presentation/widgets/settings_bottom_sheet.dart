import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../providers/detection_provider.dart';

/// Panneau de paramètres — Bottom Sheet coulissant style Glassmorphism.
///
/// Contient :
/// - Seuil de confiance (slider avec valeur en temps réel)
/// - Info sur le modèle actif
/// - Espace réservé pour la gestion du stockage des modèles
class SettingsBottomSheet extends StatelessWidget {
  const SettingsBottomSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(
          top: BorderSide(color: AppTheme.glassBorder, width: 1),
          left: BorderSide(color: AppTheme.glassBorder, width: 1),
          right: BorderSide(color: AppTheme.glassBorder, width: 1),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Handle ────────────────────────────────────────
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.glassBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // ── Titre ─────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                const Icon(Icons.tune_outlined,
                    color: AppTheme.neon, size: 20),
                const SizedBox(width: 10),
                Text(
                  'Detection Settings',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── Confidence Threshold ──────────────────────────
          const _ConfidenceSection(),

          const _Divider(),

          // ── Modèle actif ──────────────────────────────────
          const _ActiveModelSection(),

          const _Divider(),

          // ── Stockage modèles ──────────────────────────────
          const _ModelStorageSection(),

          SizedBox(
            height: MediaQuery.of(context).padding.bottom + 24,
          ),
        ],
      ),
    );
  }
}

// ── Confidence Threshold ─────────────────────────────────────────────────────

class _ConfidenceSection extends StatelessWidget {
  const _ConfidenceSection();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DetectionProvider>();
    final value = provider.confidenceThreshold;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Confidence Threshold',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              // Valeur en temps réel — monospace pour éviter le layout shift
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.neon.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppTheme.neon.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Text(
                  '${(value * 100).round()}%',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 13,
                    color: AppTheme.neon,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Filter out detections below this confidence level.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),

          // Slider esthétique
          SliderTheme(
            data: Theme.of(context).sliderTheme.copyWith(
              trackHeight: 4,
              thumbShape: _GlowThumbShape(color: AppTheme.bbColor(value)),
              activeTrackColor: AppTheme.bbColor(value),
              overlayColor: AppTheme.bbColor(value).withValues(alpha: 0.15),
            ),
            child: Slider(
              value: value,
              min: 0.1,
              max: 0.95,
              divisions: 17,
              onChanged: provider.setConfidenceThreshold,
            ),
          ),

          // Labels min/max
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('10% — permissive',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppTheme.textDisabled,
                    fontSize: 10,
                  )),
              Text('95% — strict',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppTheme.textDisabled,
                    fontSize: 10,
                  )),
            ],
          ),
        ],
      ),
    );
  }
}

/// Thumb personnalisé avec halo de couleur dynamique.
class _GlowThumbShape extends SliderComponentShape {
  const _GlowThumbShape({required this.color});
  final Color color;

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) =>
      const Size(20, 20);

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final canvas = context.canvas;

    // Glow
    canvas.drawCircle(
      center,
      14,
      Paint()
        ..color = color.withValues(alpha: 0.25)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );

    // Cercle blanc
    canvas.drawCircle(center, 10, Paint()..color = Colors.white);

    // Point central coloré
    canvas.drawCircle(center, 4, Paint()..color = color);
  }
}

// ── Modèle actif ─────────────────────────────────────────────────────────────

class _ActiveModelSection extends StatelessWidget {
  const _ActiveModelSection();

  @override
  Widget build(BuildContext context) {
    final model = context.watch<DetectionProvider>().currentModel;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.neon.withValues(alpha: 0.1),
              border: Border.all(
                color: AppTheme.neon.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Center(
              child: Text(model.flag,
                  style: const TextStyle(fontSize: 20)),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Active model',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${model.displayName} (${model.nativeName})',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                Text(
                  model.labelsAssetPath.split('/').last,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 10,
                    color: AppTheme.textDisabled,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.success.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppTheme.success.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Text(
              'Active',
              style: GoogleFonts.inter(
                fontSize: 11,
                color: AppTheme.success,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Stockage modèles ─────────────────────────────────────────────────────────

class _ModelStorageSection extends StatelessWidget {
  const _ModelStorageSection();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Model Storage',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Future models (FR & EWE) will be downloadable here once available.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),

          // Placeholder FR
          _ModelStorageRow(label: 'Français', flag: '🇫🇷', available: false),
          const SizedBox(height: 8),
          _ModelStorageRow(label: 'Èvègbe', flag: '🇹🇬', available: false),
        ],
      ),
    );
  }
}

class _ModelStorageRow extends StatelessWidget {
  const _ModelStorageRow({
    required this.label,
    required this.flag,
    required this.available,
  });
  final String label;
  final String flag;
  final bool available;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: AppTheme.glassWhite,
        border: Border.all(color: AppTheme.glassBorder, width: 1),
      ),
      child: Row(
        children: [
          Text(flag, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.warning.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppTheme.warning.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Text(
              'Coming soon',
              style: GoogleFonts.inter(
                fontSize: 10,
                color: AppTheme.warning,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Divider interne ──────────────────────────────────────────────────────────

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) => Container(
        height: 1,
        margin: const EdgeInsets.symmetric(horizontal: 24),
        color: AppTheme.glassBorder,
      );
}
