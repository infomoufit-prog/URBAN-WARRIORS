# Activación Supabase Meta/Instagram desde FIX20

Estado comprobado el 7 de octubre de 2026: backend desplegado, configuración Meta pendiente. No equivale a una integración real de extremo a extremo completada.

## Origen y migraciones aplicadas

Los archivos de Instagram de la carpeta de trabajo coinciden byte a byte con KOMBAX_20178_R120_FIX20.zip. Se conservan el ZIP y sus cuatro fragmentos originales.

Aplicadas y verificadas en poggsobhtutbuagjiydc:

| Archivo local | Nombre registrado | Versión asignada por Supabase |
|---|---|---|
| 20261007190030_kombax_meta_instagram_fix20.sql | kombax_meta_instagram_fix20 | 20261007201408 |
| 20261007201717_meta_instagram_fk_indexes_fix20.sql | meta_instagram_fk_indexes_fix20 | 20261007201735 |

La segunda migración añade cuatro índices detectados en la revisión de rendimiento. Se entrega separada; no estaba en el ZIP FIX20 original. Las versiones de historial del conector difieren del nombre de archivo local: conciliar el historial antes de un futuro db push. No volver a aplicar indiscriminadamente todas las migraciones. La migración de antigüedad/finanzas históricas incluida en FIX20 NO se ha aplicado en esta intervención.

## Edge Functions desplegadas y confirmadas ACTIVE, versión 1

| Función | verify_jwt | ID |
|---|---|---|
| meta-instagram | true | 2c249a64-936d-4def-8ff0-6a9e46053fa5 |
| meta-instagram-callback | false | 31cd4e2e-8350-4bc4-8dd0-599ee1d71953 |
| meta-instagram-deauthorize | false | 4c659ff9-9856-460f-9dd6-89da6294d27a |
| meta-instagram-data-deletion | false | e7943678-f3a4-4a07-85b1-85b78579935c |

Los callbacks públicos verifican estado OAuth/prueba de navegador o firma HMAC signed_request, según operación. La RPC interna es ejecutable solo por service_role; la RPC de contexto permite authenticated y comprueba usuario y permisos persistidos. search_path vacío verificado.

## URLs exactas para Meta

- OAuth callback: https://poggsobhtutbuagjiydc.supabase.co/functions/v1/meta-instagram-callback
- Deauthorization Callback: https://poggsobhtutbuagjiydc.supabase.co/functions/v1/meta-instagram-deauthorize
- Data Deletion Request: https://poggsobhtutbuagjiydc.supabase.co/functions/v1/meta-instagram-data-deletion

Las rutas corresponden a funciones desplegadas. No añadir barra final. Todavía responden 503 por configuración pendiente; no afirmar que Meta ya las ha validado.

## Secrets: comprobación visual del panel, sin leer valores

Ubicación: https://supabase.com/dashboard/project/poggsobhtutbuagjiydc/functions/secrets

Edge Functions > Secrets > Add or replace secrets > Name / Value > Save.

Faltan estos cinco nombres en Custom secrets:

| Nombre | Qué configurar |
|---|---|
| META_APP_ID | ID público de la app KOMBAX facilitado por el usuario |
| META_LOGIN_CONFIG_ID | ID público de Facebook Login for Business facilitado por el usuario |
| META_APP_SECRET | App Secret de esa misma app, desde Meta Settings > Basic; introducir únicamente en Supabase |
| META_GRAPH_API_VERSION | Versión Graph elegida y compatible con la app, formato vNN.N; no inferida ni fijada sin verificar Meta |
| META_TOKEN_ENCRYPTION_KEY | Clave aleatoria de 32 bytes, representada como 64 caracteres hexadecimales; guardar copia segura y no sustituirla tras conectar cuentas sin plan de rotación |

KOMBAX_APP_URL ya existe. Las claves predeterminadas SUPABASE_URL, SUPABASE_PUBLISHABLE_KEYS y SUPABASE_SECRET_KEYS figuran disponibles. No se han extraído sus valores ni añadido secretos reales al código. Esperar a que el usuario configure los cinco META_* antes de OAuth real.

## Comprobaciones en Supabase real

