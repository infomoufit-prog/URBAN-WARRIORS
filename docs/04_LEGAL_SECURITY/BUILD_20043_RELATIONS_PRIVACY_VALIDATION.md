# KOMBAX RC13 · Build 20043
## Validación de privacidad de Relaciones

Fecha de validación: 2026-08-18
Base: RC13 build 20042
Build resultante: 20043

## 1. Regla de producto

En esta fase de KOMBAX Social:

- las Relaciones son privadas;
- no existe listado público de Relaciones;
- no existe contador público de Relaciones;
- no se utiliza el número de Relaciones como métrica pública de popularidad;
- `Mis relaciones` solo está disponible para la propia identidad o una cuenta autorizada para actuar como ella;
- la afiliación verificada al Club es un concepto distinto y se conserva en el perfil público cuando corresponda.

## 2. Frontend

- El perfil público deja de renderizar `Relaciones verificadas`.
- Se elimina el renderer público de relaciones.
- La pantalla propia se denomina `Mis relaciones` y comunica explícitamente su carácter privado.
- El repositorio frontend usa `app_kombax_perfil_publico_v068` para perfil público y `app_kombax_relaciones_v068` para la red privada.

## 3. Backend real

Migración aplicada:

- `068_kombax_relations_privacy_20043.sql`

Contratos nuevos:

- `app_kombax_relaciones_v068(uuid)` exige `auth.uid()` y `app_kombax_social_puede_actuar_v051(p_social_id)`.
- Si una cuenta intenta consultar la red de una identidad que no controla, devuelve `KOMBAX_RELATIONS_PRIVATE`.
- `app_kombax_perfil_publico_v068(uuid)` conserva el contrato funcional del perfil público pero elimina la clave `relations`.
- Los RPC históricos de perfil/relaciones que podían evitar la nueva privacidad dejan de ser ejecutables por `authenticated`.

## 4. Verificación live Supabase

Comprobaciones realizadas contra el proyecto real:

- perfil público de Bryan Rivera mediante v068: `relations` ausente;
- afiliación del perfil: conservada;
- Gestor Urban Warriors → relaciones privadas de Bryan: rechazado con `KOMBAX_RELATIONS_PRIVATE`;
- Bryan autenticado → sus propias Relaciones: consulta autorizada;
- Gestor → Relaciones de la identidad Social de Urban Warriors que puede gestionar: consulta autorizada;
- RPC 068: `anon = false`;
- RPC históricos cerrados a `authenticated` en la superficie afectada.

## 5. Regresión

Nueva prueba:

- `scripts/test-kombax-20043-relations-privacy.mjs`

Cubre:

- build/cache/versionCode 20043;
- ausencia de Relaciones en perfil público;
- ausencia de contador público;
- uso exclusivo de RPC 068 en frontend;
- guard de propiedad/gestión de identidad;
- revocación de RPC históricos de bypass;
- `anon` cerrado;
- conservación de afiliación pública.

Resultado previo a empaquetado:

- `KOMBAX BUILD 20043 RELATIONS PRIVACY: PASS`
- suite histórica RC4 → 20043: PASS.

## 6. Seguridad

Se ejecutó Supabase Security Advisor después de la migración.

- Los nuevos RPC 068 no son ejecutables por `anon`.
- El advisor continúa mostrando deuda histórica del proyecto (funciones `SECURITY DEFINER` y tablas RLS sin políticas directas, entre otros avisos); no se considera resuelta ni se mezcla con esta intervención.
- Los RPC 068 son intencionadamente clientes autenticados y aplican comprobaciones de identidad en el cuerpo de la función.

## 7. Rollback

El rollback 068 está deliberadamente bloqueado porque restaurar los grants históricos reabriría la exposición de Relaciones. Cualquier reversión futura debe preservar la privacidad introducida en 20043.

## 8. Certificación final de paquete

Tras corregir y volver a ejecutar el propio verificador SQL 068:

- verificador SQL 068: PASS;
- suite completa RC4 → 20043: PASS;
- `node scripts/build.mjs`: `OK build 62 archivos · web = dist = Android`;
- comparación SHA-256 independiente web ↔ dist: 0 faltantes, 0 extras, 0 diferencias;
- comparación SHA-256 independiente web ↔ Android: 0 faltantes, 0 extras, 0 diferencias;
- smoke HTTP en `127.0.0.1:4177`: build/cache 20043, perfil público sin Relaciones, UI `Mis relaciones` y RPC v068: PASS;
- Android preflight: 4/5; únicamente firma JKS local pendiente;
- archivos de firma privada/JKS/keystore/p12/pem/key: 0;
- `node_modules`: 0.

No se certifica APK/AAB firmada en este entorno.
