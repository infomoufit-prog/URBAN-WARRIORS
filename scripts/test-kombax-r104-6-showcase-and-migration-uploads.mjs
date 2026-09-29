import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import vm from 'node:vm';

const showcaseSource = readFileSync(new URL('../web/js/modules/showcase.js', import.meta.url), 'utf8');
const opsSource = readFileSync(new URL('../web/js/modules/customer-operations.js', import.meta.url), 'utf8');
const repoSource = readFileSync(new URL('../web/js/core/repositories.js', import.meta.url), 'utf8');

// Showcase editor: run its actual submit handler against a fully local mock repository.
const editorStart = showcaseSource.indexOf('function itemEditor(');
const editorEnd = showcaseSource.indexOf('\nasync function openSellerOrders(', editorStart);
assert.ok(editorStart >= 0 && editorEnd > editorStart, 'El editor de Showcase existe');
let editor;
const uploadCalls = [], saved = {}, meta = {}, commerce = {};
const mockRepos = { kombaxShowcase: {
  uploadImage: async (_brandId, file) => { uploadCalls.push(file.name); return { path: `mock/${file.name}`, url: `https://local.invalid/${file.name}` }; },
  saveItem: async payload => { saved.item = payload; return { id: 'mock-product-1' }; },
  saveListingMeta: async (_id, payload) => { saved.meta = payload; Object.assign(meta, payload); },
  saveCommerce: async (_id, payload) => { saved.commerce = payload; Object.assign(commerce, payload); },
  removeOwnedImages: async () => 0,
  removeUploadedImage: async () => 0,
} };
const editorContext = {
  categories: [{ id: 'sports', nombre: 'Equipamiento' }],
  CTA_KEYS: { info: 'more', contact: 'contact', shop: 'shop', web: 'web', where: 'where' },
  LIMIT_LABELS: { 30: 'máximo 30' }, PROVIDER_LABELS: { club: 'Club' },
  isProfessionalProvider: () => false, t: key => key, openForm: config => { editor = config; },
  repos: mockRepos, safeExternal: value => /^https:\/\//.test(String(value)), slugify: value => String(value).toLowerCase().replace(/\s+/g, '-'),
  prewarmUserContentTranslations: async () => {}, toast: () => {}, renderManagement: async () => {},
};
vm.createContext(editorContext);
vm.runInContext(`${showcaseSource.slice(editorStart, editorEnd)}\nitemEditor({ id:'moufit-local', nombre:'Moufit Demo', sujeto_tipo:'club', limite_visible:30 }, null, { commerceAllowed:true, sellerAccountActive:false });`, editorContext);
assert.ok(editor.fields.some(field => field.name === 'product_type' && field.type === undefined), 'El editor ofrece clasificación de producto');
assert.ok(editor.fields.find(field => field.name === 'product_type').label.includes('producto'));
assert.deepEqual(Array.from(editor.fields.find(field => field.name === 'listing_kind').options, item => item.value), ['product', 'professional_service']);
assert.equal(editor.fields.find(field => field.name === 'imagen_archivo').type, 'file');
assert.equal(editor.fields.find(field => field.name === 'galeria_archivo_1').type, 'file');
await editor.onSubmit({
  nombre:'Guantes de entrenamiento', product_type:'Equipamiento', categoria_id:'sports', listing_kind:'product',
  imagen_archivo:{ name:'guantes.png', type:'image/png', size:100 }, galeria_archivo_1:{ name:'detalle.webp', type:'image/webp', size:100 },
  galeria_archivo_2:null, galeria_archivo_3:null, imagen_url:'', galeria_1:'', galeria_2:'', galeria_3:'',
  quitar_imagen:false, precio_orientativo:'24.90', sku:'MOU-GUA-01', stock_alert_threshold:3,
  commerce_enabled:true, precio_venta:'24.90', stock:'5', fulfillment:'seller_shipping', cta_tipo:'info',
  resumen:'Producto de prueba', descripcion:'Descripción local de prueba',
});
assert.deepEqual(uploadCalls, ['guantes.png', 'detalle.webp'], 'Se solicitan la imagen principal y la galería al servicio de archivos');
assert.equal(saved.item.nombre, 'Guantes de entrenamiento');
assert.equal(saved.item.product_type, 'Equipamiento');
assert.equal(saved.meta.listing_kind, 'product');
assert.equal(saved.meta.product_type, 'Equipamiento');
assert.equal(saved.commerce.commerce_enabled, false, 'Sin activación de vendedor no se habilita checkout aunque el catálogo se guarda');
assert.equal(saved.item.imagen_url, 'https://local.invalid/guantes.png');
assert.deepEqual(Array.from(saved.item.galeria), ['https://local.invalid/detalle.webp']);
console.log('PASS Showcase: producto clasificado, foto principal y galería llegan al guardado mock; Commerce permanece cerrado sin activar vendedor.');

