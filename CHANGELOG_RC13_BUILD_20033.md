# KOMBAX RC13 · build 20033 · Códigos de acceso por club

- Sustituye las invitaciones individuales 059 por dos códigos reutilizables por club.
- Código **Alumnos/Familias** y código **Equipo**.
- Generación automática de 5 dígitos; Gestor/Coordinación pueden fijar manualmente 4 o 5 dígitos.
- El QR/enlace identifica el club; el código se valida dentro de ese contexto.
- Rotar un código invalida el anterior inmediatamente.
- Código de alumnos conserva la regla 16+ para autorregistro y el flujo de tutor para menores.
- Código de equipo crea una solicitud pendiente; nunca asigna permisos por sí solo.
- Gestor/Coordinación revisan solicitudes; solo Gestor puede conceder Coordinación. Dirección no se concede mediante código.
- Se desactivan las RPC de invitación individual v059 y las invitaciones pendientes anteriores quedan revocadas.
