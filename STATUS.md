# STATUS · KOMBAX 20.063 · SOCIAL MESSAGING FINAL QA

Candidata actual de validación: **build 20063**.

## Implementado

- Chat Social simplificado: X conserva; `Cerrar chat` eliminado; eliminación explícita.
- Comentarios inline.
- `Mi red` como terminología pública y red privada.
- Mensajes KOMBAX con badge/acceso separado.
- Bandeja Social/Showcase con diferenciación visual.
- Contexto de producto preparado para conversaciones Showcase.
- CTA de contacto desde Showcase.
- Contact Gate frontend 10–500.
- Fallback de contratos para mantener Social compatible mientras backend 107 no esté activo.

## Evidencia

- `npm test`: PASS.
- `npm run build`: PASS.
- web/dist/Android: 66/66/66, 0 diferencias SHA-256.
- Android versionCode: 20063.
- Android preflight: 4/5; solo firma local pendiente.
- Secret files de firma dentro del paquete: 0.

## Producción

- **Netlify 20063 no desplegado**; mantener 20062 durante QA móvil.
- Migración Supabase 107: preparada y preflight live correcto, **no aplicada live todavía**.

## Release

**CANDIDATA DE VALIDACIÓN MÓVIL · NO FREEZE.**

Siguiente paso operativo: generar APK signed 20063 localmente con el JKS existente, validar Social; activar 107 de forma controlada para validar Showcase por producto; revalidar 20062 web; solo entonces congelar/desplegar 20063 y generar AAB para Google Play.

## RC13 build 20065 · Role Invitations + Team Filter QA
- Team listado con roles operativos únicamente; Alumno/Familia excluidos.
- Invitaciones de alumnos/familias compartibles.
- Invitaciones de equipo con rol solicitado y aprobación posterior.
- Supabase 109 aplicado/verificado; 108 sigue pendiente.
- npm test/build PASS; web=dist=Android (68 archivos).
- APK signed y Netlify pendientes de validación móvil.
