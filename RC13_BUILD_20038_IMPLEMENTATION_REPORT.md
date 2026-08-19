# RC13 build 20038 · Informe de implementación y validación

Intervención cerrada sobre **identidad visual, álbum de Club y render de media**. Base: RC13 build 20037. Resultado de código: build 20038.

## Alcance implementado

1. **Perfil público de Club → KOMBAX Social**
   - El logo y la portada públicos del Club pasan a ser la fuente pública efectiva del perfil Social de tipo Club.
   - El trigger de sincronización se corrige para no conservar valores antiguos por `coalesce` cuando el Club cambia su imagen.
   - Se ejecutó backfill de los perfiles Club ya existentes.
   - Las RPC de directorio, feed, selector de identidades, comentarios y perfil público usan la identidad visual efectiva.

2. **Avatar de miembro/alumno → KOMBAX Social con privacidad**
   - `profile-media` se mantiene privado.
   - No se publica automáticamente la foto privada de un alumno desde la cuenta de un Gestor u otro tercero.
   - El propio usuario autenticado puede crear/reparar su copia pública de avatar Social a partir de su foto privada usando la capa Storage existente.
   - La foto Social explícita tiene prioridad sobre fallbacks heredados.

3. **Álbum de Club**
   - Selector `Tipo` corregido con opciones visibles `Fotografía` (`photo`) y `Vídeo` (`video`).
   - El renderer de formularios admite además tuplas legacy de forma defensiva para evitar futuros selectores vacíos.
   - El repositorio normaliza y valida tipo/MIME antes de invocar backend.
   - RLS de Storage alineada con la ruta real `<uid>/club/<club_id>/<archivo>` sin ampliar el sujeto autorizado.

4. **Publicar + guardar en álbum**
   - Si una foto del álbum ya está adjuntada a Social, se reutiliza el adjunto en lugar de duplicarlo.
   - Si se crea un adjunto Social nuevo y la publicación falla, se revierte el adjunto aunque la fuente proviniera de un álbum existente.
   - Si la fuente Club/Directa era nueva y la publicación falla, también se revierte esa fuente.
   - No se elimina una fuente preexistente del álbum durante rollback.

5. **Render de imágenes**
   - El feed Social conserva la proporción original de fotografías verticales, horizontales y cuadradas.
   - Se elimina el zoom hover que podía recortar bordes.
   - Se limita la altura visual sin deformar: `object-fit: contain`.
   - Las miniaturas de álbum pueden seguir en cuadrícula `cover`, pero la vista completa abre la fotografía sin recorte.

## Cambios de backend aplicados en Supabase

### Migración 063 — `kombax_identity_album_media_20038`
Aplicada con historial formal de migraciones.

- Corrige policy `kombax_club_media_insert_v046` a profundidad real de 3 carpetas.
- Mantiene controles de bucket, UID propietario, segmento `club` y permiso real de gestión del Club.
- Añade helpers canónicos de URL pública de avatar/banner.
- Corrige trigger `club_public_sync_kombax_social_v051`.
- Ejecuta backfill del perfil Social de Club.
- Actualiza RPC Social para identidad visual efectiva.

### Migración 064 — `kombax_identity_helpers_hardening_20038`
Aplicada con historial formal de migraciones.

- Retira `EXECUTE` directo de los helpers internos 063 para `public`, `anon` y `authenticated`.
- Las RPC autorizadas siguen funcionando a través de su interfaz pública gobernada.

## Verificación live de Supabase

- Urban Warriors Social devuelve el mismo `avatar_url` que el logo vigente de su perfil público.
- Trigger de sincronización de Club presente y activo.
- Policy de álbum exige exactamente las condiciones previstas.
- Simulación autenticada como Gestor: puede gestionar Urban Warriors y cumple los tres segmentos de la ruta de Storage.
- Simulación autenticada como Bryan alumno: miembro activo, puede actuar con su identidad Social, tiene avatar privado y cumple las condiciones para crear **su propia** copia pública Social.
- Prueba transaccional del backend del álbum:
  - `tipo='photo'` → aceptado y revertido de prueba.
  - `tipo='imagen'` → rechazado con `KOMBAX_CLUB_MEDIA_TYPE_INVALID`.
