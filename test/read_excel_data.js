const path = require('path');
const xlsx = require(path.join(__dirname, '../../api-sistemapia/node_modules/xlsx'));

const excelPath = 'H:/My Drive/DATAPIA/2026/la nocturna/dataparaprueba.xlsx';
const workbook = xlsx.readFile(excelPath);

console.log('Sheet Names:', workbook.SheetNames);
const sheetName = workbook.SheetNames[0];
const sheet = workbook.Sheets[sheetName];

const data = xlsx.utils.sheet_to_json(sheet);
console.log('Total rows in Excel:', data.length);
console.log('First 5 rows:');
console.log(data.slice(0, 5));
