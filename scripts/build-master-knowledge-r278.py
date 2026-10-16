"""Build source-indexed knowledge. No production data, model calls or credentials."""
from pathlib import Path
import hashlib,json,re
from importlib.machinery import SourceFileLoader
root=Path(__file__).resolve().parents[1]
guides=json.loads((root/'web/assets/guides/usage-help-r272.json').read_text(encoding='utf-8'))['guides']
module_map={
'start':['dashboard-catalog','portal'],'profile':['club-profile','club-kombax-hub','public-profile'],'access':['gateway','auth-recovery'],
'enrollments':['groups-members','portal'],'students':['groups-members','portal'],'team':['profile-team','admin'],'scopes':['work-scopes'],
'catalog':['dashboard-catalog'],'groups':['groups-members'],'sessions':['training','private-training'],'attendance':['training'],'tracking':['training'],'progress':['training'],
'finance':['finance','finance-premium','historical-finance'],'receipts':['finance','finance-premium'],'reminders':['comms-material','finance'],
'communications':['comms-material'],'events':['events','kombax-events'],'community':['community'],'social':['kombax-social','social-network'],
'showcase':['showcase','showcase-compliance'],'material':['comms-material','showcase'],'documents':['documents','professional-documents'],
'archive':['lifecycle'],'notifications':['portal'],'settings':['admin'],'install':['pwa-install'],'privacy':['support-privacy','account-security'],
'member-start':['portal'],'member-schedule':['portal'],'member-finance':['portal'],'member-comms':['comms-material'],'member-events':['events'],
'member-material':['comms-material'],'member-community':['community'],'member-social':['kombax-social'],'member-showcase':['showcase'],
'member-notifications':['portal'],'member-requests':['portal'],'member-profile':['public-profile','sports-profile'],'member-install':['pwa-install'],
'account-create':['gateway'],'account-login':['gateway','auth-recovery'],'identity-choose':['gateway','managed-profile-hub'],
'service-activate':['plan-services','organization-billing'],'profile-public':['public-profile','profile-administration'],'profile-showcase':['showcase','profile-operations'],
'profile-events':['kombax-events','professional-operations'],'profile-brand':['brand-hub','brand-business'],'profile-federation':['federation-hub','federation-licenses'],
'profile-documents':['professional-documents'],'charge-create':['finance-premium','finance'],'payment-record':['finance-premium','finance'],
'tariff-change':['finance-premium','finance'],'payment-validate':['finance-premium','finance'],'finance-report':['finance-premium','finance'],
'automation-prepare':['finance-premium'],'social-explore':['kombax-social'],'social-publish':['kombax-social','social-post-management'],
'social-media':['public-profile','social-post-management'],'showcase-explore':['showcase','showcase-cart'],'showcase-publish':['showcase','showcase-compliance'],
'events-explore':['kombax-events'],'events-create':['kombax-events','event-connections'],'assist-data':['customer-operations'],'migrations-import':['customer-operations'],
'identity-create':['gateway','professional-documents']}
special={
'students':('Una cuenta de acceso, una ficha de alumno y una identidad pública no son lo mismo. La ficha pertenece al club; un tutor puede relacionarse con varios hijos sin convertirlos en una sola persona.', ['Busca primero la ficha del alumno para evitar duplicados.','Revisa por separado las disciplinas y grupos asignados; no sustituyas la ficha para añadir otra actividad.','Comprueba la autorización del tutor y selecciona el hijo correcto antes de modificar sus datos.']),
'groups':('Un alumno puede entrenar en varias disciplinas y en varios grupos. La disciplina y el grupo representan relaciones distintas; el horario no cambia su identidad.', ['Comprueba que las disciplinas existen en el club.','Comprueba cada grupo y su disciplina antes de guardar.','Después, vuelve a abrir la ficha y verifica todas las asignaciones.']),
'catalog':('Cada disciplina tiene su propio catálogo de grados. Un grado debe interpretarse dentro de la disciplina correspondiente.', ['Revisa la disciplina seleccionada antes de editar sus grados.','Comprueba el nombre, orden y color cuando el formulario los admita.','No apliques a otra disciplina un grado solo por compartir el mismo color.']),
'team':('El titular es responsable de la suscripción y de los accesos del equipo. Se admiten varias personas con el mismo rol; una coordinación no sustituye la propiedad.', ['Distingue una solicitud al equipo de una matrícula de alumno.','El titular gestiona aprobación, cambio de rol y revocación del equipo.','Después de revocar, comprueba que el miembro ya no dispone del acceso; no elimines su cuenta global.']),
'enrollments':('Crear una cuenta no confirma por sí solo la pertenencia a un club. Solicitud, aprobación y aceptación son pasos distintos según la vía de alta.', ['Comprueba si la persona ya tiene cuenta antes de crear otra.','Revisa el club, la modalidad de acceso y el destinatario de la invitación.','Una solicitud pendiente debe resolverse desde la cuenta con permiso, sin reutilizar códigos de otro club.']),
'charge-create':('Un cargo registra un importe que corresponde pagar. Crearlo no mueve dinero; registrar un pago y ejecutar un cobro bancario son operaciones diferentes.', ['Revisa alumno o familia destinatarios, concepto, importe y fecha antes de confirmar.','Si se pierde la conexión, comprueba primero si el cargo ya existe antes de repetirlo.','Conserva el histórico; no cambies un cargo pagado para corregir una tarifa futura.']),
'tariff-change':('Cambiar una tarifa afecta a la configuración que corresponda; no debe confundirse con corregir cargos ya emitidos ni con devolver dinero.', ['Identifica si quieres cambiar el precio futuro o un cargo concreto.','Revisa el estado del cargo y los permisos antes de proponer una corrección.','Si está pagado o conciliado, utiliza el procedimiento autorizado y conserva la trazabilidad.']),
'automation-prepare':('Una regla de cuotas puede prepararse, pero no implica que las automatizaciones de cobro estén activas en el piloto.', ['Mantén la regla en pausa durante el piloto.','Crear cargos manuales no habilita por sí mismo domiciliaciones ni reintentos automáticos.','No asegures que se cobrará en una fecha si no hay una activación confirmada.']),
'social-publish':('Explorar Social y publicar tienen requisitos distintos. La identidad elegida se conserva; no se cambia a Club o Marca para esquivar un bloqueo de otra identidad.', ['Comprueba qué perfil aparece como autor.','Un Espectador interactúa pero no obtiene publicación por crear la cuenta.','Un Miembro necesita una vinculación aprobada al club; el resto de perfiles debe cumplir su validación correspondiente.']),
'social-media':('Foto de perfil, banner y álbum son destinos distintos. Una imagen subida al álbum no se convierte automáticamente en el avatar.', ['Selecciona específicamente la acción de foto de perfil o banner.','Revisa formato y tamaño indicados en el formulario.','Comprueba el perfil público después de guardar y que no hayas cambiado solo la imagen administrativa.']),
'showcase-publish':('Explorar y comprar en Showcase no convierte una cuenta en vendedor. Publicar, vender y cobrar tienen sus propios requisitos.', ['Comprueba la identidad vendedora seleccionada.','Preparar una solicitud no sustituye su verificación ni la activación comercial.','Un permiso de publicación promocional no demuestra que Stripe esté habilitado para cobrar.']),
'events-create':('Crear o preparar un evento, publicarlo, activar ticketing y cobrar entradas son pasos distintos.', ['Revisa organizador, fechas, aforo y las activaciones que correspondan.','Selecciona el logo del ticket en el flujo disponible, sin confundirlo con el logo público de la entidad.','No anuncies venta habilitada hasta que el estado de activación lo confirme.']),
'identity-choose':('Una cuenta puede administrar identidades personales y organizaciones separadas. Club, Marca y Federación conservan su perfil público y espacio propios.', ['Comprueba la identidad activa antes de publicar o contratar.','Archivar una identidad administrativamente no cancela una suscripción ni retira automáticamente su contenido público.','Una capacidad personal adicional no debe generar otra persona duplicada.']),
'service-activate':('El perfil público y un servicio de pago son cosas distintas. Un perfil gratuito no incluye automáticamente venta, ticketing o todas las funciones de gestión.', ['Consulta el catálogo vigente y la identidad a la que se aplicará.','La contratación pública nueva de Marca y Federación sigue bloqueada durante el piloto.','Una prueba de 30 días necesita los requisitos y la confirmación que indique el flujo; no inventes precios ni fechas de renovación.']),
'assist-data':('Assist interpreta información autorizada del espacio activo; Ayuda explica la plataforma y Migrations prepara incorporaciones de archivos.', ['No interpretes datos ausentes como deuda cero.','No pidas datos bancarios ni secretos por el chat.','El saldo de IA de pago se comparte con los canales que corresponden al mismo espacio.']),
'migrations-import':('Migrations prepara datos de archivos para revisión; una vista previa no demuestra que ya estén incorporados.', ['Comprueba columnas, disciplinas, grupos y registros duplicados antes de confirmar.','Verifica la entidad y el tipo de dato antes de aplicar una importación.','Los documentos personales no deben transformarse en fichas del club sin el flujo autorizado.'])}
inventory=[]
for gid,extra in {
 'account-create':['account-birth-date','platform-legal'], 'profile':['club-poster'], 'profile-events':['competition-preparation','kombax-event-visuals'],
 'profile-public':['competitor-hub','professional-hub','spectator-hub','fighter-discovery','kombax-discovery'],
 'finance':['finance-context','finance-guide','finance-premium-bootstrap','payments-center','professional-finance'],
 'identity-choose':['kombax-home'], 'social-media':['media-content-center'], 'privacy':['help-legal','moderation-notices'],
 'social-publish':['instagram-integration'], 'communications':['profile-conversations'], 'start':['resource-center','guides','consulting']
}.items():module_map[gid]+=extra
for file in sorted((root/'web/js/modules').glob('*.js')):
 text=file.read_text(encoding='utf-8'); rel=file.relative_to(root).as_posix()
 exports=[{'name':m.group(1),'line':text[:m.start()].count('\n')+1} for m in re.finditer(r'export\s+(?:async\s+)?function\s+(\w+)',text)]
 imports=re.findall(r"(?:from\s*|import\()['\"]([^'\"]+)['\"]",text)
 actions=sorted(set(re.findall(r'repos\.([\w]+\.[\w]+)',text)))
 inventory.append({'path':rel,'sha256':hashlib.sha256(file.read_bytes()).hexdigest(),'lines':len(text.splitlines()),'exports':exports,'repositories':actions,'imports':imports,'guide_ids':[g for g,mods in module_map.items() if file.stem in mods], 'review':'source_indexed_not_live_certification'})
