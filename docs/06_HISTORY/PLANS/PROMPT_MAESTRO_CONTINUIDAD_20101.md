# PROMPT MAESTRO DE CONTINUIDAD · KOMBAX RC13 build 20.101 R3

Trabaja exclusivamente desde `KOMBAX_RC13_build_20101_EVENT_VISUAL_EDITOR_HARDENING_WITH_LOCAL_SIGNING` como fuente de verdad.

## Estado actual
- Brand Heroes de Social, Events y Showcase reparados: protagonista visible, logo oficial KOMBAX, halo/motion accesible.
- Events mantiene Large Format, workspace isolation y álbum oficial 15 fotos + 5 vídeos HD/60 s.
- Evento real de validación: `Noche de Impacto · Barcelona`, UUID `d9886aba-0cc4-4269-a7c5-7708f63f31f4`.
- Slug técnico conservado: `noche-de-impacto-barcelona-demo`; no mostrar DEMO como etiqueta comercial.
- 6 Fight Cards y exactamente un Main Event: Hugo “Raven” Salvatierra vs Darío “Atlas” Moreno.
- Organiza Club Fénix Elite; avala Federación Nova Combat.
- Migración 178 aplicada en Supabase.
- Editor real: upload cartel/banner, reencuadre focal persistente, selección Main Event y foto de participante externo.
- Social puede mostrar las dos fotos de peleadores en referencia de combate.

## Reglas de continuidad
Antes de una nueva fase: plan específico con alcance, riesgos, migraciones/archivos, QA y criterios de cierre. Implementar sobre 20.101 R3, aplicar backend real cuando corresponda, ejecutar regresión completa y entregar ZIP autocontenido.

## Invariantes
- Identidad ≠ Plan ≠ Rol interno.
- KOMBAX Events público ≠ Mi Club > Eventos.
- Workspace/club activo nunca se mezcla con otra organización.
- Storage de álbum Events permanece privado y usa URLs firmadas.
- Los resultados solo se escriben por el write-path específico.
- Un evento solo puede tener un Main Event destacado.
- KOMBAX no procesa pagos/tickets; enlaza proveedores externos.
- Spectator permanece deshabilitado.
- No inventar logos KOMBAX.
- No crear rutas especiales para el evento ejemplo: debe usar los mismos lectores, Fight Cards y detalle que eventos reales.

## Android
- `applicationId=com.urbanwarriors.app`.
- versionCode 20101.
- JKS real incluido en `LOCAL_RELEASE_SIGNING/` por petición del propietario.
- no generar/reemplazar keystore.
- contraseñas y `android/keystore.properties` nunca dentro del ZIP.

## QA inmediato
Ejecutar los cuatro recorridos de `LOCAL_QA_CHECKLIST_20101_R3.md`. Si todos pasan, siguiente paso: deploy controlado Netlify por el propietario, validar deep-links y después generar APK signed/AAB desde exactamente esta fuente.
