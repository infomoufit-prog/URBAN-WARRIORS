import {readFile} from 'node:fs/promises';
const root=new URL('../',import.meta.url);
const read=p=>readFile(new URL(p,root),'utf8');
const [mig,rb]=await Promise.all([
  read('supabase/migrations/101_kombax_rls_policy_consolidation_20057.sql'),
  read('supabase/rollbacks/101_kombax_rls_policy_consolidation_20057_rollback.sql')
]);
const n=s=>s.toLowerCase().replace(/\s+/g,' ');
const m=n(mig),r=n(rb);
const ok=(v,msg)=>{if(!v) throw new Error(msg); console.log('OK '+msg)};

const regular=[
 ['asistencias','asistencia_gestion','asistencia_lectura'],
 ['club_ambito_equipo','ambito_equipo_gestion_v057','ambito_equipo_lectura_v057'],
 ['club_ambito_grupos','ambito_grupos_gestion_v057','ambito_grupos_lectura_v057'],
 ['club_ambito_socios','ambito_socios_gestion_v057','ambito_socios_lectura_v057'],
 ['club_ambitos_trabajo','ambitos_gestion_v057','ambitos_lectura_v057'],
 ['comunicaciones','comunicaciones_gestion','comunicaciones_lectura'],
 ['config_club','config_gestion','config_lectura'],
 ['configuracion_avisos_cuota','config_avisos_gestion','config_avisos_lectura'],
 ['cuotas','cuotas_gestion','cuotas_lectura'],
 ['disciplinas','disciplinas_gestion','disciplinas_lectura'],
 ['grados','grados_gestion','grados_lectura'],
 ['grupos','grupos_gestion','grupos_lectura'],
 ['horarios_grupo','horarios_gestion','horarios_lectura'],
 ['invitaciones_club','invitaciones_gestion','invitaciones_lectura'],
 ['material_catalogo','material_gestion','material_lectura'],
 ['material_entregas','entregas_gestion','entregas_lectura'],
 ['material_variantes','variantes_gestion','variantes_lectura'],
 ['miembros_club','miembros_gestion','miembros_lectura'],
 ['seguimiento','seguimiento_gestion','seguimiento_lectura'],
 ['sesiones_entrenamiento','sesiones_gestion','sesiones_lectura'],
 ['socio_disciplinas','socio_disc_gestion','socio_disc_lectura'],
 ['socios','socios_gestion','socios_lectura'],
 ['tarifas','tarifas_gestion','tarifas_lectura'],
 ['textos_legales','legales_gestion','legales_lectura'],
 ['tutores_socios','tutores_gestion','tutores_lectura']
];
for(const [table,manage,read] of regular){
  ok(m.includes(`drop policy if exists ${manage} on public.${table}`),`${table}: retira ALL de gestión`);
  for(const suffix of ['ins_v101','upd_v101','del_v101']) ok(m.includes(`${manage}_${suffix}`),`${table}: gestión separada ${suffix}`);
  ok(m.includes(`alter policy ${read} on public.${table} using`),`${table}: una sola SELECT consolidada`);
  ok(r.includes(`create policy ${manage} on public.${table} for all to authenticated`),`${table}: rollback restaura ALL`);
}
for(const [table,policy] of [
 ['clubes','clubes_publico_registro'],['disciplinas','disciplinas_publico_registro'],
 ['grupos','grupos_publico_registro'],['tarifas','tarifas_publico_registro'],
 ['textos_legales','textos_legales_publicos_rc10']
]){
  ok(m.includes(`alter policy ${policy} on public.${table} to anon`),`${table}: registro público queda solo anon`);
}
ok(m.includes('drop policy if exists horarios_publico_registro on public.horarios_grupo')&&m.includes("alter policy horarios_lectura on public.horarios_grupo using"),'horarios: rama de registro se integra en SELECT autenticada');
ok(m.includes('drop policy if exists notificaciones_gestion on public.notificaciones')&&m.includes('drop policy if exists notificaciones_marcar on public.notificaciones')&&m.includes('create policy notificaciones_update_v101'),'notificaciones: SELECT/UPDATE quedan sin policies permisivas duplicadas');
ok(m.includes('drop policy if exists accesos_gestion_equipo on public.registros_acceso_clase')&&m.includes('drop policy if exists accesos_registro_usuario on public.registros_acceso_clase')&&m.includes('create policy accesos_insert_v101'),'accesos: combina INSERT usuario/equipo sin perder ramas');
ok(m.includes('alter policy preinscripcion_publica on public.preinscripciones with check')&&m.includes('drop policy if exists preinscripciones_crear_equipo')&&m.includes('drop policy if exists preinscripciones_solicitante_lectura'),'preinscripciones: OR por acción y una sola policy');
ok(m.includes('drop policy if exists perfil_propio on public.perfiles'),'perfiles: elimina policy redundante contenida en lectura de equipo');
ok(m.includes('select auth.uid()')&&m.includes('select auth.jwt()'),'101 mantiene initplan estable para Auth');
ok(!m.includes('= auth.uid()')&&!m.includes('auth.jwt() ->>'),'101 no reintroduce llamadas Auth por fila');
ok(r.includes('create policy perfil_propio on public.perfiles')&&r.includes('create policy preinscripciones_crear_equipo')&&r.includes('create policy accesos_gestion_equipo')&&r.includes('create policy notificaciones_gestion'),'rollback restaura excepciones originales');
ok(r.includes('alter policy clubes_publico_registro on public.clubes to public')&&r.includes('alter policy textos_legales_publicos_rc10 on public.textos_legales to anon, authenticated'),'rollback restaura roles públicos previos');
ok(m.trim().endsWith("notify pgrst, 'reload schema';")&&r.trim().endsWith("notify pgrst, 'reload schema';"),'migración y rollback recargan schema PostgREST');
console.log('KOMBAX BUILD 20057 · RLS policy consolidation 101: PASS');
