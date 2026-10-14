import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {availableClubSpaces,resolveClubSpaceRole,chooseClubSpace,readClubSpacePreference,writeClubSpacePreference,CLUB_SPACE_LABELS} from '../web/js/core/club-workspaces.js';
import {clubSessionRole} from '../web/js/core/club-session-role.js';
import {has} from '../web/js/core/permissions.js';
let n=0;
const test=(msg,fn)=>{fn();n++;console.log(`OK ${n} ${msg}`)};
const a='club-a',b='club-b',id='user-1';
const rows=[
 {club_id:a,rol:'alumno',activo:true},
 {club_id:a,rol:'familia',activo:true},
 {club_id:a,rol:'monitor',activo:true},
 {club_id:a,rol:'economia',activo:false},
 {club_id:b,rol:'secretaria',activo:true},
 {club_id:b,rol:'monitor',activo:false}
];
const session={id,club_id:a,rol:'monitor',roles:['monitor','alumno','familia'],memberships:rows};
test('rol de participante con tutor y monitor simultáneos',()=>assert.deepEqual(availableClubSpaces(rows,a),['monitor','familia','alumno']));
test('club aislado: no se incluyen permisos de otro club',()=>assert.deepEqual(availableClubSpaces(rows,b),['secretaria']));
test('rol revocado nunca aparece',()=>assert.ok(!availableClubSpaces(rows,a).includes('economia')));
test('rol inexistente nunca aparece',()=>assert.ok(!availableClubSpaces(rows,a).includes('direccion')));
test('rechazo de escalada por interfaz manipulada',()=>assert.throws(()=>chooseClubSpace(session,'direccion'),/no está autorizado/));
test('rechazo de rol inactivo',()=>assert.throws(()=>chooseClubSpace(session,'economia'),/no está autorizado/));
test('no se permite perfil de rol en modo soporte',()=>assert.throws(()=>chooseClubSpace({...session,support_mode:true},'alumno'),/no hay un espacio/i));
test('no se permite cambiar sin contexto de club',()=>assert.throws(()=>chooseClubSpace({...session,club_id:null},'alumno'),/No hay/));
test('cambio a tutor sin otra cuenta',()=>{const next=chooseClubSpace(session,'familia');assert.equal(next.rol,'familia');assert.equal(next.id,id);assert.equal(next.club_id,a);assert.deepEqual(next.roles,session.roles)});
test('cambio a participante sin otra cuenta',()=>{const next=chooseClubSpace(session,'alumno');assert.equal(next.rol,'alumno');assert.equal(next.id,id)});
test('opción almacenada revocada se descarta',()=>assert.equal(resolveClubSpaceRole(session,'economia'),'monitor'));
test('opción almacenada autorizada se restaura',()=>assert.equal(resolveClubSpaceRole(session,'alumno'),'alumno'));
test('selector de rol no amplía capacidades',()=>{const alt=chooseClubSpace(session,'familia');assert.equal(has(alt,'paymentAdmin'),false);assert.equal(has(alt,'attendance'),false);assert.equal(has(chooseClubSpace(session,'monitor'),'attendance'),true)});
test('relaciones familiares verificadas habilitan vista sin membresía familiar',()=>assert.deepEqual(availableClubSpaces([{club_id:a,rol:'monitor',activo:true}],a,['familia','alumno']),['monitor','familia','alumno']));
test('relación no puede crear rol administrativo',()=>assert.deepEqual(availableClubSpaces([{club_id:a,rol:'alumno',activo:true}],a,['direccion','economia']),['alumno']));
test('coordinación sin rol explícito solamente si se asignó',()=>assert.deepEqual(availableClubSpaces([{club_id:a,rol:'secretaria',activo:true,coordinacion:true}],a),['coordinacion','secretaria']));
test('dirección no necesita coordinación virtual',()=>assert.deepEqual(availableClubSpaces([{club_id:a,rol:'direccion',activo:true,coordinacion:true}],a),['direccion']));
test('coordinación conserva roles simultáneos',()=>{const v=clubSessionRole([{rol:'secretaria',activo:true,coordinacion:true},{rol:'monitor',activo:true}],{rol:'secretaria'});assert.equal(v.rol,'coordinacion');assert.deepEqual(v.roles,['secretaria','monitor','coordinacion'])});
test('cuentas diferentes preservan preferencias separadas',()=>{const map=new Map();const store={getItem:k=>map.get(k),setItem:(k,v)=>map.set(k,v)};writeClubSpacePreference(id,a,'alumno',store);writeClubSpacePreference(id,b,'secretaria',store);writeClubSpacePreference('other',a,'familia',store);assert.equal(readClubSpacePreference(id,a,store),'alumno');assert.equal(readClubSpacePreference(id,b,store),'secretaria');assert.equal(readClubSpacePreference('other',a,store),'familia')});
test('localStorage inaccesible no bloquea la cuenta',()=>{const blocked={getItem(){throw Error('disabled')},setItem(){throw Error('disabled')}};assert.equal(readClubSpacePreference(id,a,blocked),'');assert.doesNotThrow(()=>writeClubSpacePreference(id,a,'familia',blocked))});
test('etiquetas de contextos familiares y entrenador',()=>{assert.ok(CLUB_SPACE_LABELS.familia.includes('tutor'));assert.equal(CLUB_SPACE_LABELS.monitor,'Monitor')});
const app=readFileSync('web/js/app.js','utf8'),ui=readFileSync('web/js/ui/components.js','utf8'),backend=readFileSync('web/js/core/backend.js','utf8'),repo=readFileSync('web/js/core/repositories.js','utf8');
test('selector móvil y sidebar funcional',()=>{assert.match(ui,/data-kx-club-space-select/g);assert.match(app,/querySelectorAll\('\[data-kx-club-space-select\]'\)/)});
test('cambio de espacio a través de backend',()=>assert.match(app,/await backend\.selectClubSpace\(desired\)/));
test('preferencia validada por membresías vivas al autenticar',()=>assert.match(backend,/resolveClubSpaceRole\(\{id:userId/));
test('espacio tutor limita consulta a hijos vinculados',()=>{assert.match(repo,/tutor_perfil_id=eq\.\$\{enc\(current\.id\)\}/);assert.match(repo,/perfil_id=eq\.\$\{enc\(current\.id\)\}/)});
test('no existe copia de una identidad al seleccionar',()=>assert.doesNotMatch(app.slice(app.indexOf('function openClubSpaceSelector'),app.indexOf('function openClubSwitcher')),/signOut\(|signUp\(|createUser\(/));
console.log(`PASS ${n}/${n} pruebas FASE1 selector de espacios`);
