import { readFile } from 'node:fs/promises';
import { resolve } from 'node:path';

const root=resolve(import.meta.dirname,'..');
const read=p=>readFile(resolve(root,p),'utf8');
const assert=(ok,msg)=>{if(!ok)throw new Error(`FAIL RELEASE G: ${msg}`);console.log(`OK RELEASE G: ${msg}`)};
const [sql,rollback,repos,ui]=await Promise.all([
  read('supabase/migrations/027_community_cursor_index.sql'),read('supabase/rollbacks/027_community_cursor_index.sql'),
  read('web/js/core/repositories.js'),read('web/js/modules/community.js')
]);

assert(sql.includes('club_id,estado,creado_en desc,id desc'),'índice multiclub coincide con el cursor');
assert(rollback.includes('drop index if exists'),'índice tiene rollback');
assert(repos.includes('listPage')&&repos.includes('creado_en.lt.')&&repos.includes('id.lt.'),'consulta usa cursor estable de fecha e id');
assert(repos.includes('Math.min(20'),'repositorio impide páginas mayores de 20');
assert(ui.includes('PAGE_SIZE=20')&&ui.includes('communityCursor'),'feed carga bloques de veinte');
assert(ui.includes('IntersectionObserver')&&ui.includes('Cargar más'),'scroll progresivo conserva alternativa manual');
const communityRepo=repos.slice(repos.indexOf('community:{'),repos.indexOf('legal:{'));
assert(!communityRepo.includes('limit=250'),'Comunidad deja de descargar el histórico completo');
console.log('RELEASE G COMMUNITY: PASS');
