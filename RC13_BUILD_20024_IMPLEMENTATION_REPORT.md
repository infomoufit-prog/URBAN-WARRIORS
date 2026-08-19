# RC13 build 20024 · informe de implementación

## Alcance cerrado

KOMBAX Social Alpha sobre el checkpoint 20023. Es una red profesional global diferenciada de la Comunidad del Club. Mantiene `applicationId com.urbanwarriors.app`, `versionName 2.0.0-rc.13` y Showcase desactivado.

## Implementado

- Proyección pública segura de perfiles de club, miembros con identidad social autorizada y perfiles directos cuando en el futuro estén activos y verificados.
- Entitlements `social.read`, `social.publish` y `social.moderate` separados de la membresía y del rol visual.
- Feed global con cursor `(creado_en,id)`, páginas máximas de 20 y categorías actualización, resultado, evento y oportunidad.
- Likes almacenados por usuario sin publicar la identidad de quien interactúa.
- Directorio global limitado a nombre, slug, bio, imágenes públicas, tipo y verificación.
- Solicitudes de contacto con motivo, texto entre 10 y 500 caracteres y estados pendiente/aceptada/rechazada/cerrada.
- Control backend en vivo de mayoría de edad: un perfil personal necesita fecha verificada y 18 años para enviar o recibir contacto.
- Bloqueos, denuncias, moderación global explícitamente asignada y auditoría separada.
- Normas KOMBAX Social 1.1, aceptación específica y activación opcional sin publicar el expediente.
- UI global rojo/negro/blanco con cuatro vistas: Actualidad, Perfiles, Contactos y Seguridad.

## Exclusiones deliberadas

- No existen seguidores, amistades, chat, conversaciones, mensajes encadenados, presencia ni estado en línea.
- Una solicitud aceptada no revela automáticamente email, teléfono u otro dato privado.
- No se añaden precios, cobros, checkout, tienda ni Showcase.
- Los moderadores globales no se deducen de un rol de club; necesitan asignación explícita en backend.
- No se reutilizan `publicaciones_comunidad`, likes internos o permisos de Comunidad del Club.

## Seguridad y escalabilidad

- Tablas sin privilegios DML/SELECT directos para `authenticated`; lectura y escritura pasan por RPC con `SECURITY DEFINER`, validación de sujeto y RLS habilitado.
- Mutaciones idempotentes mediante `app_mutation_requests` y `request_id` verificable en cliente.
- El feed está indexado por estado/fecha/id y no descarga el histórico completo.
- Contactos, denuncias y auditoría tienen índices por estado/destino y límites de lectura.
- Diseñado para separar clubes y capa global, pero la capacidad de 100 clubes continúa siendo un objetivo pendiente de ensayo de carga real.

## Evidencia local de cierre

- Test específico 20024: PASS.
- Arquitectura sin `fetch` directo: PASS.
- Responsive y llaves CSS: PASS.
- Sintaxis de los módulos modificados: PASS.
- Suite estática completa: 34 scripts, exit code 0.
- `scripts/build.mjs`: 58 archivos, hashes idénticos entre `web`, `dist` y Android.
- `git diff --check`: sin errores.

## Estados que no deben confundirse con validación real

- Migración 041 en Supabase real: **NO EJECUTADO**.
- Prueba SQL transaccional 041: **PENDIENTE DE ENTORNO**.
- Validación visual/manual y flujos con dos cuentas: **PENDIENTE**.
- Compilación Android Gradle y firma JKS: **PENDIENTE**.
- APK/AAB e instalación física: **PENDIENTE**.
- Netlify: **NO DESPLEGADO**.

## Orden de backend propuesto

Tras autorización: preflight 041 → copia de seguridad → migración 041 → verificación 041 → prueba transaccional 041. Probar con dos adultos de clubes distintos, un menor elegible sin contacto, un perfil de club y un moderador global asignado expresamente.
