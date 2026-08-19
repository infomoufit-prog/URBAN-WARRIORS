# KOMBAX RC13 · Build 20047 · Member Profile Enrichment

## Objetivo
Corregir la apertura de perfiles públicos Miembro y consolidar una ficha Social enriquecida sin convertir al Miembro en Competidor verificado.

## Hallazgo raíz
`app_kombax_perfil_publico_v072(uuid)` aplicaba `jsonb_set(..., to_jsonb(v_badge), ...)`. Para un Miembro, que correctamente no tiene insignia KOMBAX, `v_badge` es SQL NULL y el JSON completo podía colapsar a NULL. Club no sufría el fallo porque sí tiene badge.

## Corrección backend
Migración 093 `kombax_member_public_profile_null_badge_fix_20047` aplicada en Supabase real.

- `badge_type` puede ser JSON null sin anular el perfil.
- Miembro conserva `verified=false` y no recibe insignia.
- La privacidad de Relaciones no cambia.
- No se crean ni modifican tablas ni datos de usuario.

### Verificación real
Con sesión `authenticated` simulada y rollback:
- Sheila Azogue: perfil público devuelve objeto válido.
- BRYAN RIVERA GREY: perfil público devuelve objeto válido, banner/avatar por storage path, afiliación confirmada y publicaciones visibles.
- Urban Warriors: perfil público sigue válido, con insignia Club y Showcase.

## Ficha pública Miembro enriquecida
La ficha Miembro mantiene una identidad propia y pública:
- banner;
- avatar;
- presentación/bio pública;
- afiliación confirmada al Club cuando corresponda;
- álbum público propio;
- actividad/publicaciones KOMBAX;
- interacción Social ya existente (likes, comentarios, guardados, reportes, relaciones privadas y Contacto según edad/permisos).

### Álbum Miembro
Gestión directa desde el propio perfil:
- hasta 10 fotografías;
- hasta 3 vídeos;
- máximo 15 s por vídeo;
- avatar y banner no cuentan en el límite;
- retirada de contenido con trazabilidad;
- el álbum es público; las publicaciones restringidas siguen usando el bucket privado separado de 20.046.

## Distinción con Competidor
Miembro enriquecido NO implica perfil Competidor.

Miembro:
- sin insignia KOMBAX;
- sin dossier competitivo avanzado;
- sin verificación deportiva oficial automática.

Competidor verificado añade esas capacidades sobre la continuidad de la misma identidad Social según el diseño 20.044.

## Privacidad y condiciones
Se elimina la derivación incorrecta a `#help` desde:
- Perfil deportivo compartido del alumno.
- Mi perfil personal.

Ahora el botón abre un centro legal dedicado con:
- Condiciones de uso;
- Política de privacidad;
- Normas de Comunidad del Club;
- Derechos de imagen;
- estado de aceptación de la cuenta;
- acceso a privacidad/eliminación de cuenta.

El Perfil deportivo compartido sigue siendo una capa interna del Club y no se convierte automáticamente en información pública de KOMBAX Social.

## Pruebas
- `node --check` módulos modificados: PASS.
- `scripts/test-kombax-20047-member-profile.mjs`: PASS.
- `npm test` completo: PASS.
- `npm run build`: PASS.
- web/dist/Android: 62/62/62 archivos, diff 0.
- SHA-256 agregado independiente de cada árbol: `11795174d9a02cca0b76688a156bb9b811b893254865667032d5b8b70110d424`.
- Android preflight: 4/5. Único pendiente deliberado: firma local/keystore fuera del paquete.
- Archivos sensibles de firma/.env en el paquete: 0.

## Validación visual recomendada
1. Entrar en KOMBAX Social y abrir Sheila por nombre/avatar/tarjeta.
2. Abrir Brian y comprobar banner y avatar históricos.
3. Desde el perfil propio Miembro, abrir `Gestionar álbum` y validar foto/vídeo.
4. Comprobar que el Miembro no muestra insignia KOMBAX.
5. Comprobar que Urban Warriors mantiene su ficha Club completa.
6. Desde Perfil deportivo compartido pulsar `Privacidad y condiciones` y comprobar que abre el centro legal, no el manual.

## No tocado
- GitHub.
- Netlify.
- APK/AAB firmados.
- Google Play.
- reglas de Relaciones privadas.
- hardening 20.046.
