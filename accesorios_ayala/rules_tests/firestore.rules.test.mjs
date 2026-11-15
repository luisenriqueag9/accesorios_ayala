import fs from 'node:fs';
import net from 'node:net';
import { describe, it, before, after, beforeEach } from 'node:test';
import {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} from '@firebase/rules-unit-testing';
import {
  doc,
  collection,
  getDoc,
  getDocs,
  setDoc,
  updateDoc,
  deleteDoc,
  writeBatch,
  runTransaction,
  serverTimestamp,
  Timestamp,
  setLogLevel,
} from 'firebase/firestore';

const PROJECT_ID = 'demo-accesorios-ayala';
const EMULATOR_HOST = '127.0.0.1';
const EMULATOR_PORT = 8080;

// Forzar variable de entorno del emulador local para impedir cualquier intento de conexión externa
process.env.FIRESTORE_EMULATOR_HOST = `${EMULATOR_HOST}:${EMULATOR_PORT}`;

const ADMIN_UID_1 = 'sK72fiKvY0crBfUzpP4TuqnHhBE3';
const ADMIN_UID_2 = 'PefdVcw7gRayt1hgCUAZt7ejgYO2';
const UNAUTHORIZED_UID = 'usuario_no_autorizado_999';

function verificarEmuladorDisponible(host, port, timeoutMs = 2500) {
  return new Promise((resolve, reject) => {
    const socket = net.createConnection({ host, port });
    const timer = setTimeout(() => {
      socket.destroy();
      reject(
        new Error(
          `El emulador local de Firestore no responde en ${host}:${port} (tiempo de espera agotado). ` +
            'Inicia el emulador antes de ejecutar las pruebas. No se realizará ninguna conexión externa.',
        ),
      );
    }, timeoutMs);

    socket.once('connect', () => {
      clearTimeout(timer);
      socket.end();
      resolve();
    });

    socket.once('error', (err) => {
      clearTimeout(timer);
      socket.destroy();
      reject(
        new Error(
          `No se pudo conectar al emulador local de Firestore en ${host}:${port} (${err.message}). ` +
            'Verifica que Firebase Emulator Suite esté activo.',
        ),
      );
    });
  });
}

const rutaReglas = new URL('../firestore.rules', import.meta.url);
const contenidoReglas = fs.readFileSync(rutaReglas, 'utf8');

let testEnv;

async function sembrarDatosIniciales() {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();

    await setDoc(doc(db, 'productos', 'prod_1'), {
      id: 'prod_1',
      nombre: 'Pulsera Artesanal',
      descripcion: 'Pulsera tejida a mano',
      precio: 250,
      imageUrl: null,
    });

    await setDoc(doc(db, 'clientes', 'cli_1'), {
      id: 'cli_1',
      nombre: 'Cliente Registrado',
      telefono: '+50498765432',
      direccion: 'Choloma',
      departamento: 'Cortés',
    });

    await setDoc(doc(db, 'ventas', 'venta_1'), {
      id: 'venta_1',
      clienteId: 'cli_1',
      clienteNombre: 'Cliente Registrado',
      fecha: '2026-11-11T10:00:00.000Z',
      subtotal: 250,
      impuesto: 0,
      total: 250,
    });

    const fechaInicial = Timestamp.fromDate(new Date('2026-11-11T12:00:00.000Z'));

    await setDoc(doc(db, 'cotizaciones', 'cot_1'), {
      id: 'cot_1',
      codigo: 'AY-1001',
      estado: 'Pendiente',
      clienteNombre: 'Ana Martínez',
      clienteTelefono: '+50499887766',
      items: [
        {
          productoId: 'prod_1',
          nombre: 'Pulsera Artesanal',
          precioUnitario: 250,
          cantidad: 2,
          subtotal: 500,
        },
      ],
      totalUnidades: 2,
      totalEstimado: 500,
      createdAt: fechaInicial,
      updatedAt: fechaInicial,
    });
  });
}