- Seis tablas kombax_meta con RLS activo: audit, connections, credentials, deletions, flows y publications. Ninguna permite SELECT/INSERT/UPDATE/DELETE directo a anon o authenticated.
- Los cuatro índices complementarios existen y los cuatro avisos nuevos de FK sin índice desaparecieron.
- Petición a meta-instagram sin Authorization: 401, bloqueo esperado en gateway.
- Callback sin parámetros: 503 Configuración pendiente.
- Desautorización con signed_request inválida: 503 configuration_pending, antes de ejecutar ninguna eliminación.
- Eliminación con confirmación inválida: 503 configuration_pending.
- Evidencia HTTP: INSTAGRAM_SUPABASE_HTTP_FIX20.json. Ninguna solicitud de prueba contiene tokens reales.
- Logs consultados en ventana 20:14–20:24 UTC, filtrados a IDs Meta: tres arranques normales y tres respuestas 503; sin eventos error en ese resultado. No hay tráfico OAuth real y la ausencia de errores en esta ventana no valida ese flujo.

## Advisors, comparados con la línea previa

Seguridad: 228 a 234 avisos INFO RLS sin políticas: los seis nuevos corresponden a tablas privadas deliberadamente cerradas; no se abren políticas para silenciar el aviso. Avisos de SECURITY DEFINER autenticado: 638 a 639; el nuevo es la RPC de contexto intencional con comprobación de autorización. Los 60 avisos de funciones ejecutables por anon y el aviso de contraseñas filtradas son previos y permanecen. No se han corregido ni modificado objetos ajenos a Instagram.

Rendimiento: FK sin índices vuelve a 256, la cifra anterior. Índices sin uso: 300 a 305; cinco nuevos son índices de tablas recién creadas sin tráfico. El aviso previo de índice duplicado continúa. No hay nuevos índices FK ausentes.

Referencias de los advisors:
- https://supabase.com/docs/guides/database/database-linter?lint=0008_rls_enabled_no_policy
- https://supabase.com/docs/guides/database/database-linter?lint=0029_authenticated_security_definer_function_executable
- https://supabase.com/docs/guides/database/database-linter?lint=0005_unused_index
- https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection

## QA: distinción entre paquete y activación

El log de build del FIX20 entregado confirma 109 PASS, 0 fallos nuevos y 3 P2 heredados de traducción. Build: 648 archivos; 381 JavaScript, 926 imports locales Linux; web/dist/Android sincronizados. Esta intervención no modifica frontend ni el ZIP; añade únicamente la migración de índices y este informe.

Se repitieron ahora 23 pruebas unitarias Meta y 8 comprobaciones de transporte simulado: correctas. Son pruebas aisladas, no conexión real a Meta. No se ha repetido ahora toda la suite de frontend; se verificó el log de la entrega y la coincidencia del código Meta con el ZIP. Las pruebas anteriores de SQL aislado y navegador permanecen documentadas en AUDITORIA_META_INSTAGRAM_FIX20.md.

## Pendientes para cerrar la integración

1. Usuario configura los cinco META_* ausentes; confirmar KOMBAX_APP_URL, sin enviar secretos al chat.
2. Repetir smoke tests: deben dejar de responder configuración pendiente y rechazar correctamente firmas/estados inválidos.
3. Registrar exactamente las tres URLs en Meta. Revisar dominio kombax.es, URLs legales públicas y configuración Facebook Login for Business de la misma app.
4. Preparar frontend FIX20 en un entorno de prueba autorizado. integrations.instagram.enabled sigue false en el paquete; el retorno necesita web/meta-instagram.html disponible en el origen KOMBAX_APP_URL. El backend desplegado no actualiza automáticamente la web.
5. Conectar cuenta profesional autorizada vinculada a Página de Facebook; verificar autorización, permisos y conexión cifrada sin leer tokens. Estado actual: NO PROBADO.
6. Acordar cuenta y contenido concreto y obtener autorización expresa para publicación real. Estado actual: NO PUBLICADO.
7. Probar desconexión y eliminación de datos de esa conexión de prueba. Estado actual: NO PROBADO EN META REAL; solo ensayos aislados previos.
8. Tras validar, habilitar el flag frontend y sincronizar recursos/build. Usuario actualizará manualmente GitHub y desplegará Netlify. No se ha hecho commit, push, merge, PR ni deploy Netlify en esta intervención.

App Review / Advanced Access: añadir permisos no acredita aprobación. Pendiente comprobar el nivel real de acceso en Meta, requisitos de verificación del negocio del panel, URLs legales, instrucciones y cuenta de prueba y grabación del flujo funcional y uso justificado de cada permiso. No se ha enviado revisión ni se afirma aprobación. Fuera de los roles de prueba, no abrir contratación/publicación hasta verificar acceso autorizado por Meta.
