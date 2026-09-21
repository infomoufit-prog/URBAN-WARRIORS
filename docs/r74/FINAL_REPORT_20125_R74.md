# KOMBAX R74 · Build 20125 — Informe final

Fecha de cierre: 2026-09-16 (Europe/Madrid)
Base acumulativa: R73 / build 20124
Estado: **PILOT FREEZE CANDIDATE — implementación y QA automatizada completadas**

## Alcance completado

R74 consolida el trabajo iniciado sobre R73 sin sustituir ninguna capacidad previa. El cambio principal de Events elimina la relación 1:1 entre evento público y evento privado: un evento público puede recibir conexiones de varios clubes y cada conexión se autoriza de forma independiente por el organizador del evento público. El organizador puede ser un club, federación u otra entidad/cuenta con permisos reales sobre el evento público.

El ciclo de conexión queda en `pending → approved / rejected / revoked`. La solicitud de conexión no publica participantes ni licencias. Tras la aprobación, el club puede ejecutar de forma explícita la sincronización de participantes. Esa capa reutiliza referencias existentes a `evento_participantes` y, cuando existe, a la licencia federativa; no duplica identidades, fichas, licencias ni documentos.

Showcase incorpora autoprovisión/revinculación segura para gestores elegibles de clubes. El proveedor existente se reutiliza; no se crean espacios duplicados. En Urban Warriors, la auditoría live confirma 1 club, 1 proveedor Showcase y 2 perfiles gestores activos. La migración no toca productos existentes ni Stripe Connect.

También se corrigieron el fallback silencioso de `Mi Showcase`, el error `descriptionTranslation is not defined`, el uso de permisos canónicos en `Mis eventos` y el nuevo Centro de Evento con gestión de conexiones de clubes.

## Internacionalización

Los cambios R74 están cubiertos en EN, ES, FR, PT, IT, DE, TH y FIL. La auditoría estricta de runtime queda en **4687/4687 textos cubiertos**, 0 no resueltos. El gate de calidad inglesa queda en **2180/2180**, sin residuos fuertes de español. Los 8 idiomas continúan habilitados.

La versión jurídica visible de los documentos legales se conserva deliberadamente en build 20124 porque R74 no modifica el contenido legal ni debe generar una nueva aceptación jurídica por un simple cache-buster técnico.

## Supabase live

Se verificó que están aplicadas las cuatro migraciones R74: 260, 261, 262 y 263. No existían conexiones Events reales que transformar, por lo que el cambio de cardinalidad no reinterpretó datos productivos previos.

La tabla de compartición de participantes mantiene RLS activo y acceso directo cerrado. Las RPC privadas nuevas usan `SECURITY DEFINER` con `search_path` controlado y no son ejecutables por `anon`. La proyección pública de evento conserva acceso anónimo de forma intencional porque es la superficie pública del producto.

El advisor de rendimiento pasó de **219 a 215** FKs sin índice tras el hardening R74: las cuatro FKs nuevas quedaron cubiertas. El advisor global sigue mostrando deuda histórica ajena a R74, por lo que no se ha realizado una refactorización masiva fuera de alcance.

## QA y regresión

- R74: **47/47 PASS**
- R36: **49/49 PASS**
- R73: **7/7 PASS**
- R72 Release: **22/22 PASS**
- R72 Commercial: **18/18 PASS**
- R72 Identity/Spectator: **15/15 PASS**
- R72 Showcase Seller Center: **13/13 PASS**
- R72 Events Operations Center: **15/15 PASS**
- R72 Sidebar: **9/9 PASS**
- R72 Reputation + Catalog: **14/14 PASS**
- `npm test`: **PASS / exit 0**
- `npm run build`: **PASS / web = dist = Android / 450 archivos**
- Secret scan de alto riesgo: **PASS**

## Android

El contenido web embebido queda sincronizado con R74/build 20125 y el preflight verifica identidad, versionCode, assets y Firebase. El preflight termina 4/5 únicamente porque `android/keystore.properties` y la clave local de firma no se empaquetan. Esto es intencional: los secretos de firma deben permanecer fuera del ZIP fuente.

No se generó ni publicó una release firmada, no se hizo push a GitHub, no se desplegó frontend/Netlify y no se publicó nada en Google Play.

## Requisitos externos antes de una release firmada

1. Restaurar/configurar localmente `android/keystore.properties` y la clave de firma autorizada.
2. Ejecutar smoke autenticado en dispositivo real para las rutas privadas principales (Mi Showcase, Mis Eventos/Centro del Evento y flujo de conexión multiclub), especialmente FR/DE/TH. Las puertas automáticas de i18n y layout están en PASS; esta comprobación física depende de sesión/credenciales/dispositivo.

Estos puntos no requieren cambios de código R74 y quedan documentados como pasos de release, no como defectos de implementación.
