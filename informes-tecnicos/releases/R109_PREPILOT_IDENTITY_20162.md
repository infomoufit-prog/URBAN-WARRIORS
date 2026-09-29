# Release R109 · build 20162

## Objetivo

Cerrar la arquitectura de identidad/perfiles antes del piloto sin rediseñar R100-R108.

## Cambios funcionales

1. **Competidor:** selección inicial conserva la intención, pero el registro Auth nace como cuenta personal; la condición Competidor se fija al entrar en el flujo existente de perfil/solicitud y requiere verificación.
2. **Social:** Competidor verificado publica desde 16+ sin membresía obligatoria; contacto sigue 18+. Profesional verificado publica/contacta desde 18+ usando fecha privada; Miembro conserva membresía.
3. **Media:** el submit que antes quedaba fuera del validador canónico ahora funciona con evidencia proporcional; documento adicional opcional.
4. **UX:** mensajes específicos de verificación/edad sustituyen errores genéricos en los casos modificados.
5. **Versionado:** Web/PWA/Android/health pasan a build 20162 / R109 y se conservan marcadores R108 para regresión histórica.
6. **i18n:** nuevos textos con cobertura EN/FR/PT/IT/DE/TH/FIL.

## Backend

Migración aplicada en Supabase activo: `20260929062726_kombax_prepilot_identity_permissions_r109` (archivo local `296_kombax_prepilot_identity_permissions_r109.sql`). Tras aplicar se verificó mediante lectura de definiciones que todos los cambios esperados están presentes.

## No cambiado

No se rediseñan Feed, Mi Club, Multiclub, Events, Showcase, Commerce, Ticketing, QR, Stripe, Finanzas, Assist, Migrations, Owner, PWA/Android architecture ni algoritmos de Discover.
