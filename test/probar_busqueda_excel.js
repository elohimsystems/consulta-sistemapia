const fs = require('fs');
const path = require('path');
const http = require('http');
const https = require('https');
const { Client } = require(path.join(__dirname, '../../api-sistemapia/node_modules/pg'));
const xlsx = require(path.join(__dirname, '../../api-sistemapia/node_modules/xlsx'));

require(path.join(__dirname, '../../api-sistemapia/node_modules/dotenv')).config({
  path: path.join(__dirname, '../../api-sistemapia/.env'),
});

const excelPath = 'H:/My Drive/DATAPIA/2026/la nocturna/dataparaprueba.xlsx';
const eventId = process.argv[2] || '2026050433003';
const limit = process.argv[3] ? parseInt(process.argv[3], 10) : 50;
const apiBaseUrl = process.argv[4] || 'http://localhost:4550';

async function consultarApi(url) {
  return new Promise((resolve) => {
    const start = Date.now();
    const mod = url.startsWith('https') ? https : http;
    mod.get(url, (res) => {
      let body = '';
      res.on('data', chunk => body += chunk);
      res.on('end', () => {
        const duration = Date.now() - start;
        let data = null;
        try { data = JSON.parse(body); } catch (_) {}
        resolve({
          statusCode: res.statusCode,
          duration,
          data,
          body,
        });
      });
    }).on('error', (err) => {
      resolve({
        statusCode: 0,
        duration: Date.now() - start,
        error: err.message,
      });
    });
  });
}

async function consultarDbDirecta(client, eventId, cedulas) {
  const start = Date.now();
  try {
    const numEventId = parseInt(eventId, 10) || 0;
    // 1. Buscar en dorsales_imagenes
    let res = await client.query(
      `SELECT i.id, i.iddocumento, c.nombre, c.apellido, i.ruta_imagen
       FROM piaaccess.dorsales_imagenes i
       LEFT JOIN piaaccess.tmcompetidores c ON TRIM(c.iddocumento) = TRIM(i.iddocumento)
       WHERE (i.idevento = $1 OR i.idevento::text = $2) AND (TRIM(i.iddocumento) = ANY($3::text[]) OR TRIM(c.iddocumento) = ANY($3::text[]))`,
      [numEventId, String(eventId), cedulas],
    );

    if (res.rows.length > 0) {
      return { success: true, duration: Date.now() - start, rows: res.rows };
    }

    // 2. Si no hay dorsal generado todavía, verificar si el competidor está en tmcompetidores
    res = await client.query(
      `SELECT c.id, c.iddocumento, c.nombre, c.apellido
       FROM piaaccess.tmcompetidores c
       WHERE TRIM(c.iddocumento) = ANY($1::text[])`,
      [cedulas],
    );

    if (res.rows.length > 0) {
      return {
        success: true,
        duration: Date.now() - start,
        rows: res.rows.map(r => ({ ...r, status: 'Inscrito en BD (Dorsal no generado aún)' })),
      };
    }

    return { success: false, duration: Date.now() - start, error: 'No encontrado en base de datos' };
  } catch (e) {
    return { success: false, duration: Date.now() - start, error: e.message };
  }
}

