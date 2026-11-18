const { describe, it } = require('node:test');
const assert = require('node:assert/strict');
const { ejecutarMarcarPedidoEnviado } = require('../marcar_pedido_enviado_core');

const ADMIN_UID = 'sK72fiKvY0crBfUzpP4TuqnHhBE3';
const NON_ADMIN_UID = 'usuario_normal_123';
const SERVER_TOKEN = Symbol('SERVER_TIMESTAMP');

function crearFirestoreMock(
  estadoInicial = {},
  fechaServidor = new Date('2026-11-18T18:30:00.000Z'),
) {
  const store = new Map();
  for (const [col, docs] of Object.entries(estadoInicial)) {
    for (const [id, data] of Object.entries(docs)) {
      store.set(`${col}/${id}`, structuredClone(data));
    }
  }

  let bloqueo = Promise.resolve();

  function resolverValor(val) {
    if (val === SERVER_TOKEN) return new Date(fechaServidor.getTime());
    if (Array.isArray(val)) return val.map(resolverValor);
    if (val && typeof val === 'object' && !(val instanceof Date)) {
      const out = {};
      for (const [k, v] of Object.entries(val)) {
        out[k] = resolverValor(v);
      }
      return out;
    }
    return structuredClone(val);
  }

  const db = {
    collection(col) {
      return {
        doc(id) {
          return { id, path: `${col}/${id}` };
        },
      };
    },
    async runTransaction(fn) {
      const ejecutar = async () => {
        const escrituras = [];
        const tx = {
          async get(ref) {
            const existe = store.has(ref.path);
            const data = existe ? structuredClone(store.get(ref.path)) : undefined;
            return {
              id: ref.id,
              exists: existe,
              data: () => (existe ? structuredClone(data) : undefined),
            };
          },
          update(ref, data) {
            escrituras.push({
              tipo: 'update',
              path: ref.path,
              data: resolverValor(data),
            });
          },
        };

        const resultado = await fn(tx);

        for (const op of escrituras) {
          const previo = store.get(op.path);
          if (!previo) {
            throw new Error(`No existe documento para update: ${op.path}`);
          }
          store.set(op.path, { ...previo, ...op.data });
        }
        return resultado;
      };

      const siguiente = bloqueo.then(ejecutar, ejecutar);
      bloqueo = siguiente.catch(() => {});
      return siguiente;
    },
    leer(col, id) {
      return store.get(`${col}/${id}`);
    },
  };

  return db;
}

function crearItems(cantidad, { estado = 'terminado' } = {}) {
  return Array.from({ length: cantidad }, (_, i) => ({
    itemId: `item-${i + 1}`,
    productoId: `prod-${i + 1}`,
    nombre: `Pulsera ${i + 1}`,
    cantidad: 1,
    precioUnitario: 100,
    estadoElaboracion: estado,
  }));
}

function crearPedidoBase(overrides = {}) {
  return {
    id: 'ped-1',
    numeroPedido: 'PED-0001',
    clienteId: 'cli-1',
    clienteNombre: 'María José Muñoz',
    estadoProduccion: 'terminado',
    estadoEnvio: 'pendiente',
    facturado: false,
    ventaId: null,
    facturaNumero: null,
    costoEnvio: 120,
    borradorFactura: {
      impuestoPorcentaje: 0,
      descuentoMayoristaActivo: false,
      descuentoPorcentaje: 0,
      costoEnvio: 120,
      subtotalEstimado: 100,
      totalEstimado: 220,
    },
    items: crearItems(1),
    fechaEnvio: null,
    updatedAt: new Date('2026-11-18T12:00:00.000Z'),
    ...overrides,
  };
}