- Los helpers internos 063 tienen `anon_execute=false` y `authenticated_execute=false` tras 064.
- La RPC `app_kombax_social_mis_perfiles_v051` sigue devolviendo `Urban Warriors · Club` con su logo correcto bajo contexto `authenticated`.

## Pruebas automáticas ejecutadas

### Suite completa
`npm run build` ejecutado después del último cambio de deduplicación/rollback.

Resultado:
- Toda la regresión histórica RC4 → RC13: **PASS**.
- KOMBAX builds 20022 → 20037: **PASS**.
- Regresión específica 20038: **PASS**.
- Build final: `OK build 62 archivos · web = dist = Android`.

### Regresión específica 20038
Comprueba, entre otros:
- build 20038 coherente;
- selector Tipo legible y valores correctos;
- renderer defensivo de selects;
- ausencia de selectores tuple defectuosos en `web/js`;
- validación tipo/MIME;
- self-heal solo desde sesión propietaria;
- prioridad del avatar Social explícito;
- rollback de media nueva;
- deduplicación al reutilizar álbum;
- rollback de adjunto Social con fuente de álbum existente;
- feed y visor sin recorte;
- viewers de álbum completos;
- contrato de migración 063;
- hardening 064;
- inclusión en suite principal.

### Smoke test local HTTP
- `npm run dev` arrancó correctamente en `http://127.0.0.1:4173`.
- `/` sirvió referencias cache-busted `v=20038`.
- `/config.js` devolvió `build: 20038`.
- CSS servido contiene el render `object-fit: contain` de media Social.

### Sincronización de artefactos
Auditoría SHA-256 independiente:
- `web`: 62 archivos.
- `dist`: 62 archivos.
- `android/app/src/main/assets/www`: 62 archivos.
- faltantes: 0.
- extras: 0.
- diferencias SHA-256: 0.

### Arquitectura
- No hay `fetch()` directo en las superficies modificadas.
- La suite de arquitectura completa lo valida.
- No quedan selectores `options:[[...]]` defectuosos en `web/js`.

## Android preflight

Resultado final: **4/5**.

PASS:
- applicationId estable `com.urbanwarriors.app`.
- versionCode 20038.
- web embebida presente y sincronizada.
- Firebase presente.

PENDIENTE deliberado:
- firma local (`android/keystore.properties` / JKS).

No se afirma que exista APK/AAB release firmado de 20038. El paquete fuente no contiene JKS, `.keystore` ni `keystore.properties` con secretos.

## Auditoría Supabase Advisors

Se ejecutaron advisors de seguridad y rendimiento.

### Intervención 20038
- La exposición directa innecesaria de los helpers 063 detectada durante la auditoría se corrigió en 064 y se verificó.
- No se amplió el bucket privado `profile-media` ni se convirtió en público.

### Deuda global preexistente detectada, fuera de este bloque
Los advisors siguen informando deuda histórica de alcance global: numerosas funciones `SECURITY DEFINER`, tablas RLS deny-by-default sin policies directas, claves foráneas sin índice, políticas con `auth.uid()` no optimizado, políticas permisivas duplicadas y algunos índices duplicados/no utilizados. No se modificaron masivamente en esta intervención porque afectan contratos de toda la plataforma y requieren una auditoría/hardening independiente.

## Criterios de cierre

- Backend/RLS: **PASS**.
- Identidad visual de Club: **PASS live**.
- Privacidad de avatar miembro: **PASS por diseño y simulación autenticada**.
- Tipo de álbum: **PASS backend + frontend estático**.
- Rollback/deduplicación: **PASS automatizado**.
- Render sin recorte: **PASS estático/regresión**.
- Suite histórica: **PASS**.
- Sincronización PWA/Android: **PASS**.
- Android signing: **PENDIENTE**, intencional y no falseado.

La única comprobación que no puede sustituirse por tests estáticos/backend es la percepción visual final en el navegador/dispositivo real (foto vertical completa, texto legible del selector y avatar renderizado). Esa es la siguiente validación manual local sobre el build 20038.