async function ejecutarPruebas() {
  console.log('================================================================');
  console.log('  SISTEMA PIA - PRUEBA AUTOMATIZADA DE BUSQUEDA DESDE EXCEL');
  console.log('================================================================');
  console.log(`Archivo Excel: ${excelPath}`);

  if (!fs.existsSync(excelPath)) {
    console.error(`ERROR: No se encontró el archivo Excel en: ${excelPath}`);
    process.exit(1);
  }

  const workbook = xlsx.readFile(excelPath);
  const sheetName = workbook.SheetNames[0];
  const sheet = workbook.Sheets[sheetName];
  const filas = xlsx.utils.sheet_to_json(sheet);

  console.log(`Total de participantes en Excel: ${filas.length}`);
  console.log(`ID de Evento: ${eventId}`);
  console.log(`Límite de filas a probar: ${limit}`);
  console.log('----------------------------------------------------------------\n');

  // Intentar probar primero si el servidor NestJS está corriendo en localhost
  const testApi = await consultarApi(`${apiBaseUrl}/config`);
  const isApiOnline = testApi.statusCode === 200;

  let dbClient = null;
  if (!isApiOnline) {
    console.log('⚠️ Servidor API NestJS no detectado en localhost:4550. Consultando base de datos PostgreSQL directa...\n');
    try {
      dbClient = new Client({
        host: process.env.DB_HOST || 'localhost',
        port: parseInt(process.env.DB_PORT || '5432', 10),
        user: process.env.DB_USER,
        password: process.env.DB_PASS,
        database: process.env.DB_NAME,
      });
      await dbClient.connect();
    } catch (dbErr) {
      console.error(`❌ Error al conectar a PostgreSQL: ${dbErr.message}`);
    }
  } else {
    console.log('🟢 Servidor API NestJS en línea en localhost:4550.\n');
  }

  let exitos = 0;
  let fallos = 0;
  let tiempoTotalMs = 0;
  const lineasReporte = [];

  const headerReporte = `REPORTE DE PRUEBAS AUTOMATIZADAS DE BUSQUEDA DE DORSAL\nFecha: ${new Date().toLocaleString()}\nEvento ID: ${eventId}\nTotal Filas Excel: ${filas.length}\n${'='.repeat(80)}\n`;
  lineasReporte.push(headerReporte);

  const filasAProbar = filas.slice(0, limit);

  for (let i = 0; i < filasAProbar.length; i++) {
    const fila = filasAProbar[i];
    const cedulaRaw = String(fila.Cedula || fila.cedula || '').trim();
    const nombreExcel = `${fila.Nombre || ''} ${fila.Apellido || ''}`.trim();
    const numeroExcel = fila.Numero || fila.numero || 'S/N';
    const categoriaExcel = fila.Categoria || 'N/A';

    if (!cedulaRaw) continue;

    const opcionesCedula = [cedulaRaw];
    if (!cedulaRaw.startsWith('V-') && !cedulaRaw.startsWith('E-')) {
      opcionesCedula.push(`V-${cedulaRaw}`);
    }

    let exito = false;
    let dur = 0;
    let detalle = '';

    if (isApiOnline) {
      for (const ced of opcionesCedula) {
        const url = `${apiBaseUrl}/dorsales/buscar/${eventId}/${encodeURIComponent(ced)}`;
        const res = await consultarApi(url);
        dur = res.duration;
        if (res.statusCode === 200 && Array.isArray(res.data) && res.data.length > 0) {
          exito = true;
          const item = res.data[0];
          detalle = `Dorsal #${item.id} | ${item.nombre || nombreExcel} | Cat: ${item.categoria || categoriaExcel}`;
          break;
        } else {
          detalle = res.data?.message || `HTTP ${res.statusCode}`;
        }
      }
    } else if (dbClient) {
      const dbRes = await consultarDbDirecta(dbClient, eventId, opcionesCedula);
      dur = dbRes.duration;
      if (dbRes.success && dbRes.rows.length > 0) {
        exito = true;
        const row = dbRes.rows[0];
        detalle = row.status
          ? `Participante ID #${row.id} | ${row.nombre || ''} ${row.apellido || ''} (${row.status})`
          : `Dorsal ID #${row.id} | ${row.nombre || ''} ${row.apellido || ''} | Ruta: ${row.ruta_imagen}`;
      } else {
        detalle = dbRes.error || 'No encontrado en base de datos';
      }
    } else {
      detalle = 'API fuera de línea y sin conexión a PostgreSQL';
    }

    tiempoTotalMs += dur;

    if (exito) {
      exitos++;
      const msj = `[${i + 1}/${filasAProbar.length}] 🟢 ÉXITO | Num: ${numeroExcel} | Cédula: ${cedulaRaw} | ${detalle} | ${dur}ms`;
      console.log(msj);
      lineasReporte.push(msj);
    } else {
      fallos++;
      const msj = `[${i + 1}/${filasAProbar.length}] 🔴 FALLO | Num: ${numeroExcel} | Cédula: ${cedulaRaw} | Nombre Excel: ${nombreExcel} | Detalle: ${detalle} | ${dur}ms`;
      console.log(msj);
      lineasReporte.push(msj);
    }
  }

  if (dbClient) await dbClient.end();

  const tiempoPromedio = filasAProbar.length > 0 ? (tiempoTotalMs / filasAProbar.length).toFixed(2) : 0;
  const tasaExito = filasAProbar.length > 0 ? ((exitos / filasAProbar.length) * 100).toFixed(1) : 0;

  const resumen = `\n${'='.repeat(80)}\nRESUMEN FINAL DE PRUEBAS AUTOMATIZADAS DE BUSQUEDA\n${'='.repeat(80)}\n` +
    `Total Evaluadas: ${filasAProbar.length}\n` +
    `🟢 Encontradas (Éxito): ${exitos}\n` +
    `🔴 No Encontradas (Fallo): ${fallos}\n` +
    `Tasa de Éxito: ${tasaExito}%\n` +
    `Tiempo Promedio por Consulta: ${tiempoPromedio} ms\n` +
    `${'='.repeat(80)}\n`;

  console.log(resumen);
  lineasReporte.push(resumen);

  const reportPath = path.join(__dirname, 'reporte_busqueda_excel.txt');
  fs.writeFileSync(reportPath, lineasReporte.join('\n'), 'utf-8');
  console.log(`Reporte guardado en: ${reportPath}\n`);
}

ejecutarPruebas();
