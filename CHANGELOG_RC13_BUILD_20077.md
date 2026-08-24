# KOMBAX RC13 build 20077

## Data lifecycle, metrics, consumption and Owner access

- Ciclo de vida global activo/histórico/papelera/eliminación definitiva.
- Paginación/lecturas acotadas para evitar listas y descargas masivas.
- Retención automática y cron diario.
- Métricas agregadas y consumo para KOMBAX Analytics Owner.
- Eliminación definitiva con preview de impacto.
- Acceso Owner cotidiano simplificado: cuenta Owner + contraseña, sesión 30 min.
- OTP reservado a elevación crítica/destructiva.
- Eliminación de cuenta irreversible protegida por `ELIMINAR` + OTP crítico.
- Borrados profundos legacy protegidos por OTP crítico.
- GitHub y Netlify no desplegados.


## Owner Support Mode · migration 140
- Owner conserva su membresía real de Urban Warriors como Dirección/Gestor.
- Cualquier otro Club se abre mediante una sesión de entidad temporal y auditada, sin crear membresía en `miembros_club`.
- El contexto de soporte se presenta visualmente como `MODO SOPORTE KOMBAX` y permite salir de forma explícita.
- El backend trata la sesión de soporte del Club como Dirección únicamente para el Club objetivo y solo mientras la sesión Owner + entity session sigan activas.
- Marca/Federación/Competidor/perfil profesional reciben scope `owner_support` temporal mediante `app_kombax_puede_gestionar_perfil_v070`; no se cambia propietario ni se crea `kombax_perfil_gestores`.
- Showcase reconoce soporte Owner sin insertar al Owner como gestor del proveedor.
- Entrada/salida del workspace deja auditoría privilegiada.
- Cuentas siguen administrándose desde la ficha Owner; no hay suplantación de contraseña/identidad.
