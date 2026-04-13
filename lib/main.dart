import 'dart:async';

import 'package:album_filmes_app/providers/movie_provider.dart';
import 'package:album_filmes_app/services/carrega_movies.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// BUG FIX: necessário para registrar GlobalMaterialLocalizations.delegate,
// que o showDatePicker exige ao usar locale: Locale('pt','BR').
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'views/splash_screen.dart';
import 'services/firebase_options.dart';
import 'views/auth/login_screen.dart';
import 'views/auth/signup_screen.dart';
import 'views/home/home_screen.dart';
import 'profile/profile_screen.dart';
import 'controllers/achievement_controller.dart';
import 'services/firestore_service.dart';
import 'services/config.dart';
import 'services/ads_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Trava a orientação em modo retrato — o app não foi projetado para landscape.
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // FIX XIAOMI: Configura edge-to-edge para respeitar a barra de gestos.
  // Usamos unawaited (não-bloqueante) para evitar congelamento em dispositivos
  // que demoram a responder ao platform channel antes do runApp().
  unawaited(
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge).then((_) {
      SystemChrome.setSystemUIOverlayStyle(
        const SystemUiOverlayStyle(
          systemNavigationBarColor: Colors.transparent,
          systemNavigationBarDividerColor: Colors.transparent,
          statusBarColor: Colors.transparent,
        ),
      );
    }),
  );

  try {
    await dotenv.load(fileName: "assets/.env");
  } catch (e) {
    // Falha ao carregar .env — continua sem variáveis de ambiente
  }

  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
  } catch (e) {
    // Falha ao inicializar Firebase — registra silenciosamente
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => MovieProvider()),
      ],
      child: const MyApp(),
    ),
  );

  unawaited(_initAdsInBackground());
  unawaited(_seedAchievementsIfAdmin());
}

Future<void> _initAdsInBackground() async {
  try {
    if (!Config.adsEnabled) return;
    if (Config.admobInterstitialUnitId.isEmpty) return;
    await AdsService.instance.init();
    await AdsService.instance
        .preloadInterstitial(adUnitId: Config.admobInterstitialUnitId);
  } catch (_) {
    // Não bloquear bootstrap por falha de ads
  }
}

Future<void> _seedAchievementsIfAdmin() async {
  try {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final tokenResult = await user.getIdTokenResult(true);
    final isAdmin = tokenResult.claims?['admin'] == true;
    if (!isAdmin) return;
    final achievementController =
        AchievementController(firestoreService: FirestoreService());
    await achievementController.setupInitialAchievements();
  } catch (_) {
    // Seed de achievements é responsabilidade administrativa — falha silenciosa
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Movie Album',
      // BUG FIX: delegates e locale necessários para que o showDatePicker
      // com locale: Locale('pt','BR') funcione sem lançar
      // "No MaterialLocalizations found" e causar crash.
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('pt', 'BR'),
        Locale('en', 'US'),
      ],
      locale: const Locale('pt', 'BR'),
      theme: ThemeData(
        primarySwatch: Colors.blue,
        inputDecorationTheme: const InputDecorationTheme(
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Color(0xFFFFD700), width: 2.0),
          ),
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Colors.grey, width: 1.0),
          ),
          border: OutlineInputBorder(),
        ),
      ),
      initialRoute: '/splash',
      routes: {
        '/splash': (context) => const SplashScreen(),
        '/login': (context) => const LoginScreen(),
        '/signup': (context) => const SignUpScreen(),
        '/admin': (context) => const AdminScreen(),
        '/profile': (context) => const ProfileScreen(),
        '/home': (context) => const HomeScreen(),
      },
    );
  }
}
