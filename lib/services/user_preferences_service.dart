import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/user_preferences.dart';

class UserPreferencesService {
  UserPreferencesService._();
  static final UserPreferencesService instance = UserPreferencesService._();

  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection('user_preferences');

  String? get _uid => _auth.currentUser?.uid;

  Future<UserPreferences?> getCurrentUserPreferences() async {
    final uid = _uid;
    if (uid == null) return null;

    final doc = await _col.doc(uid).get();
    if (!doc.exists || doc.data() == null) return null;
    return UserPreferences.fromMap(doc.data()!);
  }

  Future<void> saveCurrentUserPreferences(UserPreferences prefs) async {
    final uid = _uid;
    if (uid == null) {
      throw Exception('Usuário não autenticado.');
    }

    final data = prefs.copyWith(updatedAt: DateTime.now()).toMap();
    await _col.doc(uid).set(data, SetOptions(merge: true));
  }
}
