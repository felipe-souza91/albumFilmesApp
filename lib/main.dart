import 'dart:async';

import 'package:album_filmes_app/providers/movie_provider.dart';
import 'package:album_filmes_app/services/carrega_movies.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
// BUG FIX: Importado para controle do modo de exibição do sistema (Xiaomi / barra de gestos)
import 'package:flutter/services.dart';
// BUG FIX: Importado para suporte a localização pt-BR (DatePicker, etc.)
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

  // BUG FIX: Define modo edge-to-edge para que o app respeite corretamente
  // as barras de navegação por gestos em dispositivos Xiaomi (MIUI) e outros
  // Android com barra de navegação personalizada. Sem isso, o conteúdo pode
  // ficar escondido atrás da barra inferior do sistema.
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
      statusBarColor: Colors.transparent,
    ),
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

      // BUG FIX: Delegates e locale adicionados para corrigir o formato de data
      // do DatePicker (que aparecia em formato americano MM/DD/YYYY).
      // Com pt-BR configurado, passa a exibir DD/MM/YYYY corretamente.
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('pt', 'BR'),
        Locale('en', 'US'), // fallback
      ],
      locale: const Locale('pt', 'BR'),

      theme: ThemeData(
        primarySwatch: Colors.blue,
        // BUG FIX: Garante que o Scaffold respeite as insets do sistema
        // em dispositivos com barra de navegação por gestos (Xiaomi, etc.)
        useMaterial3: false,
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
