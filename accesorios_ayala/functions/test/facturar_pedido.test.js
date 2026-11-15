const { describe, it } = require('node:test');
const assert = require('node:assert/strict');
const {
  formatearNumeroFactura,
  ejecutarFacturarPedido,
} = require('../facturar_pedido_core');

const ADMIN_UID = 'sK72fiKvY0crBfUzpP4TuqnHhBE3';
const NON_ADMIN_UID = 'usuario_normal_123';
const SERVER_TOKEN = Symbol('SERVER_TIMESTAMP');

function crearFirestoreMock(estadoInicial = {}, fechaServidor = new Date('2026-11-14T20:30:00.000Z')) {
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
          set(ref, data) {
            escrituras.push({ tipo: 'set', path: ref.path, data: resolverValor(data) });
          },
          update(ref, data) {
            escrituras.push({ tipo: 'update', path: ref.path, data: resolverValor(data) });
          },
        };

        const resultado = await fn(tx);

        for (const op of escrituras) {
          if (op.tipo === 'set') {
            store.set(op.path, op.data);
          } else {
            const previo = store.get(op.path);
            if (!previo) throw new Error(`No existe documento para update: ${op.path}`);
            store.set(op.path, { ...previo, ...op.data });
          }
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

function crearItems(cantidad, { estado = 'terminado', precioUnitario = 100 } = {}) {
  return Array.from({ length: cantidad }, (_, i) => ({
    itemId: `item-${i + 1}`,
    productoId: `prod-${i + 1}`,
    nombre: `Accesorio ${i + 1}`,
    cantidad: 1,
    precioUnitario,
    imageUrl: null,
    notaPersonalizacion: '',
    estadoElaboracion: estado,
  }));
}

function crearPedido({
  cantidadItems = 2,
  estadoItem = 'terminado',
  facturado = false,
  ventaId = null,
  facturaNumero = null,
  updatedAt = new Date('2026-11-14T18:00:00.000Z'),
  impuestoPorcentaje = 15,
  descuentoMayoristaActivo = true,
  descuentoPorcentaje = 20,
  costoEnvio = 120,
} = {}) {
  return {
    id: 'ped-1',
    numeroPedido: 'PED-0001',
    clienteId: 'cli-1',
    clienteNombre: 'Ana López',
    items: crearItems(cantidadItems, { estado: estadoItem, precioUnitario: 250 }),
    borradorFactura: {
      impuestoPorcentaje,
      descuentoMayoristaActivo,
      descuentoPorcentaje,
      costoEnvio,
    },
    facturado,
    ventaId,
    facturaNumero,
    updatedAt,
  };
}

describe('facturarPedido (Cloud Functions core)', () => {
  it('formatea consecutivos FAC-0001+ correctamente', () => {
    assert.equal(formatearNumeroFactura(1), 'FAC-0001');
    assert.equal(formatearNumeroFactura(42), 'FAC-0042');
    assert.equal(formatearNumeroFactura(10000), 'FAC-10000');
  });

  it('factura válidamente un pedido creando contadores/facturas, venta compatible y actualizando pedido', async () => {
    const updatedAt = new Date('2026-11-14T18:00:00.000Z');
    const fechaEmision = new Date('2026-11-14T20:15:00.000Z');
    const db = crearFirestoreMock({
      pedidos: { 'ped-1': crearPedido({ updatedAt }) },
    });

    const res = await ejecutarFacturarPedido({
      auth: { uid: ADMIN_UID },
      data: {
        pedidoId: 'ped-1',
        updatedAtEsperadoMs: updatedAt.getTime(),
        subtotal: 1,
        total: 1,
      },
      db,
      serverTimestamp: () => SERVER_TOKEN,
      now: () => fechaEmision,
    });

    assert.equal(res.facturaNumero, 'FAC-0001');
    assert.equal(res.subtotal, 500);
    assert.equal(res.descuentoMonto, 100);
    assert.equal(res.impuesto, 60);
    assert.equal(res.envio, 120);
    assert.equal(res.total, 580);

    const venta = db.leer('ventas', 'FAC-0001');
    assert.deepEqual(venta, {
      id: 'FAC-0001',
      clienteId: 'cli-1',
      clienteNombre: 'Ana López',
      fecha: '2026-11-14T20:15:00.000Z',
      subtotal: 500,
      impuesto: 60,
      total: 580,
      envio: 120,
      descuentoMayoristaActivo: true,
      descuentoPorcentaje: 20,
      descuentoMonto: 100,
    });

    const contador = db.leer('contadores', 'facturas');
    assert.equal(contador.ultimoNumero, 1);
    assert.equal(contador.ultimaVentaId, 'FAC-0001');
    assert.equal(contador.ultimoPedidoId, 'ped-1');

    const pedido = db.leer('pedidos', 'ped-1');
    assert.equal(pedido.facturado, true);
    assert.equal(pedido.ventaId, 'FAC-0001');
    assert.equal(pedido.facturaNumero, 'FAC-0001');
  });

  it('factura pedido con 25 accesorios terminados sin límite de 20', async () => {
    const updatedAt = new Date('2026-11-14T18:00:00.000Z');
    const db = crearFirestoreMock({
      pedidos: {
        'ped-25': crearPedido({
          cantidadItems: 25,
          descuentoMayoristaActivo: false,
          descuentoPorcentaje: 0,
          impuestoPorcentaje: 0,
          costoEnvio: 50,
          updatedAt,
        }),
      },
    });

    const res = await ejecutarFacturarPedido({
      auth: { uid: ADMIN_UID },
      data: { pedidoId: 'ped-25', updatedAtEsperadoMs: updatedAt.getTime() },
      db,
      serverTimestamp: () => SERVER_TOKEN,
    });

    assert.equal(res.subtotal, 6250);
    assert.equal(res.total, 6300);
  });

  it('factura pedido con 50 accesorios terminados sin límite de 20', async () => {
    const updatedAt = new Date('2026-11-14T18:00:00.000Z');
    const db = crearFirestoreMock({
      pedidos: {
        'ped-50': crearPedido({
          cantidadItems: 50,
          descuentoMayoristaActivo: false,
          descuentoPorcentaje: 0,
          impuestoPorcentaje: 15,
          costoEnvio: 0,
          updatedAt,
        }),
      },
    });

    const res = await ejecutarFacturarPedido({
      auth: { uid: ADMIN_UID },
      data: { pedidoId: 'ped-50', updatedAtEsperadoMs: updatedAt.getTime() },
      db,
      serverTimestamp: () => SERVER_TOKEN,
    });

    assert.equal(res.subtotal, 12500);
    assert.equal(res.impuesto, 1875);
    assert.equal(res.total, 14375);
  });

  it('rechaza pedido con un accesorio pendiente (en_proceso)', async () => {
    const updatedAt = new Date('2026-11-14T18:00:00.000Z');
    const pedido = crearPedido({ cantidadItems: 25, updatedAt });
    pedido.items[24].estadoElaboracion = 'en_proceso';

    const db = crearFirestoreMock({ pedidos: { 'ped-pend': pedido } });

    await assert.rejects(
      () =>
        ejecutarFacturarPedido({
          auth: { uid: ADMIN_UID },
          data: { pedidoId: 'ped-pend', updatedAtEsperadoMs: updatedAt.getTime() },
          db,
          serverTimestamp: () => SERVER_TOKEN,
        }),
      (err) => err.code === 'failed-precondition',
    );
  });

  it('rechaza pedido ya facturado', async () => {
    const updatedAt = new Date('2026-11-14T18:00:00.000Z');
    const db = crearFirestoreMock({
      pedidos: {
        'ped-fac': crearPedido({
          facturado: true,
          ventaId: 'FAC-0001',
          facturaNumero: 'FAC-0001',
          updatedAt,
        }),
      },
    });

    await assert.rejects(
      () =>
        ejecutarFacturarPedido({
          auth: { uid: ADMIN_UID },
          data: { pedidoId: 'ped-fac', updatedAtEsperadoMs: updatedAt.getTime() },
          db,
          serverTimestamp: () => SERVER_TOKEN,
        }),
      (err) => err.code === 'failed-precondition',
    );
  });

  it('rechaza usuario no autenticado y usuario no administrador aunque envíe UID admin en payload', async () => {
    const updatedAt = new Date('2026-11-14T18:00:00.000Z');
    const db = crearFirestoreMock({ pedidos: { 'ped-1': crearPedido({ updatedAt }) } });

    await assert.rejects(
      () =>
        ejecutarFacturarPedido({
          auth: null,
          data: { pedidoId: 'ped-1', updatedAtEsperadoMs: updatedAt.getTime(), uid: ADMIN_UID },
          db,
          serverTimestamp: () => SERVER_TOKEN,
        }),
      (err) => err.code === 'unauthenticated',
    );

    await assert.rejects(
      () =>
        ejecutarFacturarPedido({
          auth: { uid: NON_ADMIN_UID },
          data: { pedidoId: 'ped-1', updatedAtEsperadoMs: updatedAt.getTime(), adminUid: ADMIN_UID },
          db,
          serverTimestamp: () => SERVER_TOKEN,
        }),
      (err) => err.code === 'permission-denied',
    );
  });

  it('impide doble facturación concurrente sobre el mismo pedido y respeta consecutivo incremental', async () => {
    const updatedAt = new Date('2026-11-14T18:00:00.000Z');
    const db = crearFirestoreMock({
      contadores: {
        facturas: { ultimoNumero: 4, ultimaVentaId: 'FAC-0004', ultimoPedidoId: 'ped-prev' },
      },
      pedidos: { 'ped-1': crearPedido({ updatedAt }) },
    });

    const [r1, r2] = await Promise.allSettled([
      ejecutarFacturarPedido({
        auth: { uid: ADMIN_UID },
        data: { pedidoId: 'ped-1', updatedAtEsperadoMs: updatedAt.getTime() },
        db,
        serverTimestamp: () => SERVER_TOKEN,
      }),
      ejecutarFacturarPedido({
        auth: { uid: ADMIN_UID },
        data: { pedidoId: 'ped-1', updatedAtEsperadoMs: updatedAt.getTime() },
        db,
        serverTimestamp: () => SERVER_TOKEN,
      }),
    ]);

    const exitos = [r1, r2].filter((r) => r.status === 'fulfilled');
    const fallos = [r1, r2].filter((r) => r.status === 'rejected');

    assert.equal(exitos.length, 1);
    assert.equal(fallos.length, 1);
    assert.equal(exitos[0].value.facturaNumero, 'FAC-0005');
    assert.equal(db.leer('contadores', 'facturas').ultimoNumero, 5);
  });

  it('acepta accesorio con precio cero válido', async () => {
    const updatedAt = new Date('2026-11-14T18:00:00.000Z');
    const pedido = crearPedido({
      cantidadItems: 1,
      descuentoMayoristaActivo: false,
      descuentoPorcentaje: 0,
      impuestoPorcentaje: 0,
      costoEnvio: 50,
      updatedAt,
    });
    pedido.items[0].precioUnitario = 0;

    const db = crearFirestoreMock({ pedidos: { 'ped-0': pedido } });
    const res = await ejecutarFacturarPedido({
      auth: { uid: ADMIN_UID },
      data: { pedidoId: 'ped-0', updatedAtEsperadoMs: updatedAt.getTime() },
      db,
      serverTimestamp: () => SERVER_TOKEN,
    });

    assert.equal(res.subtotal, 0);
    assert.equal(res.total, 50);
  });

  it('rechaza cantidad fraccionaria en un accesorio', async () => {
    const updatedAt = new Date('2026-11-14T18:00:00.000Z');
    const pedido = crearPedido({ cantidadItems: 1, updatedAt });
    pedido.items[0].cantidad = 1.5;

    const db = crearFirestoreMock({ pedidos: { 'ped-frac': pedido } });
    await assert.rejects(
      () =>
        ejecutarFacturarPedido({
          auth: { uid: ADMIN_UID },
          data: { pedidoId: 'ped-frac', updatedAtEsperadoMs: updatedAt.getTime() },
          db,
          serverTimestamp: () => SERVER_TOKEN,
        }),
      (err) =>
        err.code === 'failed-precondition' &&
        err.message.includes('cantidades o precios inválidos'),
    );
  });

  it('rechaza cantidad cero o negativa en un accesorio', async () => {
    const updatedAt = new Date('2026-11-14T18:00:00.000Z');
    for (const cantidadInvalida of [0, -2]) {
      const pedido = crearPedido({ cantidadItems: 1, updatedAt });
      pedido.items[0].cantidad = cantidadInvalida;
      const db = crearFirestoreMock({ pedidos: { 'ped-cant': pedido } });

      await assert.rejects(
        () =>
          ejecutarFacturarPedido({
            auth: { uid: ADMIN_UID },
            data: { pedidoId: 'ped-cant', updatedAtEsperadoMs: updatedAt.getTime() },
            db,
            serverTimestamp: () => SERVER_TOKEN,
          }),
        (err) =>
          err.code === 'failed-precondition' &&
          err.message.includes('cantidades o precios inválidos'),
      );
    }
  });

  it('rechaza precio negativo o no numérico en un accesorio', async () => {
    const updatedAt = new Date('2026-11-14T18:00:00.000Z');
    for (const precioInvalido of [-10, '100']) {
      const pedido = crearPedido({ cantidadItems: 1, updatedAt });
      pedido.items[0].precioUnitario = precioInvalido;
      const db = crearFirestoreMock({ pedidos: { 'ped-precio': pedido } });

      await assert.rejects(
        () =>
          ejecutarFacturarPedido({
            auth: { uid: ADMIN_UID },
            data: { pedidoId: 'ped-precio', updatedAtEsperadoMs: updatedAt.getTime() },
            db,
            serverTimestamp: () => SERVER_TOKEN,
          }),
        (err) =>
          err.code === 'failed-precondition' &&
          err.message.includes('cantidades o precios inválidos'),
      );
    }
  });

  it('rechaza descuentoMayoristaActivo con tipo inválido distinto de booleano', async () => {
    const updatedAt = new Date('2026-11-14T18:00:00.000Z');
    const pedido = crearPedido({ cantidadItems: 1, updatedAt });
    pedido.borradorFactura.descuentoMayoristaActivo = 'true';

    const db = crearFirestoreMock({ pedidos: { 'ped-desc-tipo': pedido } });
    await assert.rejects(
      () =>
        ejecutarFacturarPedido({
          auth: { uid: ADMIN_UID },
          data: { pedidoId: 'ped-desc-tipo', updatedAtEsperadoMs: updatedAt.getTime() },
          db,
          serverTimestamp: () => SERVER_TOKEN,
        }),
      (err) =>
        err.code === 'failed-precondition' &&
        err.message.includes('descuento mayorista'),
    );
  });

  it('maneja descuentos de 0 %, 100 % y rechaza mayores de 100 %', async () => {
    const updatedAt = new Date('2026-11-14T18:00:00.000Z');

    const db0 = crearFirestoreMock({
      pedidos: {
        'ped-0pct': crearPedido({
          cantidadItems: 1,
          descuentoMayoristaActivo: true,
          descuentoPorcentaje: 0,
          impuestoPorcentaje: 15,
          costoEnvio: 80,
          updatedAt,
        }),
      },
    });
    const res0 = await ejecutarFacturarPedido({
      auth: { uid: ADMIN_UID },
      data: { pedidoId: 'ped-0pct', updatedAtEsperadoMs: updatedAt.getTime() },
      db: db0,
      serverTimestamp: () => SERVER_TOKEN,
    });
    assert.equal(res0.descuentoMonto, 0);
    assert.equal(res0.impuesto, 37.5);
    assert.equal(res0.total, 367.5);

    const db100 = crearFirestoreMock({
      pedidos: {
        'ped-100pct': crearPedido({
          cantidadItems: 1,
          descuentoMayoristaActivo: true,
          descuentoPorcentaje: 100,
          impuestoPorcentaje: 15,
          costoEnvio: 80,
          updatedAt,
        }),
      },
    });
    const res100 = await ejecutarFacturarPedido({
      auth: { uid: ADMIN_UID },
      data: { pedidoId: 'ped-100pct', updatedAtEsperadoMs: updatedAt.getTime() },
      db: db100,
      serverTimestamp: () => SERVER_TOKEN,
    });
    assert.equal(res100.descuentoMonto, 250);
    assert.equal(res100.impuesto, 0);
    assert.equal(res100.total, 80);

    const db120 = crearFirestoreMock({
      pedidos: {
        'ped-120pct': crearPedido({
          cantidadItems: 1,
          descuentoMayoristaActivo: true,
          descuentoPorcentaje: 120,
          updatedAt,
        }),
      },
    });
    await assert.rejects(
      () =>
        ejecutarFacturarPedido({
          auth: { uid: ADMIN_UID },
          data: { pedidoId: 'ped-120pct', updatedAtEsperadoMs: updatedAt.getTime() },
          db: db120,
          serverTimestamp: () => SERVER_TOKEN,
        }),
      (err) =>
        err.code === 'failed-precondition' &&
        err.message.includes('configuración fiscal'),
    );
  });

  it('inicializa contador inexistente en FAC-0001', async () => {
    const updatedAt = new Date('2026-11-14T18:00:00.000Z');
    const db = crearFirestoreMock({
      pedidos: { 'ped-init': crearPedido({ updatedAt }) },
    });
    assert.equal(db.leer('contadores', 'facturas'), undefined);

    const res = await ejecutarFacturarPedido({
      auth: { uid: ADMIN_UID },
      data: { pedidoId: 'ped-init', updatedAtEsperadoMs: updatedAt.getTime() },
      db,
      serverTimestamp: () => SERVER_TOKEN,
    });

    assert.equal(res.facturaNumero, 'FAC-0001');
    assert.equal(db.leer('contadores', 'facturas').ultimoNumero, 1);
  });

  it('rechaza contador corrupto sin modificar pedido ni crear venta', async () => {
    const updatedAt = new Date('2026-11-14T18:00:00.000Z');
    for (const ultimoNumero of [0, -1, 'abc', 1.5]) {
      const db = crearFirestoreMock({
        contadores: { facturas: { ultimoNumero } },
        pedidos: { 'ped-corr': crearPedido({ updatedAt }) },
      });

      await assert.rejects(
        () =>
          ejecutarFacturarPedido({
            auth: { uid: ADMIN_UID },
            data: { pedidoId: 'ped-corr', updatedAtEsperadoMs: updatedAt.getTime() },
            db,
            serverTimestamp: () => SERVER_TOKEN,
          }),
        (err) => err.code === 'internal' && err.message.includes('contador'),
      );
      assert.equal(db.leer('pedidos', 'ped-corr').facturado, false);
    }
  });

  it('rechaza si el número de factura FAC-XXXX ya existe en ventas', async () => {
    const updatedAt = new Date('2026-11-14T18:00:00.000Z');
    const db = crearFirestoreMock({
      pedidos: { 'ped-col': crearPedido({ updatedAt }) },
      ventas: { 'FAC-0001': { id: 'FAC-0001', total: 999 } },
    });

    await assert.rejects(
      () =>
        ejecutarFacturarPedido({
          auth: { uid: ADMIN_UID },
          data: { pedidoId: 'ped-col', updatedAtEsperadoMs: updatedAt.getTime() },
          db,
          serverTimestamp: () => SERVER_TOKEN,
        }),
      (err) => err.code === 'already-exists',
    );
    assert.equal(db.leer('pedidos', 'ped-col').facturado, false);
    assert.equal(db.leer('contadores', 'facturas'), undefined);
  });

  it('rechaza cuando updatedAt está desactualizado (conflicto de concurrencia)', async () => {
    const updatedAtReal = new Date('2026-11-14T18:05:00.000Z');
    const updatedAtViejo = new Date('2026-11-14T18:00:00.000Z');
    const db = crearFirestoreMock({
      pedidos: { 'ped-stale': crearPedido({ updatedAt: updatedAtReal }) },
    });

    await assert.rejects(
      () =>
        ejecutarFacturarPedido({
          auth: { uid: ADMIN_UID },
          data: { pedidoId: 'ped-stale', updatedAtEsperadoMs: updatedAtViejo.getTime() },
          db,
          serverTimestamp: () => SERVER_TOKEN,
        }),
      (err) =>
        err.code === 'failed-precondition' &&
        err.message.includes('modificado por otro administrador'),
    );
  });

  it('rechaza cuando el pedido no existe', async () => {
    const db = crearFirestoreMock({});

    await assert.rejects(
      () =>
        ejecutarFacturarPedido({
          auth: { uid: ADMIN_UID },
          data: {
            pedidoId: 'ped-inexistente',
            updatedAtEsperadoMs: new Date('2026-11-14T18:00:00.000Z').getTime(),
          },
          db,
          serverTimestamp: () => SERVER_TOKEN,
        }),
      (err) => err.code === 'not-found',
    );
  });

  it('asigna consecutivos distintos en facturación concurrente de dos pedidos diferentes', async () => {
    const updatedAt = new Date('2026-11-14T18:00:00.000Z');
    const db = crearFirestoreMock({
      pedidos: {
        'ped-a': crearPedido({ updatedAt }),
        'ped-b': crearPedido({ updatedAt }),
      },
    });

    const [resA, resB] = await Promise.all([
      ejecutarFacturarPedido({
        auth: { uid: ADMIN_UID },
        data: { pedidoId: 'ped-a', updatedAtEsperadoMs: updatedAt.getTime() },
        db,
        serverTimestamp: () => SERVER_TOKEN,
      }),
      ejecutarFacturarPedido({
        auth: { uid: ADMIN_UID },
        data: { pedidoId: 'ped-b', updatedAtEsperadoMs: updatedAt.getTime() },
        db,
        serverTimestamp: () => SERVER_TOKEN,
      }),
    ]);

    assert.deepEqual(
      [resA.facturaNumero, resB.facturaNumero].sort(),
      ['FAC-0001', 'FAC-0002'],
    );
    assert.equal(db.leer('contadores', 'facturas').ultimoNumero, 2);
    assert.equal(db.leer('pedidos', 'ped-a').facturado, true);
    assert.equal(db.leer('pedidos', 'ped-b').facturado, true);
  });
});
