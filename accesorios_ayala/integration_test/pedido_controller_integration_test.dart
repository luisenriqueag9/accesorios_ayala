import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';

import 'package:accesorios_ayala/controllers/pedido_controller.dart';
import 'package:accesorios_ayala/models/pedido.dart';

const String _proyectoEmulador = 'demo-accesorios-ayala';
const String _hostEmulador = '127.0.0.1';
const int _puertoFirestore = 8080;
const int _puertoAuth = 9099;
const String _uidAdminPrueba = 'sK72fiKvY0crBfUzpP4TuqnHhBE3';
const Duration _timeoutOperacion = Duration(seconds: 20);

Future<T> _conDiagnostico<T>(
  String descripcion,
  Future<T> Function() accion, {
  Duration timeout = _timeoutOperacion,
}) async {
  debugPrint('[INTEGRACION] Iniciando: $descripcion');
  try {
    final resultado = await accion().timeout(
      timeout,
      onTimeout: () {
        final mensaje =
            '[INTEGRACION] Tiempo de espera agotado (${timeout.inSeconds}s) en: $descripcion';
        debugPrint(mensaje);
        throw TimeoutException(mensaje, timeout);
      },
    );
    debugPrint('[INTEGRACION] Completado: $descripcion');
    return resultado;
  } catch (e) {
    debugPrint('[INTEGRACION] Error en "$descripcion": $e');
    rethrow;
  }
}

Future<void> _verificarEmuladorActivo({
  required String nombre,
  required Uri uri,
}) async {
  debugPrint(
    '[INTEGRACION] Iniciando: verificación del emulador de $nombre en ${uri.host}:${uri.port}',
  );
  try {
    await http.get(uri).timeout(const Duration(seconds: 3));
    debugPrint(
      '[INTEGRACION] Completado: emulador de $nombre disponible en ${uri.host}:${uri.port}',
    );
  } catch (e) {
    debugPrint(
      '[INTEGRACION] Error: emulador de $nombre no disponible en ${uri.host}:${uri.port}: $e',
    );
    fail(
      'El emulador local de $nombre no está disponible en ${uri.host}:${uri.port}. '
      'Inicia los emuladores con "firebase emulators:start --only firestore,auth --project $_proyectoEmulador". '
      'Detalle: $e',
    );
  }
}

/// Construye un Custom Token JWT sin firma (`alg: none`) aceptado únicamente
/// por el emulador local de Firebase Authentication para autenticar el UID
/// administrativo de prueba sin credenciales reales ni conexión a producción.
String _crearCustomTokenEmulador(String uid) {
  String codificarBase64Url(Map<String, dynamic> data) {
    final bytes = utf8.encode(jsonEncode(data));
    return base64UrlEncode(bytes).replaceAll('=', '');
  }

  final ahoraSegundos = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
  final header = codificarBase64Url({'alg': 'none', 'typ': 'JWT'});
  final payload = codificarBase64Url({
    'iss': 'firebase-auth-emulator@example.com',
    'sub': 'firebase-auth-emulator@example.com',
    'aud':
        'https://identitytoolkit.googleapis.com/google.identity.identitytoolkit.v1.IdentityToolkit',
    'iat': ahoraSegundos,
    'exp': ahoraSegundos + 3600,
    'uid': uid,
  });

  return '$header.$payload.';
}

