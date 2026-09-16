# KOMBAX 20.101 · R34 — Auditoría y verificación de continuidad

Fecha de cierre: 2026-09-03
Base: R33.1 + mejoras R34 (KOMBAX Assist, migración asistida y preparación/peso)
Estado: **BASE DE CONTINUIDAD VERIFICADA**

## Evidencia ejecutada

- Test específico R34: **PASS 33/33**.
- Regresión completa `npm test`: **exit 0** y **0 tokens FAIL**.
- R32: **PASS 36/36**.
- R33: **PASS 52/52**.
- R33.1: **PASS 27/27**.
- Build estático: **PASS**.
- Paridad independiente: **web 186 = dist 186 = Android 186**, **0 diferencias SHA-256**.
- Android preflight: **4/5**. Único pendiente: configuración local privada `android/keystore.properties`; no se empaqueta por seguridad.

## Verificación backend R34

Verificado contra el backend principal:

- 3 tablas de preparación/peso presentes con RLS activo.
- tabla privada de archivos de migración presente.
- 5 RPC principales de preparación/peso presentes.
- 8 RPC R34 comprobadas sin permiso EXECUTE para `anon`.
- 2 buckets privados presentes:
  - `competition-weight-evidence` — privado, límite 5 MB.
  - `kombax-migration-staging` — privado, límite 10 MB.
- 6 políticas Storage específicas R34 presentes.
- funciones R34 SECURITY DEFINER usan `search_path` vacío/fijado, evitando resolución implícita de objetos.

## Seguridad del paquete

- No contiene `.env`.
- No contiene `keystore.properties`.
- No contiene `.jks` / `.keystore` privados.
- No se han detectado symlinks en el árbol de continuidad.
- La ausencia de configuración privada de firma es intencionada y no invalida este ZIP como base de desarrollo.

## Criterio de continuidad

Este árbol es la base autorizada para los siguientes cambios. Las nuevas modificaciones deben aplicarse sobre esta R34 y conservar:

1. la matriz funcional y UX de R32/R33/R33.1;
2. KOMBAX Assist y migración asistida R34;
3. preparación/peso privado y su enlace con Events;
4. RLS, RPCs estrechas, buckets privados y aislamiento por identidad/club;
5. paridad web/dist/Android antes de cada nuevo cierre.

## Evidencia incluida

Consultar `qa/r34/` para logs de test, build, preflight y paridad.