describe('ejecutarMarcarPedidoEnviado', () => {
  const fechaServidor = new Date('2026-11-18T18:30:00.000Z');
  const updatedAtInicial = new Date('2026-11-18T12:00:00.000Z');

  it('marca como enviado un pedido pendiente con todos los artículos terminados y conserva los demás campos', async () => {
    const pedidoInicial = crearPedidoBase();
    const db = crearFirestoreMock(
      { pedidos: { 'ped-1': pedidoInicial } },
      fechaServidor,
    );

    const resultado = await ejecutarMarcarPedidoEnviado({
      auth: { uid: ADMIN_UID },
      data: {
        pedidoId: 'ped-1',
        updatedAtEsperadoMs: updatedAtInicial.getTime(),
      },
      db,
      serverTimestamp: () => SERVER_TOKEN,
    });

    assert.deepEqual(resultado, {
      ok: true,
      pedidoId: 'ped-1',
      estadoEnvio: 'enviado',
    });

    const guardado = db.leer('pedidos', 'ped-1');
    assert.equal(guardado.estadoEnvio, 'enviado');
    assert.equal(guardado.fechaEnvio.getTime(), fechaServidor.getTime());
    assert.equal(guardado.updatedAt.getTime(), fechaServidor.getTime());
    assert.equal(guardado.numeroPedido, pedidoInicial.numeroPedido);
    assert.equal(guardado.clienteId, pedidoInicial.clienteId);
    assert.equal(guardado.clienteNombre, pedidoInicial.clienteNombre);
    assert.equal(guardado.estadoProduccion, pedidoInicial.estadoProduccion);
    assert.equal(guardado.facturado, pedidoInicial.facturado);
    assert.deepEqual(guardado.borradorFactura, pedidoInicial.borradorFactura);
    assert.deepEqual(guardado.items, pedidoInicial.items);
  });

  it('permite marcar como enviado un pedido con 25 artículos terminados sin límite de 20', async () => {
    const db = crearFirestoreMock(
      {
        pedidos: {
          'ped-25': crearPedidoBase({
            id: 'ped-25',
            items: crearItems(25, { estado: 'terminado' }),
          }),
        },
      },
      fechaServidor,
    );

    const resultado = await ejecutarMarcarPedidoEnviado({
      auth: { uid: ADMIN_UID },
      data: {
        pedidoId: 'ped-25',
        updatedAtEsperadoMs: updatedAtInicial.getTime(),
      },
      db,
      serverTimestamp: () => SERVER_TOKEN,
    });

    assert.equal(resultado.ok, true);
    assert.equal(db.leer('pedidos', 'ped-25').estadoEnvio, 'enviado');
  });

  it('rechaza un pedido con más de 20 artículos cuando el artículo 21 no está terminado', async () => {
    const items = crearItems(25, { estado: 'terminado' });
    items[20].estadoElaboracion = 'en_proceso';

    const db = crearFirestoreMock({
      pedidos: {
        'ped-21': crearPedidoBase({
          id: 'ped-21',
          estadoProduccion: 'en_proceso',
          items,
        }),
      },
    });

    await assert.rejects(
      () =>
        ejecutarMarcarPedidoEnviado({
          auth: { uid: ADMIN_UID },
          data: {
            pedidoId: 'ped-21',
            updatedAtEsperadoMs: updatedAtInicial.getTime(),
          },
          db,
          serverTimestamp: () => SERVER_TOKEN,
        }),
      (err) => err.code === 'failed-precondition',
    );

    assert.equal(db.leer('pedidos', 'ped-21').estadoEnvio, 'pendiente');
  });

  it('permite marcar como enviado un pedido ya facturado con producción terminada', async () => {
    const db = crearFirestoreMock(
      {
        pedidos: {
          'ped-fac': crearPedidoBase({
            id: 'ped-fac',
            facturado: true,
            ventaId: 'FAC-0010',
            facturaNumero: 'FAC-0010',
          }),
        },
      },
      fechaServidor,
    );

    const resultado = await ejecutarMarcarPedidoEnviado({
      auth: { uid: ADMIN_UID },
      data: {
        pedidoId: 'ped-fac',
        updatedAtEsperadoMs: updatedAtInicial.getTime(),
      },
      db,
      serverTimestamp: () => SERVER_TOKEN,
    });

    assert.equal(resultado.ok, true);
    const guardado = db.leer('pedidos', 'ped-fac');
    assert.equal(guardado.estadoEnvio, 'enviado');
    assert.equal(guardado.facturado, true);
    assert.equal(guardado.facturaNumero, 'FAC-0010');
  });

  it('considera como pendiente un pedido antiguo sin campo estadoEnvio', async () => {
    const pedidoAntiguo = crearPedidoBase({ id: 'ped-old' });
    delete pedidoAntiguo.estadoEnvio;

    const db = crearFirestoreMock(
      { pedidos: { 'ped-old': pedidoAntiguo } },
      fechaServidor,
    );

    const resultado = await ejecutarMarcarPedidoEnviado({
      auth: { uid: ADMIN_UID },
      data: {
        pedidoId: 'ped-old',
        updatedAtEsperadoMs: updatedAtInicial.getTime(),
      },
      db,
      serverTimestamp: () => SERVER_TOKEN,
    });

    assert.equal(resultado.ok, true);
    assert.equal(db.leer('pedidos', 'ped-old').estadoEnvio, 'enviado');
  });

  it('rechaza pedidos sin artículos', async () => {
    const db = crearFirestoreMock({
      pedidos: {
        'ped-vacio': crearPedidoBase({ id: 'ped-vacio', items: [] }),
      },
    });

    await assert.rejects(
      () =>
        ejecutarMarcarPedidoEnviado({
          auth: { uid: ADMIN_UID },
          data: {
            pedidoId: 'ped-vacio',
            updatedAtEsperadoMs: updatedAtInicial.getTime(),
          },
          db,
          serverTimestamp: () => SERVER_TOKEN,
        }),
      (err) => err.code === 'failed-precondition',
    );
  });

  it('rechaza pedidos con artículos sin estadoElaboracion', async () => {
    const itemSinEstado = {
      itemId: 'item-1',
      productoId: 'prod-1',
      nombre: 'Pulsera',
      cantidad: 1,
      precioUnitario: 100,
    };

    const db = crearFirestoreMock({
      pedidos: {
        'ped-sin-est': crearPedidoBase({
          id: 'ped-sin-est',
          items: [itemSinEstado],
        }),
      },
    });

    await assert.rejects(
      () =>
        ejecutarMarcarPedidoEnviado({
          auth: { uid: ADMIN_UID },
          data: {
            pedidoId: 'ped-sin-est',
            updatedAtEsperadoMs: updatedAtInicial.getTime(),
          },
          db,
          serverTimestamp: () => SERVER_TOKEN,
        }),
      (err) => err.code === 'failed-precondition',
    );
  });

  it('rechaza pedidos ya enviados y conserva su fechaEnvio', async () => {
    const fechaEnvioPrevia = new Date('2026-11-17T10:00:00.000Z');
    const db = crearFirestoreMock({
      pedidos: {
        'ped-env': crearPedidoBase({
          id: 'ped-env',
          estadoEnvio: 'enviado',
          fechaEnvio: fechaEnvioPrevia,
        }),
      },
    });

    await assert.rejects(
      () =>
        ejecutarMarcarPedidoEnviado({
          auth: { uid: ADMIN_UID },
          data: {
            pedidoId: 'ped-env',
            updatedAtEsperadoMs: updatedAtInicial.getTime(),
          },
          db,
          serverTimestamp: () => SERVER_TOKEN,
        }),
      (err) => err.code === 'failed-precondition',
    );

    const guardado = db.leer('pedidos', 'ped-env');
    assert.equal(guardado.estadoEnvio, 'enviado');
    assert.equal(guardado.fechaEnvio.getTime(), fechaEnvioPrevia.getTime());
  });

  it('rechaza pedidos históricos entregados sin modificarlos', async () => {
    const db = crearFirestoreMock({
      pedidos: {
        'ped-ent': crearPedidoBase({
          id: 'ped-ent',
          estadoEnvio: 'entregado',
        }),
      },
    });

    await assert.rejects(
      () =>
        ejecutarMarcarPedidoEnviado({
          auth: { uid: ADMIN_UID },
          data: {
            pedidoId: 'ped-ent',
            updatedAtEsperadoMs: updatedAtInicial.getTime(),
          },
          db,
          serverTimestamp: () => SERVER_TOKEN,
        }),
      (err) => err.code === 'failed-precondition',
    );

    assert.equal(db.leer('pedidos', 'ped-ent').estadoEnvio, 'entregado');
  });

  it('rechaza usuario no autenticado', async () => {
    const db = crearFirestoreMock({ pedidos: { 'ped-1': crearPedidoBase() } });

    await assert.rejects(
      () =>
        ejecutarMarcarPedidoEnviado({
          auth: null,
          data: {
            pedidoId: 'ped-1',
            updatedAtEsperadoMs: updatedAtInicial.getTime(),
          },
          db,
          serverTimestamp: () => SERVER_TOKEN,
        }),
      (err) => err.code === 'unauthenticated',
    );
  });

  it('rechaza usuario sin permisos administrativos', async () => {
    const db = crearFirestoreMock({ pedidos: { 'ped-1': crearPedidoBase() } });

    await assert.rejects(
      () =>
        ejecutarMarcarPedidoEnviado({
          auth: { uid: NON_ADMIN_UID },
          data: {
            pedidoId: 'ped-1',
            updatedAtEsperadoMs: updatedAtInicial.getTime(),
          },
          db,
          serverTimestamp: () => SERVER_TOKEN,
        }),
      (err) => err.code === 'permission-denied',
    );
  });

  it('rechaza cuando el pedido no existe', async () => {
    const db = crearFirestoreMock({});

    await assert.rejects(
      () =>
        ejecutarMarcarPedidoEnviado({
          auth: { uid: ADMIN_UID },
          data: {
            pedidoId: 'inexistente',
            updatedAtEsperadoMs: updatedAtInicial.getTime(),
          },
          db,
          serverTimestamp: () => SERVER_TOKEN,
        }),
      (err) => err.code === 'not-found',
    );
  });

  it('rechaza conflicto de concurrencia cuando updatedAtEsperadoMs no coincide', async () => {
    const db = crearFirestoreMock({ pedidos: { 'ped-1': crearPedidoBase() } });

    await assert.rejects(
      () =>
        ejecutarMarcarPedidoEnviado({
          auth: { uid: ADMIN_UID },
          data: {
            pedidoId: 'ped-1',
            updatedAtEsperadoMs: updatedAtInicial.getTime() - 1000,
          },
          db,
          serverTimestamp: () => SERVER_TOKEN,
        }),
      (err) => err.code === 'failed-precondition',
    );

    assert.equal(db.leer('pedidos', 'ped-1').estadoEnvio, 'pendiente');
  });

  it('impide doble transición cuando llegan dos solicitudes simultáneas', async () => {
    const db = crearFirestoreMock(
      { pedidos: { 'ped-1': crearPedidoBase() } },
      fechaServidor,
    );

    const resultados = await Promise.allSettled([
      ejecutarMarcarPedidoEnviado({
        auth: { uid: ADMIN_UID },
        data: {
          pedidoId: 'ped-1',
          updatedAtEsperadoMs: updatedAtInicial.getTime(),
        },
        db,
        serverTimestamp: () => SERVER_TOKEN,
      }),
      ejecutarMarcarPedidoEnviado({
        auth: { uid: ADMIN_UID },
        data: {
          pedidoId: 'ped-1',
          updatedAtEsperadoMs: updatedAtInicial.getTime(),
        },
        db,
        serverTimestamp: () => SERVER_TOKEN,
      }),
    ]);

    const exitos = resultados.filter((r) => r.status === 'fulfilled');
    const fallos = resultados.filter((r) => r.status === 'rejected');

    assert.equal(exitos.length, 1);
    assert.equal(fallos.length, 1);
    assert.equal(fallos[0].reason.code, 'failed-precondition');
    assert.equal(db.leer('pedidos', 'ped-1').estadoEnvio, 'enviado');
  });
});
