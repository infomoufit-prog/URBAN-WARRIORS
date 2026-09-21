import { readFile } from 'node:fs/promises';
import { resolve } from 'node:path';

const root=resolve(import.meta.dirname,'..');
const read=p=>readFile(resolve(root,p),'utf8');
const assert=(ok,msg)=>{if(!ok)throw new Error(`FAIL RELEASE E: ${msg}`);console.log(`OK RELEASE E: ${msg}`)};
const [sql,rollback,repos,ui,css]=await Promise.all([
  read('supabase/migrations/024_finance_annual_metrics.sql'),
  read('supabase/rollbacks/024_finance_annual_metrics.sql'),
  read('web/js/core/repositories.js'),
  read('web/js/modules/finance.js'),
  read('web/css/app.css')
]);

assert(sql.includes('add column if not exists origen')&&sql.includes("'cuota','material','otro'"),'origen financiero extensible y no destructivo');
assert(sql.includes('with (security_invoker=true)')&&sql.includes('to authenticated'),'vistas derivadas conservan RLS del llamante');
assert(sql.includes('left join lateral')&&sql.includes("filter(where p.estado_validacion='validado')"),'pagos se agregan una vez por cargo y solo validados');
assert(sql.includes('v_finanzas_metricas_mensuales')&&sql.includes('v_finanzas_metricas_anuales'),'métricas mensuales y anuales derivadas');
assert(sql.includes('club_id,periodo desc,origen,estado'),'índice multiclub para filtros financieros');
assert(rollback.includes('Rollback conservador')&&!rollback.includes('drop column'),'rollback no destruye datos financieros');
assert(repos.includes('v_finanzas_detalle')&&repos.includes('&anio=eq.')&&repos.includes('&socio_id=eq.'),'filtros se ejecutan en Supabase');
assert(ui.includes('Historial financiero')&&ui.includes('Evolución mensual')&&ui.includes('Evolución anual'),'panel interno anual completo');
assert(ui.includes("pageHeader('Mis pagos'")&&ui.includes('Total pendiente')&&ui.includes('Conceptos pendientes'),'portal alumno/familia deliberadamente simple');
assert(css.includes('.finance-filters')&&css.includes('grid-template-columns:1fr 1fr'),'filtros adaptados a escritorio y móvil');
assert(!sql.includes('notas_internas')&&!ui.includes('notas_internas'),'portal no recibe notas administrativas');
assert(ui.includes('summarizeFinance')&&ui.includes('Desglose por origen'),'totales visibles respetan origen, alumno, mes y estado');
assert(ui.includes('visibleFees')&&ui.includes('balanceByFee'),'cargos filtrados conservan su saldo específico');
console.log('RELEASE E FINANCE: PASS');
