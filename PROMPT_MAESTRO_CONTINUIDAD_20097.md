# PROMPT MAESTRO DE CONTINUIDAD · KOMBAX RC13 build 20.097

Base vigente: KOMBAX RC13 build 20.097 · Events Workspace Isolation.

## Estado
- Supabase 171 y 172 ya aplicadas.
- Frontend 20.097 usa organizadores/invitaciones/gestión/mutaciones contextuales en workspace Club.
- Urban Warriors NO tiene todavía `events.public.organize` en producción para evitar mezcla con una frontend anterior.
- Tras desplegar 20.097, ejecutar `POSTDEPLOY_ENABLE_URBAN_WARRIORS_EVENTS_20097.sql` y validar creación de un evento de prueba como Urban Warriors.
- La Federación QA de la misma cuenta jamás debe aparecer como organizador cuando `state.session.club_id` es Urban Warriors.
- `Mi Club > Eventos` sigue siendo dominio interno separado.
- JKS local incluido en `LOCAL_RELEASE_SIGNING/`; contraseñas no incluidas.

## Próximo gate recomendado
1. Deploy 20.097 a Netlify/kombax.es.
2. Activar entitlement piloto Urban Warriors.
3. Login gestor Urban Warriors → KOMBAX Eventos → confirmar botón Crear evento.
4. Confirmar que selector Organiza como contiene solo Urban Warriors.
5. Crear evento borrador y verificar en DB `creador_tipo=club` y `creador_club_id` Urban Warriors.
6. Confirmar que Federación QA no aparece ni obtiene botones de gestión dentro del workspace Urban Warriors.
7. Generar APK/AAB 20097 tras restaurar firma local.
