import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../camera/camera_screen.dart';
import '../onboarding/onboarding_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _glowCtrl;

  @override
  void initState() {
    super.initState();
    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _navigate();
  }

  Future<void> _navigate() async {
    await Future.delayed(AppConstants.splashDuration);
    if (!mounted) return;

    final prefs = await SharedPreferences.getInstance();
    final firstLaunch = prefs.getBool(AppConstants.prefFirstLaunch) ?? true;

    if (firstLaunch) {
      await prefs.setBool(AppConstants.prefFirstLaunch, false);
      _push(const OnboardingScreen());
    } else {
      _push(const CameraScreen());
    }
  }

  void _push(Widget screen) {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, a, __) => screen,
        transitionsBuilder: (_, a, __, child) =>
            FadeTransition(opacity: a, child: child),
        transitionDuration: const Duration(milliseconds: 600),
      ),
    );
  }

  @override
  void dispose() {
    _glowCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Fond radial animé
          AnimatedBuilder(
            animation: _glowCtrl,
            builder: (_, __) => Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.2),
                  radius: 0.8,
                  colors: [
                    AppTheme.neon.withValues(alpha: 0.08 + _glowCtrl.value * 0.06),
                    AppTheme.bg,
                  ],
                ),
              ),
            ),
          ),

          // Logo + titre centrés
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icône œil entouré d'un halo cyan
                AnimatedBuilder(
                  animation: _glowCtrl,
                  builder: (_, __) => Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.neon
                              .withValues(alpha: 0.3 + _glowCtrl.value * 0.25),
                          blurRadius: 40 + _glowCtrl.value * 20,
                          spreadRadius: 4,
                        ),
                      ],
                      border: Border.all(
                        color: AppTheme.neon
                            .withValues(alpha: 0.4 + _glowCtrl.value * 0.3),
                        width: 1.5,
                      ),
                      color: AppTheme.neon.withValues(alpha: 0.08),
                    ),
                    child: const Icon(
                      Icons.remove_red_eye_outlined,
                      color: AppTheme.neon,
                      size: 44,
                    ),
                  ),
                ),

                const SizedBox(height: 28),

                Text(
                  'VisionX',
                  style: GoogleFonts.inter(
                    fontSize: 40,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                    letterSpacing: -1.5,
                  ),
                ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.2),

                const SizedBox(height: 8),

                Text(
                  'Real-time Object Detection',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: AppTheme.textSecondary,
                    letterSpacing: 0.5,
                  ),
                ).animate(delay: 200.ms).fadeIn(duration: 500.ms),

                const SizedBox(height: 4),

                Text(
                  'EN · FR · EWE',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 11,
                    color: AppTheme.neon.withValues(alpha: 0.7),
                    letterSpacing: 3,
                  ),
                ).animate(delay: 400.ms).fadeIn(duration: 500.ms),
              ],
            ),
          ),

          // Loader en bas
          Positioned(
            bottom: 60,
            left: 0,
            right: 0,
            child: Column(
              children: [
                SizedBox(
                  width: 120,
                  child: LinearProgressIndicator(
                    backgroundColor: AppTheme.glassBorder,
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(AppTheme.neon),
                    minHeight: 2,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ).animate(delay: 300.ms).fadeIn(),
                const SizedBox(height: 12),
                Text(
                  'Initializing models…',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: AppTheme.textDisabled,
                  ),
                ).animate(delay: 300.ms).fadeIn(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
