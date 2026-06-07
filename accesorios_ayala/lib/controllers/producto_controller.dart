import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/producto.dart';

class ProductoController {
  static final _firestore = FirebaseFirestore.instance;

  static const String collection = 'productos';

  static Future<void> guardarProducto(Producto producto) async {
    await _firestore
        .collection(collection)
        .doc(producto.id)
        .set(producto.toMap());
  }

  static Future<List<Producto>> cargarProductos() async {
    final snapshot = await _firestore.collection(collection).get();

    return snapshot.docs.map((doc) {
      return Producto.fromMap({'id': doc.id, ...doc.data()});
    }).toList();
  }

  static Future<void> eliminarProducto(String id) async {
    await _firestore.collection(collection).doc(id).delete();
  }
}