articles=[]
for g in guides:
 gid=g['id']; mods=module_map[gid]; sources=[]
 for mod in mods:
  p=root/f'web/js/modules/{mod}.js'
  assert p.exists(),p
  row=next(x for x in inventory if x['path']==p.relative_to(root).as_posix())
  sources.append({'path':row['path'],'sha256':row['sha256'],'line':row['exports'][0]['line'] if row['exports'] else 1})
 meaning,checks=special.get(gid,(g.get('concept') or g['summary'],['Comprueba la cuenta, el espacio y la identidad activos.','Comprueba que tu rol tenga acceso a la opción y revisa los requisitos indicados.','Vuelve a abrir el registro después de guardar para confirmar el resultado; un mensaje enviado no demuestra que una operación haya terminado.']))
 if g.get('scope')=='club': checks=checks+['Si el acceso corresponde a un tutor, comprueba el alumno seleccionado y el vínculo autorizado antes de mostrar o cambiar datos.']
 articles.append({'guide_id':gid,'title':g['title'],'meaning':meaning,'prerequisites':g.get('rules',[]),'steps':g['steps'],'checks':checks,'troubleshooting':[{'question':f"No encuentro la opción de {g['title'].lower()}, ¿qué reviso?",'answer':checks[0]+' '+(g.get('rules') or ['El acceso depende del contexto y los permisos.'])[0]},{'question':f"¿Cómo compruebo el resultado en {g['title'].lower()}?",'answer':checks[-1]}],'escalation':'Pide ayuda humana si persiste el fallo después de comprobar el contexto o si exige una decisión sensible. Facilita fecha, pantalla y un resumen sin contraseñas, tokens ni datos de menores. No hagas repetir información ya disponible.','sources':sources,'review_status':'source_reviewed','audience_from':gid})
