# CHANGELOG · KOMBAX 20.101 R21

## Global Media Framing
- Nuevo editor transversal no destructivo de encuadre.
- Modos automático / mostrar completo / rellenar marco.
- Foco X/Y, zoom, orientación y reset.
- Persistencia por contexto sin alterar el original.

## Events
- Ajuste individual de fotos de participantes/peleadores y miniaturas de álbum.
- Fight Cards respetan la presentación del peleador.
- Hardening responsive/overflow móvil.
- Seminario/masterclass/formación reciben flujo y ficha formativa propios sin Fight Card/Main Event forzados.

## Showcase y Materiales
- Productos priorizan visibilidad del objeto completo.
- Ajuste persistente de imagen principal.
- Ajuste independiente de cada imagen secundaria de galería.
- Materiales usan el mismo patrón común.

## Social / Perfil / Comunidad
- Feed Social con encuadre editable en publicaciones propias.
- Avatar privado, foto deportiva, media de perfiles y álbumes ajustables.
- Logo/portada del club y del perfil público ajustables.
- Comunidad y comunicaciones con ajuste persistente.

## Backend
- Migraciones 187 + 188 aplicadas al Supabase principal.
- RPC v187/v188 con permisos y guards por dominio.

## QA
- R21 específico 30/30 PASS.
- Regresión completa PASS.
- Build PASS; web=dist=Android, 171 archivos.
- Android preflight 4/5; firma local pendiente.
