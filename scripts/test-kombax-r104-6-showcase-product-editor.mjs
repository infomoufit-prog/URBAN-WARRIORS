import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import vm from 'node:vm';

const source = readFileSync(new URL('../web/js/modules/showcase.js', import.meta.url), 'utf8');
const start = source.indexOf('function itemEditor(');
const end = source.indexOf('\nasync function openSellerOrders(', start);
assert.ok(start >= 0 && end > start, 'El editor de Showcase existe');

let opened;
const context = {
  categories: [{ id: 'category-1', nombre: 'Equipamiento' }],
  CTA_KEYS: { info: 'more', contact: 'contact', shop: 'shop', web: 'web', where: 'where' },
  LIMIT_LABELS: { 30: 'máximo 30' },
  PROVIDER_LABELS: { club: 'Club' },
  isProfessionalProvider: () => false,
  t: key => key,
  openForm: config => { opened = config; },
};
vm.createContext(context);
vm.runInContext(`${source.slice(start, end)}\nitemEditor({ id: 'provider-1', nombre: 'Moufit', sujeto_tipo: 'club', limite_visible: 30 }, null, { commerceAllowed: true, sellerAccountActive: false });`, context);

assert.equal(opened?.title, 'Nueva ficha de Showcase');
assert.ok(opened.fields.some(field => field.name === 'nombre' && field.required));
assert.ok(opened.fields.some(field => field.name === 'imagen_archivo' && field.type === 'file'));
assert.ok(opened.fields.some(field => field.name === 'galeria_archivo_1' && field.type === 'file'));
assert.deepEqual(Array.from(opened.fields.find(field => field.name === 'cta_tipo').options, option => option.value), ['info', 'contact', 'shop', 'web', 'where']);
console.log('PASS: Añadir producto abre el editor con acciones e imágenes');
