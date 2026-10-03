# KOMBAX R117 · build 20174 · Pilot Hotfix 4

**Release:** `2.0.0-rc.13-r117-pilot-hotfix-4`  
**Android versionCode:** `20174`  
**Package:** `com.urbanwarriors.app`  
**Base empaquetada anterior:** R117 build 20172

## Objetivo
Consolidar el estado real del backend piloto posterior a 20172 y cerrar la auditoría de fricción de onboarding con un modelo progresivo: **crear primero, completar después, verificar solo cuando la capacidad lo requiera**.

## Cambios principales

### Perfil Social
- Terminología canónica: **Perfil Social**. “Elite Social” no es un nombre de producto válido.
- Miembro/Practicante sin Club: Perfil Social, avatar/banner, álbum y red; sin publicación de feed.
- Espectador: Perfil Social básico; sin álbum ni publicación de feed.
- Perfil Social, membresía privada, publicación y verificación siguen siendo capas separadas.

### Alumnos
- Crear/editar ficha sin disciplina ni grupo.
- Disciplina con grupo pendiente también es válida.
- Si se informa grupo sin disciplina, el backend puede deducir la disciplina.
- Editar datos básicos no borra matrículas existentes.

### Preinscripción y vinculación
- Ya no se exige pertenecer a un Club antes de solicitar entrar.
- Crear cuenta no crea una membresía privada prematura.
- La aprobación del Club activa la capa privada.
- Código/invitación permanece como una vía alternativa, no obligatoria.
- Padres/madres/tutores autenticados pueden quedar vinculados tras aprobación del Club sin un segundo código innecesario.

### Club Piloto
- Alta directa sin código, documento inicial o revisión manual.
- Solo nombre del Club + cuenta/email confirmado + declaración son imprescindibles en la ventana piloto.
- Ubicación, disciplinas y teléfono son datos progresivos.

### Profesional
- Puede crear Perfil Social antes de elegir especialidad.
- Si indica especialidad, se valida.
- La verificación profesional conserva los requisitos necesarios para capacidades verificadas.

### UX de errores
- Duplicados/importaciones potenciales ya muestran mensajes humanos y accionables en vez de códigos técnicos.

## Migraciones nuevas en el paquete
- 309 `kombax_member_save_optional_sport_r117`
- 310 `kombax_preenrollment_optional_sport_r117`
- 311 `kombax_progressive_club_enrollment_r117`
- 312 `kombax_pilot_club_minimal_progressive_r117`
- 313 `kombax_member_social_profile_canonical_age_r117`
- 314 `kombax_professional_social_profile_progressive_r117`

## QA de cierre
- R115: 11/11 PASS.
- R116: 12/12 PASS.
- R117 perfiles/alta abierta: 7/7 PASS.
- Build 20174 friction/Perfil Social: 46/46 PASS.
- Build determinista: `web = dist = Android` · 624 archivos.
- Gate Netlify piloto: 63 PASS · 5 P2 históricos documentados · 0 fallos nuevos.
- I18N full product audit: 241 pendientes históricos, sin incremento respecto a la base 20172 después de localizar el copy nuevo de 20174.
- Android preflight: 7/8; único pendiente = firma local/upload key, que deliberadamente no se incluye en el ZIP.

## Netlify
No se desplegó desde el conector disponible porque solo expone `learninglabnexo`, no el sitio KOMBAX. El paquete incluye un CMD que obliga a comprobar `netlify status` y confirmar manualmente **DESPLEGAR** en el sitio correcto.

## Estado
**CONFIRMADO:** código fuente 20174, migraciones 309-314, frontend progresivo, paridad web/dist/Android.  
**PENDIENTE DE VALIDAR EN DISPOSITIVO:** APK/AAB firmado y smoke test real.  
**NO VERIFICADO DESDE ESTE ENTORNO:** deploy real de `kombax.es`, porque el sitio KOMBAX no aparece en la conexión Netlify disponible.
