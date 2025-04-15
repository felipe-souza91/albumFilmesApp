import 'package:cloud_firestore/cloud_firestore.dart';

void testFirestore() async {
  final firestore = FirebaseFirestore.instance;
  await firestore.collection('test').doc('example').set({
    'message': 'Firestore funcionando!',
    'timestamp': FieldValue.serverTimestamp(),
  });
  print('Documento adicionado ao Firestore!');
}