describe('Reglas de Seguridad de Firestore - Accesorios Ayala (demo-accesorios-ayala)', () => {
  before(async () => {
    setLogLevel('error');
    await verificarEmuladorDisponible(EMULATOR_HOST, EMULATOR_PORT);

    testEnv = await initializeTestEnvironment({
      projectId: PROJECT_ID,
      firestore: {
        host: EMULATOR_HOST,
        port: EMULATOR_PORT,
        rules: contenidoReglas,
      },
    });
  });

  beforeEach(async () => {
    await testEnv.clearFirestore();
    await sembrarDatosIniciales();
  });

  after(async () => {
    if (testEnv) {
      await testEnv.clearFirestore();
      await testEnv.cleanup();
    }
  });

  describe('1. Visitante no autenticado', () => {
    it('Permite leer un producto individual y listar la colección productos', async () => {
      const visitorDb = testEnv.unauthenticatedContext().firestore();

      await assertSucceeds(getDoc(doc(visitorDb, 'productos', 'prod_1')));
      await assertSucceeds(getDocs(collection(visitorDb, 'productos')));
    });

    it('Deniega leer una cotización individual o listar la colección cotizaciones', async () => {
      const visitorDb = testEnv.unauthenticatedContext().firestore();

      await assertFails(getDoc(doc(visitorDb, 'cotizaciones', 'cot_1')));
      await assertFails(getDocs(collection(visitorDb, 'cotizaciones')));
    });

    it('Deniega crear, actualizar o eliminar cotizaciones', async () => {
      const visitorDb = testEnv.unauthenticatedContext().firestore();

      await assertFails(
        setDoc(doc(visitorDb, 'cotizaciones', 'cot_nueva'), {
          id: 'cot_nueva',
          estado: 'Pendiente',
          clienteNombre: 'Visitante',
          clienteTelefono: '+50499112233',
          totalEstimado: 250,
          createdAt: serverTimestamp(),
          updatedAt: serverTimestamp(),
        }),
      );

      await assertFails(
        updateDoc(doc(visitorDb, 'cotizaciones', 'cot_1'), {
          estado: 'Confirmado',
          updatedAt: serverTimestamp(),
        }),
      );

      await assertFails(deleteDoc(doc(visitorDb, 'cotizaciones', 'cot_1')));
    });
  });

  describe('2. Administradores autorizados', () => {
    it('Ambos UID administrativos autorizados pueden leer y listar cotizaciones', async () => {
      const admin1Db = testEnv.authenticatedContext(ADMIN_UID_1).firestore();
      const admin2Db = testEnv.authenticatedContext(ADMIN_UID_2).firestore();

      await assertSucceeds(getDoc(doc(admin1Db, 'cotizaciones', 'cot_1')));
      await assertSucceeds(getDocs(collection(admin1Db, 'cotizaciones')));

      await assertSucceeds(getDoc(doc(admin2Db, 'cotizaciones', 'cot_1')));
      await assertSucceeds(getDocs(collection(admin2Db, 'cotizaciones')));
    });

    it('Permite actualizar únicamente estado y updatedAt con serverTimestamp() para los 4 estados válidos', async () => {
      const adminDb = testEnv.authenticatedContext(ADMIN_UID_1).firestore();
      const estadosValidos = ['Contactado', 'Confirmado', 'Cancelado', 'Pendiente'];

      for (const nuevoEstado of estadosValidos) {
        await assertSucceeds(
          updateDoc(doc(adminDb, 'cotizaciones', 'cot_1'), {
            estado: nuevoEstado,
            updatedAt: serverTimestamp(),
          }),
        );
      }
    });

    it('Deniega estados no permitidos fuera del catálogo oficial', async () => {
      const adminDb = testEnv.authenticatedContext(ADMIN_UID_1).firestore();

      await assertFails(
        updateDoc(doc(adminDb, 'cotizaciones', 'cot_1'), {
          estado: 'Pagado',
          updatedAt: serverTimestamp(),
        }),
      );

      await assertFails(
        updateDoc(doc(adminDb, 'cotizaciones', 'cot_1'), {
          estado: '',
          updatedAt: serverTimestamp(),
        }),
      );
    });

    it('Deniega modificar precios, items, datos del cliente o createdAt', async () => {
      const adminDb = testEnv.authenticatedContext(ADMIN_UID_1).firestore();

      // Intento de alterar totalEstimado
      await assertFails(
        updateDoc(doc(adminDb, 'cotizaciones', 'cot_1'), {
          estado: 'Confirmado',
          totalEstimado: 100,
          updatedAt: serverTimestamp(),
        }),
      );

      // Intento de alterar items
      await assertFails(
        updateDoc(doc(adminDb, 'cotizaciones', 'cot_1'), {
          estado: 'Confirmado',
          items: [],
          updatedAt: serverTimestamp(),
        }),
      );

      // Intento de alterar datos del cliente
      await assertFails(
        updateDoc(doc(adminDb, 'cotizaciones', 'cot_1'), {
          estado: 'Contactado',
          clienteNombre: 'Nombre Alterado',
          updatedAt: serverTimestamp(),
        }),
      );

      await assertFails(
        updateDoc(doc(adminDb, 'cotizaciones', 'cot_1'), {
          estado: 'Contactado',
          clienteTelefono: '+50400000000',
          updatedAt: serverTimestamp(),
        }),
      );

      // Intento de alterar createdAt
      await assertFails(
        updateDoc(doc(adminDb, 'cotizaciones', 'cot_1'), {
          estado: 'Confirmado',
          createdAt: serverTimestamp(),
          updatedAt: serverTimestamp(),
        }),
      );
    });

    it('Deniega establecer manualmente updatedAt con una fecha arbitraria distinta de request.time', async () => {
      const adminDb = testEnv.authenticatedContext(ADMIN_UID_1).firestore();

      await assertFails(
        updateDoc(doc(adminDb, 'cotizaciones', 'cot_1'), {
          estado: 'Contactado',
          updatedAt: Timestamp.fromDate(new Date('2030-01-01T00:00:00.000Z')),
        }),
      );
    });

    it('Deniega crear cotizaciones directamente desde el SDK cliente incluso siendo administrador', async () => {
      const adminDb = testEnv.authenticatedContext(ADMIN_UID_1).firestore();

      await assertFails(
        setDoc(doc(adminDb, 'cotizaciones', 'cot_manual_admin'), {
          id: 'cot_manual_admin',
          estado: 'Pendiente',
          clienteNombre: 'Prueba Admin',
          clienteTelefono: '+50499887766',
          items: [],
          totalEstimado: 0,
          createdAt: serverTimestamp(),
          updatedAt: serverTimestamp(),
        }),
      );
    });

    it('Permite eliminar cotizaciones a los administradores autorizados', async () => {
      const adminDb = testEnv.authenticatedContext(ADMIN_UID_2).firestore();

      await assertSucceeds(deleteDoc(doc(adminDb, 'cotizaciones', 'cot_1')));
    });
  });

  describe('3. Usuario autenticado no autorizado', () => {
    it('Deniega leer, listar, crear, actualizar o eliminar cotizaciones', async () => {
      const unauthorizedDb = testEnv
        .authenticatedContext(UNAUTHORIZED_UID)
        .firestore();

      await assertFails(getDoc(doc(unauthorizedDb, 'cotizaciones', 'cot_1')));
      await assertFails(getDocs(collection(unauthorizedDb, 'cotizaciones')));

      await assertFails(
        setDoc(doc(unauthorizedDb, 'cotizaciones', 'cot_intruso'), {
          id: 'cot_intruso',
          estado: 'Pendiente',
          updatedAt: serverTimestamp(),
        }),
      );

      await assertFails(
        updateDoc(doc(unauthorizedDb, 'cotizaciones', 'cot_1'), {
          estado: 'Cancelado',
          updatedAt: serverTimestamp(),
        }),
      );

      await assertFails(deleteDoc(doc(unauthorizedDb, 'cotizaciones', 'cot_1')));
    });
  });

  describe('4. Pruebas de regresión (productos, clientes y ventas)', () => {
    it('Mantiene la escritura de productos reservada exclusivamente a administradores', async () => {
      const visitorDb = testEnv.unauthenticatedContext().firestore();
      const unauthorizedDb = testEnv
        .authenticatedContext(UNAUTHORIZED_UID)
        .firestore();
      const adminDb = testEnv.authenticatedContext(ADMIN_UID_1).firestore();

      await assertFails(
        setDoc(doc(visitorDb, 'productos', 'prod_nuevo'), {
          nombre: 'Intento Visitante',
          precio: 100,
        }),
      );

      await assertFails(
        setDoc(doc(unauthorizedDb, 'productos', 'prod_nuevo'), {
          nombre: 'Intento No Autorizado',
          precio: 100,
        }),
      );

      await assertSucceeds(
        setDoc(doc(adminDb, 'productos', 'prod_nuevo'), {
          id: 'prod_nuevo',
          nombre: 'Producto Oficial',
          descripcion: 'Creado por admin',
          precio: 350,
        }),
      );
    });

    it('Mantiene clientes y ventas protegidos contra visitantes y usuarios no autorizados, y accesibles para administradores', async () => {
      const visitorDb = testEnv.unauthenticatedContext().firestore();
      const unauthorizedDb = testEnv
        .authenticatedContext(UNAUTHORIZED_UID)
        .firestore();
      const adminDb = testEnv.authenticatedContext(ADMIN_UID_1).firestore();

      // Visitante denegado en clientes y ventas
      await assertFails(getDoc(doc(visitorDb, 'clientes', 'cli_1')));
      await assertFails(getDocs(collection(visitorDb, 'clientes')));
      await assertFails(getDoc(doc(visitorDb, 'ventas', 'venta_1')));
      await assertFails(getDocs(collection(visitorDb, 'ventas')));

      // Usuario autenticado no autorizado denegado en clientes y ventas
      await assertFails(getDoc(doc(unauthorizedDb, 'clientes', 'cli_1')));
      await assertFails(getDocs(collection(unauthorizedDb, 'clientes')));
      await assertFails(
        setDoc(doc(unauthorizedDb, 'clientes', 'cli_intruso'), {
          nombre: 'Intruso',
        }),
      );
      await assertFails(getDoc(doc(unauthorizedDb, 'ventas', 'venta_1')));
      await assertFails(getDocs(collection(unauthorizedDb, 'ventas')));
      await assertFails(
        setDoc(doc(unauthorizedDb, 'ventas', 'venta_intruso'), {
          total: 0,
        }),
      );

      // Administrador autorizado permitido en clientes y ventas
      await assertSucceeds(getDoc(doc(adminDb, 'clientes', 'cli_1')));
      await assertSucceeds(getDocs(collection(adminDb, 'clientes')));
      await assertSucceeds(getDoc(doc(adminDb, 'ventas', 'venta_1')));
      await assertSucceeds(getDocs(collection(adminDb, 'ventas')));
    });
  });

  describe('5. Pedidos y contador consecutivo (contadores/pedidos)', () => {
    function construirPedidoValido(pedidoId, numeroPedido) {
      return {
        id: pedidoId,
        numeroPedido,
        clienteId: 'cli_1',
        clienteNombre: 'Cliente Registrado',
        clienteTelefono: '+50498765432',
        clienteDireccion: 'Choloma',
        clienteDepartamento: 'Cortés',
        items: [
          {
            itemId: 'item_1',
            productoId: 'prod_1',
            nombre: 'Pulsera Artesanal',
            cantidad: 2,
            precioUnitario: 250,
            imageUrl: null,
            notaPersonalizacion: 'Iniciales A.M.',
            estadoElaboracion: 'recibido',
          },
        ],
        keywordsBusqueda: [
          numeroPedido.toLowerCase(),
          'ped',
          'cliente',
          'registrado',
          'pulsera',
          'artesanal',
        ],
        estadoProduccion: 'recibido',
        estadoEnvio: 'pendiente',
        costoEnvio: 120,
        borradorFactura: {
          impuestoPorcentaje: 0,
          descuentoMayoristaActivo: false,
          descuentoPorcentaje: 0,
          costoEnvio: 120,
          subtotalEstimado: 500,
          totalEstimado: 620,
        },
        facturado: false,
        ventaId: null,
        facturaNumero: null,
        fechaPrevistaEntrega: Timestamp.fromDate(
          new Date('2026-11-20T18:00:00.000Z'),
        ),
        fechaEnvio: null,
        fechaEntrega: null,
        fechaFacturacion: null,
        createdAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      };
    }

    async function crearPedidoAtomico(db, pedidoId, numeroEsperado, numeroInt) {
      const batch = writeBatch(db);
      batch.set(
        doc(db, 'pedidos', pedidoId),
        construirPedidoValido(pedidoId, numeroEsperado),
      );
      if (numeroInt === 1) {
        batch.set(doc(db, 'contadores', 'pedidos'), {
          ultimoNumero: 1,
          ultimoPedidoId: pedidoId,
          updatedAt: serverTimestamp(),
        });
      } else {
        batch.update(doc(db, 'contadores', 'pedidos'), {
          ultimoNumero: numeroInt,
          ultimoPedidoId: pedidoId,
          updatedAt: serverTimestamp(),
        });
      }
      return batch.commit();
    }

    it('Administrador autorizado puede crear pedidos consecutivos de forma atómica con transacción y leerlos', async () => {
      const adminDb = testEnv.authenticatedContext(ADMIN_UID_1).firestore();
      const adminDb2 = testEnv.authenticatedContext(ADMIN_UID_2).firestore();

      // Primer pedido (inicializa contador en 1 -> PED-0001)
      await assertSucceeds(crearPedidoAtomico(adminDb, 'ped_1', 'PED-0001', 1));

      // Segundo pedido mediante runTransaction por segundo admin (-> PED-0002)
      await assertSucceeds(
        runTransaction(adminDb2, async (tx) => {
          const contadorRef = doc(adminDb2, 'contadores', 'pedidos');
          const snap = await tx.get(contadorRef);
          const siguiente = (snap.data()?.ultimoNumero ?? 0) + 1;
          const numero = `PED-${String(siguiente).padStart(4, '0')}`;
          const pedidoRef = doc(adminDb2, 'pedidos', 'ped_2');

          tx.set(pedidoRef, construirPedidoValido('ped_2', numero));
          tx.update(contadorRef, {
            ultimoNumero: siguiente,
            ultimoPedidoId: 'ped_2',
            updatedAt: serverTimestamp(),
          });
        }),
      );

      await assertSucceeds(getDoc(doc(adminDb, 'pedidos', 'ped_1')));
      await assertSucceeds(getDoc(doc(adminDb, 'pedidos', 'ped_2')));
      await assertSucceeds(getDoc(doc(adminDb, 'contadores', 'pedidos')));
    });

    it('Deniega acceso de lectura y escritura a visitante no autenticado y usuario no autorizado', async () => {
      const visitorDb = testEnv.unauthenticatedContext().firestore();
      const unauthorizedDb = testEnv
        .authenticatedContext(UNAUTHORIZED_UID)
        .firestore();

      await assertFails(getDoc(doc(visitorDb, 'pedidos', 'ped_1')));
      await assertFails(getDocs(collection(visitorDb, 'pedidos')));
      await assertFails(getDoc(doc(visitorDb, 'contadores', 'pedidos')));
      await assertFails(
        crearPedidoAtomico(visitorDb, 'ped_visitante', 'PED-0001', 1),
      );

      await assertFails(getDoc(doc(unauthorizedDb, 'pedidos', 'ped_1')));
      await assertFails(getDocs(collection(unauthorizedDb, 'pedidos')));
      await assertFails(getDoc(doc(unauthorizedDb, 'contadores', 'pedidos')));
      await assertFails(
        crearPedidoAtomico(unauthorizedDb, 'ped_intruso', 'PED-0001', 1),
      );
    });

    it('Deniega crear un pedido sin actualizar el contador', async () => {
      const adminDb = testEnv.authenticatedContext(ADMIN_UID_1).firestore();

      await assertFails(
        setDoc(
          doc(adminDb, 'pedidos', 'ped_sin_contador'),
          construirPedidoValido('ped_sin_contador', 'PED-0001'),
        ),
      );
    });

    it('Deniega incrementar el contador sin crear el pedido correspondiente', async () => {
      const adminDb = testEnv.authenticatedContext(ADMIN_UID_1).firestore();

      await assertFails(
        setDoc(doc(adminDb, 'contadores', 'pedidos'), {
          ultimoNumero: 1,
          ultimoPedidoId: 'ped_inexistente',
          updatedAt: serverTimestamp(),
        }),
      );

      // Crear ped_1 correctamente y luego intentar incrementar el contador apuntando al mismo ped_1
      await assertSucceeds(crearPedidoAtomico(adminDb, 'ped_1', 'PED-0001', 1));

      await assertFails(
        updateDoc(doc(adminDb, 'contadores', 'pedidos'), {
          ultimoNumero: 2,
          ultimoPedidoId: 'ped_fantasma',
          updatedAt: serverTimestamp(),
        }),
      );
    });

    it('Deniega número de pedido incorrecto respecto al contador e intento de reutilizar un número', async () => {
      const adminDb = testEnv.authenticatedContext(ADMIN_UID_1).firestore();

      // Número incorrecto (PED-0099 cuando ultimoNumero es 1)
      await assertFails(crearPedidoAtomico(adminDb, 'ped_mal', 'PED-0099', 1));

      // Crear ped_1 válido (PED-0001)
      await assertSucceeds(crearPedidoAtomico(adminDb, 'ped_1', 'PED-0001', 1));

      // Intentar reutilizar PED-0001 con contador en 2
      await assertFails(crearPedidoAtomico(adminDb, 'ped_2', 'PED-0001', 2));

      // Intentar sobreescribir ped_1 con otro batch
      await assertFails(crearPedidoAtomico(adminDb, 'ped_1', 'PED-0002', 2));
    });

    it('Deniega salto de consecutivo, decremento y eliminación del contador', async () => {
      const adminDb = testEnv.authenticatedContext(ADMIN_UID_1).firestore();

      // Salto inicial (ultimoNumero: 2 en creación)
      await assertFails(crearPedidoAtomico(adminDb, 'ped_salto', 'PED-0002', 2));

      // Inicializar correctamente en 1
      await assertSucceeds(crearPedidoAtomico(adminDb, 'ped_1', 'PED-0001', 1));

      // Salto de 1 a 3
      await assertFails(crearPedidoAtomico(adminDb, 'ped_3', 'PED-0003', 3));

      // Decremento / reinicio a 1 o 0
      await assertFails(crearPedidoAtomico(adminDb, 'ped_dec', 'PED-0001', 1));
      await assertFails(crearPedidoAtomico(adminDb, 'ped_cero', 'PED-0000', 0));

      // Eliminación del contador
      await assertFails(deleteDoc(doc(adminDb, 'contadores', 'pedidos')));
    });

    it('Deniega campos extra, facturado: true al crear, y deniega actualizaciones y eliminaciones de pedidos', async () => {
      const adminDb = testEnv.authenticatedContext(ADMIN_UID_1).firestore();

      // Campo adicional no autorizado
      const batchExtra = writeBatch(adminDb);
      batchExtra.set(doc(adminDb, 'pedidos', 'ped_extra'), {
        ...construirPedidoValido('ped_extra', 'PED-0001'),
        campoInesperado: true,
      });
      batchExtra.set(doc(adminDb, 'contadores', 'pedidos'), {
        ultimoNumero: 1,
        ultimoPedidoId: 'ped_extra',
        updatedAt: serverTimestamp(),
      });
      await assertFails(batchExtra.commit());

      // facturado: true al crear
      const batchFacturado = writeBatch(adminDb);
      batchFacturado.set(doc(adminDb, 'pedidos', 'ped_fact'), {
        ...construirPedidoValido('ped_fact', 'PED-0001'),
        facturado: true,
      });
      batchFacturado.set(doc(adminDb, 'contadores', 'pedidos'), {
        ultimoNumero: 1,
        ultimoPedidoId: 'ped_fact',
        updatedAt: serverTimestamp(),
      });
      await assertFails(batchFacturado.commit());

      // Crear pedido válido y verificar que update y delete están denegados por ahora
      await assertSucceeds(crearPedidoAtomico(adminDb, 'ped_1', 'PED-0001', 1));

      await assertFails(
        updateDoc(doc(adminDb, 'pedidos', 'ped_1'), {
          estadoEnvio: 'enviado',
          updatedAt: serverTimestamp(),
        }),
      );

      await assertFails(deleteDoc(doc(adminDb, 'pedidos', 'ped_1')));
    });

    it('Administrador autorizado actualiza únicamente estadoElaboracion, estadoProduccion coherente y updatedAt con serverTimestamp()', async () => {
      const adminDb = testEnv.authenticatedContext(ADMIN_UID_1).firestore();
      const pedidoMultiItem = {
        ...construirPedidoValido('ped_upd_ok', 'PED-0001'),
        items: [
          {
            itemId: 'item_1',
            productoId: 'prod_1',
            nombre: 'Pulsera Artesanal',
            cantidad: 2,
            precioUnitario: 250,
            imageUrl: null,
            notaPersonalizacion: 'Iniciales A.M.',
            estadoElaboracion: 'recibido',
          },
          {
            itemId: 'item_2',
            productoId: 'prod_1',
            nombre: 'Pulsera Artesanal',
            cantidad: 1,
            precioUnitario: 250,
            imageUrl: null,
            notaPersonalizacion: 'Iniciales J.R.',
            estadoElaboracion: 'recibido',
          },
        ],
      };

      const batch = writeBatch(adminDb);
      batch.set(doc(adminDb, 'pedidos', 'ped_upd_ok'), pedidoMultiItem);
      batch.set(doc(adminDb, 'contadores', 'pedidos'), {
        ultimoNumero: 1,
        ultimoPedidoId: 'ped_upd_ok',
        updatedAt: serverTimestamp(),
      });
      await assertSucceeds(batch.commit());

      // 1 terminado + 1 recibido -> estadoProduccion debe ser 'en_proceso'
      const itemsParciales = [
        { ...pedidoMultiItem.items[0], estadoElaboracion: 'terminado' },
        { ...pedidoMultiItem.items[1], estadoElaboracion: 'recibido' },
      ];
      await assertSucceeds(
        updateDoc(doc(adminDb, 'pedidos', 'ped_upd_ok'), {
          items: itemsParciales,
          estadoProduccion: 'en_proceso',
          updatedAt: serverTimestamp(),
        }),
      );

      // Todos terminados -> estadoProduccion debe ser 'terminado'
      const itemsCompletos = [
        { ...pedidoMultiItem.items[0], estadoElaboracion: 'terminado' },
        { ...pedidoMultiItem.items[1], estadoElaboracion: 'terminado' },
      ];
      await assertSucceeds(
        updateDoc(doc(adminDb, 'pedidos', 'ped_upd_ok'), {
          items: itemsCompletos,
          estadoProduccion: 'terminado',
          updatedAt: serverTimestamp(),
        }),
      );
    });

    it('Deniega actualización de estados de producción a no autenticados y usuarios no administradores', async () => {
      const adminDb = testEnv.authenticatedContext(ADMIN_UID_1).firestore();
      const unauthDb = testEnv.unauthenticatedContext().firestore();
      const otherDb = testEnv.authenticatedContext(UNAUTHORIZED_UID).firestore();

      await assertSucceeds(
        crearPedidoAtomico(adminDb, 'ped_upd_auth', 'PED-0001', 1),
      );

      const baseItem = construirPedidoValido('ped_upd_auth', 'PED-0001').items[0];
      const payload = {
        items: [{ ...baseItem, estadoElaboracion: 'en_proceso' }],
        estadoProduccion: 'en_proceso',
        updatedAt: serverTimestamp(),
      };

      await assertFails(
        updateDoc(doc(unauthDb, 'pedidos', 'ped_upd_auth'), payload),
      );
      await assertFails(
        updateDoc(doc(otherDb, 'pedidos', 'ped_upd_auth'), payload),
      );
    });

    it('Deniega modificar precios, cantidades, personalizaciones, identificadores o reordenar/agregar/eliminar accesorios', async () => {
      const adminDb = testEnv.authenticatedContext(ADMIN_UID_1).firestore();
      const pedidoBase = {
        ...construirPedidoValido('ped_upd_campos', 'PED-0001'),
        items: [
          {
            itemId: 'item_1',
            productoId: 'prod_1',
            nombre: 'Pulsera Artesanal',
            cantidad: 2,
            precioUnitario: 250,
            imageUrl: null,
            notaPersonalizacion: 'Nota 1',
            estadoElaboracion: 'recibido',
          },
          {
            itemId: 'item_2',
            productoId: 'prod_2',
            nombre: 'Collar Dorado',
            cantidad: 1,
            precioUnitario: 350,
            imageUrl: null,
            notaPersonalizacion: 'Nota 2',
            estadoElaboracion: 'recibido',
          },
        ],
      };

      const batch = writeBatch(adminDb);
      batch.set(doc(adminDb, 'pedidos', 'ped_upd_campos'), pedidoBase);
      batch.set(doc(adminDb, 'contadores', 'pedidos'), {
        ultimoNumero: 1,
        ultimoPedidoId: 'ped_upd_campos',
        updatedAt: serverTimestamp(),
      });
      await assertSucceeds(batch.commit());

      const ref = doc(adminDb, 'pedidos', 'ped_upd_campos');
      const [item1, item2] = pedidoBase.items;

      // Cambiar precioUnitario
      await assertFails(
        updateDoc(ref, {
          items: [{ ...item1, precioUnitario: 100, estadoElaboracion: 'en_proceso' }, item2],
          estadoProduccion: 'en_proceso',
          updatedAt: serverTimestamp(),
        }),
      );

      // Cambiar cantidad
      await assertFails(
        updateDoc(ref, {
          items: [{ ...item1, cantidad: 5, estadoElaboracion: 'en_proceso' }, item2],
          estadoProduccion: 'en_proceso',
          updatedAt: serverTimestamp(),
        }),
      );

      // Cambiar notaPersonalizacion
      await assertFails(
        updateDoc(ref, {
          items: [{ ...item1, notaPersonalizacion: 'Alterada', estadoElaboracion: 'en_proceso' }, item2],
          estadoProduccion: 'en_proceso',
          updatedAt: serverTimestamp(),
        }),
      );

      // Cambiar itemId o productoId
      await assertFails(
        updateDoc(ref, {
          items: [{ ...item1, itemId: 'item_hack', estadoElaboracion: 'en_proceso' }, item2],
          estadoProduccion: 'en_proceso',
          updatedAt: serverTimestamp(),
        }),
      );
      await assertFails(
        updateDoc(ref, {
          items: [{ ...item1, productoId: 'prod_hack', estadoElaboracion: 'en_proceso' }, item2],
          estadoProduccion: 'en_proceso',
          updatedAt: serverTimestamp(),
        }),
      );

      // Reordenar accesorios
      await assertFails(
        updateDoc(ref, {
          items: [item2, item1],
          estadoProduccion: 'recibido',
          updatedAt: serverTimestamp(),
        }),
      );

      // Agregar o eliminar accesorios
      await assertFails(
        updateDoc(ref, {
          items: [item1, item2, { ...item2, itemId: 'item_3' }],
          estadoProduccion: 'recibido',
          updatedAt: serverTimestamp(),
        }),
      );
      await assertFails(
        updateDoc(ref, {
          items: [item1],
          estadoProduccion: 'recibido',
          updatedAt: serverTimestamp(),
        }),
      );
    });

    it('Deniega alterar envío/facturación, estados inválidos, estadoProduccion inconsistente y updatedAt manipulado', async () => {
      const adminDb = testEnv.authenticatedContext(ADMIN_UID_1).firestore();
      const pedidoBase = {
        ...construirPedidoValido('ped_upd_consist', 'PED-0001'),
        items: [
          {
            itemId: 'item_1',
            productoId: 'prod_1',
            nombre: 'Pulsera Artesanal',
            cantidad: 1,
            precioUnitario: 250,
            imageUrl: null,
            notaPersonalizacion: 'A',
            estadoElaboracion: 'recibido',
          },
          {
            itemId: 'item_2',
            productoId: 'prod_1',
            nombre: 'Pulsera Artesanal',
            cantidad: 1,
            precioUnitario: 250,
            imageUrl: null,
            notaPersonalizacion: 'B',
            estadoElaboracion: 'recibido',
          },
        ],
      };

      const batch = writeBatch(adminDb);
      batch.set(doc(adminDb, 'pedidos', 'ped_upd_consist'), pedidoBase);
      batch.set(doc(adminDb, 'contadores', 'pedidos'), {
        ultimoNumero: 1,
        ultimoPedidoId: 'ped_upd_consist',
        updatedAt: serverTimestamp(),
      });
      await assertSucceeds(batch.commit());

      const ref = doc(adminDb, 'pedidos', 'ped_upd_consist');
      const [item1, item2] = pedidoBase.items;
      const itemsEnProceso = [
        { ...item1, estadoElaboracion: 'terminado' },
        { ...item2, estadoElaboracion: 'recibido' },
      ];

      // Alterar envío o facturación junto con estados
      await assertFails(
        updateDoc(ref, {
          items: itemsEnProceso,
          estadoProduccion: 'en_proceso',
          costoEnvio: 0,
          updatedAt: serverTimestamp(),
        }),
      );
      await assertFails(
        updateDoc(ref, {
          items: itemsEnProceso,
          estadoProduccion: 'en_proceso',
          facturado: true,
          updatedAt: serverTimestamp(),
        }),
      );

      // Estado general inconsistente (1 terminado + 1 recibido no puede ser 'terminado' ni 'recibido')
      await assertFails(
        updateDoc(ref, {
          items: itemsEnProceso,
          estadoProduccion: 'terminado',
          updatedAt: serverTimestamp(),
        }),
      );
      await assertFails(
        updateDoc(ref, {
          items: itemsEnProceso,
          estadoProduccion: 'recibido',
          updatedAt: serverTimestamp(),
        }),
      );

      // Valor de estado inválido
      await assertFails(
        updateDoc(ref, {
          items: [{ ...item1, estadoElaboracion: 'cancelado' }, item2],
          estadoProduccion: 'en_proceso',
          updatedAt: serverTimestamp(),
        }),
      );

      // Fecha de actualización manipulada (no serverTimestamp)
      await assertFails(
        updateDoc(ref, {
          items: itemsEnProceso,
          estadoProduccion: 'en_proceso',
          updatedAt: Timestamp.fromDate(new Date('2026-11-14T12:00:00.000Z')),
        }),
      );

      // Actualizar únicamente updatedAt sin cambiar ningún estadoElaboracion
      await assertFails(
        updateDoc(ref, {
          updatedAt: serverTimestamp(),
        }),
      );
      await assertFails(
        updateDoc(ref, {
          items: pedidoBase.items,
          estadoProduccion: pedidoBase.estadoProduccion,
          updatedAt: serverTimestamp(),
        }),
      );
    });
  });
});
