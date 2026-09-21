# Informe de implementación — RC13 build 20036

## Auditoría funcional incorporada al manual
1. Inicio y panel del club.
2. Perfil del club y perfil público.
3. Códigos del club e invitaciones.
4. Solicitudes de inscripción.
5. Alumnos y fichas.
6. Equipo del club, roles y solicitudes.
7. Ámbitos y privacidad de monitores.
8. Disciplinas y grados.
9. Grupos.
10. Sesiones y recurrencia.
11. Asistencia y check-in.
12. Seguimiento.
13. Progreso y evaluaciones.
14. Finanzas, cuotas y cobros.
15. Recibos y justificantes.
16. Avisos de cobro.
17. Comunicaciones y avisos.
18. Eventos.
19. Comunidad del Club.
20. Combat Social / KOMBAX Social.
21. Showcase.
22. Material.
23. Archivo documental.
24. Archivo y papelera.
25. Centro de notificaciones.
26. Configuración, branding y temas.
27. Instalación, PWA y cartel de descarga.
28. Privacidad, condiciones y eliminación.

## Interacción
- Búsqueda instantánea.
- Filtro por bloques.
- Fichas operativas pulsables.
- Modal “Cómo funciona”.
- Paso a paso.
- Reglas y límites.
- Indicador de disponibilidad por rol.
- Deep-link a la pantalla real cuando el rol tiene acceso.
- Responsive para PC/móvil/PWA/Android.

## Recursos sustituidos
El paquete deja de depender de:
- `Manual_Usuario_Urban_Warriors.pdf`
- `Manual_Equipo_Urban_Warriors.pdf`
- galerías `manual-usuario/` y `manual-equipo/`
- `Cartel_Guia_Rapida_Usuarios.png`

Nuevo recurso:
- `web/assets/docs/Cartel_Descarga_KOMBAX_Club.png`

## QA
- Sintaxis módulos modificados: PASS.
- Regresión específica 20036: PASS (28 temas).
- Suite completa heredada: PASS.
