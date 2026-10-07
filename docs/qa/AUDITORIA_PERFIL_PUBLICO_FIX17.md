# FIX17 · Foto y banner públicos · 7 de octubre de 2026

## Resultado y cambios

Moufit, perfil Marca de infomoufit@gmail.com, tiene la modalidad vigente `brand_growth` en prueba manual desde el 7 de octubre hasta el 6 de noviembre de 2026, 06:53 UTC. No se ejecutó Checkout, cargo, renovación ni cambio del catálogo. Referencia administrativa: PILOT-MOUFIT-PREMIUM-20261007. Su verificación continúa `no_iniciada`: la concesión comercial no acredita documentación ni autoriza por sí sola a vender o cobrar. La contratación pública nueva permanece bloqueada.

Tres causas corregidas:

1. La política de Storage exigía tres carpetas; el cargador directo usa usuario/perfil/archivo, es decir, dos. Migración aplicada: `20261007065536_direct_profile_public_media_path_fix17.sql`. Conserva usuario autenticado, prefijo propio y permiso de edición de esa identidad.
2. El repositorio de subida enviaba la variable inexistente `tipo` en vez de `tipo:type`. Fallaba después de subir y antes de registrar la imagen. Corregido en el frontend.
3. La gestión pública de Marca, Federación, Profesional, Media, Competidor y Espectador carecía del acceso a foto/banner y edición. Añadidos en Gestionar perfil. Usan el cargador directo existente y la identidad seleccionada, sin exigir una suscripción para personalizar imágenes. Se conserva la separación respecto del logo/banner administrativo privado.

El álbum vuelve a abrirse después del cierre automático del formulario para permitir subir foto y después banner. Corregida también la interpolación literal del contador de álbum.

## Pruebas ejecutadas

Supabase real, con transacciones revertidas: guardado de avatar y banner de Moufit mediante el RPC autenticado; propagación de ambas rutas al perfil Social; inserción de metadatos Storage con la ruta real del cargador; rechazo del prefijo ajeno y de un perfil ajeno. La prueba reprodujo el rechazo RLS antes de la migración y pasó después. Ninguna foto del usuario fue sustituida ni quedaron objetos QA.

Clubes reales comprobados con sus titulares: Urban Warriors, Sant Pedro urban warrios y Doragon Santa Coloma. También QA-CLUB-001. En los cuatro pasaron las políticas de subida de logo/portada, el guardado por `app_mutate_v160` y la propagación de ambas imágenes al perfil Social. Todas las operaciones de prueba se revirtieron.

Navegador aislado: 20 comprobaciones, seis tipos de perfil, identidad seleccionada entre dos marcas, formulario real de avatar y banner, decodificación de imágenes, repositorio real, refresco, rechazo de archivo inválido y ausencia de gestión para visitantes. Transporte Storage/RPC simulado; no es una subida HTTP autenticada con la sesión del usuario. Evidencia: QA_PERFIL_PUBLICO_FIX17.json.

Compilación: 642 recursos sincronizados web/dist/Android; 376 archivos JavaScript y 903 importaciones compatibles con Linux. No se generó APK/AAB ni se publicó nada.

Regresión enfocada: pasaron las suites de perfil público Club, identidad/membresías R58, acceso a espacios FIX14, documentos públicos R120 (24), operaciones de perfiles R120 (29), acreditación R120 (26), identidad gratuita R112 (12) y edición R113 (12). No se repitió la batería acumulativa completa en este parche.

Tres suites antiguas mostraron fallos heredados: 20045 exige texto literal anterior a traducciones; 20038 exige una traza de versiones antigua; R21 falla dos aserciones de encuadre deportivo/branding. Se ejecutaron sobre los archivos extraídos del ZIP FIX16 y reprodujeron los mismos fallos; no se alteraron para ocultarlos. Evidencia: QA_BASELINE_MEDIA_FIX17.json.

Advisors consultados: 226 avisos informativos de tablas privadas con RLS sin políticas y avisos sobre RPC security-definer (60 anon, 637 authenticated), además de protección de contraseñas filtradas desactivada. No constituyen por sí solos una auditoría completa ni se han atribuido a esta política. Referencias: https://supabase.com/docs/guides/database/database-linter?lint=0008_rls_enabled_no_policy y https://supabase.com/docs/guides/database/database-linter?lint=0028_anon_security_definer_function_executable y https://supabase.com/docs/guides/database/database-linter?lint=0029_authenticated_security_definer_function_executable y https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection.

## Actualización necesaria

La concesión Premium y la corrección RLS ya están en Supabase. Los dos fallos de frontend requieren desplegar este código en Netlify para corregir la web publicada. No se hizo push ni despliegue automático. Si se prueba una APK con recursos incluidos, necesitará recompilarse con estos recursos. El versionCode 20178 ya fue usado: una AAB nueva necesita otro código no utilizado y la firma original.
