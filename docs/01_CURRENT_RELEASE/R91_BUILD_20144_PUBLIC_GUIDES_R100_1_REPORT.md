# KOMBAX R91 · build 20144 · Guías públicas R100.1

Fecha de cierre: 23/09/2026

## Alcance

R91 parte exclusivamente de la base acumulativa R90 build 20143 y sustituye la biblioteca pública de KOMBAX Guías por la colección pública R100.1 saneada editorialmente. No activa ni importa la capa formativa de Claude R100.

## Implementado

- 38 guías públicas R100.1 activas.
- 19 guías generales/profesionales y 19 fichas territoriales.
- PDFs regenerados desde fuentes Markdown editables con un maquetador propio de KOMBAX, sin rutas absolutas del entorno Claude.
- Apertura y descarga conservadas en web/PWA y mediante puente nativo PDF en Android.
- El antiguo dossier territorial maestro se mantiene solo como evidencia histórica y queda oculto en la UI pública.
- Las 15 entradas base legacy necesarias para regresión histórica permanecen inactivas y no se muestran al usuario.
- Correcciones editoriales/normativas aplicadas en fuentes públicas sensibles antes de regenerar los PDFs.

## Manual KOMBAX de Gestión de Clubes

Se ha transformado el dossier general en un producto editorial autónomo:

- Título: Manual KOMBAX de Gestión de Clubes.
- Orientado a dirección y gestión de clubes.
- Sin actividades, autoevaluaciones, solucionarios, banco de preguntas ni estructura de curso.
- Incluido en KOMBAX Premium.
- Precio individual de referencia: 6 EUR.
- Estado comercial: preparado, no activado.

El PDF completo y su fuente se conservan en `artifacts/manuals/` para el propietario, pero:

- no se copian a `web/`;
- no se copian a `dist/`;
- no se copian al paquete Android;
- la carpeta está ignorada por Git para evitar publicación accidental.

La UI muestra la ficha comercial del manual, pero no expone una URL al PDF ni simula un checkout. El acceso deberá conectarse más adelante a una autorización Premium/compra individual real.

## Formación expresamente fuera de alcance

R91 NO implementa:

- dossiers de alumnado;
- dossiers o cuadernos de formador;
- actividades;
- autoevaluaciones;
- solucionarios;
- banco de preguntas;
- Aiken/GIFT/JSONL/LMS;
- nuevas matrículas, cursos o credenciales Training.

La fundación privada Training preexistente de releases anteriores no se amplía en R91.

## QA

- Gate R91: 34/34 PASS.
- Gate histórico R90: 35/35 PASS.
- `npm test`: PASS.
- `npm run release:legal-gate`: PASS.
- `npm run release:build`: PASS.
- Build: 594 archivos con paridad `web = dist = Android`.
- 38/38 PDFs públicos presentes en web, dist y Android.
- Manual completo: 0 copias en web/dist/Android.
- Validación PDF: 39/39 válidos (38 guías + manual), 282 páginas, texto extraíble.
- i18n: claves nuevas incorporadas a ES/EN/FR/PT/IT/DE/TH/FIL y gates acumulativos en PASS.
- Android preflight: 4/5; pendiente únicamente firma local.

## Supabase

R91 no necesita migración de base de datos. Conserva todas las migraciones acumulativas hasta R89. El endpoint `health` se sincroniza con build 20144.

## Release identity

- Release: R91
- Build: 20144
- Web/PWA: `2.0.0-rc.13-r91-public-guides-r100-1`
- Android versionCode: 20144
- Android versionName: `2.0.0-rc.13-r91-public-guides-r100-1`
- iOS CURRENT_PROJECT_VERSION: 20144

R91 build 20144 pasa a ser la única base acumulativa válida para el siguiente cambio.
