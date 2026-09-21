# QA VALIDATION · KOMBAX 20.101 R14

## Resultado general
**PASS con una salvedad operativa de firma local.**

La implementación R14, la migración real de Supabase y la regresión completa están cerradas. La APK firmada no se genera dentro de este entorno porque `android/keystore.properties` no se incluye deliberadamente al contener secretos locales.

## Frontend / producto
PASS:
- Constructor R14 presente.
- Crear evento continúa al constructor.
- Seis etapas operativas presentes.
- Participantes y fotos integrados.
- Edición/reemplazo de foto de participante externo.
- Gestor Fight Card y horarios.
- Álbum visible para gestor aunque esté vacío.
- `Álbum · 0` y CTA `Subir fotos o vídeos` en estado vacío.
- Público no recibe álbum vacío.
- Asociación de media a combate.
- Asociación de media a Competidor KOMBAX.
- Límites 15 fotos / 5 vídeos conservados.
- Responsive específico del constructor.
- Urban Warriors y assets demo preservados.

## Backend real Supabase
Proyecto verificado: `poggsobhtutbuagjiydc`.

Migración aplicada:
- `181_kombax_events_creator_participant_update_20101_r14.sql`

RPC desplegado:
- `app_kombax_eventos_mutate_v181(text,jsonb,uuid)`

Verificación de permisos/aislamiento:
- función existe: PASS
- `anon EXECUTE = false`: PASS
- `authenticated EXECUTE = true`: PASS
- guard `app_kombax_evento_contexto_gestion_v171`: PASS
- error de gestión `EVENT_WORKSPACE_MANAGEMENT_FORBIDDEN`: PASS

La función es `SECURITY DEFINER` intencionadamente, pero no es pública para `anon` y valida internamente autenticación + workspace/gestión antes de actualizar.

## Advisors Supabase
Se ejecutaron advisors de seguridad y rendimiento después de la migración.

El advisor de seguridad sigue reportando avisos históricos/globales del proyecto, entre ellos funciones SECURITY DEFINER antiguas, tablas con RLS sin políticas directas y protección de contraseñas filtradas desactivada. Son hallazgos preexistentes y transversales que no se amplían dentro de R14.

R14 específico:
- v181 NO aparece como ejecutable por `anon`.
- v181 sí aparece como ejecutable por `authenticated`, coherente con el contrato previsto y protegido internamente por workspace.
- no se detectó un bloqueo R14 específico en el advisor de rendimiento.

## Datos de eventos tras R14
Verificación directa en Supabase:
- Noche de Impacto: 12 participantes visibles, 6 combates visibles, 0 media activa.
- Urban Warriors Jiu-Jitsu: 12 participantes visibles, 6 combates visibles, 0 media activa.

El contador 0 confirma que el álbum real todavía está vacío; R14 habilita al organizador para llenarlo desde la nueva interfaz, no inventa registros multimedia de prueba.

## Tests locales
PASS:
- `package.json` válido.
- `node --check web/js/modules/kombax-events.js`.
- `node --check web/js/core/repositories.js`.
- `node scripts/test-kombax-20101-event-creator-r14.mjs`.
- regresión R13 actualizada para aceptar cache R14.
- `npm run build` completo.

Resultado final de build:
`OK build 152 archivos · web = dist = Android`

## Android
JKS presente:
`LOCAL_RELEASE_SIGNING/kombax-release.jks`

SHA-256 JKS:
`7c70adc0d8e7b9426990d86a3f4743e2794e391f725dd708082e48264183a415`

Preflight:
- Identidad Android estable: OK
- versionCode 20101: OK
- assets/www: OK
- Firebase push: OK
- firma local: PENDIENTE únicamente porque falta `android/keystore.properties` con los secretos locales

Resultado: 4/5, esperado por política de no incluir contraseñas en ZIP.

## Límites conocidos / fuera de R14
No se declara implementado:
- brackets/árboles de torneo;
- rol estructural Main Event / Co-Main separado mediante `card_role`;
- drag & drop avanzado de horarios.
