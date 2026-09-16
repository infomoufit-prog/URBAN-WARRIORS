# KOMBAX 20.101 R21 · QA VALIDATION

## Alcance
R21 consolida un sistema transversal de presentación/encuadre multimedia para KOMBAX Events, Showcase, Materiales, KOMBAX Social, Mi perfil/Mi contenido, Mi Club/Comunidad, perfiles deportivos, perfil público del club y branding del club.

## Garantía técnica del editor de encuadre
Se auditó el código de todos los puntos de subida/edición de imágenes de presentación. El criterio de cierre es: si una imagen puede mostrarse recortada en una card, avatar, cabecera, Fight Card, feed, producto o miniatura de álbum, debe existir una acción visible de ajuste para el propietario/gestor autorizado.

Cobertura validada:
- Events: participantes/peleadores, Fight Cards, álbum y miniaturas; cartel/banner conservan el sistema de foco existente.
- Events formativos: seminario/masterclass/formación usan presentación propia y no fuerzan Main Event/Fight Card.
- Showcase: imagen principal y cada slot de galería secundaria.
- Materiales: imagen de catálogo/producto.
- KOMBAX Social: imágenes de publicaciones propias.
- Mi perfil privado: avatar.
- Perfil deportivo: foto.
- Perfiles públicos/directos: media/álbum y encuadres persistentes.
- Club: logo y portada de branding.
- Perfil público del club: logo, portada y álbum.
- Comunidad: imagen de publicación.
- Comunicaciones: imagen de publicación/comunicación.

El editor conserva el archivo original y persiste solo parámetros de presentación: fit, focus_x, focus_y, zoom y orientación. Permite mostrar completo, rellenar marco, mover foco, zoom y restablecer.

### Exclusión deliberada
Justificantes de pago, documentos de expediente y documentación de verificación no se consideran multimedia de presentación: son adjuntos privados que se abren/descargan como documentos y no usan recorte editorial.

## Backend real
Proyecto principal: poggsobhtutbuagjiydc

Migraciones aplicadas:
- 187_kombax_global_media_framing_20101_r21.sql
- 188_kombax_global_media_framing_completion_20101_r21.sql

Se verificó la existencia de las columnas JSONB de presentación y los RPC v187/v188.
- setter v188: anon NO EXECUTE; authenticated EXECUTE.
- lector v188: expone solo metadatos visuales de recursos visibles/autorizados según scope.
- normalización limita fit/foco/zoom/orientación a valores aceptados.

## Tests
- Test específico R21: PASS 30/30.
- Regresión completa `npm test`: PASS hasta R21, incluyendo R19 y R20.
- Tests históricos de cache busting fueron future-proofed para aceptar revisiones posteriores manteniendo el requisito mínimo original.

## Build y paridad
- `npm run build`: PASS.
- Builder: `OK build 171 archivos · web = dist = Android`.
- Comparación SHA-256 por ruta relativa: web=dist=True; web=android=True; 171 archivos en cada árbol.

## Android
`npm run android:preflight`:
- package com.urbanwarriors.app: PASS
- versionCode 20101: PASS
- assets/www: PASS
- Firebase: PASS
- firma local: PENDIENTE por ausencia intencional de `android/keystore.properties`.

JKS heredado presente en `LOCAL_RELEASE_SIGNING/kombax-release.jks`. No contiene contraseñas documentadas en el ZIP.
No se generó ni se declara APK Signed R21.

## Seed preservation
Backend verificado tras R21:
- R19 Urban Warriors Showcase demo: 3 productos / 3 slugs únicos.
- R20 seminario Adrián Serrano: 1 evento, perteneciente a Urban Warriors.
- R20 Comunidad: 2 publicaciones internas.
- seminario en club ajeno: 0.
- publicaciones R20 en club ajeno: 0.

## Advisors Supabase
Security Advisor y Performance Advisor ejecutados después de R21.
El proyecto NO se declara security-clean/performance-clean.
Persisten warnings globales/históricos de RLS/SECURITY DEFINER, leaked-password protection, FKs sin índice, índices sin uso y un índice financiero duplicado.
R21 añade funciones SECURITY DEFINER de media con guards explícitos; los readers públicos son intencionales para metadatos de presentación ya públicos y los setters requieren authenticated + autorización por dominio. R21 no añade FKs ni índices nuevos.

## Validación visual
PENDIENTE aceptación física en Chrome local, móvil/tablet y APK Signed instalada. La cobertura técnica y de persistencia está validada; no se afirma perfección visual en todos los dispositivos hasta completar esa aceptación.

## Resultado
IMPLEMENTADO: sistema transversal R21 y cierre de huecos multimedia.
VALIDADO: tests 30/30, regresión completa, build, paridad, backend, permisos, seed preservation.
PENDIENTE: validación visual real y APK Signed por el usuario.
NO MODIFICADO: Netlify, GitHub remoto, versionCode, Finanzas/Auth fuera de dependencias existentes.
