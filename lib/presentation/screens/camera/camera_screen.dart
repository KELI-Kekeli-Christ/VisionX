import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../services/camera_service/camera_service.dart';
import '../../providers/detection_provider.dart';
import '../../widgets/bounding_box_painter.dart';
import '../../widgets/language_selector.dart';
import '../../widgets/settings_bottom_sheet.dart';

class CameraScreen extends StatelessWidget {
  const CameraScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.black,
      body: _CameraBody(),
    );
  }
}

class _CameraBody extends StatelessWidget {
  const _CameraBody();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DetectionProvider>();

    if (!provider.cameraReady) {
      return const _LoadingView(message: 'Starting camera…');
    }

    final controller = CameraService.instance.controller!;

    return Stack(
      fit: StackFit.expand,
      children: [
        // ── 1. Flux vidéo plein écran net ──────────────────
        _FullScreenCamera(controller: controller),

        // ── 2. Overlay bounding boxes ──────────────────────
        if (provider.isRunning)
          _DetectionOverlay(provider: provider),

        // ── 3. Gradients décoratifs haut/bas ──────────────
        const _EdgeGradients(),

        // ── 4. Top bar (titre + compteur) ──────────────────
        const _TopBar(),

        // ── 5. Bannière statut modèle (téléchargement, etc.)
        Positioned(
          top: MediaQuery.of(context).padding.top + 52,
          left: 16,
          right: 16,
          child: _ModelStatusBanner(provider: provider),
        ),

        // ── 6. Sélecteur de langue ─────────────────────────
        const Positioned(
          bottom: 120,
          left: 0,
          right: 0,
          child: LanguageSelector(),
        ),

        // ── 7. Boutons bas ─────────────────────────────────
        Positioned(
          bottom: 36,
          left: 0,
          right: 0,
          child: _BottomActions(provider: provider),
        ),

        // ── 8. Overlay pendant le changement de modèle ────
        if (provider.isSwitchingModel)
          const _SwitchingModelOverlay(),
      ],
    );
  }
}

// ── Flux caméra — net et plein écran ─────────────────────────────────────────
//
// Formule officielle du plugin camera :
//   scale = screenAspect * previewAspect
//   si scale < 1 → on inverse
// Cela garantit que le preview remplit l'écran sans distorsion ni blur.

class _FullScreenCamera extends StatelessWidget {
  const _FullScreenCamera({required this.controller});
  final CameraController controller;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);

    var scale = size.aspectRatio * controller.value.aspectRatio;
    if (scale < 1) scale = 1 / scale;

    return ClipRect(
      child: Transform.scale(
        scale: scale,
        child: Center(
          child: AspectRatio(
            aspectRatio: controller.value.aspectRatio,
            child: CameraPreview(controller),
          ),
        ),
      ),
    );
  }
}

// ── Overlay bounding boxes ───────────────────────────────────────────────────

class _DetectionOverlay extends StatelessWidget {
  const _DetectionOverlay({required this.provider});
  final DetectionProvider provider;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTapDown: (details) => _onTap(context, details, provider),
      child: RepaintBoundary(
        child: CustomPaint(
          painter: BoundingBoxPainter(
            detections: provider.detections,
            threshold: provider.confidenceThreshold,
          ),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }

  void _onTap(BuildContext context, TapDownDetails details,
      DetectionProvider provider) {
    final size = MediaQuery.sizeOf(context);
    final tapX = details.globalPosition.dx / size.width;
    final tapY = details.globalPosition.dy / size.height;
    for (final d in provider.detections) {
      if (d.boundingBox.contains(Offset(tapX, tapY))) {
        provider.speakDetection(d);
        break;
      }
    }
  }
}

// ── Bannière statut modèle ───────────────────────────────────────────────────

class _ModelStatusBanner extends StatelessWidget {
  const _ModelStatusBanner({required this.provider});
  final DetectionProvider provider;

  @override
  Widget build(BuildContext context) {
    // Modèle prêt → rien à afficher
    if (provider.modelReady && !provider.isSwitchingModel) {
      return const SizedBox.shrink();
    }

    final isDownloading = provider.isDownloadingModel;
    final progress = provider.downloadProgress;
    final hasFailed = provider.modelFailed;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasFailed
              ? AppTheme.error.withValues(alpha: 0.5)
              : AppTheme.neon.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: hasFailed
          ? _FailedRow(onRetry: provider.retryModelDownload)
          : isDownloading
              ? _DownloadRow(progress: progress)
              : _WaitingRow(),
    );
  }
}

class _WaitingRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(
              strokeWidth: 1.5, color: AppTheme.neon),
        ),
        const SizedBox(width: 10),
        Text('Initializing model…',
            style: GoogleFonts.inter(
                fontSize: 12, color: AppTheme.textSecondary)),
      ],
    );
  }
}