// Test the actual image upload adapter with a local storage mock and image optimizer mock.
const imageStart = repoSource.indexOf('async function uploadKombaxShowcaseImage(');
const imageEnd = repoSource.indexOf('\nasync function uploadReputationMedia(', imageStart);
assert.ok(imageStart >= 0 && imageEnd > imageStart, 'Existe el adaptador de subida de Showcase');
const imageSource = repoSource.slice(imageStart, imageEnd).replace('async function uploadKombaxShowcaseImage', 'async function uploadKombaxShowcaseImage');
const imageUploads = [];
class MockFile { constructor(parts, name, options={}) { this.parts=parts; this.name=name; this.type=options.type||''; this.size=parts.reduce((sum,p)=>sum+(p.size||p.length||0),0); this.lastModified=options.lastModified||0; } }
const imageContext = {
  session: () => ({ id:'local-user' }),
  File: MockFile,
  crypto: { randomUUID: () => 'local-token' },
  Date,
  Math,
  optimizeImage: async (file, options) => ({ file: new MockFile([file], 'normalized.jpg', { type:'image/jpeg' }), options }),
  backend: {
    upload: async (bucket, path, file) => { imageUploads.push({ bucket, path, type:file.type }); },
    publicUrl: (bucket, path) => `https://local.invalid/${bucket}/${path}`,
  },
};
vm.createContext(imageContext);
vm.runInContext(`${imageSource}\nthis.uploadImage=uploadKombaxShowcaseImage;`, imageContext);
for (const [name,type] of [['shoe.jpg','image/jpeg'],['shirt.png','image/png'],['wrap.webp','image/webp'],['phone.heic','image/heic'],['phone.heif','image/heif'],['poster.avif','image/avif']]) {
  const result = await imageContext.uploadImage('moufit-local', { name, type, size:128, lastModified:1 });
  assert.match(result.url, /^https:\/\/local\.invalid\/kombax-public-media\//);
}
assert.equal(imageUploads.length, 6);
assert.ok(imageUploads.every(entry => entry.bucket === 'kombax-public-media' && entry.type === 'image/jpeg'), 'Las imágenes se normalizan antes de almacenar en el mock local');
await assert.rejects(() => imageContext.uploadImage('moufit-local', { name:'manual.pdf', type:'application/pdf', size:128 }), /Showcase admite fotos/);
console.log('PASS Showcase upload adapter: JPG/PNG/WEBP/HEIC/HEIF/AVIF aceptados y normalizados; PDF rechazado.');

// Migrations chat validation and staging: exercise actual code with an isolated backend mock.
const validationStart = opsSource.indexOf('function validateMigrationFiles(');
const validationEnd = opsSource.indexOf('\nfunction bindMigrationUpload(', validationStart);
assert.ok(validationStart >= 0 && validationEnd > validationStart, 'Existe la validación de adjuntos de Migrations');
const validationContext = {};
vm.createContext(validationContext);
vm.runInContext(`${opsSource.slice(validationStart, validationEnd)}\nthis.validate=validateMigrationFiles;`, validationContext);
const validate = files => validationContext.validate(files);
const allowedMigrationFiles = [
  { name:'alumnos.pdf', type:'application/pdf', size:100 },
  { name:'cuotas.csv', type:'text/csv', size:100 },
  { name:'miembros.xlsx', type:'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet', size:100 },
  { name:'archivo.xls', type:'application/vnd.ms-excel', size:100 },
  { name:'ficha.jpg', type:'image/jpeg', size:100 },
  { name:'ficha.png', type:'image/png', size:100 },
  { name:'ficha.webp', type:'image/webp', size:100 },
];
assert.equal(validate(allowedMigrationFiles), null, 'Documentos, hojas de cálculo e imágenes admitidas pasan validación');
assert.equal(validate([{ name:'contrato.docx', type:'application/vnd.openxmlformats-officedocument.wordprocessingml.document', size:100 }])?.name, 'contrato.docx');
assert.equal(validate([{ name:'grande.pdf', type:'application/pdf', size:10*1024*1024+1 }])?.name, 'grande.pdf');
assert.equal(validate([{ name:'foto.heic', type:'image/heic', size:100 }])?.name, 'foto.heic');

const stageStart = repoSource.indexOf('    async stageMigrationFiles(ticket_id,files=[],onProgress=null){');
const stageEnd = repoSource.indexOf('\n    }\n  },\n  platformAdmin:', stageStart);
assert.ok(stageStart >= 0 && stageEnd > stageStart, 'Existe el flujo de carga de documentos de Migrations');
let stagedUploads = [], registrations = [], progress = [];
const stageSnippet = `({${repoSource.slice(stageStart, stageEnd+6).trim().replace(/^async stageMigrationFiles/, 'async stageMigrationFiles')}})`;
const migrationContext = {
  session: () => ({ id:'local-user' }), File: MockFile, crypto:{ randomUUID:()=>`migration-${stagedUploads.length+1}` }, Date, Math,
  backend: {
    upload: async (bucket,path,file) => { stagedUploads.push({bucket,path,type:file.type}); },
    globalWriteRpc: async (name,args) => { registrations.push({name,args}); return { file_id:`mock-file-${registrations.length}` }; },
    remove: async () => {},
  },
};
vm.createContext(migrationContext);
vm.runInContext(`this.customerOps=${stageSnippet};`, migrationContext);
const staged = await migrationContext.customerOps.stageMigrationFiles('migration-local-1', allowedMigrationFiles, item => progress.push(item));
assert.equal(staged.length, 7);
assert.equal(stagedUploads.length, 7);
assert.ok(stagedUploads.every(entry => entry.bucket === 'kombax-migration-staging'));
assert.equal(registrations.length, 7);
assert.ok(registrations.every(row => row.name === 'app_kombax_migration_file_register_v228'));
assert.equal(progress.length, 7);
assert.equal(registrations[0].args.p_mime_type, 'application/pdf');
assert.equal(registrations[2].args.p_mime_type, 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
await assert.rejects(() => migrationContext.customerOps.stageMigrationFiles('migration-local-1', [{ name:'no.docx', type:'application/msword', size:100 }]), /Formato no admitido/);
console.log('PASS Migrations chat: PDF/CSV/XLS/XLSX/JPG/PNG/WEBP se validan, suben y registran en mocks; DOCX/HEIC y >10 MB se rechazan antes de subir.');
console.log('PASS: Todas las subidas se simularon localmente; no se contactó Supabase ni se crearon datos reales.');
