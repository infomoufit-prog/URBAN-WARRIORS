# KOMBAX — Informe de desarrollo fase 4

Fecha: 14/10/2026. Base de trabajo: **KOMBAX_20178_R120_FIX22_FASE3_FINANZAS_FULL_CUMULATIVE.zip**, hash SHA-256 confirmado `39e9c91d489cc17da732213b6c6a23c921bc00e52556e3dfd9b2476aee9daa84`.

## Objetivo

Sustituir la navegación plana o excesivamente concentrada de las identidades directas por una navegación premium contextual, consistente con Mi Club/Mi Marca, sin activar funcionalidades nuevas ni elevar privilegios.

## Implementación real

1. Nuevo componente reutilizable `web/js/ui/managed-profile-navigation.js`, que expone modelo y generador de HTML independientes del DOM, con agrupación por identidad.
2. `managed-profile-hub.js` integra ese generador para Competidor, Federación, Profesional, Marca, Media y Espectador. Mi Club conserva la navegación ya implementada para clubes.
3. Secciones agrupadas y visualmente diferenciadas: deporte/oportunidades, gestión federativa/administración, actividad profesional/licencias, negocio/gestión de marca, creador y espectador. Solo aparecen módulos conocidos en el `workspace` y herramientas globales explícitas.
4. Se respetan capacidades existentes: faltas de acceso aparecen como vista previa. El handler revisa `moduleAllowed()` antes de iniciar rutas, especialmente Social/Showcase/Events. Los permisos definitivos siguen en Supabase. Finanzas profesionales se condicionan a `professional.finance.manage` o `professional.finance.reports`.
5. El equipo y los permisos solo se muestran en las cinco identidades que ya tenían el botón de gestión en la cabecera. Se conserva acceso a recursos, privacidad, perfil público, Social, Events, Showcase, vuelta a Inicio y selección de identidad.
6. CSS premium nuevo en `kombax-guides-nav-r94.css`: secciones, iconografía, marcación por identidad, tablet/móvil (drawer), foco accesible y movimiento reducido. Cabecera móvil contextual.
7. Copias web/dist/Android sincronizadas (verificación de hashes). No se compila APK/AAB en esta fase.

## Estado de despliegue

- GitHub: **sin push**.
- Netlify: **sin deploy**.
- Supabase: **sin migraciones ni operaciones de escritura** durante esta fase. No son necesarias porque el cambio es frontend y reutiliza el backend de perfiles.
- Meta/Instagram: sin modificaciones; sigue siendo una fase posterior.
- Versionado `package.json`/`web/config.js`: R118/build 20178 (heredado). Nombre del acumulativo base R120 FIX22. Conciliar versiones y caché al preparar el despliegue autorizado; no se ha cambiado para evitar regresiones.

## Límites reconocidos

No se ha realizado E2E con usuarios de prueba autenticados ni captura visual real de navegador, PWA, Android o tablet. Los módulos existentes del backend podrían requerir ajustes específicos de permisos o capacidades detectables solo en una cuenta de prueba. No se han completado funciones nuevas de Mi Federación; esa fase continúa.
