# PLAN_IMPLEMENTACION_R39.md

## Objetivo
Cerrar la navegación interna de Mi Club para piloto sin alterar la navegación global KOMBAX ni las identidades/perfiles públicos.

## Reglas inmutables
1. Fuera de Mi Club se preservan Mi perfil, KOMBAX Social, KOMBAX Eventos, KOMBAX Showcase y el acceso Mi Club.
2. La intervención R39 afecta exclusivamente al acordeón/panel interno de Mi Club y a banners contextuales dentro de páginas del club.
3. KOMBAX Assist y KOMBAX Migrations permanecen separados funcionalmente.
4. Assist mantiene soporte estándar email-first y chat guiado activado solo cuando procede.
5. Migrations mantiene acceso directo, chat + archivos, análisis por lotes, vista previa y confirmación obligatoria.
6. No se toca la privacidad de R35-R38, Fighter Discovery, Brand Business Hub ni pesos.
7. No Netlify, GitHub ni firma Android hasta QA local completo.

## Navegación Mi Club
Orden de secciones:
- Inicio
- Gestión del club
- Eventos del club
- Economía
- Comunicaciones
- Federaciones y licencias
- Administración
- Equipo y permisos
- Asistencia
- Configuración del club
- Mi cuenta

### Asistencia
- Asistencia virtual
- KOMBAX Migrations
- Manual interactivo

### Federaciones y licencias
Mis licencias deja de mostrarse como entrada independiente del acordeón. Se accede dentro de Federaciones y licencias como `Mis licencias personales`. La ruta histórica se conserva.

## Visibilidad contextual de Migrations
Mostrar CTA contextual dentro de Mi Club en:
- Inicio
- Alumnos
- Finanzas
- Perfil del Club (ya existente)
- Otros hubs internos donde ya estaba anunciado

Los CTA llevan directamente a KOMBAX Migrations, nunca a Assist/email.

## QA obligatorio
- navegación global idéntica a R38;
- acordeón Mi Club ordenado por secciones;
- no entrada independiente Mis licencias;
- acceso a licencias personales desde Federaciones y licencias;
- Assist visible como Asistencia virtual;
- Migrations directo y visible;
- banners Inicio/Alumnos/Finanzas funcionales;
- regresión R38-R32;
- npm test completo;
- build web=dist=Android;
- Android preflight;
- ZIP limpio, manifiesto SHA-256, sin secretos/JKS/symlinks.
