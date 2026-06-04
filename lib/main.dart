import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'core/theme/app_theme.dart';
import 'presentation/providers/detection_provider.dart';
import 'presentation/screens/splash/splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Edge-to-edge sur Android
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
    ),
  );

  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // Le ModelManager est initialisé de manière asynchrone dans DetectionProvider
  // → l'app démarre immédiatement, la bannière de téléchargement informe l'utilisateur.

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => DetectionProvider()),
      ],
      child: const VisionXApp(),
    ),
  );
}

class VisionXApp extends StatelessWidget {
  const VisionXApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VisionX',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: const SplashScreen(),
    );
  }
}
