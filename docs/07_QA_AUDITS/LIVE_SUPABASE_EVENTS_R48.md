# SUPABASE VIVO · Combat Events R48

Proyecto principal auditado: `poggsobhtutbuagjiydc`.

## Decisión
**No se aplicó migración R48.** El modelo vivo ya ofrece los contratos necesarios para la experiencia solicitada.

## Contratos verificados en vivo
- columna `co_estelar boolean`: presente.
- índice único `uq_kombax_evento_one_co_main_r22`: presente.
- `app_kombax_eventos_mutate_v191(text,jsonb,uuid)`: presente.
- mutador v191 ejecutable por `authenticated`: sí.
- mutador v191 ejecutable por `anon`: no.
- `app_kombax_evento_media_cuota_v175(uuid,uuid)`: presente.
- cuota de 30 fotos: presente en función viva.
- cuota de 5 vídeos: presente en función viva.
- guard de máximo 30 combates: presente en mutador vivo.
- `kombax_evento_media`: RLS activo.
- acceso directo a tabla de media por `anon`: no.
- INSERT directo por `authenticated`: no.

## Datos demo observados
En la lectura de estado realizada durante R48:
- `Urban Warriors Jiu-Jitsu Interclub Demo`: 5 combates, 1 Main, 0 Co-Main.
- `Urban Warriors Noche de Impacto`: 6 combates, 1 Main, 1 Co-Main.
- no había aún un poster R48 persistido reconocido en esos demos.

Esto no indica defecto de implementación: el flujo de carga R48 todavía no ha sido ejercido manualmente con una sesión real de organizador en el backend vivo.

## E2E pendiente
Pendiente prueba manual autenticada: subir → visualizar → fullscreen → sustituir → retirar cartel de Fight Card. No se realizó escritura de prueba artificial en producción para no ensuciar datos reales/demo.

## Edge Functions
R48 no modifica Edge Functions. Comparación R47→R48: no hay cambios de backend Supabase.
