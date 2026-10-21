const fs = require('fs');
const path = require('path');
const http = require('http');
const xlsx = require(path.join(__dirname, '../../api-sistemapia/node_modules/xlsx'));

const excelPath = 'H:/My Drive/DATAPIA/2026/la nocturna/dataparaprueba.xlsx';
const eventId = process.argv[2] || '20'; // ID de evento por defecto o pasado por argumento
const apiBaseUrl = 'http://localhost:4550';

async function consultarApi(url) {
  return new Promise((resolve) => {
    const start = Date.now();
    http.get(url, (res) => {
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

async function ejecutarPruebas() {
  console.log('================================================================');
  console.log('  SISTEMA PIA - PRUEBA AUTOMATIZADA DE BUSQUEDA DESDE EXCEL');
  console.log('================================================================');
  console.log(`Leyendo archivo Excel: ${excelPath}`);

  if (!fs.existsSync(excelPath)) {
    console.error(`ERROR: No se encontró el archivo Excel en: ${excelPath}`);
    process.exit(1);
  }

  const workbook = xlsx.readFile(excelPath);
  const sheetName = workbook.SheetNames[0];
  const sheet = workbook.Sheets[sheetName];
  const filas = xlsx.utils.sheet_to_json(sheet);

  console.log(`Total de filas leídas en Excel: ${filas.length}`);
  console.log(`ID de Evento para la prueba: ${eventId}`);
  console.log(`Consultando API en: ${apiBaseUrl}`);
  console.log('----------------------------------------------------------------\n');

  let exitos = 0;
  let fallos = 0;
  let tiempoTotalMs = 0;
  const lineasReporte = [];

  const headerReporte = `REPORTE DE PRUEBAS AUTOMATIZADAS DE BUSQUEDA DE DORSAL\nFecha: ${new Date().toLocaleString()}\nEvento ID: ${eventId}\nTotal Filas Excel: ${filas.length}\n${'='.repeat(80)}\n`;
  lineasReporte.push(headerReporte);

  // Probar las primeras 50 filas o limite por argumento
  const limit = process.argv[3] ? parseInt(process.argv[3], 10) : 50;
  const filasAProbar = filas.slice(0, limit);

  console.log(`Ejecutando pruebas para ${filasAProbar.length} participantes...\n`);

  for (let i = 0; i < filasAProbar.length; i++) {
    const fila = filasAProbar[i];
    const cedulaRaw = String(fila.Cedula || fila.cedula || '').trim();
    const nombreExcel = `${fila.Nombre || ''} ${fila.Apellido || ''}`.trim();
    const numeroExcel = fila.Numero || fila.numero || 'S/N';

    if (!cedulaRaw) continue;

    // Probar primero cédula con V- y sin V-
    const opcionesCedula = [cedulaRaw];
    if (!cedulaRaw.startsWith('V-') && !cedulaRaw.startsWith('E-')) {
      opcionesCedula.unshift(`V-${cedulaRaw}`);
    }

    let resultadoPrueba = null;
    let cedulaExitosa = '';

    for (const ced of opcionesCedula) {
      const url = `${apiBaseUrl}/dorsales/buscar/${eventId}/${encodeURIComponent(ced)}`;
      const res = await consultarApi(url);
      if (res.statusCode === 200 && Array.isArray(res.data) && res.data.length > 0) {
        resultadoPrueba = res;
        cedulaExitosa = ced;
        break;
      } else if (!resultadoPrueba) {
        resultadoPrueba = res;
        cedulaExitosa = ced;
      }
    }

    const dur = resultadoPrueba ? resultadoPrueba.duration : 0;
    tiempoTotalMs += dur;

    if (resultadoPrueba && resultadoPrueba.statusCode === 200 && Array.isArray(resultadoPrueba.data) && resultadoPrueba.data.length > 0) {
      exitos++;
      const item = resultadoPrueba.data[0];
      const msj = `[${i + 1}/${filasAProbar.length}] 🟢 ÉXITO | Cédula: ${cedulaRaw} (${cedulaExitosa}) | Num: ${numeroExcel} | Nombre: ${nombreExcel} | Categ: ${item.categoria || 'N/A'} | Tiempo: ${dur}ms`;
      console.log(msj);
      lineasReporte.push(msj);
    } else {
      fallos++;
      const errorDetail = resultadoPrueba?.data?.message || resultadoPrueba?.error || `HTTP ${resultadoPrueba?.statusCode || 0}`;
      const msj = `[${i + 1}/${filasAProbar.length}] 🔴 FALLO | Cédula: ${cedulaRaw} | Nombre Excel: ${nombreExcel} | Detalle: ${errorDetail} | Tiempo: ${dur}ms`;
      console.log(msj);
      lineasReporte.push(msj);
    }
  }

  const tiempoPromedio = filasAProbar.length > 0 ? (tiempoTotalMs / filasAProbar.length).toFixed(2) : 0;
  const tasaExito = filasAProbar.length > 0 ? ((exitos / filasAProbar.length) * 100).toFixed(1) : 0;

  const resumen = `\n${'='.repeat(80)}\nRESUMEN FINAL DE PRUEBAS\n${'='.repeat(80)}\n` +
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
