# KOMBAX RC13 build 20077 · OWNER SUPPORT MODE VALIDATION

## Objetivo
Permitir al Owner prestar soporte sobre cualquier Club o perfil profesional con su misma cuenta, sin suplantar al cliente ni contaminar equipos/gestores.

## Resultado
- PASS · migración live 140 `kombax_owner_support_mode_20077`.
- PASS · helper de sesión Owner+entidad restringido por `auth.uid`, `session_id`, entidad, expiración y sesión Owner activa.
- PASS · prueba reversible sobre QA-CLUB: `support_active`, `es_miembro_club`, `tiene_rol_club(direccion)`, lifecycle y branding = true.
- PASS · Owner real NO pertenece al club QA: 0 filas antes y 0 filas creadas.
- PASS · prueba reversible sobre Competidor de otra cuenta: gestión admin = true, `manager_role=owner_support`, 0 gestores Owner creados.
- PASS · frontend muestra franja `MODO SOPORTE KOMBAX` y salida explícita.
- PASS · contraseña/propiedad del cliente no se toca.
- PASS · `npm test` completo tras el cambio.

## Modelo de acceso
1. Owner entra por acceso oculto con su correo y contraseña.
2. Busca Club/Marca/Federación/Competidor/cuenta.
3. Indica motivo de soporte (mínimo 10 caracteres).
4. Se abre entity session temporal y auditada.
5. Club: KOMBAX abre módulos ordinarios con contexto de Dirección temporal, sin membresía.
6. Perfil profesional: KOMBAX abre el hub de gestión del perfil objetivo con role `owner_support`, sin cambiar owner/manager.
7. Salir cierra entity session y vuelve a Consola Owner.

## Límites deliberados
- Una cuenta individual se administra desde Owner (estado, membresías, verificaciones, incidencias); no se inicia sesión como el usuario ni se conoce su contraseña.
- OTP continúa reservado a operaciones críticas/destructivas según migración 139.