Pedido _construirBorradorPrueba() {
  return Pedido(
    id: '',
    clienteId: 'cli-emulador-1',
    clienteNombre: 'Ana López Prueba',
    clienteTelefono: '9999-0000',
    clienteDireccion: 'Col. Centro',
    clienteDepartamento: 'Cortés',
    items: [
      PedidoItem(
        itemId: 'item-1',
        productoId: 'prod-1',
        nombre: 'Pulsera Artesanal',
        cantidad: 2,
        precioUnitario: 250.0,
        notaPersonalizacion: 'Prueba emulador',
      ),
    ],
    costoEnvio: 120.0,
  );
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late FirebaseFirestore db;
  late FirebaseAuth auth;

  setUpAll(() async {
    await _verificarEmuladorActivo(
      nombre: 'Firestore',
      uri: Uri.parse('http://$_hostEmulador:$_puertoFirestore/'),
    );
    await _verificarEmuladorActivo(
      nombre: 'Authentication',
      uri: Uri.parse('http://$_hostEmulador:$_puertoAuth/'),
    );

    if (Firebase.apps.isEmpty) {
      await _conDiagnostico(
        'Firebase.initializeApp para proyecto $_proyectoEmulador',
        () => Firebase.initializeApp(
          options: const FirebaseOptions(
            apiKey: 'demo-api-key',
            appId: 'demo-app-id',
            messagingSenderId: 'demo-sender-id',
            projectId: _proyectoEmulador,
          ),
        ),
      );
    }

    auth = FirebaseAuth.instance;
    await _conDiagnostico(
      'conexión a Authentication Emulator (useAuthEmulator)',
      () => auth.useAuthEmulator(_hostEmulador, _puertoAuth),
    );

    db = FirebaseFirestore.instance;
    debugPrint(
      '[INTEGRACION] Configurando Firestore Emulator en $_hostEmulador:$_puertoFirestore',
    );
    db.useFirestoreEmulator(_hostEmulador, _puertoFirestore);

    final tokenEmulador = _crearCustomTokenEmulador(_uidAdminPrueba);
    final credencial = await _conDiagnostico(
      'autenticación con token ficticio (signInWithCustomToken)',
      () => auth.signInWithCustomToken(tokenEmulador),
    );
    expect(credencial.user?.uid, _uidAdminPrueba);
  });

  tearDownAll(() async {
    if (Firebase.apps.isNotEmpty) {
      await _conDiagnostico(
        'cierre de sesión en FirebaseAuth (signOut)',
        () => FirebaseAuth.instance.signOut(),
      );
    }
  });

  testWidgets(
    'Crea pedidos consecutivos en Firestore Emulator, protege ID repetido y no crea ventas',
    (tester) async {
      final marcaTiempo = DateTime.now().microsecondsSinceEpoch;
      final idPedido1 = 'ped_int_${marcaTiempo}_1';
      final idPedido2 = 'ped_int_${marcaTiempo}_2';

      final contadorAntesSnap = await _conDiagnostico(
        'primera lectura de Firestore (contadores/pedidos antes de crear)',
        () => db
            .collection(PedidoController.contadoresCollection)
            .doc(PedidoController.contadorDocId)
            .get(),
      );
      final ultimoAntes = contadorAntesSnap.exists
          ? ((contadorAntesSnap.data()?['ultimoNumero'] as num?)?.toInt() ?? 0)
          : 0;

      final numeroEsperado1 = PedidoController.formatearNumeroPedido(
        ultimoAntes + 1,
      );
      final numeroEsperado2 = PedidoController.formatearNumeroPedido(
        ultimoAntes + 2,
      );

      final ventasAntesSnap = await _conDiagnostico(
        'lectura inicial de colección ventas',
        () => db.collection('ventas').get(),
      );
      final cantidadVentasAntes = ventasAntesSnap.docs.length;

      // 1. Primer pedido creado por PedidoController
      final primero = await _conDiagnostico(
        'PedidoController.crearPedido (primer pedido: $idPedido1)',
        () => PedidoController.crearPedido(
          _construirBorradorPrueba(),
          firestore: db,
          pedidoId: idPedido1,
        ),
      );
      expect(primero.id, idPedido1);
      expect(primero.numeroPedido, numeroEsperado1);
      expect(primero.facturado, isFalse);
      expect(primero.createdAt, isNotNull);
      expect(primero.updatedAt, isNotNull);

      // 2. Segundo pedido consecutivo
      final segundo = await _conDiagnostico(
        'PedidoController.crearPedido (segundo pedido: $idPedido2)',
        () => PedidoController.crearPedido(
          _construirBorradorPrueba(),
          firestore: db,
          pedidoId: idPedido2,
        ),
      );
      expect(segundo.id, idPedido2);
      expect(segundo.numeroPedido, numeroEsperado2);
      expect(segundo.createdAt, isNotNull);
      expect(segundo.updatedAt, isNotNull);

      // 3. Verificar persistencia de ambos documentos y del contador
      final doc1 = await _conDiagnostico(
        'lectura de comprobación del primer pedido ($idPedido1)',
        () => db
            .collection(PedidoController.collection)
            .doc(idPedido1)
            .get(),
      );
      final doc2 = await _conDiagnostico(
        'lectura de comprobación del segundo pedido ($idPedido2)',
        () => db
            .collection(PedidoController.collection)
            .doc(idPedido2)
            .get(),
      );
      expect(doc1.exists, isTrue);
      expect(doc2.exists, isTrue);
      expect(doc1.data()?['numeroPedido'], numeroEsperado1);
      expect(doc2.data()?['numeroPedido'], numeroEsperado2);

      final contadorDespuesSnap = await _conDiagnostico(
        'lectura de comprobación de contadores/pedidos después de crear',
        () => db
            .collection(PedidoController.contadoresCollection)
            .doc(PedidoController.contadorDocId)
            .get(),
      );
      expect(contadorDespuesSnap.exists, isTrue);
      expect(contadorDespuesSnap.data()?['ultimoNumero'], ultimoAntes + 2);
      expect(contadorDespuesSnap.data()?['ultimoPedidoId'], idPedido2);

      // 4. Rechazar reutilización de pedidoId sin consumir consecutivo
      await expectLater(
        () => _conDiagnostico(
          'PedidoController.crearPedido con ID repetido ($idPedido1)',
          () => PedidoController.crearPedido(
            _construirBorradorPrueba(),
            firestore: db,
            pedidoId: idPedido1,
          ),
        ),
        throwsA(
          isA<PedidoControllerException>().having(
            (e) => e.tipo,
            'tipo',
            TipoErrorPedido.pedidoExistente,
          ),
        ),
      );

      final contadorTrasRechazoSnap = await _conDiagnostico(
        'lectura de comprobación de contadores/pedidos tras rechazo de ID repetido',
        () => db
            .collection(PedidoController.contadoresCollection)
            .doc(PedidoController.contadorDocId)
            .get(),
      );
      expect(contadorTrasRechazoSnap.data()?['ultimoNumero'], ultimoAntes + 2);
      expect(contadorTrasRechazoSnap.data()?['ultimoPedidoId'], idPedido2);

      // 5. Confirmar que no se crearon ventas
      final ventasDespuesSnap = await _conDiagnostico(
        'lectura de comprobación final de colección ventas',
        () => db.collection('ventas').get(),
      );
      expect(ventasDespuesSnap.docs.length, cantidadVentasAntes);
    },
  );

  testWidgets(
    'PedidoController.cargarPedidos consulta pedidos ordenados por createdAt descendente y retorna lista vacía si no hay documentos',
    (tester) async {
      final marcaTiempo = DateTime.now().microsecondsSinceEpoch;
      final idPedido1 = 'ped_lec_${marcaTiempo}_1';
      final idPedido2 = 'ped_lec_${marcaTiempo}_2';

      // 1. Crear dos pedidos de prueba mediante el mecanismo existente
      final primero = await _conDiagnostico(
        'PedidoController.crearPedido para lectura (1: $idPedido1)',
        () => PedidoController.crearPedido(
          _construirBorradorPrueba(),
          firestore: db,
          pedidoId: idPedido1,
        ),
      );

      final segundo = await _conDiagnostico(
        'PedidoController.crearPedido para lectura (2: $idPedido2)',
        () => PedidoController.crearPedido(
          _construirBorradorPrueba(),
          firestore: db,
          pedidoId: idPedido2,
        ),
      );

      // 2. Consultar los pedidos usando PedidoController.cargarPedidos(firestore: db)
      final cargados = await _conDiagnostico(
        'PedidoController.cargarPedidos(firestore: db)',
        () => PedidoController.cargarPedidos(firestore: db),
      );

      // 3. Comprobar que ambos aparecen
      final indice1 = cargados.indexWhere((p) => p.id == primero.id);
      final indice2 = cargados.indexWhere((p) => p.id == segundo.id);
      expect(indice1, isNonNegative);
      expect(indice2, isNonNegative);

      // 4. Comprobar orden descendente por createdAt
      for (var i = 0; i < cargados.length - 1; i++) {
        final actual = cargados[i].createdAt;
        final siguiente = cargados[i + 1].createdAt;
        if (actual != null && siguiente != null) {
          expect(
            actual.isBefore(siguiente),
            isFalse,
            reason:
                'Los pedidos deben venir ordenados de forma descendente por createdAt.',
          );
        }
      }
      if (primero.createdAt != null &&
          segundo.createdAt != null &&
          segundo.createdAt!.isAfter(primero.createdAt!)) {
        expect(indice2, lessThan(indice1));
      }

      // 5. Comprobar que se conservan los IDs y números de pedido
      final recuperado1 = cargados[indice1];
      final recuperado2 = cargados[indice2];
      expect(recuperado1.id, idPedido1);
      expect(recuperado1.numeroPedido, primero.numeroPedido);
      expect(recuperado2.id, idPedido2);
      expect(recuperado2.numeroPedido, segundo.numeroPedido);

      // 6. Comprobar colección vacía en un entorno de prueba aislado del emulador
      final nombreAppAislada = 'app_vacia_$marcaTiempo';
      final proyectoAislado = 'demo-accesorios-ayala-vacio-$marcaTiempo';
      final appAislada = await _conDiagnostico(
        'Firebase.initializeApp aislado ($proyectoAislado)',
        () => Firebase.initializeApp(
          name: nombreAppAislada,
          options: FirebaseOptions(
            apiKey: 'demo-api-key',
            appId: 'demo-app-id',
            messagingSenderId: 'demo-sender-id',
            projectId: proyectoAislado,
          ),
        ),
      );

      final authAislado = FirebaseAuth.instanceFor(app: appAislada);
      try {
        await _conDiagnostico(
          'useAuthEmulator en entorno aislado',
          () => authAislado.useAuthEmulator(_hostEmulador, _puertoAuth),
        );
        final dbAislada = FirebaseFirestore.instanceFor(app: appAislada);
        dbAislada.useFirestoreEmulator(_hostEmulador, _puertoFirestore);

        await _conDiagnostico(
          'signInWithCustomToken en entorno aislado',
          () => authAislado.signInWithCustomToken(
            _crearCustomTokenEmulador(_uidAdminPrueba),
          ),
        );

        final pedidosVacios = await _conDiagnostico(
          'PedidoController.cargarPedidos en colección vacía aislada',
          () => PedidoController.cargarPedidos(firestore: dbAislada),
        );
        expect(pedidosVacios, isEmpty);
      } finally {
        await authAislado.signOut();
        await appAislada.delete();
      }
    },
  );
}
