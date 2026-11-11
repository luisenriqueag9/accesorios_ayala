import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

import '../models/producto.dart';

class ProductoController {
  static final _firestore = FirebaseFirestore.instance;
  static final _storage = FirebaseStorage.instance;

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
    final docRef = _firestore.collection(collection).doc(id);
    Reference? refImagenParaEliminar;

    try {
      final docSnapshot = await docRef.get();
      final data = docSnapshot.data();
      final imageUrl = (data?['imageUrl'] as String?)?.trim();

      if (imageUrl != null && imageUrl.isNotEmpty) {
        final refCandidata = _storage.refFromURL(imageUrl);
        final bucketEsperado = _storage.ref().bucket;
        final rutaCandidata = refCandidata.fullPath;

        final esBucketValido =
            bucketEsperado.isNotEmpty && refCandidata.bucket == bucketEsperado;
        final esRutaProductosValida =
            rutaCandidata.startsWith('productos/') &&
            rutaCandidata.length > 'productos/'.length &&
            !rutaCandidata.split('/').contains('..');

        if (esBucketValido && esRutaProductosValida) {
          final productosSnapshot =
              await _firestore.collection(collection).get();
          bool compartidaODudosa = false;

          for (final doc in productosSnapshot.docs) {
            if (doc.id == id) continue;

            final otraUrl = (doc.data()['imageUrl'] as String?)?.trim();
            if (otraUrl == null || otraUrl.isEmpty) continue;

            if (otraUrl == imageUrl) {
              compartidaODudosa = true;
              break;
            }

            try {
              final otraRef = _storage.refFromURL(otraUrl);
              if (otraRef.bucket == refCandidata.bucket &&
                  otraRef.fullPath == rutaCandidata) {
                compartidaODudosa = true;
                break;
              }
            } catch (_) {
              compartidaODudosa = true;
              break;
            }
          }

          if (!compartidaODudosa) {
            refImagenParaEliminar = refCandidata;
          }
        }
      }
    } catch (e) {
      debugPrint(
        'Advertencia: no se pudo verificar con seguridad la imagen antes de eliminar el producto $id: $e',
      );
      refImagenParaEliminar = null;
    }

    // 1. Eliminar primero el documento en Firestore. Si falla, la excepción se propaga y no se toca Storage.
    await docRef.delete();

    // 2. Eliminar la fotografía en Storage únicamente si todas las verificaciones previas fueron satisfactorias.
    if (refImagenParaEliminar != null) {
      try {
        await refImagenParaEliminar.delete();
      } on FirebaseException catch (e) {
        if (e.code != 'object-not-found') {
          debugPrint(
            'Advertencia: el producto $id se eliminó de Firestore, pero falló la limpieza de su imagen (${refImagenParaEliminar.fullPath}) en Storage: [${e.code}] ${e.message}',
          );
        }
      } catch (e) {
        debugPrint(
          'Advertencia: el producto $id se eliminó de Firestore, pero ocurrió un error al limpiar su imagen (${refImagenParaEliminar.fullPath}) en Storage: $e',
        );
      }
    }
  }
}