class _DownloadRow extends StatelessWidget {
  const _DownloadRow({required this.progress});
  final double progress;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.download_rounded, color: AppTheme.neon, size: 14),
            const SizedBox(width: 8),
            Text(
              'Downloading model… ${(progress * 100).round()}%',
              style: GoogleFonts.inter(
                  fontSize: 12, color: AppTheme.textSecondary),
            ),
          ],
        ),
        const SizedBox(height: 6),
        LinearProgressIndicator(
          value: progress > 0 ? progress : null,
          backgroundColor: AppTheme.glassBorder,
          valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.neon),
          minHeight: 2,
          borderRadius: BorderRadius.circular(2),
        ),
      ],
    );
  }
}

class _FailedRow extends StatelessWidget {
  const _FailedRow({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.warning_amber_rounded,
            color: AppTheme.warning, size: 14),
        const SizedBox(width: 8),
        Text('Model unavailable',
            style: GoogleFonts.inter(
                fontSize: 12, color: AppTheme.textSecondary)),
        const SizedBox(width: 12),
        GestureDetector(
          onTap: onRetry,
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: AppTheme.neon.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                  color: AppTheme.neon.withValues(alpha: 0.4), width: 1),
            ),
            child: Text('Retry',
                style: GoogleFonts.inter(
                    fontSize: 11,
                    color: AppTheme.neon,
                    fontWeight: FontWeight.w600)),
          ),
        ),
      ],
    );
  }
}

// ── Gradients ────────────────────────────────────────────────────────────────

class _EdgeGradients extends StatelessWidget {
  const _EdgeGradients();

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      Positioned(
        top: 0, left: 0, right: 0, height: 140,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.55),
                Colors.transparent
              ],
            ),
          ),
        ),
      ),
      Positioned(
        bottom: 0, left: 0, right: 0, height: 200,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [
                Colors.black.withValues(alpha: 0.65),
                Colors.transparent
              ],
            ),
          ),
        ),
      ),
    ]);
  }
}

// ── Top bar ──────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DetectionProvider>();
    final count = provider.detections.length;

    return Positioned(
      top: MediaQuery.of(context).padding.top + 12,
      left: 20,
      right: 20,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(children: [
            const Icon(Icons.remove_red_eye_outlined,
                color: AppTheme.neon, size: 20),
            const SizedBox(width: 8),
            Text('VisionX',
                style: Theme.of(context).textTheme.titleMedium),
          ]),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: count > 0
                ? _Chip(
                    key: ValueKey(count),
                    label: '$count object${count > 1 ? 's' : ''}',
                    color: AppTheme.neon)
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({super.key, required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: color.withValues(alpha: 0.15),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1),
      ),
      child:
          Text(label, style: Theme.of(context).textTheme.labelSmall),
    );
  }
}

// ── Boutons bas ──────────────────────────────────────────────────────────────

class _BottomActions extends StatelessWidget {
  const _BottomActions({required this.provider});
  final DetectionProvider provider;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _ActionButton(
            icon: Icons.flip_camera_ios_outlined,
            onTap: provider.flipCamera),
        const SizedBox(width: 24),
        _MainActionButton(provider: provider),
        const SizedBox(width: 24),
        _ActionButton(
            icon: Icons.tune_outlined,
            onTap: () => showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => const SettingsBottomSheet(),
                )),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppTheme.glassWhite,
          border: Border.all(color: AppTheme.glassBorder, width: 1),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 12)
          ],
        ),
        child: Icon(icon, color: AppTheme.textPrimary, size: 22),
      ),
    );
  }
}

class _MainActionButton extends StatelessWidget {
  const _MainActionButton({required this.provider});
  final DetectionProvider provider;

  @override
  Widget build(BuildContext context) {
    final isRunning = provider.isRunning;
    return GestureDetector(
      onTap:
          isRunning ? provider.stopDetection : provider.startDetection,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isRunning ? AppTheme.neon : AppTheme.error,
          boxShadow: [
            BoxShadow(
              color: (isRunning ? AppTheme.neon : AppTheme.error)
                  .withValues(alpha: 0.4),
              blurRadius: 24,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Icon(
          isRunning ? Icons.pause_rounded : Icons.play_arrow_rounded,
          color: AppTheme.bg,
          size: 32,
        ),
      ),
    );
  }
}

// ── Overlay changement de modèle ─────────────────────────────────────────────

class _SwitchingModelOverlay extends StatelessWidget {
  const _SwitchingModelOverlay();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withValues(alpha: 0.65),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(
                  color: AppTheme.neon, strokeWidth: 2),
            ),
            const SizedBox(height: 16),
            Text('Loading model…',
                style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}

// ── Loading initial ──────────────────────────────────────────────────────────

class _LoadingView extends StatelessWidget {
  const _LoadingView({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(
              color: AppTheme.neon, strokeWidth: 2),
          const SizedBox(height: 16),
          Text(message,
              style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}
