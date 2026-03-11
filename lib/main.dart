import 'package:album_filmes_app/providers/movie_provider.dart';
import 'package:album_filmes_app/services/carrega_movies.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
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
  WidgetsFlutterBinding.ensureInitialized(); // <- TEM que vir primeiro

  try {
    await dotenv.load(fileName: "assets/.env");
    //print("Envs carregadas com Sucesso");
  } catch (e) {
    //print("Erro ao carregar env: $e");
  }

  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      //print("Firebase inicializado com sucesso!");
    } else {
      //print("Firebase já inicializado com ${Firebase.apps.length} instância(s).");
    }
  } catch (e) {
    //print("Erro ao inicializar Firebase: $e");
  }

  await _seedAchievementsIfAdmin();
  await _initAds();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => MovieProvider()),
      ],
      child: MyApp(),
    ),
  );
}

Future<void> _initAds() async {
  try {
    if (!Config.adsEnabled) return;
    await AdsService.instance.init();
    if (Config.admobInterstitialUnitId.isNotEmpty) {
      await AdsService.instance
          .loadInterstitial(adUnitId: Config.admobInterstitialUnitId);
    }
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
    // evita ruído no startup; seed de achievements é responsabilidade administrativa
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Movie Album',
      theme: ThemeData(
          primarySwatch: Colors.blue,
          inputDecorationTheme: InputDecorationTheme(
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: Color(0xFFFFD700), width: 2.0),
            ),
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(color: Colors.grey, width: 1.0),
            ),
            border: OutlineInputBorder(),
          )),
      initialRoute: '/splash',
      routes: {
        '/splash': (context) => const SplashScreen(),
        '/login': (context) => LoginScreen(),
        '/signup': (context) => SignUpScreen(),
        '/admin': (context) => AdminScreen(),
        '/profile': (context) => ProfileScreen(),
        '/home': (context) => HomeScreen(),
      },
    );
  }
}
