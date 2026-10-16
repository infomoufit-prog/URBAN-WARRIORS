export const OWNER_REPORT_TYPES=Object.freeze([
 ['executive','Ejecutivo'],['pilot','Piloto'],['adoption','Altas y activación'],['marketing','Marketing y adopción'],['support','Soporte e incidencias'],['ai','IA y conocimiento'],['operations','Operaciones y verificaciones']
]);
export function ownerReportKind(value){return OWNER_REPORT_TYPES.some(([id])=>id===value)?value:'executive';}
const labels={accounts:'Cuentas',identities:'Identidades',verifications:'Verificaciones',social:'Publicaciones Social',events:'Eventos',support:'Soporte',ai_paid:'IA de pago',ai_free:'Ayuda gratuita',owner_agents:'Agentes Owner'};
const groups={executive:['accounts','identities','verifications','support','owner_agents'],pilot:['accounts','identities','social','events','owner_agents'],adoption:['accounts','identities','verifications'],marketing:['identities','social','events'],support:['support','owner_agents'],ai:['ai_paid','ai_free','owner_agents'],operations:['verifications','support','owner_agents']};
const count=v=>Number.isFinite(Number(v))&&v!==null&&v!==undefined?new Intl.NumberFormat('es',{maximumFractionDigits:3}).format(Number(v)):'No disponible';
export function ownerInsightSections(data,kind='executive'){
 kind=ownerReportKind(kind);if(!data?.ok)return [{title:'Datos ampliados',lines:['No disponibles en esta ejecución. No equivalen a cero.']}];
 const out=groups[kind].map(key=>{const d=data[key],lines=!d?.available?['Fuente no disponible. No equivale a cero.']:[`Total actual: ${count(d.total)}. Altas o registros del periodo: ${count(d.period)}.`,...(d.by_status||[]).slice(0,10).map(r=>`Estado ${r.label}: ${count(r.total)} en el periodo.`),...(d.by_type||[]).slice(0,10).map(r=>`Tipo ${r.label}: ${count(r.total)} en el periodo.`)];return {title:labels[key],lines}});
 if(['marketing','adoption'].includes(kind)){
  out.push({title:'Cohortes por semana de alta',lines:(data.marketing?.cohorts||[]).slice(-16).map(r=>`${r.week}: ${count(r.accounts)} cuentas; ${count(r.accounts_with_identity)} con identidad actual.`)});
  out.push({title:'Límites de interpretación y campañas',lines:data.marketing?.limits||['No hay datos de consentimiento disponibles para crear una lista de contactos.']});
 }
 if(kind==='ai')out.push({title:'Conocimiento revisado',lines:data.knowledge?.available?[`Propuestas pendientes: ${count(data.knowledge.pending)}. Revisadas: ${count(data.knowledge.reviewed)}.`,'Las propuestas no se publican automáticamente. El contenido privado no se convierte en conocimiento general.']:['No disponible.']});
 if(['executive','adoption','pilot','marketing'].includes(kind))out.push({title:'Perfiles públicos · situación actual',lines:data.public_profiles?.available?[`Total ${count(data.public_profiles.total)}; visibles ${count(data.public_profiles.visible)}; verificados ${count(data.public_profiles.verified)}; con publicación habilitada ${count(data.public_profiles.publishing_enabled)}.`,'Son estados actuales, no una conversión temporal ni usuarios activos del periodo.']:['Fuente no disponible.']});
 return out;
}
export function ownerInsightsCsv(data,kind='executive'){
 const cell=x=>'"'+String(x??'').replaceAll('"','""').replace(/^[=+@-]/,"'$&")+'"';
 return '\uFEFF'+[['Informe',ownerReportKind(kind)],['Generado',data?.generated_at||'No disponible'],['Periodo días',data?.days||'No disponible'],...ownerInsightSections(data,kind).flatMap(s=>s.lines.map(l=>[s.title,l]))].map(r=>r.map(cell).join(';')).join('\r\n');
}
