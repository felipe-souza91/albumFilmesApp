import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'view/splash_screen.dart';
import 'services/firebase_options.dart';
import 'view/auth/login_screen.dart';
import 'view/auth/signup_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized(); // <- TEM que vir primeiro

  try {
    await dotenv.load(fileName: "assets/.env");
    print("Envs carregadas com Sucesso");
  } catch (e) {
    print("Erro ao carregar env: $e");
  }

  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      print("Firebase inicializado com sucesso!");
    } else {
      print(
          "Firebase já inicializado com ${Firebase.apps.length} instância(s).");
    }
  } catch (e) {
    print("Erro ao inicializar Firebase: $e");
  }

  runApp(const MyApp());
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
      ),
      initialRoute: '/splash',
      routes: {
        '/splash': (context) => const SplashScreen(),
        '/login': (context) => LoginScreen(),
        '/signup': (context) => SignUpScreen(),
      },
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Home')),
      body: Center(child: Text('Bem-vindo!')),
    );
  }
}
