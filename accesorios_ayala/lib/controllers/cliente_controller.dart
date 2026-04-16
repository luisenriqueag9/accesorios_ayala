import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/cliente.dart';

class ClienteController {
  static final _db = FirebaseFirestore.instance;
  static const String collection = 'clientes';

  static Future<List<Cliente>> cargarClientes() async {
    final snapshot = await _db
        .collection(collection)
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs
        .map((doc) => Cliente.fromMap(
              doc.data(),
              id: doc.id,
            ))
        .toList();
  }

  static Future<void> agregarCliente(Cliente cliente) async {
    await _db.collection(collection).add({
      ...cliente.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> editarCliente(Cliente cliente) async {
    await _db
        .collection(collection)
        .doc(cliente.id)
        .update(cliente.toMap());
  }

  static Future<void> eliminarCliente(String id) async {
    await _db.collection(collection).doc(id).delete();
  }
}
