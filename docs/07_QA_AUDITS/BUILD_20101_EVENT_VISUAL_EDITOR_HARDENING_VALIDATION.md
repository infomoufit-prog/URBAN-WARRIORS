# KOMBAX RC13 build 20.101 R3 · Event Visual Editor Hardening · Validación

Fecha de cierre: 2026-08-27

## Objetivo
Cerrar los defectos visuales detectados durante la validación local de 20.101 sin abrir una nueva fase funcional: Main Event vacío, organización poco visible en portada, encuadre no editable de cartel/banner, fotografías Hero que podían quedar ocultas y referencias de combate demasiado textuales en KOMBAX Social.

## Implementado

### KOMBAX Events
- Main Event conectado a la Fight Card real con prioridad: `main_event_fight_id` → `destacado` → primer combate no cancelado.
- Presentación `mainEventBattle()` con fotos grandes de ambos peleadores, VS central, clubs, disciplina/categoría/peso y horario.
- Invariante backend: solo un combate puede permanecer `destacado=true` por evento al guardar un nuevo Main Event.
- Organizador y entidad avaladora visibles en la zona alta de la portada/detalle además de la sección completa de organización.
- Presentación del evento ejemplo limpia: `Noche de Impacto · Barcelona`, `Club Fénix Elite`, `Federación Nova Combat`; no depende de la palabra DEMO como etiqueta pública.

### Editor visual de eventos
- Subida de cartel y banner desde archivo JPG/PNG/WEBP.
- Reencuadre por arrastre/táctil del cartel y del banner.
- Persistencia de `cartel_focus_x`, `cartel_focus_y`, `banner_focus_x`, `banner_focus_y` en Supabase.
- Vista previa y restablecimiento de encuadre.
- El mismo editor está disponible para eventos reales gestionables; no es una herramienta exclusiva del ejemplo.
- Participantes externos pueden recibir fotografía pública específica del evento desde archivo.

### Brand Heroes
- Se elimina el stacking negativo que podía ocultar las fotografías de Social, Events y Showcase.
- Fotografía en capa visible + overlays + atmósfera + copy con orden de capas explícito.
- Nube/halo animado detrás del texto, conservando `prefers-reduced-motion`.
- Se mantiene exclusivamente el logo oficial KOMBAX ya existente.

### KOMBAX Social
- Las referencias de un combate/evento pueden mostrar los dos peleadores con composición VS rojo/cian cuando existen `a_foto_url` y `b_foto_url`.
- El enlace sigue apuntando al Event/Fight de origen; Social no duplica el dominio del evento.

## Backend real
Migración 178 aplicada al Supabase principal:
`kombax_events_visual_editor_hardening_20101`

Nuevos contratos:
- `app_kombax_eventos_publicos_v178`
- `app_kombax_evento_publico_detalle_v178`
- `app_kombax_evento_publico_slug_v178`
- `app_kombax_eventos_mutate_v178`
- `app_kombax_demo_event_seed_v178`

ACL verificada:
- lectores públicos: `anon=true`, `authenticated=true`;
- mutation v178: `anon=false`, `authenticated=true`;
- seed v178: `anon=false`, `authenticated=true`.

Evento de validación live:
- UUID `d9886aba-0cc4-4269-a7c5-7708f63f31f4`;
- slug técnico `noche-de-impacto-barcelona-demo`;
- nombre público `Noche de Impacto · Barcelona`;
- 6 combates;
- exactamente 1 Main Event;
- Main Event: Hugo “Raven” Salvatierra vs Darío “Atlas” Moreno;
- organización: Club Fénix Elite;
- aval: Federación Nova Combat;
- focales públicos presentes en el lector v178.

## QA
- `node --check` de módulos modificados: PASS.
- `npm test`: PASS completo hasta 20.101 R3.
- `npm run build`: PASS.
- resultado de build: `132 archivos · web = dist = Android`.
- `npm run release:legal-gate`: PASS.
- Android preflight: 4/5; único pendiente `android/keystore.properties`, que contiene credenciales y se restaura localmente.
- JKS existente conservado; no se generó ni sustituyó ninguna clave.

## Advisors Supabase
Security y Performance Advisors ejecutados tras migración 178. No se detectó una incidencia nueva específica de los cuatro campos focales ni del contrato v178. Permanecen avisos sistémicos/preexistentes del proyecto (políticas RLS/InitPlan, FKs sin índice, índices no usados y un índice duplicado en `informes_financieros`). No se modificaron dominios no relacionados para silenciar esos avisos durante este hardening de Events.

## Criterio de cierre
20.101 R3 queda apta para validación local real cuando se confirmen manualmente los cuatro recorridos de `LOCAL_QA_CHECKLIST_20101_R3.md`. Netlify y Google Play no se despliegan desde esta intervención.