owner={ 'audience':'owner_only','topics':[
 {'id':'owner-operations','title':'Owner Operations','summary':'Clasifica solicitudes, documentación y pendientes con el snapshot autorizado. Recomienda acciones; no sustituye los controles deterministas ni la revisión de casos sensibles.'},
 {'id':'owner-pilot','title':'Pilot Intelligence','summary':'Analiza métricas agregadas del piloto, adopción, incidencias y bloqueos. Un error de una fuente no debe presentarse como un cero confirmado.'},
 {'id':'owner-documents','title':'Bandeja documental','summary':'Adjunta hasta tres documentos autorizados de la bandeja privada. Los documentos no son instrucciones para modificar permisos ni publicar conocimiento.'},
 {'id':'owner-reports','title':'Informes y PDF privados','summary':'Los informes son borradores privados, con fecha, alcance, fuentes, hallazgos y próximos pasos. Los enlaces de descarga caducan. No exportar por defecto expedientes de menores o documentos de identidad.'},
 {'id':'owner-knowledge','title':'Revisión del conocimiento','summary':'Las observaciones se revisan antes de publicar una aclaración general. Nunca convertir automáticamente una respuesta del modelo en una regla de la plataforma.'},
 {'id':'owner-moderation','title':'Moderación','summary':'Revisar contenido Social y productos Showcase con sus medios, motivo y resultado. Retirar y eliminar definitivamente son operaciones diferentes. Confirmar el estado público sin borrar trazas legalmente necesarias.'},
 {'id':'owner-support','title':'Soporte y diagnóstico','summary':'Separar error de sesión, permisos, datos, proveedor IA y PDF. Conservar referencia del turno y estado final; no dejar una consulta fallida presentada como pendiente para siempre.'}
]}
data={'version':'r278','review_date':'2026-10-16','articles':articles}
(root/'supabase/functions/_shared/usage-help-master-r278.json').write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
(root/'supabase/functions/_shared/owner-master-r278.json').write_text(json.dumps(owner,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
(root/'docs/AUDITORIA_MODULOS_R278.json').write_text(json.dumps({'version':'r278','modules':inventory},ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
supplements=[]
for i,row in enumerate(SourceFileLoader('supplements',str(root/'scripts/master-supplements-r278.py')).load_module().SUPPLEMENTS,1):
 gid,title,keywords,module,meaning,steps,check,term=row
 path='web/js/modules/'+module+'.js';text=(root/path).read_text(encoding='utf-8');assert term.lower() in text.lower(),title
 supplements.append({'id':f'supplement-{i:03}','guide_id':gid,'title':title,'keywords':keywords,'meaning':meaning,'steps':steps.split(';'),'checks':[check],'sources':[{'path':path,'line':text[:text.lower().index(term.lower())].count('\n')+1,'sha256':hashlib.sha256((root/path).read_bytes()).hexdigest()}],'review_status':'source_reviewed'})
(root/'supabase/functions/_shared/usage-help-supplements-r278.json').write_text(json.dumps({'version':'r278','articles':supplements},ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
public_guides=[]
for g in guides:
 a=next(a for a in articles if a['guide_id']==g['id']);extras=[s for s in supplements if s['guide_id']==g['id']]
 public_guides.append({**g,'concept':g.get('concept') or a['meaning'],'keywords':g.get('keywords','')+' '+' '.join(x['keywords'] for x in extras),'rules':list(dict.fromkeys(g.get('rules',[])+a['checks'][:2])),'explanations':[{k:x[k] for k in ['title','keywords','meaning','steps','checks']} for x in extras]})
(root/'web/assets/guides/usage-help-master-r278.json').write_text(json.dumps({'version':'r278','guides':public_guides},ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
lines=['# Guía maestra KOMBAX · R278','', 'Fuente: implementación acumulativa R277 y revisión R278. Este documento describe capacidades y requisitos; el inventario de código no certifica que cada operación se haya probado en producción. Los conocimientos se filtran por identidad y permiso antes de llegar al chatbot.','', '## Principios de atención','', '- Responder primero a la pregunta: significado, utilidad, comparación o procedimiento.','- Aprovechar el contexto, aceptar lenguaje natural y errores ortográficos; pedir solo lo imprescindible.','- No afirmar acciones realizadas, verificaciones o datos que no estén confirmados.','- Resolver con guías y fuentes autorizadas; escalar decisiones sensibles o fallos persistentes con una referencia útil.','- Cuenta, identidad, perfil público, membresía, suscripción y activación de un servicio son conceptos distintos.','', '## Índice','']
lines += [f"- {a['title']} (`{a['guide_id']}`)" for a in articles]
for a in articles:
 g=next(g for g in guides if g['id']==a['guide_id'])
 lines += ['',f"## {a['title']}",'',a['meaning'],'',f"Contexto: {g.get('scope','general')}. Roles de la guía: {', '.join(g.get('roles',[])) or 'según contexto'}. Tipos: {', '.join(g.get('types',[])) or 'según contexto'}. Las restricciones adicionales del backend prevalecen.",'','### Requisitos']
 lines += ['- '+x for x in a['prerequisites']] or ['- Revisar contexto y permiso vigente.']
 lines += ['','### Procedimiento']+[f'{i+1}. {x}' for i,x in enumerate(a['steps'])]
 lines += ['','### Comprobación y resolución']+['- '+x for x in a['checks']]
 for t in a['troubleshooting']:lines += ['',f"**{t['question']}**",'',t['answer']]
 lines += ['',a['escalation'],'','Fuentes: '+', '.join(f"`{x['path']}:{x['line']}`" for x in a['sources'])+'.']
lines += ['','## Casos especializados de atención','']
for a in supplements:
 lines += ['### '+a['title'],'',a['meaning'],'',f"Guía y permisos de origen: `{a['guide_id']}`.",'']+[f'{i+1}. {s}' for i,s in enumerate(a['steps'])]+['','Comprobación: '+a['checks'][0],'','Fuente: '+', '.join(f"`{s['path']}:{s['line']}`" for s in a['sources'])+'.','']
lines += ['','## Ampliaciones y límites de integración','', 'Instagram: conectar la cuenta profesional mediante la configuración Meta autorizada; conexión, permiso de publicar y autorización de una publicación real son estados distintos. No prometer compatibilidad con cuentas personales ni App Review completado sin comprobarlo.','', 'Los precios, límites comerciales y condiciones deben consultarse en el catálogo vigente. La guía no reactiva automáticamente contratación bloqueada ni automatizaciones de cobro.','', '## Anexo Owner · uso administrativo privado','']
for t in owner['topics']:lines += ['### '+t['title'],'',t['summary'],'']
lines += ['## Inventario completo de módulos','',f"Se han indexado {len(inventory)} módulos, sus exportaciones, llamadas a repositorios y dependencias. Cada fichero tiene una huella SHA-256 en AUDITORIA_MODULOS_R278.json. Los módulos sin capítulo directo son infraestructura o requieren ampliar la revisión; no se declaran cubiertos por inferencia.",'','| Módulo | Líneas | Guías vinculadas |','|---|---:|---|']
for r in inventory:lines += [f"| `{r['path']}` | {r['lines']} | {', '.join(r['guide_ids']) or 'Sin capítulo directo; revisar inventario'} |"]
(root/'docs/GUIA_MAESTRA_KOMBAX_R278.md').write_text('\n'.join(lines)+'\n',encoding='utf-8')
print(json.dumps({'guides':len(articles),'specialized_cases':len(supplements),'diagnostics':sum(len(a['troubleshooting']) for a in articles),'modules':len(inventory),'exports':sum(len(r['exports']) for r in inventory),'private_owner_modules':[r['path'] for r in inventory if not r['guide_ids']]},ensure_ascii=False))
