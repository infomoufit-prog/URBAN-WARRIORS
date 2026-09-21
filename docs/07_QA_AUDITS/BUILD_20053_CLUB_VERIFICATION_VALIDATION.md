# KOMBAX 20.053 · CLUB VERIFICATION · VALIDATION

Fecha: 2026-08-19
Base: KOMBAX 20.052 · CLUB ONBOARDING
Estado: BUILD DE VALIDACIÓN · NO CONGELADA

## Objetivo implementado
Completar la verificación administrativa de altas Club sin convertirla en un proceso burocrático excesivo.

## Alta Club · datos mínimos
La solicitud Club recoge y separa datos públicos y privados:
- Nombre comercial del Club.
- Tipo de club/entidad (informativo; no condiciona el alta).
- Nombre legal.
- CIF/identificación fiscal opcional en verificación inicial.
- Email oficial.
- Teléfono oficial obligatorio.
- Responsable autorizado y cargo/relación.
- Población/zona pública.
- Dirección administrativa o zona privada opcional.
- Disciplinas.
- Web/redes públicas si existen.
- Evidencia contrastable.
- Documento acreditativo privado tipificado.

No se exige que el documento sea documentación empresarial compleja: se admiten licencia/acreditación federativa, registro de club/asociación, documento fiscal/legal, documento del gimnasio/centro u otro documento acreditativo razonable.

## Administración KOMBAX
La revisión de una solicitud Club ya no presenta JSON técnico como vista principal. Muestra:
- Identidad del Club.
- Responsable.
- Contacto y ubicación.
- Actividad deportiva y presencia pública.
- Evidencia aportada.
- Documentos privados con acción "Ver documento" mediante URL firmada de 10 minutos.
- Checklist previo a aprobación.

Antes de resolver como Verificado, el Administrador KOMBAX debe confirmar:
1. El club existe y coincide con la identidad solicitada.
2. La persona puede representar al club.
3. Contacto/presencia oficial contrastados.
4. Documento acreditativo revisado.

Si faltan datos mínimos, la opción Verificar queda fuera del selector y Supabase también bloquea el alta.

## Backend / Supabase
Migración aplicada:
- `098_kombax_club_verification_20053.sql`
- Estado remoto: `kombax_club_verification_20053` aplicada.

Nuevo helper interno:
- `app_kombax_club_payload_validate_v098(text,jsonb,jsonb)`
- EXECUTE anon: FALSE
- EXECUTE authenticated: FALSE

La validación se ejecuta tanto en solicitudes como en el núcleo de alta directa del Administrador KOMBAX.
Prueba positiva: PASS.
Prueba negativa sin teléfono: bloqueada con `KOMBAX_CLUB_FIELDS_REQUIRED:telefono`.
Clubs existentes durante la comprobación: 1. No se creó ningún club QA.

## Tests
- `node scripts/test-kombax-20053-club-verification.mjs` → PASS
- `npm test` → PASS completo
- `npm run build` → PASS
- Árboles independientes: web 64 / dist 64 / Android 64
- Diferencias web=dist=Android: 0
- Tree SHA-256 web: `10f21056807f78b04aabd9ec2af975e0fac4e379681fb9d7ef569104cf59d8f5`

## Android preflight
- Identidad Android: PASS
- versionCode 20053: PASS
- assets/www: PASS
- Firebase: PASS
- Firma local JKS/keystore.properties: PENDIENTE INTENCIONADO (no se empaqueta la clave privada)
Resultado: 4/5.

## Pendiente manual antes de congelar
E2E real de interfaz con dos cuentas:
1. Solicitar `Soy un Club`.
2. Completar datos y subir acreditación.
3. Administrador KOMBAX abre la solicitud y el documento.
4. Solicitar información si procede.
5. Completar los cuatro checks y Verificar.
6. Confirmar tenant creado, Dirección/Gestor asignada y perfil público/Social del nuevo Club.

No se ha realizado deploy Netlify, publicación GitHub, APK/AAB final ni Google Play en esta build.
