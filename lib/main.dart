import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'theme/app_theme.dart';
import 'screens/splash_screen.dart';
import 'config/supabase_config.dart';
import 'config/api_config.dart';
import 'services/ai_service.dart';

final AiService aiService = AiService();

Future<void> main() async {
  // Disable runtime font fetching – makes text always visible even if
  // the network is unavailable (avoids "blank quest card" symptom).
  GoogleFonts.config.allowRuntimeFetching = false;

  WidgetsFlutterBinding.ensureInitialized();

  assert(() {
    debugPrint('--- KarmaX Boot Diagnostics ---');
    debugPrint('Backend URL  : ${ApiConfig.backendBaseUrl}');
    debugPrint('Supabase URL : ${SupabaseConfig.resolvedUrl}');
    debugPrint(
        'Supabase Key : ${SupabaseConfig.anonKey.isNotEmpty ? "✓ loaded" : "✗ missing"}');
    debugPrint('Supabase OK  : ${SupabaseConfig.isConfigured}');
    debugPrint('-------------------------------');
    return true;
  }());

  if (SupabaseConfig.isConfigured) {
    await Supabase.initialize(
      url: SupabaseConfig.resolvedUrl,
      publishableKey: SupabaseConfig.anonKey,
    );
    debugPrint('Supabase initialized successfully.');
  } else {
    debugPrint(SupabaseConfig.missingConfigMessage);
  }

  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppTheme.bg900,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const KarmaXApp());
}

class KarmaXApp extends StatelessWidget {
  const KarmaXApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KarmaX',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      home: const SplashScreen(),
    );
  }
}
