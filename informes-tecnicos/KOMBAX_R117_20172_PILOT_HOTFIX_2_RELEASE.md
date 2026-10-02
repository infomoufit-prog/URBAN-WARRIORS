# KOMBAX R117 · build 20172 · Pilot Hotfix 2

## Objetivo
Cerrar dos incidencias de onboarding detectadas en fase piloto: (1) no repetir la pantalla de solicitud de perfil a un Miembro ya plenamente configurado y vinculado; (2) capturar fecha de nacimiento privada en la creación de todas las cuentas nuevas para disponer de un contexto de edad canónico y reutilizable.

## Regla de entrada de Miembro
Una cuenta Miembro/Practicante puede crear su Elite Social sin club. Mientras no exista membresía confirmada, mantiene su perfil público/álbum/red pero no publica en el feed. Cuando existe exactamente una membresía de alumno activa, un perfil público Social y la autorización Social correspondiente por edad/consentimiento, el login resuelve automáticamente el club y entra en el espacio de Miembro con su navegación privada. No vuelve a presentar una pantalla de “solicitar perfil”.

Si hay varias membresías o la configuración no está completa, KOMBAX no adivina: conserva el hub para que la persona elija o complete el recorrido.

## Fecha de nacimiento universal de cuenta
Toda cuenta NUEVA, con independencia del perfil previsto (Miembro/Familiar, Espectador, Competidor, Club, Federación, Marca, Profesional o Media/Creador), debe incluir fecha de nacimiento junto con nombre, apellidos, email y contraseña. Es un dato privado de la persona titular de la cuenta, no un dato público de la entidad.

Se almacena en `kombax_account_private_r117`. El trigger de alta de Auth rechaza nuevas cuentas sin fecha o con fecha inválida. La fecha se reutiliza en verificaciones posteriores para evitar volver a pedirla cuando ya está disponible. Las cuentas históricas se rellenan únicamente desde fechas reales ya existentes en ficha de club, perfil privado o identidad de Miembro. Nunca se inventa una fecha.

## Reglas preservadas
- Club Piloto: alta abierta, sin código.
- Código de invitación de Miembro/Familia: vía opcional, no requisito universal.
- Solicitud de vinculación al encontrar el club: disponible sin código; el club aprueba o rechaza.
- La vinculación habilita Mi Club/ficha/cuotas/asistencia/documentos/comunicaciones privadas; no crea una nueva identidad Social.
- Miembro sin club: Elite Social + avatar/banner + bio + álbum + red; sin feed hasta membresía confirmada.
- Espectador: perfil público básico + avatar/banner + red/interacciones permitidas; sin álbum y sin feed.
- Compras/Showcase/Events no dependen de ser miembro de un club; mantienen sus propias reglas de edad y checkout.
- Android: continuidad tras llamadas, multitarea y recreación de Activity preservada desde build 20171.

## Backend canónico añadido
- `307_kombax_account_birthdate_member_entry_r117.sql`
- `308_kombax_birthdate_required_all_new_accounts_r117.sql`

## Versionado
- Release: `2.0.0-rc.13-r117-pilot-hotfix-2`
- Android versionCode: `20172`
- Package: `com.urbanwarriors.app`

## QA exigido
1. Crear cuenta nueva para cada recorrido principal y comprobar que fecha de nacimiento es obligatoria.
2. Confirmar que no se expone fecha de nacimiento en perfil público.
3. Miembro sin club: crear Elite Social/álbum y confirmar bloqueo de publicación.
4. Vincular Miembro mediante solicitud sin código y aprobación del club.
5. Cerrar sesión/entrar de nuevo: Miembro plenamente habilitado debe entrar directamente en su espacio de club.
6. Espectador: no álbum/no feed.
7. Android: llamada, background, bloqueo/desbloqueo y retorno conservando navegación.
