# Validación build 20045 · Perfiles públicos + audiencias Social

## Objetivo

Certificar el contrato aprobado para KOMBAX Social: todos los perfiles participantes son públicos dentro de la red, mientras una publicación concreta puede restringir su audiencia sin convertir el perfil en privado.

## Contrato funcional certificado

- Perfiles Social públicos: Miembro, Competidor, Club, Marca y Federación.
- No existe opción de «perfil privado» para el usuario; `visible` queda reservado a estado/moderación.
- Nombre, avatar o logo del autor abren su perfil público desde feed, comentarios, directorio y Guardados.
- Publicación nueva: `Público · Todo KOMBAX` por defecto.
- Audiencias opcionales cuando corresponden al actor y sus afiliaciones:
  - `Solo mi club`.
  - `Solo afiliados a mi federación`.
  - Federación: `Solo clubes afiliados` para responsables autorizados de clubes afiliados.
- Marca permanece pública en esta fase.
- No existe audiencia «solo Relaciones/amigos».
- Una publicación restringida no se comparte externamente desde la UI.
- Relaciones siguen privadas y no aparecen en el perfil público.
- Datos administrativos, financieros, de verificación, documentación y contacto privado quedan fuera del perfil público.

## Multimedia / banner

- Banner/portada del perfil: excepción visual con `object-fit: cover`; llena el área y puede recortarse proporcionalmente.
- Publicaciones, álbum y contenido multimedia conservan el tratamiento de contenido completo previsto para cada módulo; el cambio de `cover` no se aplica globalmente.

## Supabase real

Proyecto validado: `poggsobhtutbuagjiydc`.

Migración aplicada: `083_kombax_public_profiles_post_audiences_20045.sql` / `kombax_public_profiles_post_audiences_20045`.

Verificaciones reales posteriores a la migración:

- columnas de audiencia y constraints presentes;
- RPC 083 de audiencias/feed/perfil/comentarios/guardados/mutación presentes;
- RPC antiguas críticas 067/072/053/044 cerradas a `authenticated` donde podían saltarse la audiencia;
- acceso directo a `kombax_relaciones` cerrado para `anon` y `authenticated`;
- `app_kombax_perfil_publico_v083` elimina `relations` del resultado;
- las 4 publicaciones existentes quedaron migradas a `audiencia='publica'`;
- los 3 perfiles Social existentes (1 Club + 2 Miembros) están activos y visibles;
- smoke transaccional con `ROLLBACK`: publicación sin audiencia => `publica`; audiencia `club` sin target => rechazada por CHECK constraint.

## QA y build

- `npm test`: PASS, incluida la regresión histórica y `test-kombax-20045-public-profiles-audiences.mjs`.
- `npm run build`: PASS.
- Builder: `62 archivos · web = dist = Android`.
- Segunda comparación SHA-256 independiente: 0 diferencias.
- Android: applicationId estable, target/config Firebase presentes, versionCode `20045`.
- Android preflight: 4/5; único pendiente: firma release local JKS, que deliberadamente no se incluye en el paquete.
- Escaneo de secretos: sin JKS/keystore, `key.properties`, `.env`, PEM/P12/PFX ni credenciales privadas incluidas.

## Seguridad pendiente de producción

Supabase Advisor mantiene avisos heredados del proyecto sobre RLS deny-by-default sin policy directa y múltiples funciones `SECURITY DEFINER`, además de Leaked Password Protection desactivada. Las RPC 083 públicas son entradas autenticadas intencionales y no se han abierto a `anon`.

Referencias de remediación de Supabase:
- RLS sin policy directa: https://supabase.com/docs/guides/database/database-linter?lint=0008_rls_enabled_no_policy
- SECURITY DEFINER ejecutable por anon: https://supabase.com/docs/guides/database/database-linter?lint=0028_anon_security_definer_function_executable
- SECURITY DEFINER ejecutable por authenticated: https://supabase.com/docs/guides/database/database-linter?lint=0029_authenticated_security_definer_function_executable
- Protección de contraseñas filtradas: https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection

Estos avisos se tratarán como hardening de producción y no justifican debilitar el contrato RPC/RLS validado en este build.
