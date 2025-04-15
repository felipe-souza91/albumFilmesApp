import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'services/update_movies.dart';
import 'firebase_options.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: Text('Test App')),
        body: Center(
          child: ElevatedButton(
            onPressed: () async {
              final updater = MovieUpdater();
              await updater
                  .updateFirestore(8526195); // Substitua pelo seu listId
            },
            child: Text('Update Movies'),
          ),
        ),
      ),
    );
  }
}
